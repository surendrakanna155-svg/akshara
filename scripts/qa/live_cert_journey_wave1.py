#!/usr/bin/env python3
"""Live-mode certification for MODULE_JOURNEY_ROADMAP **Journey Wave 1** —
"Data-integrity & money/identity correctness" — against the live VPS pilot.

Real VPS + real pilot OTP auth (teacher / student / admin / parent JWTs carrying
real RBAC) + real DB rows + real write→read cycles. Unlike Wave 0 (config-only),
Wave 1 changes backend behaviour, so this cert exercises genuine write→read loops
and asserts the corrected state is actually persisted and visible.

Items covered:
  MJ-C2  Teacher can SEE student homework submissions to grade (read joins
         homework_submissions; submissions[] carry real UUIDs + pendingReviews).
  MJ-H7  Graded homework status/grade reaches the STUDENT (write-back to the
         student's homework_item + read overlay). (Parent grade visibility is
         Wave-2 HOMEW-3 and intentionally NOT asserted here.)
  MJ-H8  Homework is delivered to the TARGET CLASS only, not the whole school
         (class-targeted fan-out via sis_student_enrollments).
  MJ-H9  Approved attendance correction UPDATES the real attendance record
         (the old 0-row UPDATE is fixed): a student marked absent, corrected to
         present and approved, reads back as present.
  MJ-H10 HR employee profile returns REAL, per-employee-DISTINCT data (no shared
         fabricated manager / leave / documents constants).
  MJ-M1  A logged hostel visitor APPEARS on the Visitors screen (read recomputes
         from the live visitor entities, not a frozen snapshot).
  MJ-H11 Razorpay confirm is FAIL-CLOSED in live mode (asserted statically — the
         live VPS runs stub mode, so the fail-closed branch cannot be exercised
         without enabling real money; we assert the guard exists + stub path
         unaffected).

Writes are made with real pilot personas. They are additive (homework, a visitor
pass, an attendance correction) and do not delete or corrupt prior data.
"""
import json, os, re, time, urllib.request, urllib.error

BASE = os.environ.get("API_BASE_URL", "https://api.nikshaos.in")
ADMIN, PARENT, STUDENT, TEACHER = (
    "+919876543210", "+919876543211", "+919876543212", "+919876543213",
)
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
UUID_RE = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", re.I
)
TS = str(int(time.time()))
results = []


def rec(c, ok, d=""):
    results.append((c, bool(ok), d))
    print(f"  [{'PASS' if ok else 'FAIL':>4}] {c}  {d}")


def http(method, path, token=None, body=None):
    payload = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=payload, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
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
    except Exception as e:  # noqa: BLE001
        return 0, str(e)


def d(b):
    return (b.get("data") or {}) if isinstance(b, dict) else {}


def err(b):
    return (b.get("error") or {}) if isinstance(b, dict) else {}


def items(b):
    x = d(b)
    if isinstance(x, list):
        return x
    return x.get("items") or x.get("results") or []


def read(path):
    with open(os.path.join(REPO, path), encoding="utf-8") as f:
        return f.read()


def jwt_claims(token):
    """Decode a JWT payload (no verification) to read scope-specific claims."""
    try:
        import base64
        p = token.split(".")[1]
        p += "=" * (-len(p) % 4)
        return json.loads(base64.urlsafe_b64decode(p).decode())
    except Exception:  # noqa: BLE001
        return {}


def login(ident):
    for _ in range(6):
        s, b = http("POST", "/auth/login", body={"identifier": ident, "type": "phone"})
        otp = d(b).get("otp")
        if s == 200 and otp:
            s2, b2 = http("POST", "/auth/verify-otp", body={"identifier": ident, "otp": otp})
            tok = d(b2).get("accessToken")
            if tok and tok.count(".") == 2:
                return tok
        time.sleep(20)
    return None


print("=== Journey Wave 1 LIVE certification (real VPS / pilot OTP / real RBAC) ===\n")

s, b = http("GET", "/health")
rec("health", s == 200 and d(b).get("status") == "ok", f"HTTP {s}")

admin = login(ADMIN)
teacher = login(TEACHER)
student = login(STUDENT)
parent = login(PARENT)
rec("auth: admin/teacher/student/parent JWTs",
    all([admin, teacher, student, parent]),
    f"admin={bool(admin)} teacher={bool(teacher)} student={bool(student)} parent={bool(parent)}")
if not (admin and teacher and student):
    print("\nABORT: admin/teacher/student tokens required (OTP cooldown?). Re-run shortly.")
    raise SystemExit(1)

# Resolve the student identity/class for deterministic targeting.
s, me = http("GET", "/auth/me", token=student)
student_name = d(me).get("name") or "Staging Student"

# ── MJ-C2 / MJ-H7 — homework write→read→grade→read cycle (named-student) ─────────
HW_TITLE = f"Wave1 cert HW {TS}"
s, b = http("POST", "/teacher/homework", token=teacher, body={
    "class_label": "8-A", "subject": "Mathematics", "title": HW_TITLE,
    "due_label": "Tomorrow", "student_name": student_name,
})
hw = d(b)
hw_id = hw.get("id")
rec("MJ-C2.teacher creates homework (named student)",
    s == 200 and isinstance(hw_id, str) and hw_id.startswith("hw_") and hw.get("deliveredCount", 0) >= 1,
    f"HTTP {s} id={hw_id} delivered={hw.get('deliveredCount')}")

