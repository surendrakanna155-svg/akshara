#!/usr/bin/env python3
"""QA-R-002 + QA-R-003 — Multi-school CONCURRENT isolation — LIVE certification.

Spins up N throwaway schools in the pilot org, launches each school's core
journey ON ITS OWN threading.Thread so they all run AT THE SAME TIME (true
concurrency, not sequential), then — after the concurrent burst — asserts that
each school sees ONLY its own rows (zero cross-tenant bleed). The QA-R-003 tenant
isolation assertion is folded directly into the concurrent run: the bleed check
runs against data each thread wrote while the others were writing too.

  QA-R-002  N schools run their journeys concurrently and all succeed (the
            backend serves overlapping tenants without interference).
  QA-R-003  Cross-tenant isolation under that concurrency: school A's scoped
            reads return school A's rows and NEVER another school's; the DB
            row-counts confirm each school's writes landed only under its own id.

Helper provenance (mirrored to keep this script self-contained, matching the
house convention that every live_cert_* script carries its own helpers):
  * mk_school / login / db / the finally-scrub teardown
        — scripts/qa/live_cert_pilot_simulation.py
  * MINT / mint (edge-minted scoped JWTs, to dodge OTP rate limits under N-way
    concurrent login) — scripts/qa/live_cert_b8_director_multi_school.py
  * the threading.Thread pooled-concurrency pattern
        — scripts/qa/live_cert_red_team_wave5.py (RT-35 concurrent section)

Run:  python3 scripts/qa/live_cert_multi_school_concurrent.py
The live SSH ControlMaster socket (~/.ssh/akshara-cm.sock) must be open. If the
socket or the API is unreachable the script ERRORS in setup — it never greens.
"""
import json, os, time, uuid, subprocess, threading, urllib.request, urllib.error

BASE = os.environ.get("API_BASE_URL", "https://api.nikshaos.in")
# Isolated Track-B run: point API_BASE_URL at the test edge, AKSHARA_DB_NAME at
# akshara_tenant_test, EDGE_CONTAINER at akshara-edge-test (never touches prod).
DB_NAME = os.environ.get("AKSHARA_DB_NAME", "akshara_db")
EDGE_CONTAINER = os.environ.get("EDGE_CONTAINER", "akshara-edge")
ORG = "a1000000-0000-4000-8000-000000000001"          # pilot org (Professional plan)
ADMIN_UID = "a3000000-0000-4000-8000-000000000001"     # real users.id (FK-safe sub)
SOCK = os.path.expanduser("~/.ssh/akshara-cm.sock")
TS = str(int(time.time()))

# N throwaway concurrent schools (all in the pilot org).
N = 3
SCHOOLS = [f"a2000000-0000-4000-8000-0000000000f{i}" for i in range(1, N + 1)]

results = []      # (check, label, detail)
results_lock = threading.Lock()


def rec(check, label, detail=""):
    with results_lock:
        results.append((check, label, detail))
        print(f"  [{label:>7}] {check}  {detail}")


def http(method, path, token=None, body=None, school=None):
    payload = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=payload, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    if school:
        req.add_header("X-School-Id", school)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
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
    """psql on the pilot Postgres via the ssh ControlMaster socket.
    Mirrors scripts/qa/live_cert_pilot_simulation.py::db."""
    out, _ = ssh(
        'docker exec akshara-postgres psql -U supabase_admin -d ' + DB_NAME + ' -tAc "'
        + sql.replace('"', '\\"') + '"')
    return out.strip()


def data(b):
    return (b.get("data") or {}) if isinstance(b, dict) else {}


def items(b):
    x = data(b)
    if isinstance(x, list):
        return x
    return x.get("items") or x.get("results") or []


def mk_school(school_id, org, name, code):
    """Seed a throwaway school + admin membership.
    Mirrors scripts/qa/live_cert_pilot_simulation.py::mk_school."""
    db(f"insert into schools (id, organization_id, name, code) values "
       f"('{school_id}','{org}','{name}','{code}') "
       f"on conflict (id) do update set deleted_at=null, organization_id=excluded.organization_id, name=excluded.name")
    mid = db(f"insert into school_memberships (user_id, school_id, role, status) "
             f"values ('{ADMIN_UID}','{school_id}','schoolAdmin','active') "
             f"on conflict do nothing returning id")
    if not mid:
        mid = db(f"select id from school_memberships where user_id='{ADMIN_UID}' and school_id='{school_id}' limit 1")
    if mid:
        db(f"insert into school_membership_roles (school_membership_id, role_slug, is_primary, status) "
           f"values ('{mid}','schoolAdmin',true,'active') on conflict do nothing")


