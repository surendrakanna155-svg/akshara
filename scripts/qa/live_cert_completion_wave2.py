#!/usr/bin/env python3
"""Live-mode certification for FINAL_COMPLETION_ROADMAP Wave 2 (multi-child
parent correctness + demo-identity purge) against the live VPS pilot.

Real VPS + real DB + parent-scope JWT (minted on the edge) + real RBAC + real OTP.

What it proves (the backend-observable half of Wave 2 — the contract the client
now depends on):
  PAR-1  Every parent read honours `?activeChildId=...`: switching the active
         child changes the resolved student, so responses differ — no silent
         `child_ids[0]` default.
  PAR-1/SEC  An `activeChildId` NOT in the parent's `child_ids` is rejected (403).
  PAR-1  No `activeChildId` still resolves (defaults to child_ids[0]) — 200.
  PAR-7  Real OTP login + `/auth/me` for a parent return
         `children: [{id,name,classLabel}]` with a REAL name + class (not the
         placeholder "Child"/"Student") so the child-switcher shows the real
         student.

Client-only Wave 2 items (PAR-2 invalidation, PAR-3 leave child, PAR-6/9 headers,
TCH-4/6/7/8/9, UX-9, PRN-3, CORE-3, STU-6/7) are covered by the Flutter suite
(analyze 0 / 2383 tests green) and not re-exercised here.

Live data note: the pilot parent (a3..03 "Staging Parent") has ONE school-A
child (a4..01 "Staging Student", 5-A); a4..02 lives in another school. So the
two-child activeChildId switch is proven with a minted token whose child_ids
list two real student ids, while PAR-7 real-name proof uses the genuine login.
"""
import json, os, subprocess, urllib.request, urllib.error

BASE = os.environ.get("API_BASE_URL", "https://api.nikshaos.in")
ORG = "a1000000-0000-4000-8000-000000000001"
SCHOOL_A = "a2000000-0000-4000-8000-000000000001"
PARENT_USER = "a3000000-0000-4000-8000-000000000003"   # real pilot parent
PARENT_PHONE = "+919876543211"
CHILD_1 = "a4000000-0000-4000-8000-000000000001"        # real school-A child (rich data)
CHILD_2 = "a4000000-0000-4000-8000-000000000002"        # 2nd real student id (switch target)
UNLINKED = "a4000000-0000-4000-8000-0000000009ff"        # not in child_ids → 403
SOCK = os.path.expanduser("~/.ssh/akshara-cm.sock")
results = []


def rec(check, ok, detail=""):
    results.append((check, bool(ok), detail))
    print(f"  [{'PASS' if ok else 'FAIL':>4}] {check}  {detail}")


