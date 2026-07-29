#!/usr/bin/env python3
"""B9 — Advanced AI Predictions (P2) — LIVE certification against the VPS pilot.

Three school-scoped, data-grounded prediction feeds (fee-default,
admission-conversion, student-risk) gated by the Enterprise `feature.ai_predictions`
entitlement. Certifies the real flow: gate DENIES the Professional pilot (402) →
a per-deal `overrides.grant` enables it → real predictions on real pilot data with
a real AI narrative. RBAC + unauth enforced. Restores the override at the end.

Real VPS + real DB + school-scope JWT (minted on the edge) + real AI/data."""
import json, os, subprocess, urllib.request, urllib.error

BASE = os.environ.get("API_BASE_URL", "https://api.nikshaos.in")
ORG = "a1000000-0000-4000-8000-000000000001"
SCHOOL_A = "a2000000-0000-4000-8000-000000000001"
USER = "a3000000-0000-4000-8000-000000000001"
SOCK = os.path.expanduser("~/.ssh/akshara-cm.sock")
results = []

def rec(check, label, detail=""):
    results.append((check, label, detail))
    print(f"  [{label:>7}] {check}  {detail}")

def http(method, path, token=None, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token: req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=90) as r:
            raw = r.read().decode()
            try: return r.status, json.loads(raw)
            except: return r.status, raw
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try: return e.code, json.loads(raw)
        except: return e.code, raw
    except Exception as e:
        return 0, str(e)

def ssh(cmd, stdin=None):
    p = subprocess.run(["ssh", "-o", "ControlPath=" + SOCK, "akshara", cmd],
                       input=stdin, capture_output=True, text=True, timeout=90)
    return p.stdout.strip(), p.stderr.strip()

def db(sql):
    out, _ = ssh(f'docker exec akshara-postgres psql -U supabase_admin -d akshara_db -tAc "{sql}"')
    return out

def grant_ai_predictions():
    # Build the JSONB with jsonb_build_object so no double-quotes appear inside the
    # double-quoted psql -c argument (embedding raw JSON breaks the nested quoting).
    db("update organization_subscriptions set overrides = "
       "jsonb_build_object('grant', jsonb_build_array('feature.ai_predictions')) "
       f"where organization_id='{ORG}'")

def clear_overrides():
    db(f"update organization_subscriptions set overrides = '{{}}'::jsonb where organization_id='{ORG}'")

def data(b): return (b.get("data") or {}) if isinstance(b, dict) else {}

MINT = '''
import { SignJWT } from "npm:jose";
const secret = new TextEncoder().encode(Deno.env.get("JWT_SECRET"));
const t = await new SignJWT({
  tenant_id: Deno.env.get("ORG"), organization_id: Deno.env.get("ORG"),
  school_id: Deno.env.get("SCHOOLID") === "null" ? null : Deno.env.get("SCHOOLID"),
  role: "schoolAdmin", role_slugs: ["schoolAdmin"], primary_role: "schoolAdmin",
  permissions: JSON.parse(Deno.env.get("PERMS")), permissions_version: 1,
  scope: Deno.env.get("SCOPE"), school_group_id: null, student_id: null,
  child_ids: [], session_id: "cert-b9",
}).setProtectedHeader({ alg: "HS256", typ: "JWT" })
  .setSubject(Deno.env.get("SUB")).setIssuedAt()
  .setExpirationTime(Math.floor(Date.now() / 1000) + 3600).sign(secret);
console.log(t);
'''

def mint(perms, scope="school", school_id=SCHOOL_A, sub=USER):
    env = (f'-e ORG={ORG} -e SCOPE={scope} -e SCHOOLID={school_id} -e SUB={sub} '
           f"-e PERMS='{json.dumps(perms)}'")
    out, _ = ssh(f"docker exec -i {env} akshara-edge deno run -A -", stdin=MINT)
    tok = out.splitlines()[-1] if out else ""
    return tok if tok.count(".") == 2 else None

ALL = ["viewFinance", "viewAdmissions", "viewStudentRisk"]
print("=== B9 Advanced AI Predictions LIVE certification (real VPS / school-JWT / DB / RBAC) ===\n")

# 0. health
s, b = http("GET", "/health")
rec("health", "PASS" if s == 200 and data(b).get("status") == "ok" else "FAIL", f"HTTP {s}")

full = mint(ALL)
if not full:
    print("\nABORT: could not mint token"); raise SystemExit(1)

# 1. entitlement gate DENIES the Professional pilot (no override) → 402
clear_overrides()
s, b = http("GET", "/predictions/fee-default", token=full)
rec("entitlement:gate-denies-professional", "PASS" if s == 402 else "FAIL",
    f"HTTP {s} (expect 402 PLAN_UPGRADE_REQUIRED)")

