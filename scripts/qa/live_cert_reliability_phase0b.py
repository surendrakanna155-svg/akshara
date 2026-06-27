#!/usr/bin/env python3
"""Data Reliability Platform — Phase 0b LIVE certification (real VPS).

Proves the deployed backend reliability layer on the live pilot:
  - migration 20260817000000: row_version + bump trigger on the 4 queueable tables
  - universal idempotency wrapper (dispatchWithIdempotency): a retried mutating
    request with the same Idempotency-Key replays EXACTLY ONCE — verified on the
    exam-mark PATCH, a route that had NO idempotency before this deploy
  - inert-without-key: a request without an Idempotency-Key creates no
    request_idempotency row (existing traffic unchanged)
  - optimistic concurrency: a stale expectedVersion → 409 CONFLICT carrying the
    current server row; the correct version applies and bumps row_version

Reuses the live harness (scoped JWTs minted against real seeded sessions, DB
checks over the owner's SSH control-master). Read-only to unrelated data;
self-cleans the mark + idempotency rows it touches.
"""
import json
import os
import subprocess
import time
import uuid

BASE = "https://akshara.veloraunisexsalon.com"
ORG = "a1000000-0000-4000-8000-000000000001"
USER = "a3000000-0000-4000-8000-000000000001"
SCHOOL_A = "a2000000-0000-4000-8000-000000000001"
MARK = "mark_1"
SOCK = os.path.expanduser("~/.ssh/akshara-cm.sock")
TS = str(int(time.time()))

results = []


def rec(check, ok, detail=""):
    results.append((check, bool(ok), detail))
    print(f"  [{'PASS' if ok else 'FAIL':>4}] {check}  {detail}")


def http(method, path, token=None, body=None, headers=None):
    import urllib.request
    import urllib.error
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


def mark_rv():
    return db(f"SELECT row_version FROM exam_mark_entries WHERE id='{MARK}'")


def mark_marks():
    return db(f"SELECT marks_obtained FROM exam_mark_entries WHERE id='{MARK}'")


def cleanup():
    db(f"DELETE FROM request_idempotency WHERE idempotency_key LIKE 'relcert-{TS}%'")
    db(f"UPDATE exam_mark_entries SET marks_obtained=0, marks_entered=false WHERE id='{MARK}'")
    for sid in seeded_sessions:
        db(f"DELETE FROM sessions WHERE id='{sid}'")


print("=== Data Reliability Platform — Phase 0b LIVE certification (real VPS) ===\n")

s, b = http("GET", "/health")
rec("health", s == 200 and d(b).get("status") == "ok", f"HTTP {s}")

# Oversight token (manages marks AND can verify results) → not subject-teacher
# scoped, so the per-teacher exam-session scope check is skipped (realistic for a
# principal/VP). Keeps the cert focused on the reliability behaviour under test.
marks_tok = mint(["manageExamMarks", "verifyExamResults"])
rec("minted oversight manageExamMarks token", bool(marks_tok))
if not marks_tok:
    print("\nABORT: token mint failed (JWT_SECRET?).")
    raise SystemExit(1)

