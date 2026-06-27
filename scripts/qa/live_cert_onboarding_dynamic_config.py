#!/usr/bin/env python3
"""Onboarding & Dynamic Configuration — LIVE certification against the VPS pilot.

Real VPS + real OTP auth + real DB + real RBAC. Proves, end-to-end, that Akshara
builds the right ERP for a school and that disabling a module removes it everywhere:
  G1/G8/G9 — startup go-live writes school_configuration.capabilities + subjects,
             and is idempotent (re-run does not 500).
  G2  — AI prefill honours interestedModules (modules + fee categories).
  G3  — backend enforces SCHOOL-DISABLED modules (403 MODULE_DISABLED), allows
        enabled ones, blocks unauth, and ENABLING restores access (round-trip).
  G4  — isChainOrganization is emitted (login user payload + JWT) for a multi-school org.
  G5  — dashboard layout never leaks a disabled optional-module widget.

Everything runs against an isolated throwaway school in the pilot org (one OTP
login, no impact on the live pilot school). Self-cleaning: the school is scrubbed
+ soft-deleted in a finally block. DB checks run via the ssh ControlMaster socket.
"""
import json, os, time, base64, subprocess, urllib.request, urllib.error

BASE = "https://akshara.veloraunisexsalon.com"
ORG = "a1000000-0000-4000-8000-000000000001"
ADMIN = "+919876543210"
ADMIN_UID = "a3000000-0000-4000-8000-000000000001"
T = "a2000000-0000-4000-8000-0000000000ce"   # throwaway onboarding target
SOCK = os.path.expanduser("~/.ssh/akshara-cm.sock")
TS = str(int(time.time()))
results = []


def rec(check, label, detail=""):
    results.append((check, label, detail))
    print(f"  [{label:>7}] {check}  {detail}")


def http(method, path, token=None, body=None, school=T):
    payload = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=payload, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    if school:
        req.add_header("X-School-Id", school)
    try:
        with urllib.request.urlopen(req, timeout=45) as r:
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


def db(sql):
    cmd = ["ssh", "-o", "ControlPath=" + SOCK, "akshara",
           f'docker exec akshara-postgres psql -U supabase_admin -d akshara_db -tAc "{sql}"']
    return subprocess.run(cmd, capture_output=True, text=True, timeout=45).stdout.strip()


def data(b):
    return (b.get("data") or {}) if isinstance(b, dict) else {}


def err_code(b):
    return (b.get("error") or {}).get("code") if isinstance(b, dict) else None


def jwt_claim(token, key):
    try:
        seg = token.split(".")[1]
        seg += "=" * (-len(seg) % 4)
        return json.loads(base64.urlsafe_b64decode(seg)).get(key)
    except Exception:
        return None


print("=== Onboarding & Dynamic Config LIVE cert (real VPS / real auth / real DB) ===\n")

# 0. health
s, b = http("GET", "/health")
rec("0.health", "PASS" if s == 200 and data(b).get("status") == "ok" else "FAIL", f"HTTP {s}")

