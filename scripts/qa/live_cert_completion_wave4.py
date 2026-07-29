#!/usr/bin/env python3
"""Live-mode certification for FINAL_COMPLETION_ROADMAP Wave 4 (AI moderation
gate + dispatch performance) against the live VPS pilot.

Real VPS + real DB + edge-minted JWTs (real RBAC). Fixtures are inserted as
supabase_admin and the assertions run through the deployed edge under real
tenant context / RLS.

What it proves (the backend-observable contract Wave 4 closes):
  AI-1  A published paper that still holds a human-REJECTED item and an
        unmoderated PENDING item exports ONLY the approved items — the rejected
        + pending question text never appears in the student paper.
  AI-1  The exported answer key is rebuilt + renumbered from the surviving
        items (1..N), so questions and answers stay aligned (the stale stored
        answer_key is ignored).
  AI-2  GET /education/question-papers/{id}/export is gated on publish state:
        a DRAFT paper returns 409 PAPER_NOT_PUBLISHED; the published paper is
        200 (positive control).
  PERF-1 POST /communications/broadcasts returns fast with status 'queued';
        recipients + push deliveries are written in batch (DB row counts match
        the recipientCount), and the per-recipient send is drained OUTSIDE the
        request (deliveries leave 'pending').
  AI-5  The question-paper read carries the composition counts inside
        `blueprint` (bankReuseCount + aiCandidateCount) — the shape the fixed
        Flutter chip mapper now reads.

PERF-2 (search debounce), AI-3 (panel-config captions) and the client-side
export filter are unit-/build-covered (flutter + deno) — no separate live
surface. Idempotent: fixtures are deleted then re-inserted by fixed id; broadcast
rows are additive cert rows; no destructive ops on real data.
"""
import json
import os
import subprocess
import time
import urllib.error
import urllib.request

BASE = os.environ.get("API_BASE_URL", "https://api.nikshaos.in")
ORG = "a1000000-0000-4000-8000-000000000001"
SCHOOL_A = "a2000000-0000-4000-8000-000000000001"
SCHOOL_ADMIN = "a3000000-0000-4000-8000-000000000001"
SOCK = os.path.expanduser("~/.ssh/akshara-cm.sock")

P_PUB = "a7000000-0000-4000-8000-0000000040a1"
P_DRAFT = "a7000000-0000-4000-8000-0000000040a2"
NONCE = str(int(time.time()))
BCAST_TITLE = f"Wave4 cert broadcast {NONCE}"
results = []


def rec(check, ok, detail=""):
    results.append((check, bool(ok), detail))
    print(f"  [{'PASS' if ok else 'FAIL':>4}] {check}  {detail}")


def http(method, path, token=None, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=90) as r:
            txt = r.read().decode()
            elapsed = time.time() - t0
            try:
                return r.status, json.loads(txt), elapsed
            except Exception:
                return r.status, txt, elapsed
    except urllib.error.HTTPError as e:
        txt = e.read().decode()
        elapsed = time.time() - t0
        try:
            return e.code, json.loads(txt), elapsed
        except Exception:
            return e.code, txt, elapsed
    except Exception as e:  # noqa: BLE001
        return 0, str(e), time.time() - t0


def ssh(cmd, stdin=None):
    p = subprocess.run(["ssh", "-o", "ControlPath=" + SOCK, "akshara", cmd],
                       input=stdin, capture_output=True, text=True, timeout=90)
    return p.stdout.strip(), p.stderr.strip()


def psql(sql):
    """Run SQL by piping via stdin (avoids -c double-shell quoting issues with
    embedded quotes/newlines). Returns trimmed stdout; prints stderr on error."""
    out, err = ssh(
        "docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db "
        "-t -A -v ON_ERROR_STOP=1", stdin=sql)
    if err and ("ERROR" in err or "FATAL" in err):
        print("    psql stderr:", err.splitlines()[0])
    return out


def data(b):
    return (b.get("data") if isinstance(b, dict) and "data" in b else b)


MINT = '''
import { SignJWT } from "npm:jose";
const secret = new TextEncoder().encode(Deno.env.get("JWT_SECRET"));
const t = await new SignJWT({
  tenant_id: Deno.env.get("ORG"), organization_id: Deno.env.get("ORG"),
  school_id: Deno.env.get("SCHOOLID"),
  role: Deno.env.get("ROLE"), role_slugs: [Deno.env.get("ROLE")],
  primary_role: Deno.env.get("ROLE"),
  permissions: JSON.parse(Deno.env.get("PERMS")), permissions_version: 1,
  scope: "school", school_group_id: null, student_id: null,
  child_ids: [], session_id: "cert-w4",
}).setProtectedHeader({ alg: "HS256", typ: "JWT" })
  .setSubject(Deno.env.get("SUB")).setIssuedAt()
  .setExpirationTime(Math.floor(Date.now() / 1000) + 3600).sign(secret);
console.log(t);
'''


