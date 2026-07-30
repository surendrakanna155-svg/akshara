#!/usr/bin/env python3
"""Live-mode certification for FINAL_COMPLETION_ROADMAP Wave 1 (stop silent
data loss) against the live VPS pilot — real OTP auth, real API, real DB/RBAC.

Covers the deployed backend changes:
  TCH-1  POST /teacher/homework persists + delivers (teacher_entities +
         student_entities homework_item).
  TCH-2  POST /teacher/messages (no thread_id) opens a real thread (compose send
         reaches the backend — the client no-op is fixed separately).
  TCH-5  PUT /academics/exams/{examId}/remarks/{studentId} persists with the
         correct role slot — class-teacher and leadership remarks coexist (no
         collision), and a class teacher cannot author a leadership remark.
"""
import json, urllib.request, urllib.error, time
import os

BASE = os.environ.get("API_BASE_URL", "https://api.nikshaos.in")
SCHOOL_1 = "a2000000-0000-4000-8000-000000000001"
STUDENT_UUID = "a4000000-0000-4000-8000-000000000001"  # seeded pilot student
TS = str(int(time.time()))
PERSONAS = {
    "admin":   "+919876543210",   # schoolAdmin + orgAdmin (manageExams)
    "teacher": "+919876543213",   # Teacher A (school ...0001)
}
results = []


def http(method, path, token=None, body=None):
    url = BASE + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    req.add_header("X-School-Id", SCHOOL_1)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
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


def record(check, ok, detail=""):
    label = "PASS" if ok else "FAIL"
    results.append((check, ok, detail))
    print(f"  [{label}] {check}  {detail}")


def login(identifier):
    s, b = http("POST", "/auth/login", body={"identifier": identifier})
    if s != 200 or not isinstance(b, dict):
        return None, f"login HTTP {s}: {str(b)[:120]}"
    otp = b.get("data", {}).get("otp")
    if not otp:
        return None, "no OTP (not allowlisted?)"
    s, b = http("POST", "/auth/verify-otp",
                body={"identifier": identifier, "otp": otp})
    if s != 200 or not isinstance(b, dict):
        return None, f"verify HTTP {s}: {str(b)[:120]}"
    tok = b.get("data", {}).get("accessToken")
    return (tok, "") if tok else (None, "no accessToken")


def data_of(b):
    return (b.get("data") or {}) if isinstance(b, dict) else {}


print("=== Completion Wave 1 — live certification ===\n")
tok = {}
for name, ident in PERSONAS.items():
    t, err = login(ident)
    tok[name] = t
    record(f"auth.login:{name}", bool(t), err if not t else ident)

admin, teacher = tok.get("admin"), tok.get("teacher")

# --- TCH-2: compose-send opens a real thread ---
if teacher:
    s, b = http("POST", "/teacher/messages", teacher, body={
        "recipient": "+919999000111",
        "subject": f"Wave1 cert {TS}",
        "body": "Live cert: compose send reaches the backend.",
    })
    thread = data_of(b)
    tid = thread.get("id") or thread.get("threadId")
    record("TCH-2.compose_send_opens_thread", s in (200, 201) and bool(tid),
           f"HTTP {s} thread={tid}")

# --- TCH-1: homework create persists + delivers ---
hw_title = f"Wave1 Cert HW {TS}"
if teacher:
    s, b = http("POST", "/teacher/homework", teacher, body={
        "class_label": "8-A",
        "subject": "Mathematics",
        "title": hw_title,
        "due_label": "Next Monday",
        "student_name": "Staging Student",
    })
    d = data_of(b)
    delivered = d.get("deliveredCount")
    ok = (s == 200 and bool(d.get("id")) and isinstance(delivered, int)
          and delivered >= 1)
    record("TCH-1.homework_create_persists", ok,
           f"HTTP {s} id={d.get('id')} delivered={delivered}"
           + ("" if ok else f" raw={str(b)[:200]}"))

# --- TCH-5: remark role-slots coexist (no collision) + RBAC ---
exam_id = None
if admin:
    s, b = http("GET", "/academics/exams", admin)
    exams = data_of(b)
    if isinstance(exams, dict):
        exams = exams.get("items") or exams.get("exams") or []
    if isinstance(exams, list) and exams:
        exam_id = exams[0].get("id") if isinstance(exams[0], dict) else None
    record("TCH-5.exam_available", bool(exam_id),
           f"HTTP {s} examId={exam_id}")

if admin and exam_id:
    # admin (manageExams) authors BOTH slots — exercises the slotted id fix.
    s1, _ = http("PUT", f"/academics/exams/{exam_id}/remarks/{STUDENT_UUID}",
                 admin, body={"text": f"Class-teacher remark {TS}",
                              "authorName": "Cert Admin",
                              "authorRole": "classTeacher"})
    s2, _ = http("PUT", f"/academics/exams/{exam_id}/remarks/{STUDENT_UUID}",
                 admin, body={"text": f"Leadership remark {TS}",
                              "authorName": "Cert Principal",
                              "authorRole": "principal"})
    record("TCH-5.both_slots_upsert", s1 == 200 and s2 == 200,
           f"teacher-slot HTTP {s1}, leadership-slot HTTP {s2}")

    s, b = http("GET", f"/academics/exams/{exam_id}/remarks", admin)
    rows = data_of(b)
    if isinstance(rows, dict):
        rows = rows.get("items") or rows.get("remarks") or []
    mine = [r for r in rows if isinstance(r, dict)
            and r.get("sisStudentId") == STUDENT_UUID]
    roles = {r.get("authorRole") for r in mine}
    record("TCH-5.no_collision_both_remarks_present",
           "classTeacher" in roles and "principal" in roles,
           f"HTTP {s} roles={sorted(roles)}")

if teacher and exam_id:
    # a class teacher must NOT be able to author the leadership remark.
    s, _ = http("PUT", f"/academics/exams/{exam_id}/remarks/{STUDENT_UUID}",
                teacher, body={"text": "should be blocked",
                               "authorName": "Teacher",
                               "authorRole": "principal"})
    record("TCH-5.rbac_teacher_cannot_author_leadership", s == 403,
           f"HTTP {s} (expect 403)")

passed = sum(1 for _, ok, _ in results if ok)
total = len(results)
print(f"\n=== {passed}/{total} checks passed ===")
import sys
sys.exit(0 if passed == total else 1)
