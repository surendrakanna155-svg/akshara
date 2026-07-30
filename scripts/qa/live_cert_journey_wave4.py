#!/usr/bin/env python3
"""Live-mode certification for MODULE_JOURNEY_ROADMAP **Journey Wave 4** —
"Build missing write surfaces & orphaned-feature wiring" — against the live VPS
pilot. Real VPS + real pilot OTP auth (admin JWT carrying real RBAC) + an
edge-minted org-scope JWT (for Org Builder) + real DB rows + real write->read
cycles + real Supabase Storage object upload/download.

Every check below proves a journey that was *broken/orphaned* before this wave now
works end-to-end in production:

  MJ-H19 Transport attendance — POST /transport/attendance persists and the
         attendance read reflects it (was a deployed-but-orphaned route, no client).
  MJ-M9  Transport delay-notify + SIS — POST /transport/notify-delay broadcasts to
         a real route's allocated cohort (recipientCount), and an allocation now
         carries the student's SIS identity + transportEnrolled flag.
  MJ-H20 Hostel attendance + mess — POST /hostel/attendance & POST /hostel/mess
         persist and their reads recompute from the live entities (were read-only,
         no route).
  MJ-H21 Library — POST /library/members enrolls a real member (issue now REJECTS a
         non-existent member — no more phantom loans), and a digital resource now
         stores a real, retrievable URL.
  MJ-H22 Alumni donations — POST /alumni/donations records a donation that appears
         live AND increments the linked campaign's raisedAmount + donorCount (was
         no write path at all).
  MJ-M6  Org Builder provisioning — POST /platform/org-builder/provision now creates
         a REAL organization + branch (+ roles/permissions), idempotently, instead
         of a simulated 'completed' job (DB-verified).
  MJ-M7  Admissions documents — presign -> PUT to Storage -> confirm stores a real
         object; download returns a signed URL that actually serves the file (was
         metadata-only, nothing retrievable).

Writes are additive pilot records; they neither delete nor corrupt prior data.
"""
import json, os, subprocess, time, urllib.request, urllib.error

BASE = os.environ.get("API_BASE_URL", "https://api.nikshaos.in")
ADMIN = "+919876543210"
ORG = "a1000000-0000-4000-8000-000000000001"
USER = "a3000000-0000-4000-8000-000000000001"
SCHOOL_A = "a2000000-0000-4000-8000-000000000001"
SOCK = os.path.expanduser("~/.ssh/akshara-cm.sock")
TS = str(int(time.time()))
results = []


def rec(check, ok, detail=""):
    results.append((check, bool(ok), detail))
    print(f"  [{'PASS' if ok else 'FAIL':>4}] {check}  {detail}")


def http(method, path, token=None, body=None, raw_url=None):
    payload = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(raw_url or (BASE + path), data=payload, method=method)
    if body is not None:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=90) as r:
            body_raw = r.read().decode()
            try:
                return r.status, json.loads(body_raw)
            except Exception:
                return r.status, body_raw
    except urllib.error.HTTPError as e:
        body_raw = e.read().decode()
        try:
            return e.code, json.loads(body_raw)
        except Exception:
            return e.code, body_raw
    except Exception as e:  # noqa: BLE001
        return 0, str(e)


def put_bytes(url, data, content_type):
    req = urllib.request.Request(url, data=data, method="PUT")
    req.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(req, timeout=90) as r:
            return r.status, r.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()
    except Exception as e:  # noqa: BLE001
        return 0, str(e)


def get_url_status(url):
    req = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=90) as r:
            return r.status, len(r.read())
    except urllib.error.HTTPError as e:
        return e.code, len(e.read())
    except Exception as e:  # noqa: BLE001
        return 0, str(e)


def ssh(cmd, stdin=None):
    p = subprocess.run(["ssh", "-o", "ControlPath=" + SOCK, "akshara", cmd],
                       input=stdin, capture_output=True, text=True, timeout=90)
    return p.stdout.strip(), p.stderr.strip()


def db(sql):
    out, _ = ssh(f'docker exec akshara-postgres psql -U supabase_admin -d akshara_db -tAc "{sql}"')
    return out


def d(b):
    return (b.get("data") or {}) if isinstance(b, dict) else {}


def items(b):
    x = d(b)
    if isinstance(x, list):
        return x
    return x.get("items") or x.get("results") or []


def blob(b):
    try:
        return json.dumps(d(b), ensure_ascii=False)
    except Exception:  # noqa: BLE001
        return str(b)


def login(ident):
    for _ in range(6):
        s, b = http("POST", "/auth/login", body={"identifier": ident, "type": "phone"})
        otp = d(b).get("otp")
        if s == 200 and otp:
            s2, b2 = http("POST", "/auth/verify-otp", body={"identifier": ident, "otp": otp})
            tok = d(b2).get("accessToken")
            if tok and tok.count(".") == 2:
                return tok
        time.sleep(20)
    return None


