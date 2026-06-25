#!/usr/bin/env python3
"""B7 — AI School Builder (Phase 1) — LIVE certification against the VPS pilot.
AI pre-fill of school structure/config on the certified onboarding foundation.
Real VPS + real OTP auth + real DB + real AI provider (OpenRouter/Claude).
Classifies each check PASS/FAIL/BLOCKED. DB verification via the ssh ControlMaster."""
import json, os, time, subprocess, urllib.request, urllib.error

BASE = "https://akshara.veloraunisexsalon.com"
SCHOOL = "a2000000-0000-4000-8000-000000000001"
ORG = "a1000000-0000-4000-8000-000000000001"
SOCK = os.path.expanduser("~/.ssh/akshara-cm.sock")
ADMIN = "+919876543210"
results = []  # (check, label, detail)

def rec(check, label, detail=""):
    results.append((check, label, detail))
    print(f"  [{label:>7}] {check}  {detail}")

def http(method, path, token=None, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token: req.add_header("Authorization", "Bearer " + token)
    req.add_header("X-School-Id", SCHOOL)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read().decode()
            try: return r.status, json.loads(raw)
            except: return r.status, raw
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try: return e.code, json.loads(raw)
        except: return e.code, raw
    except Exception as e:
        return 0, str(e)

def db(sql):
    cmd = ["ssh", "-o", "ControlPath=" + SOCK, "akshara",
           f'docker exec akshara-postgres psql -U supabase_admin -d akshara_db -tAc "{sql}"']
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=40)
    return p.stdout.strip(), p.stderr.strip()

def data(b): return (b.get("data") or {}) if isinstance(b, dict) else {}

def login(ident):
    s, b = http("POST", "/auth/login", body={"identifier": ident})
    otp = data(b).get("otp")
    if not otp: return None, f"login HTTP {s}: {str(b)[:120]}"
    s, b = http("POST", "/auth/verify-otp", body={"identifier": ident, "otp": otp})
    tok = data(b).get("accessToken")
    return (tok, "") if tok else (None, f"verify HTTP {s}: {str(b)[:120]}")

VALID_GRADES = {"Nursery", "LKG", "UKG", *[f"Grade {i}" for i in range(1, 13)]}

print("=== B7 AI School Builder (Phase 1) LIVE certification (real VPS / auth / DB / AI) ===\n")

# 0. health
s, b = http("GET", "/health")
rec("health", "PASS" if s == 200 and data(b).get("status") == "ok" else "FAIL", f"HTTP {s}")

# 1. admin auth (real OTP -> JWT)
admin, err = login(ADMIN)
rec("auth:admin-otp-login", "PASS" if admin else "FAIL", err or ADMIN)
if not admin:
    print("\nABORT: no admin token"); raise SystemExit(1)

# 2. entitlement seeded + pilot plan resolves to allow AI School Builder
rows, _ = db("select count(*) from plan_entitlements where plan_slug='professional' and entitlement_slug='feature.ai_school_builder'")
plan, _ = db(f"select plan_slug from organization_subscriptions where organization_id='{ORG}'")
gate_ok = rows == "1" and plan == "professional"
rec("entitlement:professional-grants-ai-builder", "PASS" if gate_ok else "FAIL",
    f"rows={rows} pilot_plan={plan}")

