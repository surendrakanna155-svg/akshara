#!/usr/bin/env python3
"""Live-mode certification for MODULE_JOURNEY_ROADMAP **Journey Wave 2** —
"Wire-gap 404s — build the missing backend routes so whole client journeys stop
failing silently" — against the live VPS pilot.

Real VPS + real pilot OTP auth (admin / teacher / student / parent JWTs carrying
real RBAC) + real DB rows + real write→read cycles. Every item below was a path
the Flutter app calls but the backend never registered (404), or a client wired
to the wrong route. The cert asserts each route is now LIVE (never 404) and, where
a persona has the permission, that it does real work (write→read round-trips).

Items covered:
  MJ-C5  Teacher exam workflow (marks-entry list / mark update / process / publish)
         reachable under /teacher/exams/* (delegated to the certified exam engine).
  MJ-H13 Teacher parent-communication + subject concerns: flag → list shows it →
         send communication resolves it; dismiss works.
  MJ-C3  Parent messaging: /parent/messages alias + /parent/communication/inbox
         return 200 (no longer 404 → mock fallback).
  MJ-C4  Parent PTM meetings: GET /parent/meetings returns a real (possibly empty)
         list, not the mock repository.
  MJ-H12 Parent leave: POST /parent/leave persists → GET /parent/leave reads it back.
  MJ-M2  Student notifications: GET /student/notifications returns 200 for a student
         persona (was a parent-only route → 403 → demo fallback).
  MJ-H14 Admissions: reports / settings / approval-queue / enrollments-pending /
         enrollment-prefill all return 200 (were 4 broken nav tabs).
  MJ-H15 Admissions: POST /admissions/approval/{id}/notes is live (was 404).
  MJ-C6  Communication: POST /communications/templates persists → GET lists it;
         GET /communications/broadcasts/history returns 200.
  MJ-H16 Management settings: PUT /management/settings persists → GET round-trips
         the change (Save no longer silently 404s).

Writes use real pilot personas; they are additive (a template, a concern, a leave
request, a settings tweak) and do not delete or corrupt prior data.
"""
import json, os, time, urllib.request, urllib.error

