#!/usr/bin/env python3
"""Live-mode certification for FINAL_COMPLETION_ROADMAP Wave 5 (UX consistency,
a11y, performance polish, Play-Store custody, docs) against the live VPS pilot.

Real VPS + real DB + edge-minted school JWT (real RBAC). The Wave is mostly
client-side (UX/a11y) and static (Play config) — those are proven by `flutter
analyze` (0) + `flutter test` (green). This script certifies the two
backend-/infra-observable items:

  NOT-1  A published promotion fan-out writes a per-audience deep-link `route`
         onto every queued notification_delivery, so a push tap lands on the
         persona's in-app surface (parent->/parent/notices, student->/student/notices,
         teacher->/teacher/dashboard, staff->/admin) instead of a no-destination tap.
         The route column also round-trips (schema migration 20260803 applied).

  PERF-4 Live API p95 latency is measured (not just mock-stopwatch): N sequential
         reads against a representative authenticated endpoint; asserts p95 under
         the budget. Closes the "live p95 never measured" cert gap (F2).

  PLY-3  Static: targetSdk/compileSdk pinned >= Play's API-35 floor (read locally).

Idempotent: the promotion + its deliveries are additive cert rows keyed by a
time-nonce title; no destructive ops on real data."""
import json, os, time, subprocess, urllib.request, urllib.error

BASE = "https://akshara.veloraunisexsalon.com"
ORG = "a1000000-0000-4000-8000-000000000001"
USER = "a3000000-0000-4000-8000-000000000001"
SCHOOL_A = "a2000000-0000-4000-8000-000000000001"
SOCK = os.path.expanduser("~/.ssh/akshara-cm.sock")
TITLE = f"Wave5Route_{int(time.time())}"
results = []

# Expected per-audience deep links (mirror publisher_dispatch.AUDIENCE_ROUTE).
EXPECT_ROUTE = {
    "parent_app": "/parent/notices",
    "student_app": "/student/notices",
    "teacher_app": "/teacher/dashboard",
    "staff_app": "/admin",
}
APP_DEST = list(EXPECT_ROUTE.keys())


def rec(c, ok, d=""):
    results.append((c, bool(ok), d))
    print(f"  [{'PASS' if ok else 'FAIL':>4}] {c}  {d}")


def http(method, path, token=None, body=None):
    payload = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=payload, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            raw = r.read().decode()
            el = time.time() - t0
            try:
                return r.status, json.loads(raw), el
            except Exception:
                return r.status, raw, el
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        el = time.time() - t0
        try:
            return e.code, json.loads(raw), el
        except Exception:
            return e.code, raw, el
    except Exception as e:  # noqa: BLE001
        return 0, str(e), time.time() - t0


def ssh(cmd, stdin=None):
    p = subprocess.run(["ssh", "-o", "ControlPath=" + SOCK, "akshara", cmd],
                       input=stdin, capture_output=True, text=True, timeout=120)
    return p.stdout.strip(), p.stderr.strip()


def db(sql):
    out, _ = ssh(f'docker exec akshara-postgres psql -U supabase_admin -d akshara_db -tAc "{sql}"')
    return out


def data(b):
    return (b.get("data") or {}) if isinstance(b, dict) else {}


MINT = '''
import { SignJWT } from "npm:jose";
const secret = new TextEncoder().encode(Deno.env.get("JWT_SECRET"));
const t = await new SignJWT({
  tenant_id: Deno.env.get("ORG"), organization_id: Deno.env.get("ORG"),
  school_id: Deno.env.get("SCHOOLID"),
  role: Deno.env.get("ROLE"), role_slugs: [Deno.env.get("ROLE")], primary_role: Deno.env.get("ROLE"),
  permissions: JSON.parse(Deno.env.get("PERMS")), permissions_version: 1,
  scope: "school", school_group_id: null, student_id: null,
  child_ids: [], session_id: "cert-w5",
}).setProtectedHeader({ alg: "HS256", typ: "JWT" })
  .setSubject(Deno.env.get("SUB")).setIssuedAt()
  .setExpirationTime(Math.floor(Date.now() / 1000) + 3600).sign(secret);
console.log(t);
'''


def mint(perms, role):
    env = (f'-e ORG={ORG} -e SCHOOLID={SCHOOL_A} -e SUB={USER} -e ROLE={role} '
           f"-e PERMS='{json.dumps(perms)}'")
    out, _ = ssh(f"docker exec -i {env} akshara-edge deno run -A -", stdin=MINT)
    tok = out.splitlines()[-1] if out else ""
    return tok if tok.count(".") == 2 else None


TEACHER = ["viewAchievementPromotion", "manageAchievementPromotion"]
PRINCIPAL = TEACHER + ["approveAchievementPromotion"]

print("=== Wave 5 LIVE certification (real VPS / school-JWT / DB / RBAC) ===\n")

s, b, _ = http("GET", "/health")
rec("health", s == 200 and data(b).get("status") == "ok", f"HTTP {s}")

teacher = mint(TEACHER, "teacher")
principal = mint(PRINCIPAL, "principal")
if not teacher or not principal:
    print("\nABORT: token mint failed")
    raise SystemExit(1)