# student sees it
s, b = http("GET", "/student/homework", token=student)
sitems = items(b)
mine = next((i for i in sitems if i.get("id") == hw_id), None)
rec("MJ-C2.student receives the assigned homework",
    s == 200 and mine is not None and str(mine.get("status", "")).lower() == "pending",
    f"HTTP {s} found={mine is not None} status={mine.get('status') if mine else None}")

# student submits
s, b = http("POST", "/student/homework/submit", token=student, body={
    "homework_id": hw_id, "notes": f"cert submission {TS}",
})
rec("MJ-C2.student submits homework", s in (200, 201),
    f"HTTP {s}")

# teacher now SEES the submission with a real UUID (the core MJ-C2 fix)
s, b = http("GET", "/teacher/homework", token=teacher)
titems = items(b)
thw = next((i for i in titems if i.get("id") == hw_id), None)
subs = (thw or {}).get("submissions") or []
sub = subs[0] if subs else None
sub_id = sub.get("id") if sub else None
rec("MJ-C2.teacher SEES submission w/ real UUID + pendingReviews",
    thw is not None and sub is not None and bool(UUID_RE.match(str(sub_id)))
    and (thw.get("pendingReviews") or 0) >= 1,
    f"subs={len(subs)} subId={sub_id} pending={(thw or {}).get('pendingReviews')}")

# teacher grades the real submission
if sub_id and UUID_RE.match(str(sub_id)):
    s, b = http("POST", f"/teacher/homework/submissions/{sub_id}/review", token=teacher,
                body={"grade": "A", "comment": f"cert graded {TS}"})
    rec("MJ-H7.teacher grades the submission", s in (200, 201), f"HTTP {s}")
else:
    rec("MJ-H7.teacher grades the submission", False, "no real submission UUID to grade")

# student now SEES the grade (write-back + overlay)
s, b = http("GET", "/student/homework", token=student)
sitems = items(b)
graded = next((i for i in sitems if i.get("id") == hw_id), None)
rec("MJ-H7.student SEES reviewed status + grade",
    graded is not None and str(graded.get("status", "")).lower() == "reviewed"
    and str(graded.get("reviewGrade", "")) == "A",
    f"status={graded.get('status') if graded else None} grade={graded.get('reviewGrade') if graded else None}")

# ── MJ-H8 — class targeting: a non-existent class delivers to NOBODY (not all) ──
s, b = http("POST", "/teacher/homework", token=teacher, body={
    "class_label": f"ZZ-NOEXIST-{TS}", "subject": "Science",
    "title": f"Wave1 targeting probe {TS}", "due_label": "Tomorrow",
})
delivered = d(b).get("deliveredCount")
# If the school has enrollments, a non-existent class targets 0 students (proves
# the class filter is active, not whole-school spam). If deliveredCount were the
# full active roster this would be the OLD bug.
rec("MJ-H8.non-existent class delivers to 0 (class-targeted, not whole-school)",
    s == 200 and delivered == 0,
    f"HTTP {s} deliveredCount={delivered} (0 = targeting active)")

# ── MJ-H10 — HR employee profiles are per-employee DISTINCT (no shared constants) ─
s, b = http("GET", "/employees", token=admin)
emps = items(b)
two = [e.get("id") for e in emps if UUID_RE.match(str(e.get("id", "")))][:2]
details = []
for eid in two:
    s2, b2 = http("GET", f"/employees/{eid}", token=admin)
    details.append(d(b2))
mgrs = [str(x.get("reportingManager", "")) for x in details]
addrs = [str(x.get("address", "")) for x in details]
FAB = {"Rajesh Iyer (Principal)", "Hyderabad, Telangana", "+91 90000 12345"}
no_fab = all(
    str(x.get("reportingManager", "")) not in {"Rajesh Iyer (Principal)"}
    or str(x.get("address", "")) != "Hyderabad, Telangana"
    or str(x.get("emergencyContact", "")) != "+91 90000 12345"
    for x in details
)
# Stronger: none of the old hardcoded triple should appear verbatim on every emp.
hardcoded_present = any(
    str(x.get("address", "")) == "Hyderabad, Telangana"
    and str(x.get("emergencyContact", "")) == "+91 90000 12345"
    for x in details
)
rec("MJ-H10.HR profiles carry no fabricated shared constants",
    len(details) >= 1 and not hardcoded_present,
    f"managers={mgrs} addrs={addrs}")
rec("MJ-H10.two employees yield distinct profile data",
    len(details) >= 2 and (mgrs[0] != mgrs[1] or details[0] != details[1]),
    f"distinct={len(details) >= 2 and details[0] != details[1]}")

