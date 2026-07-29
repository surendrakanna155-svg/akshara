#!/usr/bin/env python3
"""Live-mode certification for **Red Team Wave 5 — Input/Upload Hardening & Scale**
against the live VPS pilot. Real VPS + edge-minted scoped JWTs (referencing real
`sessions` rows + the live membership `permissions_version`, per Wave-3 RT-16/17)
+ real Postgres + the deployed edge code.

Source of truth: docs/RED_TEAM_MASTER_TRACKER.md (RT-31..RT-35).

Proves on the LIVE deployment, post-deploy:
  RT-31  Storage presign — a wrong-type and an oversized upload are rejected 422
         at presign (early rejection), for both the memories and admissions
         buckets.
  RT-32  Bounded text — an over-long field on a generic module write is rejected
         422; the deployed reader carries MAX_FIELD_LEN.
  RT-33  Bounded numerics — the deployed reader carries MAX_INT_MAGNITUDE
         (behaviour unit-tested in deno; static-verified live).
  RT-34  Parent fan-out — the deployed auth_context carries PARENT_FANOUT_LIMIT
         and a real parent still resolves their linked child via /auth/me.
  RT-35  Connection pool — the deployed tenant_db uses a pooled connection (not
         per-request connect/end); 20 CONCURRENT authenticated reads all succeed
         (the pool absorbs concurrency without a connection-exhaustion cliff).
"""
import json, os, subprocess, threading, time, urllib.request, urllib.error, uuid

BASE = os.environ.get("API_BASE_URL", "https://api.nikshaos.in")
ORG = "a1000000-0000-4000-8000-000000000001"
USER = "a3000000-0000-4000-8000-000000000001"        # schoolAdmin in SCHOOL_A (version 2)
SCHOOL_A = "a2000000-0000-4000-8000-000000000001"
STUDENT_A = "a4000000-0000-4000-8000-000000000001"
GUARDIAN_A = "a3000000-0000-4000-8000-000000000003"  # active guardian of STUDENT_A
SOCK = os.path.expanduser("~/.ssh/akshara-cm.sock")
TS = str(int(time.time()))
VPS_FN = "/opt/akshara/functions/_shared"

seeded_sessions = []
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
    return out.strip()


def vps_grep(pattern, path):
    out, _ = ssh(f"grep -c '{pattern}' {path} 2>/dev/null")
    try:
        return int(out.strip() or "0")
    except ValueError:
        return 0


def d(b):
    return (b.get("data") or {}) if isinstance(b, dict) else {}


def code(b):
    return (b.get("error") or {}).get("code") if isinstance(b, dict) else None


MINT = '''
import { SignJWT } from "npm:jose";
const secret = new TextEncoder().encode(Deno.env.get("JWT_SECRET"));
const t = await new SignJWT({
  tenant_id: Deno.env.get("ORG"), organization_id: Deno.env.get("ORG"),
  school_id: Deno.env.get("SCHOOL") || null,
  role: Deno.env.get("ROLE"), role_slugs: [Deno.env.get("ROLE")], primary_role: Deno.env.get("ROLE"),
  permissions: JSON.parse(Deno.env.get("PERMS")),
  permissions_version: parseInt(Deno.env.get("VERSION") || "1", 10),
  scope: Deno.env.get("SCOPE") || "school", school_group_id: null,
  student_id: Deno.env.get("STUDENT_ID") || null,
  child_ids: JSON.parse(Deno.env.get("CHILD_IDS") || "[]"),
  session_id: Deno.env.get("SESSION_ID"),
}).setProtectedHeader({ alg: "HS256", typ: "JWT" })
  .setSubject(Deno.env.get("SUB")).setIssuedAt()
  .setExpirationTime(Math.floor(Date.now() / 1000) + 3600).sign(secret);
console.log(t);
'''


def seed_session(sub, scope, school):
    sid = str(uuid.uuid4())
    db(f"INSERT INTO sessions (id, user_id, tenant_id, scope, context_school_id) "
       f"VALUES ('{sid}','{sub}','{ORG}','{scope}',{('NULL' if not school else chr(39)+school+chr(39))})")
    seeded_sessions.append(sid)
    return sid


def live_version(sub, school):
    v = db(f"SELECT permissions_version FROM school_memberships "
           f"WHERE user_id='{sub}' AND school_id='{school}' AND status='active' LIMIT 1")
    return v if v else "1"


def mint(perms, role="schoolAdmin", sub=USER, school=SCHOOL_A, scope="school",
         version=None, child_ids=None):
    sid = seed_session(sub, scope, school)
    if version is None:
        version = live_version(sub, school) if scope == "school" else "1"
    env = (f"-e ORG={ORG} -e SUB={sub} -e ROLE={role} -e SCHOOL={school or ''} "
           f"-e SCOPE={scope} -e VERSION={version} -e SESSION_ID={sid} "
           f"-e CHILD_IDS='{json.dumps(child_ids or [])}' -e PERMS='{json.dumps(perms)}'")
    out, _ = ssh(f"docker exec -i {env} akshara-edge deno run -A -", stdin=MINT)
    tok = out.splitlines()[-1] if out else ""
    return tok if tok.count(".") == 2 else None