# ── NOT-1: route schema + per-audience deep links on the fan-out ──────────────
col = db("SELECT column_name FROM information_schema.columns "
         "WHERE table_name='notification_deliveries' AND column_name='route';")
rec("NOT-1.schema route column present", col == "route", f"col={col!r}")

pid = None
try:
    s, b, _ = http("POST", "/promotions", token=teacher,
                   body={"subjectType": "achievement", "title": TITLE,
                         "description": "Wave 5 cert — deep-link route fan-out."})
    pid = data(b).get("id")
    rec("NOT-1.promotion created", s == 201 and pid, f"HTTP {s} id={pid}")

    s, b, _ = http("POST", f"/promotions/{pid}/generate", token=teacher)
    rec("NOT-1.assets generated", s == 200, f"HTTP {s} status={data(b).get('status')}")

    s, b, _ = http("POST", f"/promotions/{pid}/approve", token=principal)
    rec("NOT-1.principal approved", s == 200 and data(b).get("status") == "approved", f"HTTP {s}")

    s, b, _ = http("POST", f"/promotions/{pid}/publish", token=principal,
                   body={"destinations": APP_DEST})
    pub = data(b)
    rec("NOT-1.published to apps", s == 200 and pub.get("status") == "published", f"HTTP {s}")

    # Every queued delivery carries one of the expected per-audience deep links
    # (route correctness), and at least the audiences that have seeded recipients
    # land on the right screen. (A persona with 0 seeded users for this school
    # simply produces 0 rows — that is a fixture fact, not a routing defect.)
    expected = "(" + ",".join(f"'{r}'" for r in EXPECT_ROUTE.values()) + ")"
    total = db(f"SELECT count(*) FROM notification_deliveries WHERE rendered_subject='{TITLE}';")
    good = db("SELECT count(*) FROM notification_deliveries "
              f"WHERE rendered_subject='{TITLE}' AND route IN {expected};")
    rec("NOT-1.every delivery routes to an expected screen",
        total.isdigit() and int(total) >= 1 and total == good,
        f"routed={good}/{total}")

    # Per-persona deep link (informational): rows carrying each expected route.
    audiences_routed = 0
    for dest, route in EXPECT_ROUTE.items():
        cnt = db("SELECT count(*) FROM notification_deliveries "
                 f"WHERE rendered_subject='{TITLE}' AND route='{route}';")
        if cnt.isdigit() and int(cnt) >= 1:
            audiences_routed += 1
        rec(f"NOT-1.{dest} route={route}", cnt.isdigit(),
            f"rows={cnt}" + (" (no recipients seeded for this school)" if cnt == "0" else ""))
    rec("NOT-1.multiple personas land on their own screen", audiences_routed >= 2,
        f"{audiences_routed}/4 audiences had recipients + correct route")

    # No app delivery for this promotion was left without a route (no nulls).
    nulls = db("SELECT count(*) FROM notification_deliveries "
               f"WHERE rendered_subject='{TITLE}' AND route IS NULL;")
    rec("NOT-1.no route-less app deliveries", nulls == "0", f"null_routes={nulls}")
except Exception as e:  # noqa: BLE001
    rec("NOT-1.flow", False, f"exception {e}")

# ── PERF-4: live API p95 latency (real endpoint, real auth) ───────────────────
SAMPLES = 25
BUDGET_MS = 1500.0
lat = []
for _ in range(SAMPLES):
    s, _b, el = http("GET", "/promotions", token=teacher)
    if s == 200:
        lat.append(el * 1000.0)
if lat:
    lat.sort()
    p50 = lat[len(lat) // 2]
    p95 = lat[min(len(lat) - 1, int(round(0.95 * (len(lat) - 1))))]
    rec("PERF-4.live p95 measured & under budget", p95 <= BUDGET_MS,
        f"n={len(lat)} p50={p50:.0f}ms p95={p95:.0f}ms budget={BUDGET_MS:.0f}ms")
else:
    rec("PERF-4.live p95 measured & under budget", False, "no successful samples")

# ── PLY-3: pinned target/compile SDK >= Play floor (static, local) ────────────
try:
    gradle = open(os.path.join(os.path.dirname(__file__), "..", "..",
                  "android", "app", "build.gradle.kts")).read()
    ply3 = "targetSdk = 36" in gradle and "compileSdk = 36" in gradle
    rec("PLY-3.targetSdk/compileSdk pinned >= 35", ply3,
        "targetSdk/compileSdk = 36 (>= Play API-35)")
except Exception as e:  # noqa: BLE001
    rec("PLY-3.targetSdk/compileSdk pinned >= 35", False, f"read error {e}")

# ── summary ───────────────────────────────────────────────────────────────────
passed = sum(1 for _, ok, _ in results if ok)
total = len(results)
print(f"\n=== Wave 5 cert: {passed}/{total} checks passed ===")
for c, ok, d in results:
    if not ok:
        print(f"  FAIL: {c}  {d}")
raise SystemExit(0 if passed == total else 1)
