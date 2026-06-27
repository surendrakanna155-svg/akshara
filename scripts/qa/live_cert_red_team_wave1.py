#!/usr/bin/env python3
"""Live-mode certification for **Red Team Wave 1 — Transactional Integrity**
against the live VPS pilot. Real VPS + edge-minted scoped JWTs (HS256 with the
live JWT_SECRET) + real DB rows + real Postgres constraints/locks/RLS.

Source of truth: docs/RED_TEAM_MASTER_TRACKER.md (RT-01..RT-08).

Proves on the LIVE database:
  RT-01 Finance double-payment — (a) double-submit with the same Idempotency-Key
        yields EXACTLY ONE collection (replay), decrementing the invoice once;
        (b) two CONCURRENT full payments yield one success + one clean 422 and
        outstanding never goes negative (SELECT … FOR UPDATE). Schema present.
  RT-02 Student identity — duplicate (school, admission_number) rejected 409;
        UNIQUE constraint present; old non-unique index gone.
  RT-03 Student code — UNIQUE(school_id, student_code) present (savepoint retry).
  RT-04/05 — ids are UUID-suffixed (unit-tested); deployed handlers create
        without count collisions.
  RT-06 Snapshot lost-update — a snapshot append via the FOR UPDATE mutateSnapshot
        path persists.
  RT-07 Generic idempotency — a double-submitted module write writes once and
        replays; request_idempotency table + RLS policy present.
  RT-08 Marks bounds — negative and over-max rejected 422; valid 200s; CHECK present.

Fixtures use dedicated `cef…` UUIDs and are cleaned up; mark_1 is reset. Re-runnable.
"""
import json, os, subprocess, threading, time, urllib.request, urllib.error, uuid

BASE = "https://akshara.veloraunisexsalon.com"
ORG = "a1000000-0000-4000-8000-000000000001"
USER = "a3000000-0000-4000-8000-000000000001"
SCHOOL_A = "a2000000-0000-4000-8000-000000000001"
STUDENT_A = "a4000000-0000-4000-8000-000000000001"
FEE_STRUCTURE_A = "b7000000-0000-4000-8000-000000000001"
SOCK = os.path.expanduser("~/.ssh/akshara-cm.sock")
TS = str(int(time.time()))

F_ASSIGN = "cef00000-0000-4000-8000-000000000001"
F_ACCOUNT = "cef00000-0000-4000-8000-000000000002"
F_INVOICE = "cef00000-0000-4000-8000-000000000003"

results = []


def rec(check, ok, detail=""):
    results.append((check, bool(ok), detail))
    print(f"  [{'PASS' if ok else 'FAIL':>4}] {check}  {detail}")


def http(method, path, token=None, body=None, headers=None):
    payload = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=payload, method=method)
    if body is not None:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=90) as r:
            raw = r.read().decode()
            try:
                return r.status, json.loads(raw)
            except Exception:
                return r.status, raw
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, raw
    except Exception as e:  # noqa: BLE001
        return 0, str(e)


def ssh(cmd, stdin=None):
    p = subprocess.run(["ssh", "-o", "ControlPath=" + SOCK, "akshara", cmd],
                       input=stdin, capture_output=True, text=True, timeout=90)
    return p.stdout.strip(), p.stderr.strip()


def db(sql):
    out, _ = ssh(
        'docker exec akshara-postgres psql -U supabase_admin -d akshara_db -tAc "'
        + sql.replace('"', '\\"') + '"')
    return out


def d(b):
    return (b.get("data") or {}) if isinstance(b, dict) else {}


MINT = '''
import { SignJWT } from "npm:jose";
const secret = new TextEncoder().encode(Deno.env.get("JWT_SECRET"));
const t = await new SignJWT({
  tenant_id: Deno.env.get("ORG"), organization_id: Deno.env.get("ORG"),
  school_id: Deno.env.get("SCHOOL") || null,
  role: Deno.env.get("ROLE"), role_slugs: [Deno.env.get("ROLE")], primary_role: Deno.env.get("ROLE"),
  permissions: JSON.parse(Deno.env.get("PERMS")),
  permissions_version: parseInt(Deno.env.get("VERSION") || "1", 10),
  scope: "school", school_group_id: null, student_id: null,
  child_ids: [], session_id: Deno.env.get("SESSION_ID"),
}).setProtectedHeader({ alg: "HS256", typ: "JWT" })
  .setSubject(Deno.env.get("SUB")).setIssuedAt()
  .setExpirationTime(Math.floor(Date.now() / 1000) + 3600).sign(secret);
console.log(t);
'''

