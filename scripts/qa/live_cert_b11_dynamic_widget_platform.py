#!/usr/bin/env python3
"""B11 — Dynamic Widget Platform (P3) — LIVE certification against the VPS pilot.

The role/vertical-pack dashboard contract the Flutter `dynamic_widgets` feature
consumes: data-source registry, layout versions, per-role layouts with tenant
overrides (pack default → save override → persist → reset). RBAC-gated by
viewDynamicWidgets / manageDynamicWidgets at school scope (no entitlement gate —
this is a school-level configurability feature, matching the shipped UI).

Real VPS + real DB + school-scope JWT (minted on the edge) + real persistence."""
import json, os, time, subprocess, urllib.request, urllib.error

BASE = os.environ.get("API_BASE_URL", "https://api.nikshaos.in")
ORG = "a1000000-0000-4000-8000-000000000001"
USER = "a3000000-0000-4000-8000-000000000001"
SCHOOL_A = "a2000000-0000-4000-8000-000000000001"
SOCK = os.path.expanduser("~/.ssh/akshara-cm.sock")
ROLE = "principal"
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
  role: "schoolAdmin", role_slugs: ["schoolAdmin"], primary_role: "schoolAdmin",
  permissions: JSON.parse(Deno.env.get("PERMS")), permissions_version: 1,
  scope: Deno.env.get("SCOPE"), school_group_id: null, student_id: null,
  child_ids: [], session_id: "cert-b11",
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

AUDIT_EVENT = "widget_platform.role_layout.saved"

def cleanup():
    # supabase_admin bypasses RLS + the missing erp_tenant DELETE grant.
    db(f"delete from dashboard_layouts where organization_id='{ORG}' "
       f"and school_id='{SCHOOL_A}' and dashboard_key='role:{ROLE}'")
    db(f"delete from audit_events where event_type='{AUDIT_EVENT}' "
       f"and (metadata->>'role')='{ROLE}'")

ALL = ["viewDynamicWidgets", "manageDynamicWidgets"]
print("=== B11 Dynamic Widget Platform LIVE certification (real VPS / school-JWT / DB / RBAC) ===\n")

# 0. health
s, b = http("GET", "/health")
rec("health", "PASS" if s == 200 and data(b).get("status") == "ok" else "FAIL", f"HTTP {s}")

full = mint(ALL)
if not full:
    print("\nABORT: could not mint token"); raise SystemExit(1)

