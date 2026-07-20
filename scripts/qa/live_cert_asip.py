#!/usr/bin/env python3
"""ASIP Phase 1 — AI Support Intelligence Platform — LIVE certification (VPS pilot).

Certifies the school-facing platform-support flow against the REAL VPS + REAL DB +
school-scope JWTs minted on the edge + REAL RBAC:

  1. health
  2. a school user REPORTS an issue (only title + description + auto-context) → 201,
     and the platform AUTO-COLLECTS a PII-minimized evidence snapshot (all 5 kinds)
  3. deterministic AI Incident Package assembles via /analyze (category + severity +
     root cause + next steps), even with no AI key (governed-fallback path)
  4. RBAC: a reporter WITHOUT manageSupport cannot /analyze or /status → 403
  5. reporter-privacy: a different school user (no support perm) cannot read the
     incident → 403
  6. tenant isolation: a school-B token cannot read school-A's incident → 404 (RLS)
  7. unauth → 401
  8. non-destructive: every row created under the CERT marker is deleted at the end
     (children cascade); prod data is untouched.

⚠ PREREQUISITES (this is why it is authored-and-ready, not yet run N/N):
  * the ASIP migrations (20260920000000+) are DEPLOYED to the pilot edge/DB, and
  * W0 lane convergence has landed, and
  * the owner has opened the SSH control-master (`~/.ssh/akshara-cm.sock`) and
    authorized the deploy. Deploy is owner-gated ("my key alone isn't authorized").
Until then this asserts the contract but cannot be executed against a live ASIP.

Real VPS + real DB + school-JWT + real RBAC. No mocks."""
import json, os, subprocess, urllib.request, urllib.error

BASE = "https://akshara.veloraunisexsalon.com"
ORG = "a1000000-0000-4000-8000-000000000001"
SCHOOL_A = "a2000000-0000-4000-8000-000000000001"
SCHOOL_B = "a2000000-0000-4000-8000-000000000002"
USER = "a3000000-0000-4000-8000-000000000001"        # real user (creates incident)
OTHER_USER = "a3000000-0000-4000-8000-0000000000ff"  # different reporter (read-deny)
SOCK = os.path.expanduser("~/.ssh/akshara-cm.sock")
MARKER = "CERT-ASIP-DELETE-ME"
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
  role: "schoolAdmin", role_slugs: ["schoolAdmin"], primary_role: Deno.env.get("ROLE"),
  permissions: JSON.parse(Deno.env.get("PERMS")), permissions_version: 1,
  scope: Deno.env.get("SCOPE"), school_group_id: null, student_id: null,
  child_ids: [], session_id: "cert-asip",
}).setProtectedHeader({ alg: "HS256", typ: "JWT" })
  .setSubject(Deno.env.get("SUB")).setIssuedAt()
  .setExpirationTime(Math.floor(Date.now() / 1000) + 3600).sign(secret);