# Edge-minted scoped JWT — mirrors scripts/qa/live_cert_b8_director_multi_school.py
# (MINT/mint). Minting on the edge with the live secret dodges OTP rate limits when
# N schools authenticate at once.
MINT = '''
import { SignJWT } from "npm:jose";
const secret = new TextEncoder().encode(Deno.env.get("JWT_SECRET"));
const t = await new SignJWT({
  tenant_id: Deno.env.get("ORG"), organization_id: Deno.env.get("ORG"),
  school_id: Deno.env.get("SCHOOLID") === "null" ? null : Deno.env.get("SCHOOLID"),
  role: "schoolAdmin", role_slugs: ["schoolAdmin"],
  primary_role: "schoolAdmin",
  permissions: JSON.parse(Deno.env.get("PERMS")), permissions_version: 1,
  scope: Deno.env.get("SCOPE"), school_group_id: null, student_id: null,
  child_ids: [], session_id: Deno.env.get("SESSIONID"),
}).setProtectedHeader({ alg: "HS256", typ: "JWT" })
  .setSubject(Deno.env.get("SUB")).setIssuedAt()
  .setExpirationTime(Math.floor(Date.now() / 1000) + 3600).sign(secret);
console.log(t);
'''

PERMS = ["viewSchoolConfiguration", "manageSchoolConfiguration",
         "viewAdminHub", "viewSis", "manageSis"]


def mint(school_id, scope="school", sub=ADMIN_UID):
    # A real active session must back the token — session_validation rejects a
    # token whose session_id is not an active `sessions` row. Insert one, sign with it.
    sid = str(uuid.uuid4())
    db(f"insert into sessions (id, user_id, tenant_id, context_school_id) "
       f"values ('{sid}','{sub}','{ORG}','{school_id}') on conflict (id) do nothing")
    env = (f'-e ORG={ORG} -e SCOPE={scope} -e SCHOOLID={school_id} -e SUB={sub} -e SESSIONID={sid} '
           f"-e PERMS='{json.dumps(PERMS)}'")
    out, _ = ssh(f"docker exec -i {env} {EDGE_CONTAINER} deno run -A -", stdin=MINT)
    tok = out.splitlines()[-1] if out else ""
    return tok if tok.count(".") == 2 else None


# login() is the OTP path from live_cert_pilot_simulation.py, retained as a
# fallback for environments where edge-minting is unavailable. Concurrency uses
# mint() to avoid the OTP sliding-window under N-way parallel auth.
ADMIN = "+919876543210"


def login(school):
    db(f"delete from otp_requests where phone='{ADMIN}' and created_at > now() - interval '1 hour'")
    s, b = http("POST", "/auth/login", body={"identifier": ADMIN})
    otp = data(b).get("otp")
    s, b = http("POST", "/auth/verify-otp", body={"identifier": ADMIN, "otp": otp, "schoolId": school})
    return data(b).get("accessToken")


def require_socket_or_die():
    """FAIL LOUDLY: authoring scaffold for the LIVE run. A missing socket or an
    unreachable API must error in setup — never silently green."""
    if not os.path.exists(SOCK):
        raise SystemExit(
            f"FATAL: ssh ControlMaster socket not found at {SOCK}. "
            "Open the tunnel before running the multi-school concurrency cert; "
            "refusing to run (a missing socket must error, never pass).")
    if db("select current_user") != "supabase_admin":
        raise SystemExit("FATAL: live DB not reachable via control socket. Refusing to run.")
    s, b = http("GET", "/health")
    if not (s == 200 and data(b).get("status") == "ok"):
        raise SystemExit(f"FATAL: live API /health not OK (HTTP {s}). Refusing to run.")


# Per-school journey output, keyed by school id (written from each thread).
journey = {}            # school_id -> {"tag", "marker", "tok", "created", "errors"}
journey_lock = threading.Lock()


def school_journey(idx, school_id):
    """One school's core journey — runs concurrently with the others. Each school
    writes a UNIQUELY-MARKED SIS student via its OWN scoped token, so the later
    bleed check can prove the row landed only under this school's id."""
    tag = f"S{idx}"
    marker = f"MSC-{tag}-{TS}"
    rec(f"{tag}.mint", "PASS" if (tok := mint(school_id)) else "FAIL", f"scoped token school={school_id[-4:]}")
    with journey_lock:
        journey[school_id] = {"tag": tag, "marker": marker, "tok": tok, "created": False, "errors": []}
    if not tok:
        return

    # 1. scoped identity check — the token resolves to THIS school
    s, b = http("GET", "/auth/me", tok, school=school_id)
    me_school = data(b).get("schoolId") or data(b).get("school_id")
    rec(f"{tag}.auth/me", "PASS" if s == 200 else "FAIL",
        f"HTTP {s} me_school={str(me_school)[-4:] if me_school else None}")

    # 2. empty-state SIS read on a fresh tenant is a clean 200 (never a 500)
    s, b = http("GET", "/sis/students", tok, school=school_id)
    rec(f"{tag}.sis-read", "PASS" if s == 200 else "FAIL", f"HTTP {s} count={len(items(b))}")

    # 3. WRITE a uniquely-marked SIS student under this school (the isolation seed)
    s, b = http("POST", "/sis/students", tok,
                {"displayName": marker, "admissionNumber": marker,
                 "classLabel": "Grade 1", "sectionLabel": "A", "academicYear": "2026-27",
                 "gender": "other"}, school=school_id)
    created = s in (200, 201) and bool((data(b).get("student") or {}).get("id") or data(b).get("id") or data(b).get("studentId"))
    with journey_lock:
        journey[school_id]["created"] = created
    rec(f"{tag}.sis-write", "PASS" if created else "FAIL", f"HTTP {s} marker={marker}")