cleanup()  # pristine start
try:
    # 1. data-source registry — 6 namespaced sources, real
    s, b = http("GET", "/widgets/data-sources", token=full)
    sources = data(b).get("items") or []
    keys = {x.get("key") for x in sources}
    ok_src = s == 200 and len(sources) == 6 and "operations.school_health" in keys \
        and all("." in (k or "") for k in keys)
    rec("data-sources:registry", "PASS" if ok_src else "FAIL", f"HTTP {s} sources={len(sources)}")

    # 2. layout versions — clean state: principal at v1, not overridden
    s, b = http("GET", "/widgets/layouts/versions?verticalPack=school", token=full)
    versions = data(b).get("items") or []
    pv = next((v for v in versions if v.get("role") == ROLE), None)
    ok_ver = s == 200 and pv and pv.get("version") == 1 and pv.get("isTenantOverride") is False
    rec("versions:pack-default", "PASS" if ok_ver else "FAIL",
        f"HTTP {s} roles={len(versions)} principal={pv}")

    # 3. role layout — pack default (evolution widget ids), not an override
    s, b = http("GET", f"/widgets/layouts/{ROLE}", token=full)
    lay = data(b)
    ids = {w.get("id") for w in (lay.get("widgets") or [])}
    ok_def = (s == 200 and lay.get("isTenantOverride") is False
              and {"school_health", "fee_collection", "student_risk", "attendance_risk"} <= ids)
    rec("layout:pack-default", "PASS" if ok_def else "FAIL", f"HTTP {s} widgets={len(ids)}")

    # 4. save tenant override (hide school_health) — version bumps, flagged override
    hidden = dict(lay)
    hidden["widgets"] = [
        {**w, "visible": False} if w.get("id") == "school_health" else w
        for w in (lay.get("widgets") or [])
    ]
    s, b = http("PUT", f"/widgets/layouts/{ROLE}", token=full,
                body={"layout": hidden, "version": lay.get("version", 1)})
    saved = data(b)
    ok_save = (s == 200 and saved.get("version") == 2 and saved.get("isTenantOverride") is True)
    rec("override:save-bumps-version", "PASS" if ok_save else "FAIL",
        f"HTTP {s} version={saved.get('version')} override={saved.get('isTenantOverride')}")

    # 5. override persists durably (re-read)
    s, b = http("GET", f"/widgets/layouts/{ROLE}", token=full)
    lay2 = data(b)
    sh = next((w for w in (lay2.get("widgets") or []) if w.get("id") == "school_health"), {})
    ok_persist = (s == 200 and lay2.get("isTenantOverride") is True
                  and lay2.get("version") == 2 and sh.get("visible") is False)
    rec("override:persists", "PASS" if ok_persist else "FAIL",
        f"HTTP {s} override={lay2.get('isTenantOverride')} school_health.visible={sh.get('visible')}")

    # 6. versions reflect the override
    s, b = http("GET", "/widgets/layouts/versions?verticalPack=school", token=full)
    pv2 = next((v for v in (data(b).get("items") or []) if v.get("role") == ROLE), None)
    ok_ver2 = pv2 and pv2.get("isTenantOverride") is True and pv2.get("version") == 2
    rec("versions:reflect-override", "PASS" if ok_ver2 else "FAIL", f"principal={pv2}")

    # 7. audit row written
    a = db(f"select count(*) from audit_events where event_type='{AUDIT_EVENT}' "
           f"and (metadata->>'role')='{ROLE}'")
    rec("audit:override-recorded", "PASS" if a and int(a) >= 1 else "FAIL", f"rows={a}")

    # 8. reset to pack default — clears override (no DELETE grant: row rewritten)
    s, b = http("POST", f"/widgets/layouts/{ROLE}/reset", token=full,
                body={"verticalPack": "school"})
    rst = data(b)
    sh3 = next((w for w in (rst.get("widgets") or []) if w.get("id") == "school_health"), {})
    ok_reset = (s == 200 and rst.get("isTenantOverride") is False and sh3.get("visible") is True)
    rec("reset:pack-default", "PASS" if ok_reset else "FAIL",
        f"HTTP {s} override={rst.get('isTenantOverride')}")

    # 9. after reset, GET is back to pack default
    s, b = http("GET", f"/widgets/layouts/{ROLE}", token=full)
    rec("reset:get-default", "PASS" if data(b).get("isTenantOverride") is False else "FAIL",
        f"override={data(b).get('isTenantOverride')}")

    # 10. RBAC — save needs manageDynamicWidgets (view-only token → 403)
    view_only = mint(["viewDynamicWidgets"])
    s, _ = http("PUT", f"/widgets/layouts/{ROLE}", token=view_only,
                body={"layout": lay, "version": 1})
    rec("rbac:save-needs-manage", "PASS" if s == 403 else "FAIL", f"HTTP {s}")

    # 11. RBAC — read needs viewDynamicWidgets (no-perm token → 403)
    no_perm = mint([])
    s, _ = http("GET", "/widgets/data-sources", token=no_perm)
    rec("rbac:read-needs-view", "PASS" if s == 403 else "FAIL", f"HTTP {s}")

    # 12. school scope required (org-scope token → 403)
    org_tok = mint(ALL, scope="organization", school_id="null")
    s, _ = http("GET", f"/widgets/layouts/{ROLE}", token=org_tok)
    rec("rbac:school-scope-required", "PASS" if s == 403 else "FAIL", f"org-scope HTTP {s}")

    # 13. unauthenticated → 401
    s, _ = http("GET", "/widgets/data-sources")
    rec("rbac:unauth-rejected", "PASS" if s == 401 else "FAIL", f"HTTP {s}")

    # 14. legacy widget registry untouched (still 200 with items)
    s, b = http("GET", "/widgets/registry", token=full)
    rec("legacy:registry-intact", "PASS" if s == 200 and (data(b).get("items")) else "FAIL",
        f"HTTP {s} items={len(data(b).get('items') or [])}")
finally:
    cleanup()
    left = db(f"select count(*) from dashboard_layouts where organization_id='{ORG}' "
              f"and school_id='{SCHOOL_A}' and dashboard_key='role:{ROLE}'")
    rec("cleanup:rows-removed", "PASS" if left == "0" else "FAIL", f"override_rows={left}")

print()
p = sum(1 for _, l, _ in results if l == "PASS")
f = sum(1 for _, l, _ in results if l == "FAIL")
bl = sum(1 for _, l, _ in results if l == "BLOCKED")
print(f"=== {p} PASS / {f} FAIL / {bl} BLOCKED ===")
raise SystemExit(1 if f else 0)