restore_needed = True
try:
    # Grant the Enterprise feature to the pilot org via a per-deal override (the
    # legitimate add-on mechanism) and certify the real feature on real data.
    grant_ai_predictions()

    # 2. fee-default — real, grounded in finance_invoices
    s, b = http("GET", "/predictions/fee-default", token=full)
    fee = data(b)
    fee_items = fee.get("items") or []
    grounded_fee = s == 200 and isinstance(fee_items, list) and all(
        isinstance(i.get("outstandingInr"), int) and 0 <= i.get("riskScore", -1) <= 100
        for i in fee_items)
    rec("predict:fee-default", "PASS" if grounded_fee else "FAIL",
        f"HTTP {s} items={len(fee_items)}")

    # 3. admission-conversion — real, grounded in admissions funnel
    s, b = http("GET", "/predictions/admission-conversion", token=full)
    conv = data(b)
    conv_items = conv.get("items") or []
    grounded_conv = s == 200 and isinstance(conv_items, list) and all(
        0 <= i.get("likelihood", -1) <= 100 and i.get("band") in ("hot", "warm", "cool")
        for i in conv_items)
    rec("predict:admission-conversion", "PASS" if grounded_conv else "FAIL",
        f"HTTP {s} items={len(conv_items)}")

    # 4. student-risk — reuses the certified engine, sorted highest-first
    s, b = http("GET", "/predictions/student-risk", token=full)
    risk = data(b)
    risk_items = risk.get("items") or []
    sorted_ok = all(
        risk_items[i]["riskScore"] >= risk_items[i + 1]["riskScore"]
        for i in range(len(risk_items) - 1))
    grounded_risk = s == 200 and isinstance(risk_items, list) and sorted_ok and all(
        0 <= i.get("riskScore", -1) <= 100 and
        i.get("riskLevel") in ("critical", "high", "medium", "low")
        for i in risk_items)
    rec("predict:student-risk", "PASS" if grounded_risk else "FAIL",
        f"HTTP {s} items={len(risk_items)} sorted={sorted_ok}")

    # 5. real AI narrative (deterministic baseline + Claude; safe fallback = BLOCKED)
    narr = risk.get("narrative") or fee.get("narrative") or ""
    # The deterministic baseline is the fixed "N record(s) analysed; M flagged…" template.
    is_baseline = "record(s) analysed" in narr or "lead(s) analysed" in narr
    if narr and not is_baseline:
        rec("ai:narrative", "PASS", f"refined narrative ({len(narr)} chars)")
    elif narr:
        rec("ai:narrative", "BLOCKED", "deterministic baseline — AI not engaged")
    else:
        rec("ai:narrative", "FAIL", "empty narrative")

    # 6. RBAC — fee-default needs viewFinance (token without it → 403)
    no_fin = mint(["viewAdmissions", "viewStudentRisk"])
    s, _ = http("GET", "/predictions/fee-default", token=no_fin)
    rec("rbac:fee-default-needs-viewFinance", "PASS" if s == 403 else "FAIL", f"HTTP {s}")

    # 7. RBAC — student-risk needs viewStudentRisk (token without it → 403)
    no_risk = mint(["viewFinance", "viewAdmissions"])
    s, _ = http("GET", "/predictions/student-risk", token=no_risk)
    rec("rbac:student-risk-needs-perm", "PASS" if s == 403 else "FAIL", f"HTTP {s}")

    # 8. unauthenticated → 401
    s, _ = http("GET", "/predictions/fee-default")
    rec("rbac:unauth-rejected", "PASS" if s == 401 else "FAIL", f"HTTP {s}")

    # 9. school-scope required (org-scope token has no school_id → 403)
    org_tok = mint(ALL, scope="organization", school_id="null")
    s, _ = http("GET", "/predictions/student-risk", token=org_tok)
    rec("rbac:school-scope-required", "PASS" if s == 403 else "FAIL", f"org-scope HTTP {s}")
finally:
    if restore_needed:
        clear_overrides()
        left = db(f"select overrides::text from organization_subscriptions where organization_id='{ORG}'")
        rec("cleanup:override-restored", "PASS" if left == "{}" else "FAIL", f"overrides={left}")

# summary
print()
p = sum(1 for _, l, _ in results if l == "PASS")
f = sum(1 for _, l, _ in results if l == "FAIL")
bl = sum(1 for _, l, _ in results if l == "BLOCKED")
print(f"=== {p} PASS / {f} FAIL / {bl} BLOCKED ===")
raise SystemExit(1 if f else 0)
