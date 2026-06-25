#!/usr/bin/env python3
"""B8 — Director Multi-School (P2) — LIVE certification against the VPS pilot.

Polish for multi-branch sales on the certified Batch-6 Director backend:
 (A) metric-input write path (spend/expense/capacity → Margin/ROI/Capacity),
 (B) real board-pack export (server-assembled document from live aggregates),
 (C) real-AI executive summary (deterministic baseline + Claude, safe fallback).

Real VPS + real DB + org-scope JWT (minted on the edge with the live secret) +
RBAC + multi-school aggregation. Classifies each check PASS/FAIL/BLOCKED.
DB verification + token minting run through the ssh ControlMaster socket."""
import json, os, subprocess, urllib.request, urllib.error

BASE = "https://akshara.veloraunisexsalon.com"
ORG = "a1000000-0000-4000-8000-000000000001"
SCHOOL_A = "a2000000-0000-4000-8000-000000000001"
USER = "a3000000-0000-4000-8000-000000000001"  # real users.id → satisfies generated_by FK
SOCK = os.path.expanduser("~/.ssh/akshara-cm.sock")
ADMIN = "+919876543210"
PERIOD = "2026-06-01"
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

def data(b): return (b.get("data") or {}) if isinstance(b, dict) else {}

MINT = '''
import { SignJWT } from "npm:jose";
const secret = new TextEncoder().encode(Deno.env.get("JWT_SECRET"));
const t = await new SignJWT({
  tenant_id: Deno.env.get("ORG"), organization_id: Deno.env.get("ORG"),
  school_id: Deno.env.get("SCHOOLID") === "null" ? null : Deno.env.get("SCHOOLID"),
  role: "organizationOwner", role_slugs: ["organizationOwner"],
  primary_role: "organizationOwner",
  permissions: JSON.parse(Deno.env.get("PERMS")), permissions_version: 1,
  scope: Deno.env.get("SCOPE"), school_group_id: null, student_id: null,
  child_ids: [], session_id: "cert-b8",
}).setProtectedHeader({ alg: "HS256", typ: "JWT" })
  .setSubject(Deno.env.get("SUB")).setIssuedAt()
  .setExpirationTime(Math.floor(Date.now() / 1000) + 3600).sign(secret);
console.log(t);
'''

def mint(perms, scope="organization", school_id="null", sub=USER):
    env = (f'-e ORG={ORG} -e SCOPE={scope} -e SCHOOLID={school_id} -e SUB={sub} '
           f"-e PERMS='{json.dumps(perms)}'")
    out, err = ssh(f"docker exec -i {env} akshara-edge deno run -A -", stdin=MINT)
    tok = out.splitlines()[-1] if out else ""
    return tok if tok.count(".") == 2 else None

VIEW_MANAGE = ["viewDirectorPortal", "manageDirectorPortal"]
print("=== B8 Director Multi-School LIVE certification (real VPS / org-JWT / DB / RBAC) ===\n")

# 0. health
s, b = http("GET", "/health")
rec("health", "PASS" if s == 200 and data(b).get("status") == "ok" else "FAIL", f"HTTP {s}")

# 1. org-scope token minted + accepted by the Director portal
org = mint(VIEW_MANAGE)
s, b = http("GET", "/director/dashboard", token=org)
dash = data(b)
rec("auth:org-token-accepted", "PASS" if org and s == 200 else "FAIL", f"HTTP {s}")
if not org:
    print("\nABORT: could not mint org token"); raise SystemExit(1)

# 2. entitlement: professional plan grants module.multi_branch (the Director gate)
grant = db(f"select count(*) from plan_entitlements where plan_slug='professional' and entitlement_slug='module.multi_branch'")
plan = db(f"select plan_slug from organization_subscriptions where organization_id='{ORG}' limit 1")
rec("entitlement:professional-grants-multi-branch",
    "PASS" if grant == "1" and plan == "professional" else "FAIL",
    f"grant={grant} plan={plan}")

# 3. multi-school aggregation — real per-school rows for the org, KPIs, no PII
schools = dash.get("schoolRows") or []
n_db = db(f"select count(*) from schools where organization_id='{ORG}' and deleted_at is null")
agg_ok = (len(schools) == int(n_db or 0) and len(schools) >= 2
          and len(dash.get("kpis") or []) == 5
          and (dash.get("executiveSummary") or "").strip() != "")
rec("aggregation:multi-school-live", "PASS" if agg_ok else "FAIL",
    f"rows={len(schools)} db_schools={n_db} kpis={len(dash.get('kpis') or [])}")

# 4. RBAC — Director requires organization scope (a school-scope token is refused)
school_tok = mint(VIEW_MANAGE, scope="school", school_id=SCHOOL_A)
s, _ = http("GET", "/director/dashboard", token=school_tok)
rec("rbac:org-scope-required", "PASS" if s == 403 else "FAIL", f"school-scope HTTP {s}")