def cleanup():
    for sid in seeded_sessions:
        db(f"DELETE FROM sessions WHERE id='{sid}'")


print("=== Red Team Wave 5 LIVE certification (real VPS / pool / presign / bounds) ===\n")

s, b = http("GET", "/health")
rec("health", s == 200 and d(b).get("status") == "ok", f"HTTP {s}")
rec("live DB reachable via control socket", db("SELECT current_user") == "supabase_admin")

# ── RT-35: connection pool deployed + concurrency holds ──────────────────────
print("\n-- RT-35 tenant DB connection pool --")
rec("RT-35 deployed tenant_db uses a pooled connection (tenantPool/Pool)",
    vps_grep("tenantPool(", f"{VPS_FN}/tenant_db.ts") >= 1 and
    vps_grep("new Pool(", f"{VPS_FN}/tenant_db.ts") >= 1)
rec("RT-35 pooled acquire/release in use; per-request `await client.end()` gone",
    vps_grep("client.release()", f"{VPS_FN}/tenant_db.ts") >= 1 and
    vps_grep("await client.end()", f"{VPS_FN}/tenant_db.ts") == 0)

admin = mint(["viewManagement", "manageManagement"])
rec("minted live schoolAdmin token", bool(admin))
s, _ = http("GET", "/approvals/pending", token=admin)
rec("RT-35 a pooled authenticated read succeeds (200)", s == 200, f"HTTP {s}")

conc = {}


def reader(tag):
    st, _ = http("GET", "/approvals/pending", token=admin)
    conc[tag] = st


threads = [threading.Thread(target=reader, args=(i,)) for i in range(20)]
for t in threads:
    t.start()
for t in threads:
    t.join()
ok200 = sum(1 for st in conc.values() if st == 200)
rec("RT-35 20 CONCURRENT pooled reads all succeed (no connection cliff)",
    ok200 == 20, f"{ok200}/20 returned 200")

# ── RT-31: presign rejects wrong-type / oversized ────────────────────────────
print("\n-- RT-31 storage presign early rejection --")
mem = mint(["manageSchoolMemories", "viewSchoolMemories"])
ev = str(uuid.uuid4())
s, b = http("POST", f"/memories/events/{ev}/upload/presign", token=mem,
            body={"filename": "malware.exe", "albumTitle": "x"})
rec("RT-31 memories presign rejects disallowed file type (422)", s == 422, f"HTTP {s} code={code(b)}")
s, b = http("POST", f"/memories/events/{ev}/upload/presign", token=mem,
            body={"filename": "huge.mp4", "sizeBytes": 60 * 1024 * 1024, "albumTitle": "x"})
rec("RT-31 memories presign rejects oversized upload (422)", s == 422, f"HTTP {s} code={code(b)}")
adm = mint(["manageAdmissions", "viewAdmissions"])
s, b = http("POST", "/admissions/documents/upload/presign", token=adm,
            body={"lead_id": str(uuid.uuid4()), "file_name": "script.exe"})
rec("RT-31 admissions presign rejects disallowed file type (422)", s == 422, f"HTTP {s} code={code(b)}")

# ── RT-32: over-long text rejected on a generic module write ─────────────────
print("\n-- RT-32 bounded text input --")
lib = mint(["manageLibrary", "viewLibrary"])
s, b = http("POST", "/library/digital-resources", token=lib,
            body={"title": "x" * 20001, "resourceUrl": "https://example.com/a.pdf"})
rec("RT-32 over-long title rejected (422)", s == 422, f"HTTP {s} code={code(b)}")
rec("RT-32 deployed reader carries MAX_FIELD_LEN",
    vps_grep("MAX_FIELD_LEN", f"{VPS_FN}/entity_write/module_write_handlers.ts") >= 1)

# ── RT-33: numeric magnitude bound deployed (behaviour unit-tested in deno) ───
print("\n-- RT-33 bounded numeric input --")
rec("RT-33 deployed reader carries MAX_INT_MAGNITUDE",
    vps_grep("MAX_INT_MAGNITUDE", f"{VPS_FN}/entity_write/module_write_handlers.ts") >= 1)

# ── RT-34: parent fan-out capped; real parent still resolves the child ───────
print("\n-- RT-34 parent children fan-out cap --")
rec("RT-34 deployed auth_context carries PARENT_FANOUT_LIMIT",
    vps_grep("PARENT_FANOUT_LIMIT", f"{VPS_FN}/auth_context.ts") >= 1)
parent = mint([], role="parent", sub=GUARDIAN_A, scope="parent", child_ids=[STUDENT_A])
s, b = http("GET", "/auth/me", token=parent)
child_ids = d(b).get("childIds") if isinstance(d(b), dict) else None
rec("RT-34 a real parent still resolves their linked child (capped fan-out works)",
    s == 200 and isinstance(child_ids, list) and STUDENT_A in child_ids,
    f"HTTP {s} childIds={child_ids}")

cleanup()
passed = sum(1 for _, ok, _ in results if ok)
total = len(results)
print(f"\n=== Red Team Wave 5: {passed}/{total} checks passed ===")
for c, ok, det in results:
    if not ok:
        print(f"  FAIL: {c}  {det}")
raise SystemExit(0 if passed == total else 1)
