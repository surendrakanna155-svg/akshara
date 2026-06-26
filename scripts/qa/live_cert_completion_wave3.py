#!/usr/bin/env python3
"""Live-mode certification for FINAL_COMPLETION_ROADMAP Wave 3 (contract gaps +
entitlement client + security hardening) against the live VPS pilot.

Real VPS + real DB + edge-minted JWTs (real RBAC) + real HMAC webhook auth.

What it proves (the backend-observable contract Wave 3 closes):
  STF-4  GET /finance/discounts returns the discounts read.
  STF-1  Offline payments: record (201) -> list (contains it) -> reconcile (200).
  STF-2  QR/UPI sessions: create (201, pending+upiPayload) -> get -> confirm.
  STF-3  GET /finance/defaulters returns kpis/agingBuckets/defaulters/aiInsight/
         aiActionLabel; GET /finance/reports + GET/PUT /finance/settings work.
  INT-2  Each defaulter row carries a guardianPhone field (WhatsApp surface).
  STF-5  Scholarships: create (201) -> update (200).
  RBAC   A token without manageFinance is denied a finance write (403).
  SEC-1  POST /communications/delivery/webhook rejects an UNSIGNED call (401) and
         a WRONG-signature call (401); a correctly HMAC-signed call passes auth
         (reaches tenant lookup -> 404 for an unknown id, NOT 401).
  SEC-2  A communication mutation (device-token register) lands an audit row.
  SEC-3  parent /parent/experience/summary rejects a studentId NOT in child_ids
         (403); a linked child is not 403.
  SUP-1  Entitlement API is live: GET /subscription + GET /plans (200).
  SUP-2  superAdmin PUT /platform/organizations/{id}/subscription assigns a plan
         (200); a non-superAdmin is denied (403).
  SEC-4  intel_parent_guidance_reports has the parent-scope RLS policy (DB check).

Idempotent: writes are additive cert rows; no destructive ops.
"""
import hashlib
import hmac
import json
import os
import subprocess
import urllib.error
import urllib.request

BASE = "https://akshara.veloraunisexsalon.com"
ORG = "a1000000-0000-4000-8000-000000000001"
SCHOOL_A = "a2000000-0000-4000-8000-000000000001"
SCHOOL_ADMIN = "a3000000-0000-4000-8000-000000000001"  # real pilot "Staging School Admin"
PARENT_USER = "a3000000-0000-4000-8000-000000000003"
CHILD_1 = "a4000000-0000-4000-8000-000000000001"
UNLINKED = "a4000000-0000-4000-8000-0000000009ff"
SOCK = os.path.expanduser("~/.ssh/akshara-cm.sock")
results = []


def rec(check, ok, detail=""):
    results.append((check, bool(ok), detail))
    print(f"  [{'PASS' if ok else 'FAIL':>4}] {check}  {detail}")


def http(method, path, token=None, body=None, headers=None, raw_body=None):
    data = raw_body if raw_body is not None else (
        json.dumps(body).encode() if body is not None else None)
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=90) as r:
            txt = r.read().decode()
            try:
                return r.status, json.loads(txt)
            except Exception:
                return r.status, txt
    except urllib.error.HTTPError as e:
        txt = e.read().decode()
        try:
            return e.code, json.loads(txt)
        except Exception:
            return e.code, txt
    except Exception as e:  # noqa: BLE001
        return 0, str(e)


def ssh(cmd, stdin=None):
    p = subprocess.run(["ssh", "-o", "ControlPath=" + SOCK, "akshara", cmd],
                       input=stdin, capture_output=True, text=True, timeout=90)
    return p.stdout.strip(), p.stderr.strip()


def data(b):
    return (b.get("data") if isinstance(b, dict) and "data" in b else b)


MINT = '''
import { SignJWT } from "npm:jose";
const secret = new TextEncoder().encode(Deno.env.get("JWT_SECRET"));
const t = await new SignJWT({
  tenant_id: Deno.env.get("ORG"), organization_id: Deno.env.get("ORG"),
  school_id: Deno.env.get("SCHOOLID") === "null" ? null : Deno.env.get("SCHOOLID"),
  role: Deno.env.get("ROLE"), role_slugs: [Deno.env.get("ROLE")],
  primary_role: Deno.env.get("ROLE"),
  permissions: JSON.parse(Deno.env.get("PERMS")), permissions_version: 1,
  scope: Deno.env.get("SCOPE"), school_group_id: null, student_id: null,
  child_ids: JSON.parse(Deno.env.get("CHILDREN")), session_id: "cert-w3",
}).setProtectedHeader({ alg: "HS256", typ: "JWT" })
  .setSubject(Deno.env.get("SUB")).setIssuedAt()
  .setExpirationTime(Math.floor(Date.now() / 1000) + 3600).sign(secret);
console.log(t);
'''


def mint(sub, role, scope, perms, school=SCHOOL_A, children=None):
    env = (f'-e ORG={ORG} -e SCHOOLID={school} -e SUB={sub} -e ROLE={role} '
           f'-e SCOPE={scope} -e PERMS=\'{json.dumps(perms)}\' '
           f"-e CHILDREN='{json.dumps(children or [])}'")
    out, _ = ssh(f"docker exec -i {env} akshara-edge deno run -A -", stdin=MINT)
    tok = out.splitlines()[-1] if out else ""
    return tok if tok.count(".") == 2 else None


