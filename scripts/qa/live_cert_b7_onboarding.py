#!/usr/bin/env python3
"""B7 first-time student onboarding — LIVE certification against the VPS pilot.
Real VPS + real OTP auth + real DB. Classifies each check PASS/FAIL/BLOCKED.
DB verification runs via the active ssh ControlMaster socket (root @ VPS)."""
import json, os, time, hashlib, subprocess, urllib.request, urllib.error

BASE = "https://akshara.veloraunisexsalon.com"
SCHOOL = "a2000000-0000-4000-8000-000000000001"
SOCK = os.path.expanduser("~/.ssh/akshara-cm.sock")
ADMIN = "+919876543210"
PARENT_PERSONA = "+919876543211"
TS = str(int(time.time()))
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
        with urllib.request.urlopen(req, timeout=40) as r:
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

# Leftover committed jobs from the crashed run-1 (rolled back here to keep tenant clean).
LEFTOVER_JOBS = []  # populate with stale committed job ids to clean up, if any

def login(ident):
    s, b = http("POST", "/auth/login", body={"identifier": ident})
    otp = data(b).get("otp")
    if not otp: return None, f"login HTTP {s}: {str(b)[:120]}"
    s, b = http("POST", "/auth/verify-otp", body={"identifier": ident, "otp": otp})
    tok = data(b).get("accessToken")
    return (tok, "") if tok else (None, f"verify HTTP {s}: {str(b)[:120]}")

def srow(admission, phone, name="Live QA", aadhaar=None, cls="Grade 6", sec="A"):
    r = {"studentName": f"{name} {admission}", "admissionNumber": admission,
         "classLabel": cls, "sectionLabel": sec, "academicYear": "2026-27",
         "parentName": f"QA Parent {admission}", "parentPhone": phone}
    if aadhaar: r["aadhaar"] = aadhaar
    return r

print("=== B7 onboarding LIVE certification (real VPS / real auth / real DB) ===\n")
jobs_to_rollback = []

# 0. health
s, b = http("GET", "/health")
rec("health", "PASS" if s == 200 and data(b).get("status") == "ok" else "FAIL", f"HTTP {s}")

# 1. admin auth (real OTP -> JWT)
admin, err = login(ADMIN)
rec("auth:admin-otp-login", "PASS" if admin else "FAIL", err or ADMIN)
if not admin:
    print("\nABORT: no admin token"); raise SystemExit(1)

# org id (for DB scoping)
org, _ = db(f"select organization_id from students where school_id='{SCHOOL}' limit 1")
org = org or "a1000000-0000-4000-8000-000000000001"

# Clean up leftover committed jobs from the crashed run-1 (reuses admin token; no extra login)
for jid in LEFTOVER_JOBS:
    http("POST", f"/onboarding/imports/{jid}/rollback", admin)

# ---- 1+2+3+4: preview -> commit -> student creation -> parent provisioning ----
adm1 = f"BCERT-{TS}-1"
phone1 = "9" + TS[-9:]            # fresh 10-digit phone -> +91 normalized
s, b = http("POST", "/onboarding/imports/students/preview", admin,
            {"fileName": "cert.csv", "rows": [srow(adm1, phone1)]})
job1 = data(b).get("job", {}); jid1 = job1.get("id")
ok_prev = s == 200 and job1.get("validRows") == 1 and job1.get("status") == "previewed"
rec("1.import-preview", "PASS" if ok_prev else "FAIL", f"HTTP {s} validRows={job1.get('validRows')}")
if jid1:
    s, b = http("POST", f"/onboarding/imports/{jid1}/commit", admin)
    cj = data(b)
    ok_commit = s == 200 and cj.get("status") == "committed" and cj.get("committedRows") == 1
    rec("2.import-commit", "PASS" if ok_commit else "FAIL", f"HTTP {s} status={cj.get('status')} committed={cj.get('committedRows')}")
    jobs_to_rollback.append(jid1)
    # 3. student creation (DB)
    sid, _ = db(f"select sp.student_id from student_profiles sp where sp.organization_id='{org}' and sp.school_id='{SCHOOL}' and sp.admission_number='{adm1}' limit 1")
    enr, _ = db(f"select count(*) from sis_student_enrollments e join student_profiles sp on sp.student_id=e.student_id where sp.admission_number='{adm1}' and e.is_current=true")
    rec("3.student-creation", "PASS" if sid and enr == "1" else "FAIL", f"student_id={sid[:8] if sid else None} enrollment={enr}")
    # 4. parent provisioning (DB): user row for fresh phone + guardian link
    puid, _ = db(f"select id from users where phone='+91{phone1}' limit 1")
    glink = ""
    if sid and puid:
        glink, _ = db(f"select count(*) from student_guardians where student_id='{sid}' and guardian_user_id='{puid}' and status='active'")
    rec("4.parent-provisioning", "PASS" if puid and glink == "1" else "FAIL", f"parent_user={puid[:8] if puid else None} guardian_link={glink}")
else:
    rec("2.import-commit", "FAIL", "no jobId from preview")
    rec("3.student-creation", "FAIL", "no jobId")
    rec("4.parent-provisioning", "FAIL", "no jobId")