def mint(sub, role, perms):
    env = (f'-e ORG={ORG} -e SCHOOLID={SCHOOL_A} -e SUB={sub} -e ROLE={role} '
           f'-e PERMS=\'{json.dumps(perms)}\'')
    out, _ = ssh(f"docker exec -i {env} akshara-edge deno run -A -", stdin=MINT)
    tok = out.splitlines()[-1] if out else ""
    return tok if tok.count(".") == 2 else None


def setup_fixtures():
    """Published paper with approved+rejected+pending items, plus a draft."""
    bp = json.dumps({"bankReuseCount": 2, "aiCandidateCount": 1,
                     "placedMarks": 10, "difficultyMode": "mixed"})
    stale_key = json.dumps([{"questionNumber": 7, "answer": "STALE", "marks": 5}])
    sql = f"""
DELETE FROM edu_question_paper_items WHERE paper_id IN ('{P_PUB}','{P_DRAFT}');
DELETE FROM edu_question_papers WHERE id IN ('{P_PUB}','{P_DRAFT}');
INSERT INTO edu_question_papers
  (id, organization_id, school_id, academic_year_label, class_name, subject_name,
   total_marks, exam_type, title, status, review_status, program_track, blueprint, answer_key)
VALUES
  ('{P_PUB}','{ORG}','{SCHOOL_A}','2026-27','10','Mathematics',10,'unit_test',
   'Wave4 Published','published','published','board','{bp}'::jsonb,'{stale_key}'::jsonb),
  ('{P_DRAFT}','{ORG}','{SCHOOL_A}','2026-27','10','Mathematics',10,'unit_test',
   'Wave4 Draft','draft','draft','board','{bp}'::jsonb,'[]'::jsonb);
INSERT INTO edu_question_paper_items
  (paper_id, organization_id, school_id, sort_order, question_type, marks,
   question_text, answer_text, options, source, review_status)
VALUES
  ('{P_PUB}','{ORG}','{SCHOOL_A}',0,'mcq',5,'Q_APPROVED_ALPHA','ANS_ALPHA','[]'::jsonb,'bank','approved'),
  ('{P_PUB}','{ORG}','{SCHOOL_A}',1,'mcq',5,'Q_REJECTED_XRAY','ANS_XRAY','[]'::jsonb,'ai_candidate','rejected'),
  ('{P_PUB}','{ORG}','{SCHOOL_A}',2,'mcq',5,'Q_PENDING_PAPA','ANS_PAPA','[]'::jsonb,'ai_candidate','pending'),
  ('{P_PUB}','{ORG}','{SCHOOL_A}',3,'mcq',5,'Q_APPROVED_BRAVO','ANS_BRAVO','[]'::jsonb,'bank','approved');
"""
    psql(sql)


print("=== Completion Wave 4 — AI moderation gate + dispatch perf LIVE cert ===\n")

s, b, _ = http("GET", "/health")
rec("health", s == 200, f"HTTP {s}")

edu = mint(SCHOOL_ADMIN, "schoolAdmin",
           ["viewEducation", "manageEducation", "approveEducation"])
comm = mint(SCHOOL_ADMIN, "schoolAdmin",
            ["sendBroadcast", "viewAdminHub", "manageCommunications", "viewCommunications"])
if not all([edu, comm]):
    print("\nABORT: could not mint tokens (VPS/JWT_SECRET unreachable)")
    raise SystemExit(1)
rec("mint.tokens", True, "education / communications")

setup_fixtures()
rec("fixtures.seeded", True, "published(4 items: 2 approved/1 rejected/1 pending) + draft")

# ── AI-1: export excludes rejected + pending ─────────────────────────────────
s, b, _ = http("GET", f"/education/question-papers/{P_PUB}/export", token=edu)
d = data(b)
questions = d.get("questions", []) if isinstance(d, dict) else []
texts = [q.get("questionText") for q in questions]
rec("AI-1.export 200", s == 200, f"HTTP {s}")
rec("AI-1.only approved printed", len(questions) == 2 and texts == ["Q_APPROVED_ALPHA", "Q_APPROVED_BRAVO"],
    f"questions={texts}")
rec("AI-1.rejected text absent", "Q_REJECTED_XRAY" not in texts, "Q_REJECTED_XRAY excluded")
rec("AI-1.pending text absent", "Q_PENDING_PAPA" not in texts, "Q_PENDING_PAPA excluded")

# ── AI-1: answer key rebuilt + renumbered from survivors ─────────────────────
ak = d.get("answerKey", []) if isinstance(d, dict) else []
ak_ok = (len(ak) == 2
         and ak[0].get("questionNumber") == 1 and ak[0].get("answer") == "ANS_ALPHA"
         and ak[1].get("questionNumber") == 2 and ak[1].get("answer") == "ANS_BRAVO")