print("=== Completion Wave 3 — contract gaps + entitlement + security LIVE cert ===\n")

# 0. health
s, b = http("GET", "/health")
rec("health", s == 200, f"HTTP {s}")

# tokens
admin = mint(SCHOOL_ADMIN, "schoolAdmin", "school",
             ["manageFinance", "viewFinance", "viewCommunications", "viewSubscription"])
noperm = mint(SCHOOL_ADMIN, "teacher", "school", ["viewAdminHub"])
superadmin = mint(SCHOOL_ADMIN, "superAdmin", "organization",
                  ["managePlatformSubscriptions", "viewSubscription"], school="null")
parent = mint(PARENT_USER, "parent", "parent",
              ["viewParentAcademicSummary"], children=[CHILD_1])
if not all([admin, noperm, superadmin, parent]):
    print("\nABORT: could not mint tokens (VPS/JWT_SECRET unreachable)")
    raise SystemExit(1)
rec("mint.tokens", True, "schoolAdmin / no-perm / superAdmin / parent")

# ── STF-4: discounts read ────────────────────────────────────────────────────
s, b = http("GET", "/finance/discounts", token=admin)
rec("STF-4.GET /finance/discounts", s == 200, f"HTTP {s}")

# ── STF-1: offline payments record -> list -> reconcile ──────────────────────
s, b = http("POST", "/finance/payments/offline", token=admin, body={
    "amount": 1000, "payment_method": "cash",
    "student_name": "Cert Student", "reference_number": "CERT-OFFLINE-1"})
off = data(b) if s in (200, 201) else {}
off_id = (off or {}).get("id") if isinstance(off, dict) else None
rec("STF-1.record offline payment", s in (200, 201) and bool(off_id), f"HTTP {s} id={off_id}")

s, b = http("GET", "/finance/payments/offline", token=admin)
lst = data(b)
items = lst.get("items") if isinstance(lst, dict) else (lst if isinstance(lst, list) else [])
rec("STF-1.list offline payments", s == 200 and any(
    isinstance(i, dict) and i.get("id") == off_id for i in (items or [])),
    f"HTTP {s} count={len(items or [])}")

if off_id:
    s, b = http("POST", f"/finance/payments/offline/{off_id}/reconcile", token=admin,
                body={"notes": "cert reconcile"})
    rec("STF-1.reconcile offline payment", s == 200, f"HTTP {s}")
else:
    rec("STF-1.reconcile offline payment", False, "no id to reconcile")

# ── STF-2: QR/UPI session create -> get -> confirm ───────────────────────────
s, b = http("POST", "/finance/payments/qr", token=admin, body={"amount": 1500})
qr = data(b) if s in (200, 201) else {}
qr_id = (qr or {}).get("id") if isinstance(qr, dict) else None
rec("STF-2.create QR session", s in (200, 201) and bool(qr_id), f"HTTP {s} id={qr_id}")
if qr_id:
    s, b = http("GET", f"/finance/payments/qr/{qr_id}", token=admin)
    rec("STF-2.get QR session", s == 200, f"HTTP {s}")
    s, b = http("POST", f"/finance/payments/qr/{qr_id}/confirm", token=admin,
                body={"receipt_number": "RC-CERT-1"})
    rec("STF-2.confirm QR session", s == 200, f"HTTP {s}")
else:
    rec("STF-2.get QR session", False, "no id")
    rec("STF-2.confirm QR session", False, "no id")

# ── STF-3 + INT-2: defaulters / reports / settings ───────────────────────────
s, b = http("GET", "/finance/defaulters", token=admin)
d = data(b) if s == 200 else {}
shape_ok = isinstance(d, dict) and all(
    k in d for k in ("kpis", "agingBuckets", "defaulters", "aiInsight", "aiActionLabel"))
rec("STF-3.GET /finance/defaulters", s == 200 and shape_ok, f"HTTP {s} keys={list(d) if isinstance(d, dict) else d}")
defrows = d.get("defaulters") if isinstance(d, dict) else []
int2_ok = isinstance(defrows, list) and all(
    isinstance(r, dict) and "guardianPhone" in r for r in defrows)
rec("INT-2.defaulters carry guardianPhone", int2_ok,
    f"rows={len(defrows or [])} (all have guardianPhone field)")

s, b = http("GET", "/finance/reports", token=admin)
rec("STF-3.GET /finance/reports", s == 200, f"HTTP {s}")
s, b = http("GET", "/finance/settings", token=admin)
rec("STF-3.GET /finance/settings", s == 200, f"HTTP {s}")
s, b = http("PUT", "/finance/settings", token=admin, body={
    "academic_year": "2026-27",
    "updates": [{"section_id": "general", "item_id": "late_fee", "value": "100"}]})
rec("STF-3.PUT /finance/settings", s == 200, f"HTTP {s}")

