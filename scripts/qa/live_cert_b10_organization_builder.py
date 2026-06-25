#!/usr/bin/env python3
"""B10 — Organization Builder (P3) — LIVE certification against the VPS pilot.

The chain/trust org-scope flow: vertical packs → interview (with real AI
recommendation) → config preview → REAL provisioning → job status, gated by the
Enterprise `feature.organization_builder` entitlement. Certifies the real flow:
gate DENIES the Professional pilot (402) → a per-deal `overrides.grant` enables it
→ real org-scoped CRUD on real DB with a real AI recommendation. RBAC + org-scope
+ unauth enforced. Restores the override and removes the cert rows at the end.

Real VPS + real DB + organization-scope JWT (minted on the edge) + real AI/data."""
import json, os, time, subprocess, urllib.request, urllib.error

BASE = "https://akshara.veloraunisexsalon.com"
ORG = "a1000000-0000-4000-8000-000000000001"
USER = "a3000000-0000-4000-8000-000000000001"
SCHOOL_A = "a2000000-0000-4000-8000-000000000001"
SOCK = os.path.expanduser("~/.ssh/akshara-cm.sock")
DRAFT = f"draft_cert_{int(time.time())}"
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

def grant_feature():
    db("update organization_subscriptions set overrides = "
       "jsonb_build_object('grant', jsonb_build_array('feature.organization_builder')) "
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
  role: "organizationOwner", role_slugs: ["organizationOwner"], primary_role: "organizationOwner",
  permissions: JSON.parse(Deno.env.get("PERMS")), permissions_version: 1,
  scope: Deno.env.get("SCOPE"), school_group_id: null, student_id: null,
  child_ids: [], session_id: "cert-b10",
}).setProtectedHeader({ alg: "HS256", typ: "JWT" })
  .setSubject(Deno.env.get("SUB")).setIssuedAt()
  .setExpirationTime(Math.floor(Date.now() / 1000) + 3600).sign(secret);