print("=== QA-R-002/003 Multi-school CONCURRENT isolation — LIVE (real VPS / DB / RBAC) ===\n")

# Setup gate — die loudly if the live plane is unreachable.
require_socket_or_die()
s, b = http("GET", "/health")
rec("00.health", "PASS" if s == 200 and data(b).get("status") == "ok" else "FAIL", f"HTTP {s}")

try:
    # ─── Seed N throwaway schools ──────────────────────────────────────────────
    for i, sch in enumerate(SCHOOLS, start=1):
        mk_school(sch, ORG, f"Concurrent School {i}", f"MSC{i}{TS[-3:]}")
    rec("setup.seed-N-schools", "PASS", f"N={N} schools seeded under org {ORG[-4:]}")

    # ─── QA-R-002: launch every school's journey CONCURRENTLY ──────────────────
    # Pattern from live_cert_red_team_wave5.py (RT-35): one Thread per unit of
    # work, start-all then join-all, so the journeys genuinely overlap.
    threads = [threading.Thread(target=school_journey, args=(i, sch))
               for i, sch in enumerate(SCHOOLS, start=1)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    created_ok = sum(1 for sch in SCHOOLS if journey.get(sch, {}).get("created"))
    rec("R-002.concurrent-journeys-all-succeed", "PASS" if created_ok == N else "FAIL",
        f"{created_ok}/{N} schools completed their write under concurrency")

    # ─── QA-R-003: cross-tenant isolation (folded into the concurrent run) ──────
    # (a) DB-truth: each school's marked row landed ONLY under its own school_id.
    for sch in SCHOOLS:
        j = journey.get(sch, {})
        marker = j.get("marker")
        if not marker:
            continue
        own = db(f"select count(*) from students where school_id='{sch}' and display_name='{marker}'")
        elsewhere = db(f"select count(*) from students where school_id<>'{sch}' and display_name='{marker}'")
        rec(f"R-003.{j.get('tag')}.row-only-under-own-school",
            "PASS" if own == "1" and elsewhere == "0" else "FAIL",
            f"own={own} elsewhere={elsewhere}")

    # (b) API-truth: each school's scoped read returns its OWN marker and NEVER
    #     any sibling school's marker (zero cross-tenant bleed through RLS).
    for sch in SCHOOLS:
        j = journey.get(sch, {})
        tok = j.get("tok")
        if not tok:
            continue
        s, b = http("GET", "/sis/students", tok, school=sch)
        names = {str(x.get("displayName") or x.get("fullName") or x.get("full_name") or "") for x in items(b)}
        sees_own = j.get("marker") in names
        others = [journey[o]["marker"] for o in SCHOOLS if o != sch and journey.get(o, {}).get("marker")]
        bleed = [m for m in others if m in names]
        rec(f"R-003.{j.get('tag')}.scoped-read-no-bleed",
            "PASS" if sees_own and not bleed else "FAIL",
            f"sees_own={sees_own} cross_tenant_bleed={bleed}")

    # (c) Cross-read attempt: school 1's token reading WITH school 2's header is
    #     rejected (membership/RLS denies the mismatched scope) — never returns
    #     school 2's rows.
    if N >= 2 and journey.get(SCHOOLS[0], {}).get("tok"):
        tok1 = journey[SCHOOLS[0]]["tok"]
        s, b = http("GET", "/sis/students", tok1, school=SCHOOLS[1])
        names = {str(x.get("displayName") or x.get("fullName") or x.get("full_name") or "") for x in items(b)}
        leaked = journey.get(SCHOOLS[1], {}).get("marker") in names
        # Authorized outcome: 403 (scope mismatch) OR a 200 that contains NONE of
        # school 2's rows. A 200 that LEAKS school 2's marker is the failure.
        rec("R-003.cross-header-read-denied",
            "PASS" if (s == 403 or not leaked) else "FAIL",
            f"HTTP {s} leaked_school2_marker={leaked}")

finally:
    print("\n-- teardown --")
    for sch in SCHOOLS:
        db(f"delete from sessions where context_school_id='{sch}'")
        db(f"delete from students where school_id='{sch}'")
        db(f"delete from school_membership_roles where school_membership_id in "
           f"(select id from school_memberships where school_id='{sch}')")
        for tbl in ("sis_student_enrollments", "student_profiles",
                    "academic_subjects", "sections", "classes", "academic_years",
                    "school_branding", "school_configuration",
                    "startup_onboarding", "school_memberships"):
            db(f"delete from {tbl} where school_id='{sch}'")
        db(f"update schools set deleted_at=timezone('utc',now()) where id='{sch}'")
    for sch in SCHOOLS:
        db(f"delete from schools where id='{sch}'")

p = sum(1 for _, l, _ in results if l == "PASS")
f = sum(1 for _, l, _ in results if l == "FAIL")
print(f"\n=== RESULT: {p}/{p + f} checks passed  (total {len(results)}) ===")
print("GATE:", "PASS" if f == 0 else "FAIL")
raise SystemExit(1 if f else 0)