# ── STF-5: scholarships create -> update ─────────────────────────────────────
s, b = http("POST", "/finance/scholarships", token=admin, body={
    "name": "Cert Merit", "type": "merit",
    "max_discount": "50%", "eligibility": "Top 5%"})
sch = data(b) if s in (200, 201) else {}
sch_id = (sch or {}).get("id") if isinstance(sch, dict) else None
rec("STF-5.create scholarship", s in (200, 201) and bool(sch_id), f"HTTP {s} id={sch_id}")
if sch_id:
    s, b = http("PUT", f"/finance/scholarships/{sch_id}", token=admin,
                body={"name": "Cert Merit v2"})
    rec("STF-5.update scholarship", s == 200, f"HTTP {s}")
else:
    rec("STF-5.update scholarship", False, "no id")

# ── RBAC: finance write denied without manageFinance ─────────────────────────
s, b = http("POST", "/finance/scholarships", token=noperm,
            body={"name": "Nope", "type": "merit"})
rec("RBAC.finance write denied w/o permission", s == 403, f"HTTP {s} (expect 403)")

# ── SEC-1: webhook HMAC auth ─────────────────────────────────────────────────
secret, _ = ssh("docker exec akshara-edge printenv COMMUNICATION_WEBHOOK_SECRET")
rec("SEC-1.webhook secret configured on VPS", bool(secret), "secret present" if secret else "MISSING")
wh_body = json.dumps({"deliveryId": "00000000-0000-4000-8000-0000000000ff",
                      "status": "delivered"}).encode()

s, b = http("POST", "/communications/delivery/webhook", raw_body=wh_body)
rec("SEC-1.unsigned webhook rejected", s == 401, f"HTTP {s} (expect 401)")

s, b = http("POST", "/communications/delivery/webhook", raw_body=wh_body,
            headers={"x-akshara-signature": "deadbeef"})
rec("SEC-1.wrong-signature webhook rejected", s == 401, f"HTTP {s} (expect 401)")

if secret:
    sig = hmac.new(secret.encode(), wh_body, hashlib.sha256).hexdigest()
    s, b = http("POST", "/communications/delivery/webhook", raw_body=wh_body,
                headers={"x-akshara-signature": sig})
    # Valid signature passes auth -> tenant lookup fails for the unknown id -> 404.
    rec("SEC-1.valid-signature webhook passes auth", s == 404,
        f"HTTP {s} (expect 404 not-found, i.e. NOT 401)")
else:
    rec("SEC-1.valid-signature webhook passes auth", False, "no secret to sign with")

# ── SEC-2: communication mutation audited (device-token register) ────────────
s, b = http("POST", "/parent/device-tokens/register", token=admin,
            body={"token": "cert-device-token-w3", "platform": "android"})
reg_ok = s in (200, 201)
rec("SEC-2.device-token register", reg_ok, f"HTTP {s}")
cnt, _ = ssh(
    "docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -tAc "
    "\"SELECT count(*) FROM audit_events WHERE event_type='deviceTokenRegistered';\"")
rec("SEC-2.device-token register audited", cnt.isdigit() and int(cnt) >= 1,
    f"deviceTokenRegistered audit rows={cnt}")

# ── SEC-3: parent experience child-scope guard ───────────────────────────────
s, b = http("GET", f"/parent/experience/summary?studentId={UNLINKED}", token=parent)
rec("SEC-3.unlinked studentId rejected", s == 403, f"HTTP {s} (expect 403)")
s, b = http("GET", f"/parent/experience/summary?studentId={CHILD_1}", token=parent)
rec("SEC-3.linked child not 403", s != 403, f"HTTP {s} (expect not 403)")

# ── SUP-1: entitlement API live ──────────────────────────────────────────────
s, b = http("GET", "/subscription", token=admin)
rec("SUP-1.GET /subscription", s == 200, f"HTTP {s}")
s, b = http("GET", "/plans", token=admin)
rec("SUP-1.GET /plans", s == 200, f"HTTP {s}")

# ── SUP-2: superAdmin plan assignment ────────────────────────────────────────
s, b = http("PUT", f"/platform/organizations/{ORG}/subscription", token=superadmin,
            body={"planSlug": "professional"})
rec("SUP-2.superAdmin assigns plan", s == 200, f"HTTP {s}")
s, b = http("PUT", f"/platform/organizations/{ORG}/subscription", token=admin,
            body={"planSlug": "professional"})
rec("SUP-2.non-superAdmin denied", s == 403, f"HTTP {s} (expect 403)")

# ── SEC-4: parent-scope RLS policy present ───────────────────────────────────
pol, _ = ssh(
    "docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -tAc "
    "\"SELECT count(*) FROM pg_policies WHERE tablename='intel_parent_guidance_reports' "
    "AND policyname='intel_parent_guidance_parent_scope';\"")
rec("SEC-4.parent-scope RLS policy present", pol.strip() == "1", f"policy count={pol}")

# --- summary ---
passed = sum(1 for _, ok, _ in results if ok)
total = len(results)
print(f"\n=== {passed}/{total} checks passed ===")
raise SystemExit(0 if passed == total else 1)