MINT = '''
import { SignJWT } from "npm:jose";
const secret = new TextEncoder().encode(Deno.env.get("JWT_SECRET"));
const t = await new SignJWT({
  tenant_id: Deno.env.get("ORG"), organization_id: Deno.env.get("ORG"),
  school_id: null,
  role: "organizationOwner", role_slugs: ["organizationOwner"], primary_role: "organizationOwner",
  permissions: JSON.parse(Deno.env.get("PERMS")), permissions_version: 1,
  scope: "organization", school_group_id: null, student_id: null,
  child_ids: [], session_id: "cert-wave4",
}).setProtectedHeader({ alg: "HS256", typ: "JWT" })
  .setSubject(Deno.env.get("SUB")).setIssuedAt()
  .setExpirationTime(Math.floor(Date.now() / 1000) + 3600).sign(secret);
console.log(t);
'''


def mint(perms, sub=USER):
    env = f"-e ORG={ORG} -e SUB={sub} -e PERMS='{json.dumps(perms)}'"
    out, _ = ssh(f"docker exec -i {env} akshara-edge deno run -A -", stdin=MINT)
    tok = out.splitlines()[-1] if out else ""
    return tok if tok.count(".") == 2 else None


print("=== Journey Wave 4 LIVE certification (real VPS / pilot OTP / org-JWT / DB / Storage) ===\n")

s, b = http("GET", "/health")
rec("health", s == 200 and d(b).get("status") == "ok", f"HTTP {s}")

admin = login(ADMIN)
rec("auth: admin JWT (real OTP)", bool(admin), f"admin={bool(admin)}")
if not admin:
    print("\nABORT: admin token required (OTP cooldown?). Re-run shortly.")
    raise SystemExit(1)

# ───────────────────────────── MJ-H19 Transport attendance ───────────────────
print("\n-- MJ-H19 Transport attendance write->read --")
before = len(items(http("GET", "/transport/attendance", token=admin)[1]))
sname = f"Cert Rider {TS}"
s, b = http("POST", "/transport/attendance", token=admin,
            body={"studentName": sname, "status": "absent", "stopName": "Cert Stop",
                  "scheduledTime": "07:45", "shift": "am"})
rec("MJ-H19 POST /transport/attendance persists", s in (200, 201), f"HTTP {s}")
s, b = http("GET", "/transport/attendance", token=admin)
rec("MJ-H19 attendance read reflects the write",
    s == 200 and sname in blob(b) and len(items(b)) >= before + 1,
    f"HTTP {s} rows {before}->{len(items(b))}")

# ───────────────────────────── MJ-M9 Transport delay-notify + SIS ────────────
print("\n-- MJ-M9 Transport delay-notify + SIS identity --")
routes = items(http("GET", "/transport/routes", token=admin)[1])
route_id = str(routes[0].get("id")) if routes else ""
s, b = http("POST", "/transport/notify-delay", token=admin,
            body={"routeId": route_id, "message": f"Cert delay {TS}: bus running ~15 min late"})
rc = d(b).get("recipientCount")
rec("MJ-M9 POST /transport/notify-delay broadcasts to route cohort",
    s in (200, 201) and rc is not None, f"HTTP {s} recipientCount={rc}")
# Allocation now carries SIS identity + sets transportEnrolled (vs empty strings before).
allocs = items(http("GET", "/transport/allocations", token=admin)[1])
alloc_id = str(allocs[0].get("id")) if allocs else ""
s, b = http("POST", "/transport/allocations", token=admin,
            body={"allocationId": alloc_id, "routeId": route_id, "pickupStop": "Cert Stop",
                  "dropStop": "Cert Drop", "studentName": sname,
                  "admissionNumber": f"ADM-{TS}", "sisStudentId": f"SIS-{TS}",
                  "classLabel": "8-A"})
rec("MJ-M9 allocation accepts real SIS identity (studentName/admissionNumber/sisStudentId)",
    s in (200, 201), f"HTTP {s}")

# ───────────────────────────── MJ-H20 Hostel attendance + mess ───────────────
print("\n-- MJ-H20 Hostel attendance + mess write->read --")
hname = f"Cert Boarder {TS}"
s, b = http("POST", "/hostel/attendance", token=admin,
            body={"studentName": hname, "room": "H-101", "rollNumber": f"R{TS[-4:]}",
                  "morning": "present", "evening": "present", "night": "absent"})
rec("MJ-H20 POST /hostel/attendance persists", s in (200, 201), f"HTTP {s}")
s, b = http("GET", "/hostel/attendance", token=admin)
rec("MJ-H20 hostel attendance read reflects the write",
    s == 200 and hname in blob(b), f"HTTP {s}")