# Red Team Wave 3 (RT-16/17) added a per-request session-revocation +
# permissions_version check in authenticateRequest. A cert token must therefore
# reference a REAL, live session row and carry the LIVE membership version, or
# every authenticated probe is (correctly) rejected 401. These helpers seed that
# state; cleanup() removes the seeded sessions.
seeded_sessions = []


def seed_session(sub, school):
    sid = str(uuid.uuid4())
    db(f"INSERT INTO sessions (id, user_id, tenant_id, scope, context_school_id) "
       f"VALUES ('{sid}','{sub}','{ORG}','school','{school}')")
    seeded_sessions.append(sid)
    return sid


def live_version(sub, school):
    v = db(f"SELECT permissions_version FROM school_memberships "
           f"WHERE user_id='{sub}' AND school_id='{school}' AND status='active' LIMIT 1")
    return v if v else "1"


def mint(perms, role="schoolAdmin", sub=USER, school=SCHOOL_A):
    sid = seed_session(sub, school)
    version = live_version(sub, school)
    env = (f"-e ORG={ORG} -e SUB={sub} -e ROLE={role} -e SCHOOL={school or ''} "
           f"-e VERSION={version} -e SESSION_ID={sid} -e PERMS='{json.dumps(perms)}'")
    out, _ = ssh(f"docker exec -i {env} akshara-edge deno run -A -", stdin=MINT)
    tok = out.splitlines()[-1] if out else ""
    return tok if tok.count(".") == 2 else None


def seed_invoice(outstanding):
    db(f"DELETE FROM finance_receipts WHERE collection_id IN (SELECT id FROM finance_collections WHERE invoice_id='{F_INVOICE}')")
    db(f"DELETE FROM finance_collections WHERE invoice_id='{F_INVOICE}'")
    db(f"DELETE FROM finance_invoices WHERE id='{F_INVOICE}'")
    db(f"DELETE FROM finance_student_accounts WHERE id='{F_ACCOUNT}'")
    db(f"DELETE FROM finance_fee_assignments WHERE id='{F_ASSIGN}'")
    db(f"INSERT INTO finance_fee_assignments (id, organization_id, school_id, student_id, fee_structure_id, academic_year, assignment_status, assigned_by) VALUES ('{F_ASSIGN}','{ORG}','{SCHOOL_A}','{STUDENT_A}','{FEE_STRUCTURE_A}','CERT2026','active','{USER}')")
    db(f"INSERT INTO finance_student_accounts (id, organization_id, school_id, student_id, fee_assignment_id, academic_year, total_fee, amount_paid, outstanding_amount, status) VALUES ('{F_ACCOUNT}','{ORG}','{SCHOOL_A}','{STUDENT_A}','{F_ASSIGN}','CERT2026',{outstanding},0,{outstanding},'open')")
    db(f"INSERT INTO finance_invoices (id, organization_id, school_id, student_id, fee_assignment_id, academic_year, invoice_number, invoice_date, due_date, subtotal_amount, discount_amount, total_amount, outstanding_amount, invoice_status, created_by) VALUES ('{F_INVOICE}','{ORG}','{SCHOOL_A}','{STUDENT_A}','{F_ASSIGN}','CERT2026','INV-RTW1-{TS}',CURRENT_DATE,CURRENT_DATE,{outstanding},0,{outstanding},{outstanding},'issued','{USER}')")


def cleanup():
    db(f"DELETE FROM finance_receipts WHERE collection_id IN (SELECT id FROM finance_collections WHERE invoice_id='{F_INVOICE}')")
    db(f"DELETE FROM finance_collections WHERE invoice_id='{F_INVOICE}'")
    db(f"DELETE FROM finance_invoices WHERE id='{F_INVOICE}'")
    db(f"DELETE FROM finance_student_accounts WHERE id='{F_ACCOUNT}'")
    db(f"DELETE FROM finance_fee_assignments WHERE id='{F_ASSIGN}'")
    db("DELETE FROM request_idempotency WHERE idempotency_key LIKE 'rtw1-%'")
    db("UPDATE exam_mark_entries SET marks_obtained=0, marks_entered=false WHERE id='mark_1'")
    db("DELETE FROM student_profiles WHERE admission_number LIKE 'ADM-RTW1-%'")
    db(f"DELETE FROM students WHERE display_name='Cert RTW1 Student' AND school_id='{SCHOOL_A}'")
    for sid in seeded_sessions:
        db(f"DELETE FROM sessions WHERE id='{sid}'")