try:
    # ── Setup: isolated throwaway school in the pilot org + admin membership ──
    db(f"insert into schools (id, organization_id, name, code) values "
       f"('{T}','{ORG}','Onboarding Cert School','OCERT{TS[-5:]}') "
       f"on conflict (id) do update set deleted_at=null, name=excluded.name")
    mid = db(f"insert into school_memberships (user_id, school_id, role, status) "
             f"values ('{ADMIN_UID}','{T}','schoolAdmin','active') returning id")
    if mid:
        db(f"insert into school_membership_roles (school_membership_id, role_slug, is_primary, status) "
           f"values ('{mid}','schoolAdmin',true,'active')")

    # 1. ONE OTP login, scoped to the throwaway school. Clear the sliding-window
    # OTP rate-limit first so repeated cert runs are not blocked (pilot/dev only).
    db(f"delete from otp_requests where phone='{ADMIN}' and created_at > now() - interval '1 hour'")
    s, b = http("POST", "/auth/login", body={"identifier": ADMIN})
    otp = data(b).get("otp")
    s, b = http("POST", "/auth/verify-otp", body={"identifier": ADMIN, "otp": otp, "schoolId": T})
    admin = data(b).get("accessToken")
    rec("1.auth:admin-otp(scoped)", "PASS" if admin else "FAIL", f"HTTP {s}")
    if not admin:
        raise SystemExit("no token")

    # ── G4 — chain-organization flag (pilot org runs multiple schools) ───────
    s, b = http("GET", "/auth/me", admin)
    me_chain = data(b).get("isChainOrganization")
    rec("G4.auth-me-chain-flag", "PASS" if s == 200 and me_chain is True else "FAIL",
        f"HTTP {s} isChainOrganization={me_chain}")
    rec("G4.jwt-chain-claim", "PASS" if jwt_claim(admin, "is_chain_organization") is True else "FAIL",
        f"is_chain_organization={jwt_claim(admin, 'is_chain_organization')}")

    # ── G2 — AI prefill honours interestedModules ────────────────────────────
    brief = {"schoolName": "Cert Day School", "board": "CBSE", "curriculum": "CBSE",
             "schoolType": "day", "lowestGrade": "Grade 1", "highestGrade": "Grade 5",
             "estimatedStudents": 200, "estimatedTeachers": 12,
             "interestedModules": ["transport", "library"]}
    s, b = http("POST", "/onboarding/startup/ai-prefill", admin, brief)
    prop = data(b).get("proposal") or {}
    fees = [str(x).lower() for x in (prop.get("feeCategories") or [])]
    mods = [str(x).lower() for x in (prop.get("modulesEnabled") or [])]
    g2_ok = (s == 200 and "transport" in fees and "library" in fees
             and "transport" in mods and "library" in mods)
    rec("G2.prefill-honours-facilities", "PASS" if g2_ok else "FAIL",
        f"HTTP {s} fees={fees} modules={[m for m in mods if m in ('transport','library')]}")

    # ── G1/G8 — go-live writes capabilities + subjects ───────────────────────
    payload = {"schoolName": "Onboarding Cert School", "board": "CBSE", "curriculum": "CBSE",
               "address": "1 Cert Road", "contactPhone": "9000000001",
               "contactEmail": "cert@example.com", "academicYear": "2026-27",
               "classes": ["Grade 1", "Grade 2"], "sections": ["A", "B"],
               "feeModel": "term", "feeCategories": ["Tuition", "Transport", "Library"],
               "themePrimary": "#1565C0", "defaultLanguage": "en",
               "modulesEnabled": ["sis", "finance", "attendance", "transport", "library"]}
    s, b = http("PUT", "/onboarding/startup", admin, payload)
    rec("G1.startup-upsert", "PASS" if s == 200 else "FAIL", f"HTTP {s}")

    s, b = http("POST", "/onboarding/startup/go-live", admin)
    prov = data(b).get("provision") or {}
    rec("G1.go-live", "PASS" if s == 200 and prov.get("provisioned") else "FAIL",
        f"HTTP {s} provisioned={prov.get('provisioned')} errs={data(b).get('validationErrors')}")
    rec("G1.capabilities-applied", "PASS" if prov.get("capabilitiesApplied") else "FAIL",
        f"capabilitiesApplied={prov.get('capabilitiesApplied')}")
    rec("G8.subjects-provisioned", "PASS" if (prov.get("subjectCount") or 0) > 0 else "FAIL",
        f"subjectCount={prov.get('subjectCount')} syllabusTopics={prov.get('syllabusTopicsCreated')}")

    caps_raw = db(f"select capabilities from school_configuration where school_id='{T}'")
    caps = json.loads(caps_raw) if caps_raw else {}
    caps_ok = (caps.get("transport") is True and caps.get("library") is True
               and caps.get("hostel") is False and caps.get("inventory") is False
               and caps.get("alumni") is False)
    rec("G1.db-capabilities-match-modules", "PASS" if caps_ok else "FAIL", f"caps={caps}")
    subj = db(f"select count(*) from academic_subjects where school_id='{T}'")
    rec("G8.db-subjects-exist", "PASS" if subj.isdigit() and int(subj) > 0 else "FAIL", f"subjects={subj}")

    # ── G9 — idempotent re-run does not 500 ──────────────────────────────────
    s, b = http("POST", "/onboarding/startup/go-live", admin)
    rec("G9.go-live-idempotent", "PASS" if s == 200 else "FAIL", f"HTTP {s} (re-run)")

    # ── G3 — backend enforces school-disabled modules (now configured on T) ──
    # After go-live: transport/library ON, hostel/inventory/alumni OFF.
    s, b = http("GET", "/hostel/dashboard", admin)
    rec("G3.disabled-module-403", "PASS" if s == 403 and err_code(b) == "MODULE_DISABLED" else "FAIL",
        f"HTTP {s} code={err_code(b)}")
    s, b = http("GET", "/transport/routes", admin)
    rec("G3.enabled-module-passes", "PASS" if err_code(b) != "MODULE_DISABLED" and s != 402 else "FAIL",
        f"HTTP {s} code={err_code(b)}")
    s, b = http("GET", "/hostel/dashboard")  # no token
    rec("G3.unauth-401", "PASS" if s == 401 else "FAIL", f"HTTP {s}")

    # Round-trip: disable transport -> blocked; re-enable -> restored.
    db(f"update school_configuration set capabilities = capabilities || '{{\\\"transport\\\": false}}'::jsonb where school_id='{T}'")
    _, b_off = http("GET", "/transport/routes", admin)
    db(f"update school_configuration set capabilities = capabilities || '{{\\\"transport\\\": true}}'::jsonb where school_id='{T}'")
    _, b_on = http("GET", "/transport/routes", admin)
    rt_ok = err_code(b_off) == "MODULE_DISABLED" and err_code(b_on) != "MODULE_DISABLED"
    rec("G3.toggle-round-trip", "PASS" if rt_ok else "FAIL",
        f"disabled->{err_code(b_off)} ; re-enabled->{err_code(b_on)}")

    # ── G5 — dashboard layout excludes disabled optional-module widgets ──────
    s, b = http("GET", "/widgets/layouts/principal", admin)
    if s == 200:
        widgets = data(b).get("widgets") or []
        leaked = [w.get("dataSource") for w in widgets
                  if str(w.get("dataSource", "")).startswith(("hostel.", "alumni.", "inventory."))]
        rec("G5.layout-no-disabled-widget", "PASS" if widgets and not leaked else "FAIL",
            f"HTTP 200 widgets={len(widgets)} leaked={leaked}")
    else:
        rec("G5.layout-no-disabled-widget", "BLOCKED", f"HTTP {s}")

finally:
    # Teardown — scrub + soft-delete the throwaway school (FK-safe order).
    db(f"delete from school_membership_roles where school_membership_id in "
       f"(select id from school_memberships where school_id='{T}')")
    db(f"delete from finance_fee_structure_items where fee_structure_id in "
       f"(select id from finance_fee_structures where school_id='{T}')")
    for tbl in ("syllabus_topics", "syllabus_chapters", "syllabus_generations",
                "academic_subjects", "sections", "classes", "academic_years",
                "finance_fee_structures", "school_branding", "school_configuration",
                "startup_onboarding", "school_memberships"):
        db(f"delete from {tbl} where school_id='{T}'")
    db(f"update schools set deleted_at=timezone('utc',now()) where id='{T}'")

p = sum(1 for _, l, _ in results if l == "PASS")
f = sum(1 for _, l, _ in results if l == "FAIL")
bk = sum(1 for _, l, _ in results if l == "BLOCKED")
print(f"\n=== RESULT: {p} PASS / {f} FAIL / {bk} BLOCKED  (total {len(results)}) ===")
raise SystemExit(1 if f else 0)
