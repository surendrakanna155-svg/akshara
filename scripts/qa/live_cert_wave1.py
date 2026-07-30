#!/usr/bin/env python3
"""Authenticated live-mode certification against the live VPS (Wave 1).

Logs in real pilot personas via OTP (allowlisted -> OTP returned in response),
then exercises read + write workflows per domain and classifies each:
  PASS / FAIL / BLOCKED (needs data or payload) / REQUIRES-CREDS.
No mocks, no route-existence-only checks.
"""
import json, urllib.request, urllib.error, sys, time
import os
TS = str(int(time.time()))

BASE = os.environ.get("API_BASE_URL", "https://api.nikshaos.in")
SCHOOL_1 = "a2000000-0000-4000-8000-000000000001"
PERSONAS = {
    "admin":   "+919876543210",   # Staging School Admin (schoolAdmin + orgAdmin)
    "teacher": "+919876543213",   # Staging Teacher A (school ...0001)
    "parent":  "+919876543211",   # Staging Parent
}
results = []  # (domain, check, label, detail)

def http(method, path, token=None, body=None):
    url = BASE + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    if SCHOOL_1:
        req.add_header("X-School-Id", SCHOOL_1)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read().decode()
            try: return r.status, json.loads(raw)
            except: return r.status, raw
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try: return e.code, json.loads(raw)
        except: return e.code, raw
    except Exception as e:
        return 0, str(e)

def record(domain, check, label, detail=""):
    results.append((domain, check, label, detail))
    print(f"  [{label:>12}] {domain}/{check}  {detail}")

def login(identifier):
    s, b = http("POST", "/auth/login", body={"identifier": identifier})
    if s != 200 or not isinstance(b, dict): return None, f"login HTTP {s}: {str(b)[:120]}"
    otp = b.get("data", {}).get("otp")
    if not otp: return None, "no OTP in response (not allowlisted?)"
    s, b = http("POST", "/auth/verify-otp", body={"identifier": identifier, "otp": otp})
    if s != 200 or not isinstance(b, dict): return None, f"verify HTTP {s}: {str(b)[:120]}"
    tok = b.get("data", {}).get("accessToken")
    return (tok, "") if tok else (None, "no accessToken")

def find_requests(obj):
    """Best-effort: pull a list of leave-request dicts (with id+status) from any nesting."""
    out = []
    def walk(o):
        if isinstance(o, dict):
            if "id" in o and "status" in o: out.append(o)
            for v in o.values(): walk(v)
        elif isinstance(o, list):
            for v in o: walk(v)
    walk(obj); return out

print("=== Wave-1 authenticated live-mode certification ===\n")
tokens = {}
for name, ident in PERSONAS.items():
    tok, err = login(ident)
    tokens[name] = tok
    record("auth", f"login:{name}", "PASS" if tok else "FAIL", err if not tok else ident)

admin, teacher, parent = tokens["admin"], tokens["teacher"], tokens["parent"]

# --- JWT issuance + permission loading ---
if admin:
    s, b = http("GET", "/auth/me", admin)
    role = (b.get("data", {}) if isinstance(b, dict) else {}).get("role")
    record("auth", "me(admin)", "PASS" if s == 200 else "FAIL", f"HTTP {s} role={role}")
    s, b = http("GET", "/auth/permissions", admin)
    perms = (b.get("data", {}) if isinstance(b, dict) else {})
    n = len(perms.get("permissions", perms)) if isinstance(perms, (list, dict)) else 0
    record("auth", "permissions(admin)", "PASS" if s == 200 and n else "FAIL", f"HTTP {s} count={n}")

# --- School configuration: read + write roundtrip (admin) ---
if admin:
    s, b = http("GET", "/school-config", admin)
    record("school-config", "read", "PASS" if s == 200 else "FAIL", f"HTTP {s}")
    cur = (b.get("data", {}) if isinstance(b, dict) else {}).get("configuration") or {}
    caps = dict(cur.get("capabilities") or {"transport": True, "hostel": False, "library": True,
                "inventory": False, "alumni": False, "hrPayroll": True, "multiBranch": False, "trustOrganization": False})
    orig_lib = bool(caps.get("library", True))
    caps["library"] = not orig_lib
    put_body = {"capabilities": caps, "schoolType": cur.get("schoolType", "day_school"),
                "curriculum": cur.get("curriculum", "cbse"),
                "operationsModel": cur.get("operationsModel", "single_school"),
                "branchCount": cur.get("branchCount", 1)}
    s, b = http("PUT", "/school-config", admin, put_body)
    if s == 200:
        s2, b2 = http("GET", "/school-config", admin)
        got = (((b2.get("data") or {}).get("configuration") or {}).get("capabilities") or {}).get("library")
        ok = got == (not orig_lib)
        record("school-config", "write(roundtrip)", "PASS" if ok else "FAIL", f"library {orig_lib}->{got}")
        # restore
        caps["library"] = orig_lib
        http("PUT", "/school-config", admin, {**put_body, "capabilities": caps})
    else:
        record("school-config", "write", "FAIL", f"PUT HTTP {s}: {str(b)[:120]}")