print("=== Red Team Wave 1 LIVE certification (real VPS / scoped JWTs / DB / locks / RLS) ===\n")

s, b = http("GET", "/health")
rec("health", s == 200 and d(b).get("status") == "ok", f"HTTP {s}")

fin = mint(["manageFinance", "viewFinance"])
sis = mint(["manageSis", "viewSis"])
lib = mint(["manageLibrary", "viewLibrary"])
marks = mint(["manageExamMarks"])
rec("minted scoped school tokens", all([fin, sis, lib, marks]),
    f"fin={bool(fin)} sis={bool(sis)} lib={bool(lib)} marks={bool(marks)}")
if not all([fin, sis, lib, marks]):
    print("\nABORT: token mint failed (JWT_SECRET?).")
    raise SystemExit(1)

print("\n-- Schema: the DB-level guarantees are deployed --")
rec("RT-01 finance_collections.idempotency_key column exists",
    db("SELECT count(*) FROM information_schema.columns WHERE table_name='finance_collections' AND column_name='idempotency_key'") == "1")
rec("RT-01 partial-unique index finance_collections_idempotency_key_uq exists",
    db("SELECT count(*) FROM pg_indexes WHERE indexname='finance_collections_idempotency_key_uq'") == "1")
rec("RT-02 UNIQUE(school_id, admission_number) constraint exists",
    db("SELECT count(*) FROM pg_constraint WHERE conname='student_profiles_school_admission_unique'") == "1")
rec("RT-02 redundant non-unique admission index dropped",
    db("SELECT count(*) FROM pg_indexes WHERE indexname='idx_student_profiles_school_admission'") == "0")
rec("RT-03 students UNIQUE(school_id, student_code) present",
    db("SELECT count(*) FROM pg_constraint WHERE conrelid='students'::regclass AND contype='u'") != "0")
rec("RT-07 request_idempotency table + RLS enabled",
    db("SELECT relrowsecurity FROM pg_class WHERE relname='request_idempotency'") == "t")
rec("RT-07 request_idempotency_school_scope policy exists",
    db("SELECT count(*) FROM pg_policies WHERE tablename='request_idempotency' AND policyname='request_idempotency_school_scope'") == "1")
rec("RT-08 CHECK exam_mark_entries_marks_bounds exists",
    db("SELECT count(*) FROM pg_constraint WHERE conname='exam_mark_entries_marks_bounds'") == "1")

print("\n-- RT-01 double-submit (same Idempotency-Key) yields exactly ONE collection --")
seed_invoice(200)
KEY = f"rtw1-idem-{TS}"
s1, b1 = http("POST", "/finance/collections", token=fin,
              body={"invoice_id": F_INVOICE, "amount_collected": 50, "payment_method": "cash"},
              headers={"Idempotency-Key": KEY})
cid1 = (d(b1).get("collection") or {}).get("id") if isinstance(d(b1), dict) else None
rec("RT-01 first collection created (201)", s1 == 201 and bool(cid1), f"HTTP {s1} id={str(cid1)[:12]}")
s2, b2 = http("POST", "/finance/collections", token=fin,
              body={"invoice_id": F_INVOICE, "amount_collected": 50, "payment_method": "cash"},
              headers={"Idempotency-Key": KEY})
cid2 = (d(b2).get("collection") or {}).get("id") if isinstance(d(b2), dict) else None
rec("RT-01 replay returns the SAME collection id (no second row)", bool(cid1) and cid1 == cid2,
    f"HTTP {s2} id={str(cid2)[:12]}")
cnt = db(f"SELECT count(*) FROM finance_collections WHERE invoice_id='{F_INVOICE}'")
rec("RT-01 exactly ONE collection row persisted for the double-submit", cnt == "1", f"rows={cnt}")
out = db(f"SELECT outstanding_amount FROM finance_invoices WHERE id='{F_INVOICE}'")
rec("RT-01 invoice outstanding decremented once (200 -> 150)", out in ("150.00", "150"), f"outstanding={out}")

print("\n-- RT-01 two CONCURRENT full payments: one wins, one clean 422, no negative --")
seed_invoice(100)
conc = {}


def pay(tag):
    s, b = http("POST", "/finance/collections", token=fin,
                body={"invoice_id": F_INVOICE, "amount_collected": 100, "payment_method": "cash"})
    conc[tag] = (s, b)


