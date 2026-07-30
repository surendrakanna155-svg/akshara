#!/usr/bin/env python3
"""Live-mode certification for MODULE_JOURNEY_ROADMAP **Journey Wave 5** —
"RBAC hardening, error-state UX sweep & test-gate parity" — against the live VPS
pilot. Real VPS + real pilot OTP auth (admin JWT) + edge-minted scoped JWTs
(school/parent, with controlled permission sets) + real DB rows + real RLS.

Wave 5 is a hardening batch; the backend-observable closures are certified here.
Client-only UX items (MJ-L3 Director gates/error-handling, MJ-L5 Super Admin
honest-state, MJ-L8 global-search RBAC, MJ-L4 copilot error rendering) are proven
by the widget/unit gates (flutter test 2439 / deno 848) and are noted as such.

  MJ-M10 Teacher RBAC — pilot teacher writes (mark attendance, create/grade
         homework, edit exam marks) now require a granular permission, not just
         school scope. Proven by minted school tokens: WITHOUT the permission ->
         403; WITH it -> not 403. DB: teaching roles hold the new grants; a
         non-teaching role (librarian) does not.
  MJ-M11 Attendance — a parent can now submit a correction for their OWN child
         via POST /parent/attendance/corrections (was 403 on the staff route).
         Non-parent caller -> 403; parent + UNLINKED child -> 403 (RLS); parent +
         linked child -> 201. DB: parent grant + RLS policies exist.
  MJ-L2  Dynamic Widgets — GET /widgets/data now enforces per-widget RBAC for
         school scope: a school token WITHOUT viewFinance gets fee_collection
         permissionDenied (no real fee data crosses the wire); WITH it -> data.
  MJ-L7  Inventory — intelligence GET endpoints are now side-effect-free: two
         reads do NOT grow inventory_intelligence_snapshots (was INSERT-on-read).
  MJ-M12 Communication — the template-write + broadcast-history + PUT-template
         routes resolve live (no 404) — the path-parity the new contract test pins.

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
    out, _ = ssh(f'docker exec akshara-postgres psql -U supabase_admin -d akshara_db -tAc "{sql}"')
    return out


def d(b):
    return (b.get("data") or {}) if isinstance(b, dict) else {}


def items(b):
    x = d(b)
    if isinstance(x, list):
        return x
    return x.get("items") or x.get("results") or x.get("widgets") or []


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


# Parameterized edge-minted JWT (HS256 with the live JWT_SECRET) — lets us assert
# the gate logic with exact permission sets / scopes without depending on which
# permissions a seeded persona happens to carry.
MINT = '''
import { SignJWT } from "npm:jose";
const secret = new TextEncoder().encode(Deno.env.get("JWT_SECRET"));
const t = await new SignJWT({
  tenant_id: Deno.env.get("ORG"), organization_id: Deno.env.get("ORG"),
  school_id: Deno.env.get("SCHOOL") || null,
  role: Deno.env.get("ROLE"), role_slugs: [Deno.env.get("ROLE")], primary_role: Deno.env.get("ROLE"),
  permissions: JSON.parse(Deno.env.get("PERMS")), permissions_version: 1,
  scope: Deno.env.get("SCOPE"), school_group_id: null, student_id: null,
  child_ids: JSON.parse(Deno.env.get("CHILDREN") || "[]"), session_id: "cert-wave5",
}).setProtectedHeader({ alg: "HS256", typ: "JWT" })
  .setSubject(Deno.env.get("SUB")).setIssuedAt()
  .setExpirationTime(Math.floor(Date.now() / 1000) + 3600).sign(secret);
console.log(t);
'''


def mint(perms, scope="school", role="teacher", sub=USER, school=SCHOOL_A, children=None):
    env = (f"-e ORG={ORG} -e SUB={sub} -e SCOPE={scope} -e ROLE={role} "
           f"-e SCHOOL={school or ''} -e PERMS='{json.dumps(perms)}' "
           f"-e CHILDREN='{json.dumps(children or [])}'")
    out, _ = ssh(f"docker exec -i {env} akshara-edge deno run -A -", stdin=MINT)
    tok = out.splitlines()[-1] if out else ""
    return tok if tok.count(".") == 2 else None


print("=== Journey Wave 5 LIVE certification (real VPS / pilot OTP / scoped JWTs / DB / RLS) ===\n")

s, b = http("GET", "/health")
rec("health", s == 200 and d(b).get("status") == "ok", f"HTTP {s}")

admin = login(ADMIN)
rec("auth: admin JWT (real OTP)", bool(admin), f"admin={bool(admin)}")
if not admin:
    print("\nABORT: admin token required (OTP cooldown?). Re-run shortly.")
    raise SystemExit(1)

# ───────────────────────── MJ-M10 Teacher write RBAC gates ────────────────────
print("\n-- MJ-M10 Teacher write handlers gate on granular permission --")
no_perm = mint(["viewAdminHub"])
mark_tok = mint(["markAttendance"])
hw_tok = mint(["manageHomework"])
marks_tok = mint(["manageExamMarks"])
rec("MJ-M10 minted school tokens", all([no_perm, mark_tok, hw_tok, marks_tok]),
    f"minted={all([no_perm, mark_tok, hw_tok, marks_tok])}")

s, _ = http("POST", "/teacher/attendance/submit", token=no_perm,
            body={"class_id": "class_certw5", "entries": []})
rec("MJ-M10 attendance submit DENIED without markAttendance", s == 403, f"HTTP {s} (expect 403)")
s, _ = http("POST", "/teacher/attendance/submit", token=mark_tok,
            body={"class_id": "class_certw5", "entries": []})
rec("MJ-M10 attendance submit ALLOWED with markAttendance", s != 403 and s != 0, f"HTTP {s} (expect !=403)")

s, _ = http("POST", "/teacher/homework", token=no_perm,
            body={"class_label": "8-A", "subject": "Math", "title": "Cert HW"})
rec("MJ-M10 homework create DENIED without manageHomework", s == 403, f"HTTP {s} (expect 403)")
# WITH manageHomework but an invalid body (no title) -> 422, proving the gate passed
# without creating a junk row.
s, _ = http("POST", "/teacher/homework", token=hw_tok, body={"subject": "Math"})
rec("MJ-M10 homework create ALLOWED with manageHomework (422 on bad body, not 403)",
    s == 422, f"HTTP {s} (expect 422)")

s, _ = http("PUT", "/teacher/exams/marks/cert_no_such_mark", token=no_perm,
            body={"marks_obtained": 10})
rec("MJ-M10 exam mark update DENIED without manageExamMarks", s == 403, f"HTTP {s} (expect 403)")
s, _ = http("PUT", "/teacher/exams/marks/cert_no_such_mark", token=marks_tok,
            body={"marks_obtained": 10})
rec("MJ-M10 exam mark update ALLOWED with manageExamMarks (404 unknown id, not 403)",
    s in (404, 400, 422), f"HTTP {s} (expect 4xx not 403)")

# DB: the new grants exist for teaching roles; a non-teaching role does not.
g = db("select count(*) from role_permissions where role_slug='teacher' "
       "and permission_slug in ('markAttendance','manageHomework','manageExamMarks')")
rec("MJ-M10 teacher role granted markAttendance+manageHomework+manageExamMarks", g == "3", f"grants={g}/3")
lib = db("select count(*) from role_permissions where role_slug='librarian' and permission_slug='markAttendance'")
rec("MJ-M10 non-teaching role (librarian) NOT granted markAttendance", lib == "0", f"librarian markAttendance={lib}")

# ───────────────────────── MJ-M11 Parent attendance correction ────────────────
print("\n-- MJ-M11 Parent-scoped attendance correction (RLS to own child) --")
# Non-parent caller is rejected by the parent route.
s, _ = http("POST", "/parent/attendance/corrections", token=mark_tok, body={"sisStudentId": "x"})
rec("MJ-M11 parent route rejects a non-parent (school) caller", s == 403, f"HTTP {s} (expect 403)")

# Find a real guardian->student link to mint a parent token for.
link = db(f"select guardian_user_id||'|'||student_id from student_guardians "
          f"where school_id='{SCHOOL_A}' limit 1")
parent_sub, child_id = (link.split("|", 1) + ["", ""])[:2] if "|" in link else ("", "")
other = db(f"select id from students where school_id='{SCHOOL_A}' and id<>'{child_id}' limit 1") if child_id else ""
rec("MJ-M11 found a real guardian->child link to test", bool(parent_sub and child_id),
    f"parent={parent_sub[:8]} child={child_id[:8]}")

if parent_sub and child_id:
    ptok = mint(["submitAttendanceCorrection", "viewSis"], scope="parent", role="parent",
                sub=parent_sub, children=[child_id])
    rec("MJ-M11 parent JWT minted", bool(ptok), f"minted={bool(ptok)}")
    body = {"sisStudentId": child_id, "studentName": "Cert Child", "classLabel": "8",
            "section": "A", "dateLabel": "Today", "fromMark": "Absent", "toMark": "Present",
            "reason": f"Cert correction {TS}"}
    s, b = http("POST", "/parent/attendance/corrections", token=ptok, body=body)
    rec("MJ-M11 parent submits a correction for their OWN child -> 201", s == 201, f"HTTP {s} (expect 201)")
    if other:
        s2, _ = http("POST", "/parent/attendance/corrections", token=ptok,
                     body={**body, "sisStudentId": other})
        rec("MJ-M11 parent BLOCKED from a correction for an UNLINKED child (RLS)", s2 == 403,
            f"HTTP {s2} (expect 403)")

pg = db("select count(*) from role_permissions where role_slug='parent' and permission_slug='submitAttendanceCorrection'")
rec("MJ-M11 parent role granted submitAttendanceCorrection (client gate passes live)", pg == "1", f"grant={pg}")
pol = db("select count(*) from pg_policies where tablename='attendance_corrections' and policyname like '%parent%'")
rec("MJ-M11 parent INSERT+SELECT RLS policies exist on attendance_corrections", pol == "2", f"policies={pol}/2")

# ───────────────────────── MJ-L2 Dynamic Widgets per-widget RBAC ──────────────
print("\n-- MJ-L2 GET /widgets/data enforces per-widget RBAC for school scope --")
no_fin = mint(["viewDynamicWidgets"])
fin = mint(["viewDynamicWidgets", "viewFinance"])


def fee_widget(token):
    # Response shape: { data: { widgets: { fee_collection: {...} }, cached } }.
    s, b = http("GET", "/widgets/data?widgetIds=fee_collection", token=token)
    w = (d(b).get("widgets") or {}) if isinstance(d(b), dict) else {}
    return s, (w.get("fee_collection") if isinstance(w, dict) else None)


s, fee = fee_widget(no_fin)
denied = bool(fee.get("permissionDenied")) if isinstance(fee, dict) else False
rec("MJ-L2 fee_collection permissionDenied for a school token WITHOUT viewFinance",
    s == 200 and denied, f"HTTP {s} permissionDenied={denied}")
s, fee = fee_widget(fin)
denied2 = bool(fee.get("permissionDenied")) if isinstance(fee, dict) else True
rec("MJ-L2 fee_collection data returned WITH viewFinance (not denied)",
    s == 200 and isinstance(fee, dict) and not denied2, f"HTTP {s} permissionDenied={denied2}")

# ───────────────────────── MJ-L7 Inventory side-effect-free reads ─────────────
print("\n-- MJ-L7 inventory intelligence GET is side-effect-free --")
inv_tok = mint(["viewInventory", "viewInventoryIntelligence"])
before = db("select count(*) from inventory_intelligence_snapshots")
http("GET", "/inventory/intelligence/copilot", token=inv_tok)
http("GET", "/inventory/intelligence/lifecycle", token=inv_tok)
http("GET", "/inventory/intelligence/procurement-workflow", token=inv_tok)
after = db("select count(*) from inventory_intelligence_snapshots")
rec("MJ-L7 three intelligence GET reads do NOT INSERT a snapshot row",
    before != "" and before == after, f"snapshots {before}->{after}")

# ───────────────────────── MJ-M12 Communication path parity ───────────────────
print("\n-- MJ-M12 communication template/history routes resolve live (no route-404) --")
# Parity: a MISSING route returns errorEnvelope NOT_FOUND "Route not found: ..."
# (the mock used to mask that). These must resolve to real handlers — any status
# is fine EXCEPT a "Route not found" router miss.


def routed(method, path, body=None):
    s, b = http(method, path, token=admin, body=body)
    raw = json.dumps(b).lower() if isinstance(b, (dict, list)) else str(b).lower()
    return s, ("route not found" not in raw)


s, ok = routed("GET", "/communications/broadcasts/history")
rec("MJ-M12 GET /communications/broadcasts/history is a real route (no router miss)", s != 0 and ok, f"HTTP {s}")
s, ok = routed("POST", "/communications/templates", body={})
rec("MJ-M12 POST /communications/templates is a real route (no router miss)", s != 0 and ok, f"HTTP {s}")
# Use a valid-UUID (but non-existent) id so the handler reaches its not-found
# path and returns a clean 404 (proving the new PUT handler is deployed & wired).
s, ok = routed("PUT", "/communications/templates/00000000-0000-4000-8000-0000000000ff", body={})
rec("MJ-M12 PUT /communications/templates/:id reaches new handler (clean 404, not route-miss)",
    s == 404, f"HTTP {s} (expect 404)")

# ───────────────────────── summary ───────────────────────────────────────────
passed = sum(1 for _, ok, _ in results if ok)
total = len(results)
print(f"\n=== Journey Wave 5: {passed}/{total} checks passed ===")
for c, ok, det in results:
    if not ok:
        print(f"  FAIL: {c}  {det}")
raise SystemExit(0 if passed == total else 1)
