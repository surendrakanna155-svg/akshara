#!/usr/bin/env python3
"""Results cross-persona spine journey (live VPS): a staff member enters exam
marks, processes + verifies, then publishes results -> the parent sees the newly
published result for their child. Proves the marks-by-staff -> visible-to-parent
loop end to end, and that the publish approval gate is real (publish is refused
without an approval). Publishing is irreversible, so each run creates a uniquely
titled throwaway exam for the parent's child's section (class 5-A in the seed)."""
import json, time, urllib.request, urllib.error, sys
import os
BASE = os.environ.get("API_BASE_URL", "https://api.nikshaos.in")
SCHOOL = "a2000000-0000-4000-8000-000000000001"
ADMIN, PARENT = "+919876543210", "+919876543211"
GRADE, SECTION, SUBJECT = "5", "A", "Mathematics"
results = []

def http(m, p, tok=None, body=None):
    r = urllib.request.Request(BASE + p, data=json.dumps(body).encode() if body is not None else None, method=m)
    r.add_header("Content-Type", "application/json"); r.add_header("X-School-Id", SCHOOL)
    if tok: r.add_header("Authorization", "Bearer " + tok)
    try:
        x = urllib.request.urlopen(r, timeout=60); return x.status, json.loads(x.read().decode())
    except urllib.error.HTTPError as e:
        try: return e.code, json.loads(e.read().decode())
        except: return e.code, e.read().decode()

def login(ident):
    s, b = http("POST", "/auth/login", body={"identifier": ident}); otp = b["data"]["otp"]
    s, b = http("POST", "/auth/verify-otp", body={"identifier": ident, "otp": otp}); return b["data"]["accessToken"]

def rec(check, ok, detail=""):
    results.append(ok); print(f"  [{'PASS' if ok else 'FAIL'}] {check}  {detail}")

def parent_result_ids(tok):
    s, b = http("GET", "/parent/exams", tok)
    d = b.get("data") if isinstance(b, dict) else {}
    rows = d.get("examResults") if isinstance(d, dict) else None
    return s, {str(r.get("id")) for r in rows if r.get("id")} if isinstance(rows, list) else set()

admin, parent = login(ADMIN), login(PARENT)
print("=== results journey: marks (staff) -> published -> visible to parent ===")
rec("admin login", bool(admin)); rec("parent login", bool(parent))

# 1. admin creates a fresh exam for the parent's child's section
title = f"QA Live Journey {int(time.time())}"
s, b = http("POST", "/academics/exams", admin,
            {"title": title, "subject": SUBJECT, "grade": GRADE, "section": SECTION,
             "termLabel": "Term 1", "dateLabel": "QA", "maxMarks": 100, "examType": "unit_test"})
exam_id = (b.get("data") or {}).get("id") if isinstance(b, dict) else None
rec("admin POST /academics/exams", s in (200, 201) and bool(exam_id), f"HTTP {s} exam={exam_id}")

# 2. open marks entry -> provisions a mark slot per enrolled student in the section
s, b = http("POST", f"/academics/exams/{exam_id}/open-marks", admin, {})
rec("admin open-marks", s == 200, f"HTTP {s}")

# 3. enter marks for EVERY provisioned slot (process refuses partial entry)
s, b = http("GET", f"/academics/exams/{exam_id}/marks", admin)
marks = (b.get("data") if isinstance(b, dict) else b) or []
rec("admin GET marks (slots provisioned)", s == 200 and len(marks) > 0, f"HTTP {s} slots={len(marks)}")
entered = 0
for m in marks:
    s, _ = http("PATCH", f"/academics/exams/marks/{m['id']}", admin, {"marksObtained": 75})
    if s == 200: entered += 1
rec("admin entered all marks", entered == len(marks) and entered > 0, f"{entered}/{len(marks)}")

# 4. process -> verify (coordinator)
s, b = http("POST", f"/academics/exams/{exam_id}/process", admin, {})
rec("admin process results", s == 200, f"HTTP {s}")
s, b = http("POST", f"/academics/exams/{exam_id}/verify-coordinator", admin, {})
rec("admin verify-coordinator", s == 200, f"HTTP {s}")

# 5. publish gate is real: without an approval, publish is refused
s, b = http("POST", f"/academics/exams/{exam_id}/publish", admin, {})
code = (b.get("error") or {}).get("code") if isinstance(b, dict) else None
rec("publish blocked without approval", s == 403, f"HTTP {s} code={code}")

# 6. parent baseline (just before publish)
s, base_ids = parent_result_ids(parent)
rec("parent GET /parent/exams (baseline)", s == 200, f"HTTP {s} count={len(base_ids)}")

# 7. publish (approval bypass, as the API contract allows for the pilot)
s, b = http("POST", f"/academics/exams/{exam_id}/publish", admin, {"requireApproval": False})
published = (b.get("data") or {}).get("publishedCount") if isinstance(b, dict) else None
rec("admin publish results", s == 200 and (published or 0) > 0, f"HTTP {s} published={published}")

# 8. parent sees the newly published result for their child (cross-persona assertion)
s, after_ids = parent_result_ids(parent)
fresh = [i for i in (after_ids - base_ids) if i.startswith(exam_id + "_")]
rec("parent sees new published result", s == 200 and len(fresh) > 0,
    f"HTTP {s} {len(base_ids)}->{len(after_ids)} new={fresh}")

ok = all(results)
print(f"\nresults->published->parent journey: {'PASS' if ok else 'FAIL'} ({sum(results)}/{len(results)})")
print(f"(left published exam {exam_id} '{title}' — publish is irreversible via the API;")
print(f" remove with: DELETE FROM exam_mark_entries WHERE exam_id='{exam_id}'; "
      f"DELETE FROM exam_sessions WHERE id='{exam_id}';)")
sys.exit(0 if ok else 1)