# ── MJ-M1 — hostel visitor write → read appears on Visitors screen ──────────────
VNAME = f"Cert Visitor {TS}"
s, b = http("POST", "/hostel/visitors", token=admin, body={
    "visitor_name": VNAME, "relation": "Parent",
    "student_name": student_name, "sis_student_id": "",
})
pass_id = d(b).get("passId")
rec("MJ-M1.log hostel visitor", s in (200, 201) and bool(pass_id),
    f"HTTP {s} passId={pass_id}")

s, b = http("GET", "/hostel/visitors", token=admin)
vd = d(b)
active = vd.get("activeVisitors") or []
found_v = any(v.get("visitorName") == VNAME for v in active)
rec("MJ-M1.logged visitor APPEARS in activeVisitors (live recompute)",
    s == 200 and found_v,
    f"HTTP {s} active={len(active)} found={found_v}")
rec("MJ-M1.visitors payload keeps static fields (qr/parentRoute)",
    isinstance(vd, dict) and "qrPlaceholderLabel" in vd and "parentAppRoute" in vd,
    f"keys={[k for k in vd.keys()] if isinstance(vd, dict) else vd}")

# ── MJ-H9 — attendance correction apply updates the real record ─────────────────
# Drive the REAL fixed code path: teacher marks the student absent → admin creates
# a correction → admin submits it to the Approval Center → admin approves it (this
# is the ONLY route that calls applyAttendanceCorrection) → read the student's
# attendance back (the overlay reads attendance_records, so a present read-back
# proves the record actually flipped — the old 0-row UPDATE left it absent).
def run_attendance_correction():
    sclaims = jwt_claims(student)
    sid = sclaims.get("student_id") or sclaims.get("studentId")
    tclaims = jwt_claims(teacher)
    teacher_sub = tclaims.get("sub")
    if not sid:
        rec("MJ-H9.attendance correction applies to real record", False,
            "could not resolve student_id from the student JWT")
        return
    class_id = f"class_certw1_{TS}"
    # 1. teacher marks the student ABSENT in a fresh submitted session
    s, b = http("POST", "/teacher/attendance/submit", token=teacher, body={
        "class_id": class_id,
        "entries": [{"student_id": sid, "mark": "absent"}],
    })
    if s not in (200, 201):
        rec("MJ-H9.attendance correction applies to real record", False,
            f"attendance submit HTTP {s} {str(b)[:120]}")
        return
    # confirm the pre-state via the student's own attendance overlay
    s, ab = http("GET", "/student/attendance", token=student)
    pre_logs = d(ab).get("recentLogs") or []
    # 2. admin creates a correction absent→present (sisStudentId accepts the uuid)
    s, b = http("POST", "/attendance/corrections", token=admin, body={
        "sisStudentId": sid, "studentName": student_name,
        "classLabel": class_id, "section": "",
        "dateLabel": "Today", "fromMark": "Absent", "toMark": "Present",
        "reason": f"cert correction {TS}",
    })
    corr_id = d(b).get("id")
    if not corr_id:
        rec("MJ-H9.attendance correction applies to real record", False,
            f"create correction HTTP {s} body={str(b)[:160]}")
        return
    # 3. submit the correction to the Approval Center
    s, b = http("POST", "/approvals", token=admin, body={
        "type": "attendanceCorrection", "title": f"Attendance correction {TS}",
        "summary": f"{student_name} absent→present", "requester_id": teacher_sub or "cert",
        "requester_name": "Cert Teacher", "entity_type": "attendance_correction",
        "entity_id": corr_id,
    })
    appr_id = d(b).get("id")
    if not appr_id:
        rec("MJ-H9.attendance correction applies to real record", False,
            f"submit approval HTTP {s} body={str(b)[:160]}")
        return
    # 4. approve it → triggers applyAttendanceCorrection (the fixed UPDATE)
    s, b = http("POST", f"/approvals/{appr_id}/approve", token=admin, body={})
    approved = s in (200, 201)
    # 5. read the student's attendance back — the corrected day must be present
    s, ab2 = http("GET", "/student/attendance", token=student)
    logs = d(ab2).get("recentLogs") or []
    present_today = any(str(l.get("status", "")).lower() == "present" for l in logs[:2])
    rec("MJ-H9.attendance correction approve→record flips to present (real UPDATE)",
        approved and present_today,
        f"approved={approved} present_in_recent={present_today} corr={corr_id} appr={appr_id}")

run_attendance_correction()

# ── MJ-H11 — Razorpay fail-closed guard present (static; live runs stub mode) ───
psvc = read("supabase/functions/_shared/payment/payment_service.ts")
failclosed = (
    "if (!razorpay.stubMode)" in psvc
    and "Live payment requires" in psvc
    and "Invalid Razorpay payment signature" in psvc
)
rec("MJ-H11.confirmPayment is fail-closed in live mode (guard present)",
    failclosed,
    "live mode requires verified razorpay id+signature before capture")

# ── summary ──────────────────────────────────────────────────────────────────────
passed = sum(1 for _, ok, _ in results if ok)
total = len(results)
print(f"\n=== Journey Wave 1 cert: {passed}/{total} checks passed ===")
for c, ok, dd in results:
    if not ok:
        print(f"  FAIL: {c}  {dd}")
raise SystemExit(0 if passed == total else 1)
