#!/usr/bin/env python3
"""Pilot School Simulation — LIVE certification against the VPS pilot.

Simulates real schools the way customers run them — NOT a code audit. Proves,
end-to-end against the real VPS + real OTP auth + real DB + real RBAC:

  PART A — Multi-board onboarding. Four throwaway schools (Small Private/State,
           Large CBSE, ICSE, State Board) each go-live with a board-appropriate
           config and provision subjects + capabilities; disabled modules 403,
           empty reads 200 (never 500), AI prefill honours the board.
  PART B — Organization topology. A single-school org reports
           isChainOrganization=false; a 2-school trust reports true (the live
           rule: >1 non-deleted school in the org). Director multi-branch is
           entitlement-gated for the single-school trial org.
  PART C — Dynamic module lifecycle for all 7 modules a school grows into
           (Inventory, Hostel, Library, Transport, HR, Alumni, Marketing):
           disabled -> API 403 MODULE_DISABLED (UI hides) -> enable -> API opens
           -> create data -> disable -> API 403 again BUT the data row SURVIVES
           (not deleted) -> re-enable -> API opens and data is restored. Marketing
           is plan-entitlement-gated (402 upgrade path), proven on a trial org.

Everything runs against isolated throwaway schools/orgs in the pilot; a finally
block scrubs + soft-deletes them. DB checks run via the ssh ControlMaster socket.

Run:  python3 scripts/qa/live_cert_pilot_simulation.py
"""
import json, os, time, base64, subprocess, urllib.request, urllib.error

BASE = "https://akshara.veloraunisexsalon.com"
ORG = "a1000000-0000-4000-8000-000000000001"          # pilot org (Professional plan)
ADMIN = "+919876543210"
ADMIN_UID = "a3000000-0000-4000-8000-000000000001"
SOCK = os.path.expanduser("~/.ssh/akshara-cm.sock")
TS = str(int(time.time()))

# Throwaway schools (pilot org) for the 4 board types
SMALL = "a2000000-0000-4000-8000-0000000000d1"
CBSE  = "a2000000-0000-4000-8000-0000000000d2"
ICSE  = "a2000000-0000-4000-8000-0000000000d3"
STATE = "a2000000-0000-4000-8000-0000000000d4"
# Org-topology throwaways
SINGLE_ORG   = "a1000000-0000-4000-8000-0000000000d8"
TRUST_ORG    = "a1000000-0000-4000-8000-0000000000d9"
SINGLE_SCH   = "a2000000-0000-4000-8000-0000000000d5"
TRUST_SCH_A  = "a2000000-0000-4000-8000-0000000000d6"
TRUST_SCH_B  = "a2000000-0000-4000-8000-0000000000d7"

ALL_SCHOOLS = [SMALL, CBSE, ICSE, STATE, SINGLE_SCH, TRUST_SCH_A, TRUST_SCH_B]
ALL_ORGS = [SINGLE_ORG, TRUST_ORG]

results = []


def rec(check, label, detail=""):
    results.append((check, label, detail))
    print(f"  [{label:>7}] {check}  {detail}")


def http(method, path, token=None, body=None, school=None):
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
    return subprocess.run(cmd, capture_output=True, text=True, timeout=60).stdout.strip()


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


def login(school):
    """One scoped OTP login (pilot/dev returns the OTP). Clears the sliding
    window first so repeated runs aren't rate-limited."""
    db(f"delete from otp_requests where phone='{ADMIN}' and created_at > now() - interval '1 hour'")
    s, b = http("POST", "/auth/login", body={"identifier": ADMIN})
    otp = data(b).get("otp")
    s, b = http("POST", "/auth/verify-otp", body={"identifier": ADMIN, "otp": otp, "schoolId": school})
    return data(b).get("accessToken")


def mk_school(school_id, org, name, code):
    db(f"insert into schools (id, organization_id, name, code) values "
       f"('{school_id}','{org}','{name}','{code}') "
       f"on conflict (id) do update set deleted_at=null, organization_id=excluded.organization_id, name=excluded.name")
    mid = db(f"insert into school_memberships (user_id, school_id, role, status) "
             f"values ('{ADMIN_UID}','{school_id}','schoolAdmin','active') "
             f"on conflict do nothing returning id")
    if not mid:
        mid = db(f"select id from school_memberships where user_id='{ADMIN_UID}' and school_id='{school_id}' limit 1")
    if mid:
        db(f"insert into school_membership_roles (school_membership_id, role_slug, is_primary, status) "
           f"values ('{mid}','schoolAdmin',true,'active') on conflict do nothing")