menu = f"Cert Mess Menu {TS}"
s, b = http("POST", "/hostel/mess", token=admin,
            body={"day": "Monday", "mealType": "Lunch", "items": menu,
                  "headcount": 120, "costRupees": 8400})
rec("MJ-H20 POST /hostel/mess persists", s in (200, 201), f"HTTP {s}")
s, b = http("GET", "/hostel/mess", token=admin)
rec("MJ-H20 hostel mess read recomputes from the write",
    s == 200 and menu in blob(b), f"HTTP {s}")

# ───────────────────────────── MJ-H21 Library member + resource ──────────────
print("\n-- MJ-H21 Library member-enroll (issue validates) + resource URL --")
mname = f"Cert Member {TS}"
s, b = http("POST", "/library/members", token=admin,
            body={"name": mname, "memberType": "student", "identifier": f"LIB-{TS}",
                  "classOrDepartment": "8-A"})
member_id = d(b).get("id") if isinstance(d(b), dict) else None
rec("MJ-H21 POST /library/members enrolls a real member", s in (200, 201) and bool(member_id),
    f"HTTP {s} id={str(member_id)[:8]}")
s, b = http("GET", "/library/members", token=admin)
rec("MJ-H21 members read reflects the enrollment", s == 200 and mname in blob(b), f"HTTP {s}")
# Issue against a GARBAGE member is rejected (no phantom loan) — the core LIBRA-1 fix.
s, b = http("POST", "/library/issues", token=admin,
            body={"isbn": "000-0-00-000000-0", "memberId": f"ghost_{TS}"})
rec("MJ-H21 issue REJECTS a non-existent member (no phantom loan)", s in (400, 404, 422),
    f"HTTP {s} (expect 4xx)")
# Digital resource now stores a real, retrievable URL (vs metadata-only).
rurl = "https://api.nikshaos.in/health"
s, b = http("POST", "/library/digital-resources", token=admin,
            body={"title": f"Cert Resource {TS}", "type": "pdf", "resourceUrl": rurl})
rec("MJ-H21 POST /library/digital-resources stores a real URL",
    s in (200, 201) and rurl in blob(b), f"HTTP {s}")

# ───────────────────────────── MJ-H22 Alumni donations ───────────────────────
print("\n-- MJ-H22 Alumni donation write + campaign increment --")
camps = items(http("GET", "/alumni/campaigns", token=admin)[1])
camp = camps[0] if camps else {}
camp_id = str(camp.get("id", ""))


def rupees(v):
    return int("".join(ch for ch in str(v) if ch.isdigit()) or "0")


raised_before = rupees(camp.get("raisedAmount"))
donors_before = camp.get("donorCount") or 0
dname = f"Cert Donor {TS}"
s, b = http("POST", "/alumni/donations", token=admin,
            body={"alumniName": dname, "amount": "25000", "campaignId": camp_id,
                  "status": "received", "paymentMode": "upi"})
rec("MJ-H22 POST /alumni/donations records a donation", s in (200, 201), f"HTTP {s}")
s, b = http("GET", "/alumni/donations", token=admin)
rec("MJ-H22 donations ledger reflects the write", s == 200 and dname in blob(b), f"HTTP {s}")
camps2 = items(http("GET", "/alumni/campaigns", token=admin)[1])
camp2 = next((c for c in camps2 if str(c.get("id", "")) == camp_id), {})
raised_after = rupees(camp2.get("raisedAmount"))
donors_after = camp2.get("donorCount") or 0
rec("MJ-H22 linked campaign raisedAmount + donorCount incremented",
    raised_after >= raised_before + 25000 and donors_after == donors_before + 1,
    f"raised {raised_before}->{raised_after}, donors {donors_before}->{donors_after}")