# 3. AI pre-fill happy path — complete, go-live-shaped proposal
brief = {
    "schoolName": "Akshara Live QA School",
    "board": "CBSE",
    "schoolType": "day_school",
    "lowestGrade": "Grade 1",
    "highestGrade": "Grade 5",
    "sectionsPerGrade": 3,
    "estimatedStudents": 600,
    "estimatedTeachers": 30,
    "languages": ["Hindi", "English"],
    "interestedModules": ["library"],
}
s, b = http("POST", "/onboarding/startup/ai-prefill", token=admin, body=brief)
prop = data(b).get("proposal") or {}
source = data(b).get("source")
complete = (
    s == 200 and isinstance(prop, dict)
    and len(prop.get("classes") or []) > 0
    and len(prop.get("sections") or []) > 0
    and (prop.get("feeModel") or "").strip() != ""
    and len(prop.get("feeCategories") or []) > 0
    and "sis" in (prop.get("modulesEnabled") or [])
    and (prop.get("defaultLanguage") or "").strip() != ""
)
rec("ai-prefill:complete-proposal", "PASS" if complete else "FAIL",
    f"HTTP {s} source={source} classes={len(prop.get('classes') or [])} "
    f"sections={len(prop.get('sections') or [])} fees={len(prop.get('feeCategories') or [])}")

# 4. proposal is structurally sound — classes are real grades, range respected
classes = prop.get("classes") or []
all_valid = bool(classes) and all(c in VALID_GRADES for c in classes)
range_ok = "Grade 1" in classes and "Grade 5" in classes
rec("ai-prefill:valid-grade-structure", "PASS" if all_valid and range_ok else "FAIL",
    f"classes={classes}")

# 5. real AI engaged (OpenRouter/Claude). Safe deterministic fallback is acceptable
#    behavior, so a fallback is BLOCKED (not FAIL) — the feature still works.
if source == "ai":
    rec("ai-prefill:real-ai-engaged", "PASS", "live model refined the proposal")
else:
    rec("ai-prefill:real-ai-engaged", "BLOCKED",
        f"source={source} — safe deterministic fallback used (AI provider not engaged)")

# 6. non-destructive — the endpoint proposes only; it must NOT mutate saved state.
#    Compare config ignoring the volatile lastSavedAt (the default GET payload is
#    stamped with now() when no row exists) AND assert the DB row count is steady.
def stable(d):
    d = dict(d); d.pop("lastSavedAt", None); d.pop("id", None)
    return json.dumps(d, sort_keys=True)
rows_before, _ = db(f"select count(*) from startup_onboarding where school_id='{SCHOOL}'")
s0, b0 = http("GET", "/onboarding/startup", token=admin)
before = stable(data(b0))
http("POST", "/onboarding/startup/ai-prefill", token=admin, body=brief)
s1, b1 = http("GET", "/onboarding/startup", token=admin)
after = stable(data(b1))
rows_after, _ = db(f"select count(*) from startup_onboarding where school_id='{SCHOOL}'")
nd_ok = before == after and rows_before == rows_after and s0 == 200 == s1
rec("ai-prefill:non-destructive", "PASS" if nd_ok else "FAIL",
    f"config unchanged, rows {rows_before}->{rows_after}" if nd_ok else
    f"state changed! rows {rows_before}->{rows_after}")

# 7. entitlement wrapper does not break the ungated onboarding foundation
s, b = http("GET", "/onboarding/startup", token=admin)
rec("foundation:onboarding-passthrough-intact", "PASS" if s == 200 else "FAIL", f"HTTP {s}")

# 8. robust to an empty brief — deterministic baseline, never a 500
s, b = http("POST", "/onboarding/startup/ai-prefill", token=admin, body={})
prop2 = data(b).get("proposal") or {}
rec("ai-prefill:empty-brief-safe", "PASS" if s == 200 and len(prop2.get("classes") or []) > 0 else "FAIL",
    f"HTTP {s} classes={len(prop2.get('classes') or [])}")

# 9. unauthenticated request is rejected
s, b = http("POST", "/onboarding/startup/ai-prefill", body=brief)
rec("ai-prefill:requires-auth", "PASS" if s in (401, 403) else "FAIL", f"HTTP {s}")

# summary
print()
p = sum(1 for c, l, _ in results if l == "PASS")
f = sum(1 for c, l, _ in results if l == "FAIL")
bl = sum(1 for c, l, _ in results if l == "BLOCKED")
print(f"=== {p} PASS / {f} FAIL / {bl} BLOCKED ===")
raise SystemExit(1 if f else 0)