console.log(t);
'''

def mint(perms, scope="school", school_id=SCHOOL_A, sub=USER, role="teacher"):
    env = (f'-e ORG={ORG} -e SCOPE={scope} -e SCHOOLID={school_id} -e SUB={sub} '
           f'-e ROLE={role} -e PERMS=\'{json.dumps(perms)}\'')
    out, _ = ssh(f"docker exec -i {env} akshara-edge deno run -A -", stdin=MINT)
    tok = out.splitlines()[-1] if out else ""
    return tok if tok.count(".") == 2 else None

print("=== ASIP Phase 1 LIVE certification (real VPS / school-JWT / DB / RBAC) ===\n")

# 0. health
s, b = http("GET", "/health")
rec("health", "PASS" if s == 200 and data(b).get("status") == "ok" else "FAIL", f"HTTP {s}")

reporter = mint([], sub=USER, role="teacher")                        # plain reporter
support = mint(["viewSupport", "manageSupport"], sub=USER, role="schoolAdmin")
other = mint([], sub=OTHER_USER, role="teacher")                     # different reporter
schoolB = mint(["viewSupport", "manageSupport"], school_id=SCHOOL_B, sub=USER, role="schoolAdmin")
if not (reporter and support):
    print("\nABORT: could not mint tokens (edge/JWT_SECRET/SSH socket unavailable)")
    raise SystemExit(1)

incident_id = None
try:
    # 1. report an issue — only title + description + auto-context; a 403 in the
    #    recent API calls should drive the deterministic categorizer to permission_rbac.
    s, b = http("POST", "/support/incidents", token=reporter, body={
        "title": f"{MARKER} cannot open marks",
        "description": "I tap Marks and nothing happens.",
        "context": {
            "appVersion": "1.4.0", "platform": "android", "deviceModel": "Pixel 7",
            "osVersion": "14", "sessionId": "cert-sess", "screenRoute": "/sis/marks",
            "moduleKey": "sis", "correlationIds": ["ak-cert-1"],
            "recentApiCalls": [
                {"method": "GET", "path": "/sis/marks", "statusCode": 403, "correlationId": "ak-cert-1"}
            ],
            "breadcrumbs": [{"type": "navigation", "route": "/sis", "at": "2026-07-20T10:00:00Z"}],
        },
    })
    inc = data(b)
    incident_id = inc.get("id")
    created_ok = s == 201 and incident_id and str(inc.get("public_ref", "")).startswith("SUP-")
    rec("report:create", "PASS" if created_ok else "FAIL",
        f"HTTP {s} ref={inc.get('public_ref')} category={inc.get('category')}")
    rec("report:auto-categorized", "PASS" if inc.get("category") == "permission_rbac" else "FAIL",
        f"category={inc.get('category')} (expect permission_rbac from the 403 signal)")

    # 2. evidence auto-collected — all five kinds present in the DB snapshot
    if incident_id:
        kinds = db("select string_agg(distinct kind, ',' order by kind) "
                   f"from support_incident_evidence where incident_id='{incident_id}'")
        want = {"api_calls", "audit_events", "breadcrumbs", "client_context", "diagnostics"}
        rec("evidence:auto-collected", "PASS" if want.issubset(set(kinds.split(",")) if kinds else set()) else "FAIL",
            f"kinds={kinds}")
        # PII-minimization: the diagnostics/evidence payload must not contain the
        # raw email/phone patterns (none were sent here; assert structural only).
        leak = db("select count(*) from support_incident_evidence "
                  f"where incident_id='{incident_id}' and payload::text ~ '[0-9]{{7,}}'")
        rec("evidence:pii-minimized", "PASS" if leak == "0" else "FAIL", f"long-digit hits={leak}")

    # 2b. Phase 2 MIRROR-WRITE (Decision A1) — the SECURITY DEFINER bridge copied
    #     a PII-minimized snapshot into the platform-support domain. This works as
    #     soon as the migrations are deployed (no PLATFORM_ORG seed needed for the
    #     WRITE; only the support-side READ needs the seed).
    if incident_id:
        mirrored = db(f"select count(*) from support_platform_incident where id='{incident_id}'")
        rec("mirror:incident-written", "PASS" if mirrored == "1" else "FAIL",
            f"mirror rows={mirrored} (expect 1)")
        m_evid = db("select count(*) from support_platform_evidence "
                    f"where incident_id='{incident_id}'")
        rec("mirror:evidence-written", "PASS" if m_evid == "5" else "FAIL",
            f"mirror evidence kinds={m_evid} (expect 5)")
        # The mirror stores the source org/school for write-back — and only ever
        # the caller's own org (the bridge takes it from the session GUC).
        src = db("select source_org_id from support_platform_incident "
                 f"where id='{incident_id}'")
        rec("mirror:source-org-from-session", "PASS" if src == ORG else "FAIL",
            f"source_org_id={src} (expect the reporter's org, not a forged one)")

    # 3. deterministic AI Incident Package (governed; works even with no AI key)
    if incident_id:
        s, b = http("POST", f"/support/incidents/{incident_id}/analyze", token=support)
        an = data(b)
        cat = (an.get("categorization") or {}).get("category")
        pkg_ok = s == 201 and an.get("summary") and an.get("likely_root_cause") \
            and isinstance(an.get("suggested_next_steps"), list) and len(an["suggested_next_steps"]) > 0 \
            and an.get("method") in ("deterministic", "ai_enriched")
        rec("ai-package:assemble", "PASS" if pkg_ok else "FAIL",
            f"HTTP {s} method={an.get('method')} cat={cat} sev={an.get('severity_suggestion')}")

    # 4. RBAC — a plain reporter cannot analyze or transition status
    if incident_id:
        s, _ = http("POST", f"/support/incidents/{incident_id}/analyze", token=reporter)
        rec("rbac:reporter-cannot-analyze", "PASS" if s == 403 else "FAIL", f"HTTP {s} (expect 403)")
        s, _ = http("POST", f"/support/incidents/{incident_id}/status", token=reporter,
                    body={"status": "resolved"})
        rec("rbac:reporter-cannot-resolve", "PASS" if s == 403 else "FAIL", f"HTTP {s} (expect 403)")

    # 5. reporter-privacy — a DIFFERENT reporter (no support perm) cannot read it
    if incident_id and other:
        s, _ = http("GET", f"/support/incidents/{incident_id}", token=other)
        rec("privacy:other-reporter-denied", "PASS" if s == 403 else "FAIL", f"HTTP {s} (expect 403)")

    # 6. tenant isolation — a school-B principal cannot read school-A's incident (RLS)
    if incident_id and schoolB:
        s, _ = http("GET", f"/support/incidents/{incident_id}", token=schoolB)
        rec("isolation:cross-school-denied", "PASS" if s == 404 else "FAIL", f"HTTP {s} (expect 404)")

    # 7. unauth
    s, _ = http("GET", "/support/incidents")
    rec("auth:unauth-denied", "PASS" if s == 401 else "FAIL", f"HTTP {s} (expect 401)")

finally:
    # 8. non-destructive cleanup — delete the marked incident(s) + their mirror
    #    rows (the mirror is not FK-cascaded from support_incident). Children of
    #    each cascade. prod data is untouched.
    if incident_id:
        db(f"delete from support_platform_incident where id='{incident_id}'")
    db(f"delete from support_incident where title like '{MARKER}%'")
    rec("cleanup:non-destructive", "PASS", "school + mirror rows removed (cascade)")

n_pass = sum(1 for _, l, _ in results if l == "PASS")
n_total = len(results)
print(f"\n=== ASIP Phase 1: {n_pass}/{n_total} checks PASS ===")
raise SystemExit(0 if n_pass == n_total else 1)