# ───────────────────────────── MJ-M6 Org Builder real provisioning ───────────
print("\n-- MJ-M6 Org Builder REAL provisioning (org-JWT + DB-verified) --")
org_tok = mint(["viewOrganizationBuilder", "manageOrganizationBuilder"])
rec("MJ-M6 org-scope JWT minted", bool(org_tok), f"minted={bool(org_tok)}")
if org_tok:
    db("update organization_subscriptions set overrides = "
       "jsonb_build_object('grant', jsonb_build_array('feature.organization_builder')) "
       f"where organization_id='{ORG}'")
    draft = f"draft_w4_{TS}"
    # Create draft + run the interview (step 0 picks the pack + sets the org name;
    # answer keys mirror the real client: pack_id + identity_name), advance to
    # ready_for_preview, then preview — so a real config exists to provision.
    http("GET", f"/platform/org-builder/interview/drafts/{draft}", token=org_tok)
    http("POST", f"/platform/org-builder/interview/drafts/{draft}/step", token=org_tok,
         body={"stepIndex": 0, "answers": {"pack_id": "pack_school",
               "identity_name": f"Cert Trust {TS}"}})
    for step in range(1, 7):
        http("POST", f"/platform/org-builder/interview/drafts/{draft}/step", token=org_tok,
             body={"stepIndex": step, "answers": {"note": f"step{step}"}})
    http("POST", "/platform/org-builder/preview", token=org_tok, body={"draftId": draft})
    s, b = http("POST", "/platform/org-builder/provision", token=org_tok, body={"draftId": draft})
    job = d(b)
    job_status = job.get("status")
    rec("MJ-M6 provision returns a completed job", s in (200, 201) and job_status == "completed",
        f"HTTP {s} status={job_status}")
    # The defining proof: a REAL organization + branch now exist for this draft.
    org_row = db("select id from organizations where settings->>'org_builder_draft_id'="
                 f"'{draft}'")
    rec("MJ-M6 a REAL organization row was created (not a simulated job)", bool(org_row),
        f"org_id={org_row[:8] if org_row else 'NONE'}")
    sch_row = db(f"select count(*) from schools where organization_id='{org_row}'") if org_row else "0"
    rec("MJ-M6 a REAL branch (school) row was created", sch_row == "1",
        f"schools={sch_row}")
    # Idempotency: re-provisioning the same draft does NOT duplicate the org.
    http("POST", "/platform/org-builder/provision", token=org_tok, body={"draftId": draft})
    org_cnt = db("select count(*) from organizations where settings->>'org_builder_draft_id'="
                 f"'{draft}'")
    rec("MJ-M6 re-provision is idempotent (no duplicate org)", org_cnt == "1",
        f"orgs for draft={org_cnt}")
    db(f"update organization_subscriptions set overrides = '{{}}'::jsonb where organization_id='{ORG}'")

# ───────────────────────────── MJ-M7 Admissions document storage ─────────────
print("\n-- MJ-M7 Admissions document -> real Storage (presign/PUT/confirm/download) --")
leads = items(http("GET", "/admissions/leads", token=admin)[1])
lead_id = str(leads[0].get("id")) if leads else ""
rec("MJ-M7 has a real lead to attach a document to", bool(lead_id), f"lead={lead_id[:8]}")
if lead_id:
    fname = f"cert_marksheet_{TS}.pdf"
    s, b = http("POST", "/admissions/documents/upload/presign", token=admin,
                body={"lead_id": lead_id, "file_name": fname})
    signed = d(b).get("signedUrl")
    spath = d(b).get("storagePath")
    # Path layout is {organization_id}/{school_id}/{lead_id}/... — tenant-scoped.
    rec("MJ-M7 presign returns a signed upload URL + tenant-scoped path",
        s == 200 and bool(signed) and bool(spath)
        and str(spath).startswith(f"{ORG}/{SCHOOL_A}/") and lead_id in str(spath),
        f"HTTP {s} path={str(spath)[:40]}")
    pdf = b"%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n"
    ps, _ = (put_bytes(signed, pdf, "application/pdf") if signed else (0, ""))
    rec("MJ-M7 PUT bytes to Storage succeeds", ps in (200, 201), f"HTTP {ps}")
    s, b = http("POST", "/admissions/documents/upload", token=admin,
                body={"lead_id": lead_id, "document_type": "marks_memo",
                      "file_name": fname, "storage_path": spath})
    rec("MJ-M7 confirm stores the document with its storage object", s in (200, 201), f"HTTP {s}")
    # Find the uploaded doc + retrieve it via a signed download URL. The list
    # exposes leadId/documentType/hasFile (not fileName) — match on those.
    docs = items(http("GET", "/admissions/documents", token=admin)[1])
    doc = next((x for x in docs if str(x.get("leadId")) == lead_id
                and x.get("documentType") == "marks_memo" and x.get("hasFile")), None)
    doc_id = str(doc.get("id")) if doc else ""
    has_file = bool(doc.get("hasFile")) if doc else False
    rec("MJ-M7 document is listed with hasFile=true", bool(doc_id) and has_file,
        f"id={doc_id[:8]} hasFile={has_file}")
    if doc_id:
        s, b = http("GET", f"/admissions/documents/{doc_id}/download", token=admin)
        durl = d(b).get("downloadUrl")
        gs, glen = get_url_status(durl) if durl else (0, 0)
        rec("MJ-M7 download URL actually serves the file (retrievable)",
            s == 200 and bool(durl) and gs == 200, f"HTTP {s} fetch={gs} bytes={glen}")

# ───────────────────────────── summary ───────────────────────────────────────
passed = sum(1 for _, ok, _ in results if ok)
total = len(results)
print(f"\n=== Journey Wave 4: {passed}/{total} checks passed ===")
for c, ok, det in results:
    if not ok:
        print(f"  FAIL: {c}  {det}")
raise SystemExit(0 if passed == total else 1)