try:
    print("\n-- Migration 20260817000000: row_version + bump trigger deployed --")
    rec("row_version on all 4 queueable tables",
        db("SELECT count(*) FROM information_schema.columns WHERE column_name='row_version' "
           "AND table_name IN ('exam_mark_entries','finance_collections','mobile_leave_requests','attendance_corrections')") == "4")
    rec("bump_row_version trigger on all 4 tables",
        db("SELECT count(*) FROM pg_trigger WHERE tgname LIKE '%_row_version' AND NOT tgisinternal") == "4")
    rec("bump_row_version() function present",
        db("SELECT count(*) FROM pg_proc WHERE proname='bump_row_version'") == "1")
    rec("request_idempotency table present (reused by the universal wrapper)",
        db("SELECT count(*) FROM information_schema.tables WHERE table_name='request_idempotency'") == "1")

    print("\n-- Inert without an Idempotency-Key: existing traffic is unchanged --")
    db(f"UPDATE exam_mark_entries SET marks_obtained=0, marks_entered=false WHERE id='{MARK}'")
    idem_before = db("SELECT count(*) FROM request_idempotency")
    rv0 = int(mark_rv())
    s, b = http("PATCH", f"/academics/exams/marks/{MARK}", token=marks_tok,
                body={"marksObtained": 11})
    idem_after = db("SELECT count(*) FROM request_idempotency")
    rec("keyless PATCH succeeds (200) and applies", s == 200 and d(b).get("marksObtained") == 11, f"HTTP {s}")
    rec("keyless PATCH creates NO request_idempotency row (wrapper inert)",
        idem_after == idem_before, f"before={idem_before} after={idem_after}")
    rec("keyless update bumps row_version via trigger",
        int(mark_rv()) == rv0 + 1, f"{rv0} -> {mark_rv()}")
    rec("server response carries rowVersion for the client to capture",
        d(b).get("rowVersion") == rv0 + 1, f"rowVersion={d(b).get('rowVersion')}")

    print("\n-- Universal idempotency: a retried write with the same key replays EXACTLY ONCE --")
    KEY = f"relcert-{TS}-idem"
    s1, b1 = http("PATCH", f"/academics/exams/marks/{MARK}", token=marks_tok,
                  body={"marksObtained": 33}, headers={"Idempotency-Key": KEY})
    rv_after_first = int(mark_rv())
    # Retry with the SAME key but a DIFFERENT value — it must replay the first
    # response and NOT apply the new value (the lost-ack / offline-replay case).
    s2, b2 = http("PATCH", f"/academics/exams/marks/{MARK}", token=marks_tok,
                  body={"marksObtained": 44}, headers={"Idempotency-Key": KEY})
    icnt = db(f"SELECT count(*) FROM request_idempotency WHERE idempotency_key='{KEY}'")
    rec("first keyed PATCH applied (marks=33)", s1 == 200 and d(b1).get("marksObtained") == 33, f"HTTP {s1}")
    rec("exactly ONE request_idempotency row recorded for the key (wrapper engaged on a route with no prior idempotency)",
        icnt == "1", f"rows={icnt}")
    rec("retry REPLAYS the first response (marks still 33, not 44)",
        s2 == 200 and d(b2).get("marksObtained") == 33, f"HTTP {s2} marks={d(b2).get('marksObtained')}")
    rec("retry did NOT write again — DB value unchanged (exactly-once)",
        mark_marks() == "33", f"db marks={mark_marks()}")
    rec("retry did NOT bump row_version again (no second write)",
        int(mark_rv()) == rv_after_first, f"{rv_after_first} -> {mark_rv()}")

    print("\n-- Optimistic concurrency: stale expectedVersion → 409 CONFLICT with the current row --")
    cur = int(mark_rv())
    s, b = http("PATCH", f"/academics/exams/marks/{MARK}", token=marks_tok,
                body={"marksObtained": 25, "expectedVersion": cur - 1})
    rec("stale expectedVersion rejected with 409", s == 409, f"HTTP {s}")
    rec("409 carries error.code=CONFLICT",
        isinstance(b, dict) and (b.get("error") or {}).get("code") == "CONFLICT")
    rec("409 body carries the current server row (rowVersion) for resolution",
        d(b).get("rowVersion") == cur, f"server rowVersion={d(b).get('rowVersion')}")
    rec("conflict did NOT mutate the row (marks still 33)", mark_marks() == "33", f"db marks={mark_marks()}")
    # Correct version applies and bumps.
    s, b = http("PATCH", f"/academics/exams/marks/{MARK}", token=marks_tok,
                body={"marksObtained": 25, "expectedVersion": cur})
    rec("correct expectedVersion applies (200) and bumps row_version",
        s == 200 and d(b).get("marksObtained") == 25 and d(b).get("rowVersion") == cur + 1,
        f"HTTP {s} rowVersion={d(b).get('rowVersion')}")
finally:
    cleanup()

passed = sum(1 for _, ok, _ in results if ok)
total = len(results)
print(f"\n=== RESULT: {passed}/{total} checks passed ===")
raise SystemExit(0 if passed == total else 1)