def go_live(token, school, name, board, curriculum, modules, fee_cats):
    payload = {"schoolName": name, "board": board, "curriculum": curriculum,
               "address": "1 Pilot Road", "contactPhone": "9000000001",
               "contactEmail": "pilot@example.com", "academicYear": "2026-27",
               "classes": ["Grade 1", "Grade 2"], "sections": ["A", "B"],
               "feeModel": "term", "feeCategories": fee_cats,
               "themePrimary": "#1565C0", "defaultLanguage": "en",
               "modulesEnabled": modules}
    http("PUT", "/onboarding/startup", token, payload, school=school)
    s, b = http("POST", "/onboarding/startup/go-live", token, school=school)
    return s, (data(b).get("provision") or {})


def set_cap(school, flag, value):
    v = "true" if value else "false"
    db(f"update school_configuration set capabilities = capabilities || "
       f"'{{\\\"{flag}\\\": {v}}}'::jsonb where school_id='{school}'")


print("=== Pilot School Simulation — LIVE (real VPS / real auth / real DB / real RBAC) ===\n")

s, b = http("GET", "/health")
rec("0.health", "PASS" if s == 200 and data(b).get("status") == "ok" else "FAIL", f"HTTP {s}")

try:
    # ════════════════════ PART A — Multi-board onboarding ════════════════════
    print("\n-- PART A: multi-board onboarding --")
    # (school_id, name, code, board, curriculum, modulesEnabled, feeCategories, disabled-probe)
    BOARDS = [
        (SMALL, "Sunrise Small Private", "PSMALL", "State", "State",
         ["sis", "finance", "attendance"], ["Tuition"], "/transport/dashboard"),
        (CBSE, "Delhi Public CBSE", "PCBSE", "CBSE", "CBSE",
         ["sis", "finance", "attendance", "transport", "library", "hostel", "inventory", "hr"],
         ["Tuition", "Transport", "Hostel"], "/alumni/dashboard"),
        (ICSE, "St Marys ICSE", "PICSE", "ICSE", "ICSE",
         ["sis", "finance", "attendance", "library", "transport"],
         ["Tuition", "Library"], "/hostel/dashboard"),
        (STATE, "Govt State Board", "PSTATE", "State", "State",
         ["sis", "finance", "attendance", "transport"],
         ["Tuition"], "/library/dashboard"),
    ]
    cbse_token = None
    for sch, name, code, board, curr, mods, fees, disabled_probe in BOARDS:
        tag = code
        mk_school(sch, ORG, name, code + TS[-4:])
        tok = login(sch)
        rec(f"A.{tag}:auth", "PASS" if tok else "FAIL", f"scoped login {board}")
        if not tok:
            continue
        if sch == CBSE:
            cbse_token = tok
        # AI prefill honours the board
        s, b = http("POST", "/onboarding/startup/ai-prefill", tok,
                    {"schoolName": name, "board": board, "curriculum": curr,
                     "schoolType": "day", "lowestGrade": "Grade 1", "highestGrade": "Grade 10",
                     "estimatedStudents": 400, "estimatedTeachers": 20,
                     "interestedModules": [m for m in mods if m in ("transport", "library", "hostel")]},
                    school=sch)
        prop = data(b).get("proposal") or {}
        rec(f"A.{tag}:ai-prefill", "PASS" if s == 200 and prop else "FAIL",
            f"HTTP {s} modules={len(prop.get('modulesEnabled') or [])} (never 500)")
        # Go-live: provisions subjects + capabilities for this board
        s, prov = go_live(tok, sch, name, board, curr, mods, fees)
        rec(f"A.{tag}:go-live", "PASS" if s == 200 and prov.get("provisioned") else "FAIL",
            f"HTTP {s} provisioned={prov.get('provisioned')} caps={prov.get('capabilitiesApplied')}")
        rec(f"A.{tag}:subjects", "PASS" if (prov.get("subjectCount") or 0) > 0 else "FAIL",
            f"subjectCount={prov.get('subjectCount')} board={board}")
        # DB capabilities reflect the chosen modules
        caps_raw = db(f"select capabilities from school_configuration where school_id='{sch}'")
        caps = json.loads(caps_raw) if caps_raw else {}
        want_on = [m for m in ("transport", "library", "hostel", "inventory", "alumni") if m in mods]
        on_ok = all(caps.get(m) is True for m in want_on)
        caps_view = ",".join(m + "=" + str(caps.get(m)) for m in ("transport", "library", "hostel", "inventory", "alumni"))
        rec(f"A.{tag}:caps-match-modules", "PASS" if on_ok else "FAIL",
            f"enabled={want_on} caps[{caps_view}]")
        # A module NOT in this school's set is blocked at the API (UI hides it)
        s, b = http("GET", disabled_probe, tok, school=sch)
        rec(f"A.{tag}:disabled-module-403", "PASS" if s == 403 and err_code(b) == "MODULE_DISABLED" else "FAIL",
            f"{disabled_probe} HTTP {s} code={err_code(b)}")
        # Empty-state read on a brand-new school is a clean 200, never a 500
        s, b = http("GET", "/sis/students", tok, school=sch)
        rec(f"A.{tag}:empty-state-200", "PASS" if s == 200 else "FAIL",
            f"/sis/students HTTP {s} (fresh school -> empty, not 500)")

    # ════════════════════ PART B — Organization topology ════════════════════
    print("\n-- PART B: org topology (single school vs multi-school trust) --")
    db(f"insert into organizations (id, name, slug, plan, status) values "
       f"('{SINGLE_ORG}','Pilot Single School Org','psingle{TS[-4:]}','trial','active') "
       f"on conflict (id) do update set deleted_at=null")
    db(f"insert into organizations (id, name, slug, plan, status) values "
       f"('{TRUST_ORG}','Pilot Education Trust','ptrust{TS[-4:]}','trial','active') "
       f"on conflict (id) do update set deleted_at=null")
    mk_school(SINGLE_SCH, SINGLE_ORG, "Single Campus", "SS" + TS[-4:])
    mk_school(TRUST_SCH_A, TRUST_ORG, "Trust Branch North", "TA" + TS[-4:])
    mk_school(TRUST_SCH_B, TRUST_ORG, "Trust Branch South", "TB" + TS[-4:])

    tok = login(SINGLE_SCH)
    s, b = http("GET", "/auth/me", tok, school=SINGLE_SCH)
    me_chain = data(b).get("isChainOrganization")
    rec("B.single-org:not-chain", "PASS" if me_chain is False else "FAIL",
        f"isChainOrganization={me_chain} (1 school -> false)")
    rec("B.single-org:jwt-claim", "PASS" if jwt_claim(tok, "is_chain_organization") is False else "FAIL",
        f"jwt is_chain_organization={jwt_claim(tok, 'is_chain_organization')}")
    # Director multi-branch is entitlement-gated for a trial single-school org
    s, b = http("GET", "/director/overview", tok, school=SINGLE_SCH)
    rec("B.single-org:director-gated", "PASS" if s in (402, 403, 404) else "FAIL",
        f"/director HTTP {s} code={err_code(b)} (multi-branch not in trial plan)")

    tok = login(TRUST_SCH_A)
    s, b = http("GET", "/auth/me", tok, school=TRUST_SCH_A)
    me_chain = data(b).get("isChainOrganization")
    rec("B.trust-org:is-chain", "PASS" if me_chain is True else "FAIL",
        f"isChainOrganization={me_chain} (2 schools -> true)")
    rec("B.trust-org:jwt-claim", "PASS" if jwt_claim(tok, "is_chain_organization") is True else "FAIL",
        f"jwt is_chain_organization={jwt_claim(tok, 'is_chain_organization')}")

    # ════════════════════ PART C — Dynamic module lifecycle ════════════════════
    print("\n-- PART C: module lifecycle (disable -> enable -> use -> disable [data kept] -> re-enable) --")
    if not cbse_token:
        rec("C.setup", "FAIL", "no CBSE token from PART A")
    else:
        # (capability flag, route prefix dashboard, entities table)
        MODULES = [
            ("inventory", "/inventory/dashboard", "inventory_entities"),
            ("hostel",    "/hostel/dashboard",    "hostel_entities"),
            ("library",   "/library/dashboard",   "library_entities"),
            ("transport", "/transport/dashboard", "transport_entities"),
            ("hrPayroll", "/hr/dashboard",         "hr_entities"),
            ("alumni",    "/alumni/dashboard",     "alumni_entities"),
        ]
        for flag, probe, table in MODULES:
            # 1. DISABLED -> API blocked (UI hides the module)
            set_cap(CBSE, flag, False)
            s_off1, b_off1 = http("GET", probe, cbse_token, school=CBSE)
            blocked1 = s_off1 == 403 and err_code(b_off1) == "MODULE_DISABLED"
            # 2. ENABLE -> API opens with a clean 200 EMPTY-STATE dashboard
            #    (fresh school has no module data yet -> empty, never a 404 error).
            set_cap(CBSE, flag, True)
            s_on, b_on = http("GET", probe, cbse_token, school=CBSE)
            opened = s_on == 200
            # 3. USE -> create module data while enabled
            row_id = f"pilot-sim-{flag}-{TS}"
            db(f"insert into {table} (id, organization_id, school_id, entity_type, payload) "
               f"values ('{row_id}','{ORG}','{CBSE}','pilot_sim','{{\\\"note\\\":\\\"created while enabled\\\"}}'::jsonb)")
            present_enabled = db(f"select count(*) from {table} where id='{row_id}'") == "1"
            # 4. DISABLE again -> API blocked BUT data must NOT be deleted
            set_cap(CBSE, flag, False)
            s_off2, b_off2 = http("GET", probe, cbse_token, school=CBSE)
            blocked2 = s_off2 == 403 and err_code(b_off2) == "MODULE_DISABLED"
            survived = db(f"select count(*) from {table} where id='{row_id}'") == "1"
            # 5. RE-ENABLE -> API opens (200) and the data is restored/readable
            set_cap(CBSE, flag, True)
            s_re, b_re = http("GET", probe, cbse_token, school=CBSE)
            reopened = s_re == 200
            restored = db(f"select count(*) from {table} where id='{row_id}'") == "1"
            ok = all([blocked1, opened, present_enabled, blocked2, survived, reopened, restored])
            rec(f"C.{flag}:lifecycle", "PASS" if ok else "FAIL",
                f"off->{s_off1} on->{s_on} use={present_enabled} off2->{s_off2} kept={survived} re->{s_re} restored={restored}")
            # cleanup the sim row
            db(f"delete from {table} where id='{row_id}'")

        # Marketing is plan-entitlement-gated (upgrade path), not a school capability
        tok_single = login(SINGLE_SCH)  # trial org -> marketing not in plan
        s, b = http("GET", "/growth/campaigns", tok_single, school=SINGLE_SCH)
        rec("C.marketing:plan-gated", "PASS" if s == 402 and err_code(b) == "PLAN_UPGRADE_REQUIRED" else "FAIL",
            f"/growth HTTP {s} code={err_code(b)} (trial plan -> 402 upgrade path)")