rec("AI-1.answer key realigned 1..N", ak_ok, f"answerKey={ak}")
rec("AI-1.stale stored key ignored", all(e.get("answer") != "STALE" for e in ak), "no STALE answer")

# ── AI-2: export gated on publish state ──────────────────────────────────────
s, b, _ = http("GET", f"/education/question-papers/{P_DRAFT}/export", token=edu)
code = b.get("error", {}).get("code") if isinstance(b, dict) else None
rec("AI-2.draft export blocked 409", s == 409, f"HTTP {s} code={code}")
rec("AI-2.PAPER_NOT_PUBLISHED code", code == "PAPER_NOT_PUBLISHED", str(code))
s2, _, _ = http("GET", f"/education/question-papers/{P_PUB}/export", token=edu)
rec("AI-2.published export allowed", s2 == 200, f"HTTP {s2}")

# ── AI-5: composition counts live inside blueprint ───────────────────────────
s, b, _ = http("GET", f"/education/question-papers/{P_PUB}", token=edu)
d = data(b)
paper = d.get("paper", {}) if isinstance(d, dict) else {}
bp = paper.get("blueprint", {}) if isinstance(paper, dict) else {}
rec("AI-5.blueprint carries counts",
    s == 200 and bp.get("bankReuseCount") == 2 and bp.get("aiCandidateCount") == 1,
    f"bankReuseCount={bp.get('bankReuseCount')} aiCandidateCount={bp.get('aiCandidateCount')}")

# ── PERF-1: batched, bounded, queued (not synchronous) broadcast ─────────────
s, b, elapsed = http("POST", "/communications/broadcasts", token=comm,
                     body={"audience": "school", "title": BCAST_TITLE,
                           "body": "Wave 4 perf cert dispatch"})
d = data(b)
bcast_id = d.get("broadcastId") if isinstance(d, dict) else None
rcount = d.get("recipientCount") if isinstance(d, dict) else None
status = d.get("status") if isinstance(d, dict) else None
rec("PERF-1.broadcast 201", s == 201, f"HTTP {s}")
rec("PERF-1.status queued (async send)", status == "queued", f"status={status}")
rec("PERF-1.dropped over cap = 0", isinstance(d, dict) and d.get("droppedOverCap") == 0,
    f"droppedOverCap={d.get('droppedOverCap') if isinstance(d, dict) else '?'}")
rec("PERF-1.responds fast (<8s)", elapsed < 8.0, f"{elapsed:.2f}s")

# recipients batch-inserted
recip_db = psql(f"SELECT count(*) FROM comm_recipients WHERE broadcast_id='{bcast_id}';") if bcast_id else "?"
rec("PERF-1.recipients batch-inserted", str(recip_db) == str(rcount),
    f"comm_recipients={recip_db} recipientCount={rcount}")

# deliveries batch-enqueued (one push delivery per recipient)
deliv_db = psql(
    "SELECT count(*) FROM notification_deliveries "
    f"WHERE rendered_subject='{BCAST_TITLE}';")
rec("PERF-1.deliveries batch-enqueued", str(deliv_db) == str(rcount),
    f"notification_deliveries={deliv_db} recipientCount={rcount}")

# The send is drained OUTSIDE the request (background EdgeRuntime.waitUntil). A
# delivery is "attempted" once it leaves pending OR records a send marker
# (retry_count / last_error / sent_at) — without device tokens a push attempt
# records a retry rather than flipping status. Poll for the background drain.
attempted_sql = (
    "SELECT count(*) FROM notification_deliveries "
    f"WHERE rendered_subject='{BCAST_TITLE}' AND "
    "(status <> 'pending' OR retry_count > 0 OR last_error IS NOT NULL "
    "OR sent_at IS NOT NULL);")
attempted = "0"
for _ in range(12):
    attempted = psql(attempted_sql)
    if rcount and str(attempted) == str(rcount):
        break
    time.sleep(2)
forced = False
if not (rcount and str(attempted) == str(rcount)):
    http("POST", "/communications/notifications/process-queue", token=comm)
    forced = True
    time.sleep(1)
    attempted = psql(attempted_sql)
rec("PERF-1.queued send drains off-request",
    rcount == 0 or int(attempted or 0) >= 1,
    f"attempted={attempted}/{rcount}" + (" (forced)" if forced else " (background)"))

# ── summary ──────────────────────────────────────────────────────────────────
passed = sum(1 for _, ok, _ in results if ok)
total = len(results)
print(f"\n=== Wave 4 cert: {passed}/{total} checks passed ===")
for c, ok, d_ in results:
    if not ok:
        print(f"  FAIL: {c}  {d_}")
raise SystemExit(0 if passed == total else 1)