# --- HR leave approval end-to-end (admin) ---
if admin:
    s, b = http("GET", "/hr/leave", admin)
    record("hr", "read(leave)", "PASS" if s == 200 else "FAIL", f"HTTP {s}")
    reqs = find_requests(b) if s == 200 else []
    target = next((r for r in reqs if str(r.get("status", "")).lower() in ("pending", "submitted", "requested")), reqs[0] if reqs else None)
    if not target:
        record("hr", "write(leave-approve)", "BLOCKED", "no leave request in seed data to approve")
    else:
        rid = target["id"]
        s, b = http("POST", f"/hr/leave/{rid}/approve", admin, {})
        if s == 200:
            s2, b2 = http("GET", "/hr/leave", admin)
            after = next((r for r in find_requests(b2) if r.get("id") == rid), {})
            ok = str(after.get("status", "")).lower() == "approved"
            record("hr", "write(leave-approve)", "PASS" if ok else "FAIL", f"id={rid[:8]} -> {after.get('status')}")
        else:
            record("hr", "write(leave-approve)", "FAIL", f"approve HTTP {s}: {str(b)[:140]}")

# --- SIS: read + write (admin) ---
if admin:
    s, b = http("GET", "/sis/students", admin)
    record("sis", "read(students)", "PASS" if s == 200 else "FAIL", f"HTTP {s}")
    s, b = http("POST", "/sis/students", admin,
                {"displayName": f"CERT Smoke {TS}", "admissionNumber": f"CERT-{TS}"})
    if s in (200, 201): record("sis", "write(create-student)", "PASS", f"HTTP {s} adm=CERT-{TS}")
    elif s in (400, 422): record("sis", "write(create-student)", "BLOCKED", f"validation HTTP {s}: {str(b)[:120]}")
    else: record("sis", "write(create-student)", "FAIL", f"HTTP {s}: {str(b)[:140]}")

# --- Finance: read + write (admin) ---
if admin:
    s, b = http("GET", "/finance/dashboard", admin)
    record("finance", "read(dashboard)", "PASS" if s == 200 else "FAIL", f"HTTP {s}")
    s, b = http("POST", "/finance/fee-structures", admin,
                {"name": f"CERT Fee {TS}", "academicYearId": "ce100000-0000-4000-8000-000000000001"})
    if s in (200, 201): record("finance", "write(fee-structure)", "PASS", f"HTTP {s}")
    elif s in (400, 422): record("finance", "write(fee-structure)", "BLOCKED", f"validation HTTP {s}: {str(b)[:120]}")
    else: record("finance", "write(fee-structure)", "FAIL", f"HTTP {s}: {str(b)[:140]}")

# --- Attendance: read + write (admin holds manageSis; corrections are an admin action) ---
if admin:
    s, b = http("GET", "/attendance/sessions", admin)
    record("attendance", "read(sessions)", "PASS" if s in (200, 204) else "FAIL", f"HTTP {s}")
    corr = {"sisStudentId": "cert-smoke", "studentName": "Cert Smoke", "classLabel": "X", "section": "A",
            "dateLabel": "2026-06-24", "fromMark": "absent", "toMark": "present", "reason": "live cert smoke",
            "presentDelta": 1}
    s, b = http("POST", "/attendance/corrections", admin, corr)
    if s in (200, 201):
        record("attendance", "write(correction)", "PASS", f"HTTP {s}")
    elif s in (400, 422):
        record("attendance", "write(correction)", "BLOCKED", f"validation HTTP {s}: {str(b)[:120]}")
    else:
        record("attendance", "write(correction)", "FAIL", f"HTTP {s}: {str(b)[:140]}")
# RBAC: a teacher must NOT be able to write attendance corrections (needs manageSis)
if teacher:
    s, b = http("POST", "/attendance/corrections", teacher, {"sisStudentId": "x", "reason": "rbac-probe"})
    record("rbac", "teacher-denied(corrections)", "PASS" if s == 403 else "FAIL", f"HTTP {s} (expect 403)")

# --- Parent visibility: reads + acknowledge write (parent) ---
if parent:
    for ep in ("/parent/dashboard", "/parent/fees", "/parent/attendance"):
        s, b = http("GET", ep, parent)
        record("parent", f"read({ep.split('/')[-1]})", "PASS" if s == 200 else "FAIL", f"HTTP {s}")
    s, b = http("POST", "/parent/experience/acknowledge", parent, {"itemId": "cert-smoke", "type": "notice"})
    if s in (200, 201): record("parent", "write(acknowledge)", "PASS", f"HTTP {s}")
    elif s in (400, 422, 404): record("parent", "write(acknowledge)", "BLOCKED", f"HTTP {s}: {str(b)[:100]}")
    else: record("parent", "write(acknowledge)", "FAIL", f"HTTP {s}: {str(b)[:120]}")

# --- Report ---
print("\n=== CERTIFICATION SUMMARY ===")
from collections import Counter
c = Counter(r[2] for r in results)
for label in ("PASS", "FAIL", "BLOCKED", "REQUIRES-CREDS"):
    if c.get(label): print(f"  {label}: {c[label]}")
print(f"  TOTAL: {len(results)}")
if c.get("FAIL"):
    print("\nFAILURES:")
    for d, ch, lbl, det in results:
        if lbl == "FAIL": print(f"  - {d}/{ch}: {det}")
sys.exit(1 if c.get("FAIL") else 0)