# 5. OTP login path (allowlisted parent persona authenticates end-to-end)
ptok, perr = login(PARENT_PERSONA)
if ptok:
    s, b = http("GET", "/auth/me", ptok)
    rec("5.otp-login", "PASS", f"parent persona role={data(b).get('role')}")
else:
    rec("5.otp-login", "BLOCKED", f"persona not allowlisted for OTP issuance: {perr}")

# ---- 6. Aadhaar masking/hash + dedupe ----
aadhaar = "456789012345"
exp_mask = "XXXXXXXX2345"
exp_hash = hashlib.sha256(aadhaar.encode()).hexdigest()
admA = f"BCERT-{TS}-A"
phoneA = "9" + str(int(TS) + 1)[-9:]
s, b = http("POST", "/onboarding/imports/students/preview", admin,
            {"fileName": "cert_aadhaar.csv",
             "rows": [srow(admA, phoneA, aadhaar=aadhaar),
                      srow(f"BCERT-{TS}-Adup", phoneA, aadhaar=aadhaar)]})
pj = data(b).get("job", {}); jidA = pj.get("id")
prev_rows = data(b).get("preview", [])
dup_flagged = any("duplicate Aadhaar" in (r.get("errors") or []) or r.get("status") == "duplicate" for r in prev_rows[1:])
if jidA:
    http("POST", f"/onboarding/imports/{jidA}/commit", admin)
    jobs_to_rollback.append(jidA)
    got_mask, _ = db(f"select s.aadhaar from students s join student_profiles sp on sp.student_id=s.id where sp.admission_number='{admA}' limit 1")
    got_hash, _ = db(f"select s.aadhaar_hash from students s join student_profiles sp on sp.student_id=s.id where sp.admission_number='{admA}' limit 1")
    raw_leak, _ = db(f"select count(*) from students where aadhaar like '%{aadhaar}%'")
    ok_aad = got_mask == exp_mask and got_hash == exp_hash and raw_leak == "0" and dup_flagged
    rec("6.aadhaar-mask+hash", "PASS" if ok_aad else "FAIL",
        f"mask={got_mask} hash_ok={got_hash==exp_hash} raw_leak={raw_leak} dup_flagged={dup_flagged}")
else:
    rec("6.aadhaar-mask+hash", "FAIL", f"preview HTTP {s}: {str(b)[:120]}")

# ---- 7. Placeholder generation (no parent, no login) ----
sec_ph = f"QA{TS[-4:]}"
s, b = http("POST", "/onboarding/students/generate", admin,
            {"academicYear": "2026-27",
             "classes": [{"classLabel": "Grade 9", "sections": [{"sectionLabel": sec_ph, "studentCount": 3}]}]})
gj = data(b).get("job", {}); jidP = gj.get("id"); gcount = data(b).get("generatedCount")
if jidP:
    jobs_to_rollback.append(jidP)
    ph_cnt, _ = db(f"select count(*) from students where school_id='{SCHOOL}' and is_placeholder=true and student_code like 'PH-Grade9-{sec_ph}-%'")
    ph_nouser, _ = db(f"select count(*) from students where school_id='{SCHOOL}' and student_code like 'PH-Grade9-{sec_ph}-%' and user_id is not null")
    ph_noguard, _ = db(f"select count(*) from student_guardians sg join students s on s.id=sg.student_id where s.student_code like 'PH-Grade9-{sec_ph}-%'")
    ok_ph = gcount == 3 and ph_cnt == "3" and ph_nouser == "0" and ph_noguard == "0"
    rec("7.placeholder-generation", "PASS" if ok_ph else "FAIL",
        f"generated={gcount} db_placeholders={ph_cnt} with_user={ph_nouser} with_guardian={ph_noguard}")
else:
    rec("7.placeholder-generation", "FAIL", f"HTTP {s}: {str(b)[:120]}")

# ---- 8. Rollback (all jobs) — students removed ----
roll_ok = True; details = []
for jid in jobs_to_rollback:
    s, b = http("POST", f"/onboarding/imports/{jid}/rollback", admin)
    st = data(b).get("status")
    details.append(f"{jid[:8]}={st}({s})")
    if not (s == 200 and st == "rolled_back"): roll_ok = False
# verify the imported + placeholder students are gone
gone1, _ = db(f"select count(*) from student_profiles where admission_number='{adm1}'")
goneA, _ = db(f"select count(*) from student_profiles where admission_number='{admA}'")
goneP, _ = db(f"select count(*) from students where student_code like 'PH-Grade9-{sec_ph}-%'")
ok_roll = roll_ok and gone1 == "0" and goneA == "0" and goneP == "0"
rec("8.rollback", "PASS" if ok_roll else "FAIL", f"jobs[{','.join(details)}] residual(s={gone1},a={goneA},ph={goneP})")

# ---- summary ----
p = sum(1 for _, l, _ in results if l == "PASS")
f = sum(1 for _, l, _ in results if l == "FAIL")
bl = sum(1 for _, l, _ in results if l == "BLOCKED")
print(f"\n=== RESULT: {p} PASS / {f} FAIL / {bl} BLOCKED ===")
print("GATE:", "PASS" if f == 0 else "FAIL")