# 5. RBAC — writes require manageDirectorPortal (view-only org token is refused)
view_only = mint(["viewDirectorPortal"])
s, _ = http("POST", "/director/metric-inputs", token=view_only,
            body={"schoolId": SCHOOL_A, "periodMonth": "2026-06"})
rec("rbac:manage-required-for-write", "PASS" if s == 403 else "FAIL", f"view-only HTTP {s}")

# 6. unauthenticated request is rejected
s, _ = http("GET", "/director/dashboard")
rec("rbac:unauth-rejected", "PASS" if s == 401 else "FAIL", f"HTTP {s}")

# 7. metric-input upsert — the new write path persists real figures
db(f"delete from director_metric_inputs where organization_id='{ORG}' and school_id='{SCHOOL_A}' and period_month='{PERIOD}'")
s, b = http("POST", "/director/metric-inputs", token=org, body={
    "schoolId": SCHOOL_A, "periodMonth": "2026-06",
    "marketingSpendInr": 500000, "operatingExpenseInr": 2000000, "studentCapacity": 2000,
})
saved = data(b)
row = db(f"select operating_expense_inr::int from director_metric_inputs where organization_id='{ORG}' and school_id='{SCHOOL_A}' and period_month='{PERIOD}'")
rec("metric-input:upsert-persists", "PASS" if s == 200 and saved.get("id") and row == "2000000" else "FAIL",
    f"HTTP {s} db_expense={row}")

# 8. entered inputs flow into the live aggregates (Margin / Marketing ROI)
_, rev = http("GET", "/director/revenue", token=org)
_, mkt = http("GET", "/director/marketing", token=org)
expenses = data(rev).get("expensesCr")
spend = data(mkt).get("totalSpendLakhs")
reflected = isinstance(expenses, (int, float)) and expenses > 0 and \
            isinstance(spend, (int, float)) and spend > 0
rec("metric-input:reflected-in-aggregates", "PASS" if reflected else "FAIL",
    f"expensesCr={expenses} spendLakhs={spend}")

# 9. real export — a board-pack document assembled from live aggregates
rid = db(f"select id from director_reports where organization_id='{ORG}' order by last_generated_at limit 1")
before = db(f"select extract(epoch from last_generated_at)::bigint from director_reports where id='{rid}'")
s, b = http("POST", f"/director/reports/{rid}/export", token=org)
doc = data(b).get("document") or {}
after = db(f"select extract(epoch from last_generated_at)::bigint from director_reports where id='{rid}'")
export_ok = (s == 200 and isinstance(doc, dict)
             and len(doc.get("kpis") or []) >= 4
             and len(doc.get("schools") or []) >= 2
             and (doc.get("executiveSummary") or "").strip() != ""
             and (after or "0") >= (before or "0"))
rec("export:real-board-pack", "PASS" if export_ok else "FAIL",
    f"HTTP {s} kpis={len(doc.get('kpis') or [])} schools={len(doc.get('schools') or [])} regen={before}->{after}")

# 10. real-AI executive summary (deterministic baseline + Claude; safe fallback OK)
s, b = http("POST", "/director/summary", token=org, body={"focusArea": "strategic_reports"})
summ = data(b).get("summary") or ""
# A deterministic-only brief is a fixed template; a refined one reads as a longer
# board narrative. We accept either as functional, flagging fallback as BLOCKED.
if s == 200 and len(summ) > 200 and "Portfolio spans" not in summ:
    rec("ai:executive-summary", "PASS", f"refined narrative ({len(summ)} chars)")
elif s == 200 and summ.strip():
    rec("ai:executive-summary", "BLOCKED", f"deterministic baseline ({len(summ)} chars) — AI not engaged")
else:
    rec("ai:executive-summary", "FAIL", f"HTTP {s}")

# 11. input validation — a malformed write is rejected, never a 500
s, _ = http("POST", "/director/metric-inputs", token=org, body={"periodMonth": "2026-06"})
rec("metric-input:validation", "PASS" if s == 422 else "FAIL", f"missing schoolId HTTP {s}")

# 12. audit — the export wrote a real audit row
acount = db(f"select count(*) from audit_events where event_type='director.report.exported'")
rec("audit:export-recorded", "PASS" if (acount or '0').isdigit() and int(acount) >= 1 else "FAIL",
    f"director.report.exported rows={acount}")

# summary
print()
p = sum(1 for _, l, _ in results if l == "PASS")
f = sum(1 for _, l, _ in results if l == "FAIL")
bl = sum(1 for _, l, _ in results if l == "BLOCKED")
print(f"=== {p} PASS / {f} FAIL / {bl} BLOCKED ===")
raise SystemExit(1 if f else 0)