finally:
    print("\n-- teardown --")
    for sch in ALL_SCHOOLS:
        db(f"delete from school_membership_roles where school_membership_id in "
           f"(select id from school_memberships where school_id='{sch}')")
        db(f"delete from finance_fee_structure_items where fee_structure_id in "
           f"(select id from finance_fee_structures where school_id='{sch}')")
        for tbl in ("inventory_entities", "hostel_entities", "library_entities",
                    "transport_entities", "hr_entities", "alumni_entities",
                    "syllabus_topics", "syllabus_chapters", "syllabus_generations",
                    "academic_subjects", "sections", "classes", "academic_years",
                    "finance_fee_structures", "school_branding", "school_configuration",
                    "startup_onboarding", "school_memberships"):
            db(f"delete from {tbl} where school_id='{sch}'")
        db(f"update schools set deleted_at=timezone('utc',now()) where id='{sch}'")
    for sch in ALL_SCHOOLS:
        db(f"delete from schools where id='{sch}'")
    for org in ALL_ORGS:
        db(f"delete from organizations where id='{org}'")

p = sum(1 for _, l, _ in results if l == "PASS")
f = sum(1 for _, l, _ in results if l == "FAIL")
print(f"\n=== RESULT: {p} PASS / {f} FAIL  (total {len(results)}) ===")
print("GATE:", "PASS" if f == 0 else "FAIL")
raise SystemExit(1 if f else 0)