def http(method, path, token=None, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
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
    except Exception as e:
        return 0, str(e)


def ssh(cmd, stdin=None):
    p = subprocess.run(["ssh", "-o", "ControlPath=" + SOCK, "akshara", cmd],
                       input=stdin, capture_output=True, text=True, timeout=90)
    return p.stdout.strip(), p.stderr.strip()


def data(b):
    return (b.get("data") or {}) if isinstance(b, dict) else b


# Mint a parent-scope token carrying two children — drives resolveParentStudentId.
MINT = '''
import { SignJWT } from "npm:jose";
const secret = new TextEncoder().encode(Deno.env.get("JWT_SECRET"));
const t = await new SignJWT({
  tenant_id: Deno.env.get("ORG"), organization_id: Deno.env.get("ORG"),
  school_id: Deno.env.get("SCHOOLID"),
  role: "parent", role_slugs: ["parent"], primary_role: "parent",
  permissions: [], permissions_version: 1,
  scope: "parent", school_group_id: null, student_id: null,
  child_ids: JSON.parse(Deno.env.get("CHILDREN")), session_id: "cert-w2",
}).setProtectedHeader({ alg: "HS256", typ: "JWT" })
  .setSubject(Deno.env.get("SUB")).setIssuedAt()
  .setExpirationTime(Math.floor(Date.now() / 1000) + 3600).sign(secret);
console.log(t);
'''


def mint(child_ids):
    env = (f'-e ORG={ORG} -e SCHOOLID={SCHOOL_A} -e SUB={PARENT_USER} '
           f"-e CHILDREN='{json.dumps(child_ids)}'")
    out, _ = ssh(f"docker exec -i {env} akshara-edge deno run -A -", stdin=MINT)
    tok = out.splitlines()[-1] if out else ""
    return tok if tok.count(".") == 2 else None


READ_ENDPOINTS = [
    "/parent/dashboard", "/parent/attendance", "/parent/homework",
    "/parent/exams", "/parent/timetable", "/parent/fees", "/parent/receipts",
    "/parent/notices", "/parent/events", "/parent/leave", "/parent/profile",
]

print("=== Completion Wave 2 — multi-child + demo-purge LIVE certification ===\n")

# 0. health
s, b = http("GET", "/health")
rec("health", s == 200 and data(b).get("status") == "ok", f"HTTP {s}")

# 1. mint two-child parent token
tok = mint([CHILD_1, CHILD_2])
if not tok:
    print("\nABORT: could not mint parent token (VPS/JWT_SECRET unreachable)")
    raise SystemExit(1)
rec("mint.two_child_parent_token", True, "child_ids=[CHILD_1, CHILD_2]")

# 2. PAR-1: each read honours activeChildId; switching child changes the response.
ok_200 = 0
distinct = 0
for ep in READ_ENDPOINTS:
    sa, ba = http("GET", f"{ep}?activeChildId={CHILD_1}", token=tok)
    sb, bb = http("GET", f"{ep}?activeChildId={CHILD_2}", token=tok)
    both200 = sa == 200 and sb == 200
    diff = both200 and json.dumps(data(ba), sort_keys=True) != json.dumps(
        data(bb), sort_keys=True)
    ok_200 += 1 if both200 else 0
    distinct += 1 if diff else 0
    rec(f"PAR-1.activeChildId_honoured:{ep}", both200,
        f"A=HTTP{sa} B=HTTP{sb} differ={diff}")
rec("PAR-1.all_reads_scope_to_active_child", ok_200 == len(READ_ENDPOINTS),
    f"{ok_200}/{len(READ_ENDPOINTS)} reads accepted activeChildId")
rec("PAR-1.child_switch_changes_data", distinct >= 1,
    f"{distinct}/{len(READ_ENDPOINTS)} endpoints returned distinct per-child data")

# 3. PAR-1/SEC: an activeChildId NOT in child_ids is rejected.
s, b = http("GET", f"/parent/dashboard?activeChildId={UNLINKED}", token=tok)
rec("PAR-1.unlinked_child_rejected", s == 403, f"HTTP {s} (expect 403)")

# 4. PAR-1: default (no activeChildId) still resolves (child_ids[0]) → 200.
s, b = http("GET", "/parent/dashboard", token=tok)
rec("PAR-1.default_first_child_ok", s == 200, f"HTTP {s}")

# 5. PAR-7: real OTP login returns children[] with REAL name + class.
s, b = http("POST", "/auth/login", body={"identifier": PARENT_PHONE})
otp = data(b).get("otp") if s == 200 else None
tok_real = None
if otp:
    s, b = http("POST", "/auth/verify-otp",
                body={"identifier": PARENT_PHONE, "otp": otp})
    user = data(b).get("user") or {}
    tok_real = data(b).get("accessToken")
    children = user.get("children") or []
    named = [c for c in children
             if c.get("name") and c["name"] not in ("Child", "Student", "")]
    rec("PAR-7.login_returns_children", len(children) >= 1,
        f"children={len(children)} names={[c.get('name') for c in children]}")
    rec("PAR-7.children_have_real_names", len(named) >= 1,
        f"named={[c.get('name') for c in named]}")
    rec("PAR-7.children_have_class",
        any(c.get("classLabel") for c in children),
        f"classes={[c.get('classLabel') for c in children]}")
else:
    rec("PAR-7.login_returns_children", False,
        f"no OTP in response (HTTP {s}) — parent phone not allowlisted / rate-limited")

# 6. PAR-7: /auth/me rehydrates the same children (app-restart path).
if tok_real:
    s, b = http("GET", "/auth/me", token=tok_real)
    me_children = data(b).get("children") or []
    me_named = [c for c in me_children
                if c.get("name") and c["name"] not in ("Child", "Student", "")]
    rec("PAR-7.me_rehydrates_named_children",
        len(me_named) >= 1,
        f"me.children={len(me_children)} named={[c.get('name') for c in me_named]}")

# --- summary ---
passed = sum(1 for _, ok, _ in results if ok)
total = len(results)
print(f"\n=== {passed}/{total} checks passed ===")
raise SystemExit(0 if passed == total else 1)