console.log(t);
'''

def mint(perms, scope="organization", school_id="null", sub=USER):
    env = (f'-e ORG={ORG} -e SCOPE={scope} -e SCHOOLID={school_id} -e SUB={sub} '
           f"-e PERMS='{json.dumps(perms)}'")
    out, _ = ssh(f"docker exec -i {env} akshara-edge deno run -A -", stdin=MINT)
    tok = out.splitlines()[-1] if out else ""
    return tok if tok.count(".") == 2 else None

ALL = ["viewOrganizationBuilder", "manageOrganizationBuilder"]
print("=== B10 Organization Builder LIVE certification (real VPS / org-JWT / DB / RBAC) ===\n")

# 0. health
s, b = http("GET", "/health")
rec("health", "PASS" if s == 200 and data(b).get("status") == "ok" else "FAIL", f"HTTP {s}")

full = mint(ALL)
if not full:
    print("\nABORT: could not mint token"); raise SystemExit(1)

# 1. entitlement gate DENIES the Professional pilot (no override) → 402
clear_overrides()
s, b = http("GET", "/platform/org-builder/packs", token=full)
rec("entitlement:gate-denies-professional", "PASS" if s == 402 else "FAIL",
    f"HTTP {s} (expect 402 PLAN_UPGRADE_REQUIRED)")

try:
    grant_feature()

    # 2. packs catalog — real, from DB (4 verticals)
    s, b = http("GET", "/platform/org-builder/packs", token=full)
    packs = data(b).get("items") or []
    pack_ids = {p.get("id") for p in packs}
    ok_packs = s == 200 and {"pack_school", "pack_salon", "pack_hospital", "pack_restaurant"} <= pack_ids
    rec("packs:catalog-from-db", "PASS" if ok_packs else "FAIL", f"HTTP {s} packs={len(packs)}")

    # 3. create draft on demand (GET draft) — real persisted row
    s, b = http("GET", f"/platform/org-builder/interview/drafts/{DRAFT}", token=full)
    d = data(b)
    rec("draft:create-on-demand", "PASS" if s == 200 and d.get("id") == DRAFT else "FAIL",
        f"HTTP {s} step={d.get('currentStep')}")

    # 4. save interview step 0 (pick salon) — advances + real AI recommendation
    s, b = http("POST", f"/platform/org-builder/interview/drafts/{DRAFT}/step", token=full,
                body={"stepIndex": 0, "answers": {"pack_id": "pack_salon",
                      "identity_name": "Velora Cert Branch"}})
    d0 = data(b)
    recs = d0.get("recommendations") or []
    ok_step = (s == 200 and d0.get("currentStep") == 1 and d0.get("packId") == "pack_salon"
               and d0.get("organizationName") == "Velora Cert Branch" and len(recs) >= 1)
    rec("interview:save-step-advances", "PASS" if ok_step else "FAIL",
        f"HTTP {s} step={d0.get('currentStep')} recs={len(recs)}")

    # 5. real AI recommendation (deterministic baseline = BLOCKED, refined = PASS)
    detail = (recs[0].get("detail") if recs else "") or ""
    baseline = "Salons with repeat clients benefit from a cross-branch loyalty programme."
    if detail and detail != baseline:
        rec("ai:recommendation", "PASS", f"refined ({len(detail)} chars)")
    elif detail == baseline:
        rec("ai:recommendation", "BLOCKED", "deterministic baseline — AI not engaged")
    else:
        rec("ai:recommendation", "FAIL", "no recommendation")

    # 6. advance through the remaining steps → ready_for_preview at step 6
    last = d0
    for step in range(1, 7):
        s, b = http("POST", f"/platform/org-builder/interview/drafts/{DRAFT}/step", token=full,
                    body={"stepIndex": step, "answers": {"note": f"step{step}"}})
        last = data(b)
    ok_ready = last.get("currentStep") == 7 and last.get("status") == "ready_for_preview"
    rec("interview:reaches-ready-for-preview", "PASS" if ok_ready else "FAIL",
        f"step={last.get('currentStep')} status={last.get('status')}")

    # 7. config preview — salon roles + universal-employee module
    s, b = http("POST", "/platform/org-builder/preview", token=full, body={"draftId": DRAFT})
    pv = data(b)
    mods = {m.get("id") for m in (pv.get("modules") or [])}
    roles = [r.get("name") for r in (pv.get("roles") or [])]
    ok_preview = (s == 200 and "universal_employee" in mods and "Salon Manager" in roles
                  and pv.get("packId") == "pack_salon")
    rec("preview:resolved-config", "PASS" if ok_preview else "FAIL",
        f"HTTP {s} modules={len(mods)} roles={roles}")

    # 8. provision — REAL, persisted, all six steps completed
    s, b = http("POST", "/platform/org-builder/provision", token=full, body={"draftId": DRAFT})
    job = data(b)
    steps = job.get("steps") or []
    all_done = len(steps) == 6 and all(st.get("status") == "completed" for st in steps)
    ok_prov = s == 200 and job.get("status") == "completed" and all_done
    rec("provision:real-completed", "PASS" if ok_prov else "FAIL",
        f"HTTP {s} status={job.get('status')} steps={len(steps)}")
    job_id = job.get("id")

    # 9. job status persisted (GET /platform/provisioning-jobs/:id)
    s, b = http("GET", f"/platform/provisioning-jobs/{job_id}", token=full)
    j2 = data(b)
    rec("job:status-persisted", "PASS" if s == 200 and j2.get("id") == job_id
        and j2.get("status") == "completed" else "FAIL", f"HTTP {s}")

    # 10. draft flipped to provisioned (durable)
    s, b = http("GET", f"/platform/org-builder/interview/drafts/{DRAFT}", token=full)
    rec("draft:marked-provisioned", "PASS" if data(b).get("status") == "provisioned" else "FAIL",
        f"status={data(b).get('status')}")

    # 11. audit row written for the provision
    audit = db(f"select count(*) from audit_events "
               f"where event_type='orgBuilder.organization.provisioned' and entity_id='{job_id}'")
    rec("audit:provision-recorded", "PASS" if audit == "1" else "FAIL", f"rows={audit}")

    # 12. RBAC — provision needs manageOrganizationBuilder (view-only token → 403)
    view_only = mint(["viewOrganizationBuilder"])
    s, _ = http("POST", "/platform/org-builder/provision", token=view_only, body={"draftId": DRAFT})
    rec("rbac:provision-needs-manage", "PASS" if s == 403 else "FAIL", f"HTTP {s}")

    # 13. RBAC — packs needs viewOrganizationBuilder (no-perm token → 403)
    no_perm = mint([])
    s, _ = http("GET", "/platform/org-builder/packs", token=no_perm)
    rec("rbac:packs-needs-view", "PASS" if s == 403 else "FAIL", f"HTTP {s}")

    # 14. org-scope required (school-scope token → 403)
    school_tok = mint(ALL, scope="school", school_id=SCHOOL_A)
    s, _ = http("GET", "/platform/org-builder/packs", token=school_tok)
    rec("rbac:org-scope-required", "PASS" if s == 403 else "FAIL", f"school-scope HTTP {s}")

    # 15. unauthenticated → 401
    s, _ = http("GET", "/platform/org-builder/packs")
    rec("rbac:unauth-rejected", "PASS" if s == 401 else "FAIL", f"HTTP {s}")
finally:
    # cleanup: remove cert rows (supabase_admin bypasses RLS) + restore overrides.
    # Audit rows first (they reference the job id), then jobs, then the draft.
    db(f"delete from audit_events where event_type='orgBuilder.organization.provisioned' "
       f"and entity_id in (select id::text from org_builder_provisioning_jobs where draft_id='{DRAFT}')")
    db(f"delete from org_builder_provisioning_jobs where draft_id='{DRAFT}'")
    db(f"delete from org_builder_interview_drafts where id='{DRAFT}'")
    clear_overrides()
    left = db(f"select overrides::text from organization_subscriptions where organization_id='{ORG}'")
    leftover = db(f"select count(*) from org_builder_interview_drafts where id='{DRAFT}'")
    rec("cleanup:restored", "PASS" if left == "{}" and leftover == "0" else "FAIL",
        f"overrides={left} cert_drafts={leftover}")

print()
p = sum(1 for _, l, _ in results if l == "PASS")
f = sum(1 for _, l, _ in results if l == "FAIL")
bl = sum(1 for _, l, _ in results if l == "BLOCKED")
print(f"=== {p} PASS / {f} FAIL / {bl} BLOCKED ===")
raise SystemExit(1 if f else 0)