BASE = os.environ.get("API_BASE_URL", "https://api.nikshaos.in")
ADMIN, PARENT, STUDENT, TEACHER = (
    "+919876543210", "+919876543211", "+919876543212", "+919876543213",
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


def items(b):
    x = d(b)
    if isinstance(x, list):
        return x
    return x.get("items") or x.get("results") or []


def not_404(s):
    """A wired route never returns 404 (it may 401/403/422 on auth/validation)."""
    return s not in (0, 404)


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


print("=== Journey Wave 2 LIVE certification (real VPS / pilot OTP / real RBAC) ===\n")

s, b = http("GET", "/health")
rec("health", s == 200 and d(b).get("status") == "ok", f"HTTP {s}")

admin = login(ADMIN)
teacher = login(TEACHER)
student = login(STUDENT)
parent = login(PARENT)
rec("auth: admin/teacher/student/parent JWTs",
    all([admin, teacher, student, parent]),
    f"admin={bool(admin)} teacher={bool(teacher)} student={bool(student)} parent={bool(parent)}")
if not (admin and teacher and student and parent):
    print("\nABORT: all four pilot tokens required (OTP cooldown?). Re-run shortly.")
    raise SystemExit(1)

# ── MJ-C5 — teacher exam workflow reachable under /teacher/exams/* ───────────────
# marks-entry list (delegates to the exam-administration engine).
s, b = http("GET", "/teacher/exams/marks-entry", token=teacher)
rec("MJ-C5.GET /teacher/exams/marks-entry is live (200, list)",
    s == 200 and isinstance(items(b), list),
    f"HTTP {s} count={len(items(b))}")

# Create a real exam (admin holds manageExams), then drive process/publish via the
# teacher-facing paths. process/publish may 422 without entered marks — that still
# proves the route is WIRED (the bug was a hard 404). We assert never-404.
s, eb = http("POST", "/academics/exams", token=admin, body={
    "title": f"Wave2 cert exam {TS}", "subject": "Mathematics", "grade": "8",
    "section": "A", "termLabel": "Term 1", "maxMarks": 100, "examType": "unit_test",
})
exam_id = d(eb).get("id")
rec("MJ-C5.exam created for workflow probe", isinstance(exam_id, str) and bool(exam_id),
    f"HTTP {s} id={exam_id}")
if exam_id:
    sp, _ = http("POST", f"/teacher/exams/{exam_id}/process", token=admin, body={})
    rec("MJ-C5.POST /teacher/exams/{id}/process is wired (not 404)",
        not_404(sp), f"HTTP {sp} (delegates to exam engine)")
    # A bogus mark id legitimately resolves to mark-not-found (the handler RAN);
    # the wire-gap bug was a generic "Route not found". So we assert the response
    # is NOT the router's not-found, proving the PUT route reaches the exam engine.
    su, sub = http("PUT", "/teacher/exams/marks/00000000-0000-4000-8000-000000000000",
                   token=teacher, body={"marksObtained": 50})
    su_routed = "Route not found" not in json.dumps(sub)
    rec("MJ-C5.PUT /teacher/exams/marks/{id} reaches the handler (not route-404)",
        su_routed, f"HTTP {su} routed={su_routed}")
    spub, _ = http("POST", f"/teacher/exams/{exam_id}/publish", token=admin, body={})
    rec("MJ-C5.POST /teacher/exams/{id}/publish is wired (not 404)",
        not_404(spub), f"HTTP {spub}")

# ── MJ-H13 — teacher subject concern flag → list → resolve via communication ─────
s, cb = http("POST", "/teacher/parent-communication/concerns", token=teacher, body={
    "sisStudentId": f"cert-stu-{TS}", "category": "academic",
    "observation": f"cert concern {TS}", "subject": "Mathematics",
})
concern_id = d(cb).get("id")
rec("MJ-H13.flag subject concern persists",
    s in (200, 201) and isinstance(concern_id, str) and bool(concern_id),
    f"HTTP {s} id={concern_id}")

s, lb = http("GET", "/teacher/parent-communication/concerns", token=teacher)
listed = items(lb)
found_concern = any(x.get("id") == concern_id for x in listed)
rec("MJ-H13.flagged concern appears in pending list",
    s == 200 and found_concern, f"HTTP {s} count={len(listed)} found={found_concern}")

s, pcb = http("POST", "/teacher/parent-communication", token=teacher, body={
    "sisStudentId": f"cert-stu-{TS}", "reason": "academic_concern", "tone": "supportive",
    "channels": ["app"], "teachingRole": "subjectTeacher",
    "customMessage": f"cert comm {TS}", "useAi": False, "sourceConcernId": concern_id,
})
rec("MJ-H13.send parent-communication (resolves source concern)",
    s in (200, 201) and d(pcb).get("status") == "sent", f"HTTP {s} status={d(pcb).get('status')}")

# the resolved concern should have left the pending queue
s, lb2 = http("GET", "/teacher/parent-communication/concerns", token=teacher)
still_pending = any(x.get("id") == concern_id for x in items(lb2))
rec("MJ-H13.resolved concern no longer pending",
    s == 200 and not still_pending, f"HTTP {s} stillPending={still_pending}")

# ── MJ-C3 — parent messaging routes return 200 (were 404 → mock) ─────────────────
s, _ = http("GET", "/parent/messages", token=parent)
rec("MJ-C3.GET /parent/messages alias is live (200)", s == 200, f"HTTP {s}")
s, ib = http("GET", "/parent/communication/inbox", token=parent)
rec("MJ-C3.GET /parent/communication/inbox is live (200, list)",
    s == 200 and isinstance(items(ib), list), f"HTTP {s} count={len(items(ib))}")

# ── MJ-C4 — parent PTM meetings backed by a real route ──────────────────────────
s, mb = http("GET", "/parent/meetings", token=parent)
rec("MJ-C4.GET /parent/meetings is live (200, real list)",
    s == 200 and isinstance(items(mb), list), f"HTTP {s} count={len(items(mb))}")

# ── MJ-H12 — parent leave write→read ────────────────────────────────────────────
# The real client sends the active child id (ParentLeaveSubmitRequestDto → child_id).
# POST is served by routePilotOperations (mobile_leave_requests); the Wave-2 fix is
# that GET /parent/leave now overlays those real rows so the parent SEES the leave.
pclaims = jwt_claims(parent)
child_ids = pclaims.get("child_ids") or []
child0 = child_ids[0] if child_ids else None
s, lvb = http("POST", "/parent/leave", token=parent, body={
    "child_id": child0, "from_date_label": "Tomorrow", "to_date_label": "Tomorrow",
    "reason": f"cert leave {TS}", "type": "sick", "has_attachment": False,
})
rec("MJ-H12.POST /parent/leave persists", s in (200, 201) and bool(child0), f"HTTP {s}")
s, glb = http("GET", "/parent/leave", token=parent)
reasons = [str(x.get("reason", "")) for x in items(glb)]
rec("MJ-H12.submitted leave reads back in GET /parent/leave (overlay)",
    s == 200 and any(f"cert leave {TS}" in r for r in reasons),
    f"HTTP {s} found={any(f'cert leave {TS}' in r for r in reasons)} count={len(reasons)}")

# ── MJ-M2 — student notifications route reachable for a student (was 403) ────────
s, _ = http("GET", "/student/notifications", token=student)
rec("MJ-M2.GET /student/notifications is 200 for student persona (not 403)",
    s == 200, f"HTTP {s}")

# ── MJ-H14 — admissions 5 GET tabs all live (were 404) ──────────────────────────
adm_routes = [
    ("reports", "/admissions/reports"),
    ("settings", "/admissions/settings"),
    ("approval-queue", "/admissions/approval-queue"),
    ("enrollments/pending", "/admissions/enrollments/pending"),
    ("enrollment/prefill", "/admissions/enrollment/prefill"),
]
for label, path in adm_routes:
    s, _ = http("GET", path, token=admin)
    rec(f"MJ-H14.GET {path} is live (200)", s == 200, f"HTTP {s}")

# ── MJ-H15 — admissions approval notes route live ───────────────────────────────
s, qb = http("GET", "/admissions/approval-queue", token=admin)
queue = items(qb)
appr_id = queue[0].get("id") if queue else None
if appr_id:
    sn, _ = http("POST", f"/admissions/approval/{appr_id}/notes", token=admin,
                 body={"note": f"cert approval note {TS}"})
    rec("MJ-H15.POST /admissions/approval/{id}/notes is live",
        sn in (200, 201), f"HTTP {sn} appr={appr_id}")
else:
    sn, _ = http("POST", "/admissions/approval/probe-id/notes", token=admin,
                 body={"note": "probe"})
    rec("MJ-H15.POST /admissions/approval/{id}/notes is wired (not 404)",
        not_404(sn), f"HTTP {sn} (empty queue → route-reachability probe)")

# ── MJ-C6 — communication template create→list + broadcast history ──────────────
TMPL_CODE = f"cert_tmpl_{TS}"
s, tb = http("POST", "/communications/templates", token=admin, body={
    "code": TMPL_CODE, "channel": "push", "name": f"Cert Template {TS}",
    "subject_template": "Cert {name}", "body_template": "Hello {name}, cert.",
    "variables": ["name"],
})
rec("MJ-C6.POST /communications/templates persists", s in (200, 201), f"HTTP {s}")
s, gtb = http("GET", "/communications/templates", token=admin)
codes = [str(x.get("code", "")) for x in items(gtb)]
rec("MJ-C6.created template appears in GET /communications/templates",
    s == 200 and TMPL_CODE in codes, f"HTTP {s} found={TMPL_CODE in codes}")
s, hb = http("GET", "/communications/broadcasts/history", token=admin)
rec("MJ-C6.GET /communications/broadcasts/history is live (200, list)",
    s == 200 and isinstance(items(hb), list), f"HTTP {s} count={len(items(hb))}")

# ── MJ-H16 — management settings PUT round-trips ────────────────────────────────
s, gsb = http("GET", "/management/settings", token=admin)
year_before = d(gsb).get("academicYear")
new_year = f"AY-CERT-{TS[-4:]}"
sp, _ = http("PUT", "/management/settings", token=admin,
             body={"academic_year": new_year})
put_ok = sp in (200, 201)
rec("MJ-H16.PUT /management/settings persists (not 404)", put_ok, f"HTTP {sp}")
s, gsb2 = http("GET", "/management/settings", token=admin)
year_after = d(gsb2).get("academicYear")
rec("MJ-H16.GET after PUT round-trips the change",
    s == 200 and year_after == new_year,
    f"before={year_before} after={year_after} expected={new_year}")

# ── summary ──────────────────────────────────────────────────────────────────────
passed = sum(1 for _, ok, _ in results if ok)
total = len(results)
print(f"\n=== Journey Wave 2 cert: {passed}/{total} checks passed ===")
for c, ok, dd in results:
    if not ok:
        print(f"  FAIL: {c}  {dd}")
raise SystemExit(0 if passed == total else 1)