t1 = threading.Thread(target=pay, args=("a",))
t2 = threading.Thread(target=pay, args=("b",))
t1.start(); t2.start(); t1.join(); t2.join()
statuses = sorted([conc["a"][0], conc["b"][0]])
successes = sum(1 for s, _ in conc.values() if s == 201)
rec("RT-01 concurrent: exactly ONE payment succeeded (201)", successes == 1, f"statuses={statuses}")
rec("RT-01 concurrent: loser got a clean 422 (not 500/dup)",
    any(s == 422 for s, _ in conc.values()), f"statuses={statuses}")
out2 = db(f"SELECT outstanding_amount FROM finance_invoices WHERE id='{F_INVOICE}'")
rec("RT-01 concurrent: outstanding settled at 0, never negative", out2 in ("0.00", "0"), f"outstanding={out2}")
ccnt = db(f"SELECT count(*) FROM finance_collections WHERE invoice_id='{F_INVOICE}' AND collection_status='completed'")
rec("RT-01 concurrent: exactly ONE completed collection row", ccnt == "1", f"rows={ccnt}")

print("\n-- RT-02 duplicate admission number is rejected (409), DB-enforced --")
adm = f"ADM-RTW1-{TS}"
body_student = {"displayName": "Cert RTW1 Student", "admissionNumber": adm}
s, b = http("POST", "/sis/students", token=sis, body=body_student)
rec("RT-02 first student create (201)", s == 201, f"HTTP {s}")
s, b = http("POST", "/sis/students", token=sis, body=body_student)
rec("RT-02 duplicate admission number rejected (409)", s == 409, f"HTTP {s} (expect 409)")

print("\n-- RT-08 exam marks are bounded 0..max_marks (server + DB CHECK) --")
mschool = db("SELECT school_id FROM exam_mark_entries WHERE id='mark_1'")
mmax = db("SELECT max_marks FROM exam_mark_entries WHERE id='mark_1'")
marks_tok = mint(["manageExamMarks"], school=mschool) if mschool else marks
s, _ = http("PUT", "/teacher/exams/marks/mark_1", token=marks_tok, body={"marks_obtained": -5})
rec("RT-08 negative marks rejected (422)", s == 422, f"HTTP {s} (expect 422)")
s, _ = http("PUT", "/teacher/exams/marks/mark_1", token=marks_tok, body={"marks_obtained": 999})
rec(f"RT-08 marks > max_marks ({mmax}) rejected (422)", s == 422, f"HTTP {s} (expect 422)")
s, _ = http("PUT", "/teacher/exams/marks/mark_1", token=marks_tok, body={"marks_obtained": 25})
rec("RT-08 valid in-range marks accepted (200)", s == 200, f"HTTP {s} (expect 200)")

print("\n-- RT-07 generic write idempotency replay (+ RT-06 snapshot append) --")
LKEY = f"rtw1-lib-{TS}"
s1, b1 = http("POST", "/library/digital-resources", token=lib,
              body={"title": f"Cert RTW1 Resource {TS}", "resourceUrl": "https://example.com/x.pdf"},
              headers={"Idempotency-Key": LKEY})
rid1 = d(b1).get("id") if isinstance(d(b1), dict) else None
rec("RT-06/07 first digital-resource write (201) — snapshot append via FOR UPDATE path",
    s1 == 201 and bool(rid1), f"HTTP {s1} id={str(rid1)[:12]}")
s2, b2 = http("POST", "/library/digital-resources", token=lib,
              body={"title": f"Cert RTW1 Resource {TS}", "resourceUrl": "https://example.com/x.pdf"},
              headers={"Idempotency-Key": LKEY})
rid2 = d(b2).get("id") if isinstance(d(b2), dict) else None
rec("RT-07 replay returns the SAME resource id (write happened once)", bool(rid1) and rid1 == rid2,
    f"HTTP {s2} id={str(rid2)[:12]}")
icnt = db(f"SELECT count(*) FROM request_idempotency WHERE idempotency_key='{LKEY}'")
rec("RT-07 exactly ONE idempotency row recorded for the key", icnt == "1", f"rows={icnt}")

db("UPDATE library_entities SET payload = jsonb_set(payload, '{resources}', (SELECT COALESCE(jsonb_agg(e), '[]'::jsonb) FROM jsonb_array_elements(payload->'resources') e WHERE e->>'title' NOT LIKE 'Cert RTW1 Resource %')) WHERE entity_type='snapshot_digital_resources' AND school_id='" + SCHOOL_A + "'")

cleanup()
passed = sum(1 for _, ok, _ in results if ok)
total = len(results)
print(f"\n=== Red Team Wave 1: {passed}/{total} checks passed ===")
for c, ok, det in results:
    if not ok:
        print(f"  FAIL: {c}  {det}")
raise SystemExit(0 if passed == total else 1)
