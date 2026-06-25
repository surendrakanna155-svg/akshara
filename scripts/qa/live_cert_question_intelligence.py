#!/usr/bin/env python3
"""Question Intelligence — LIVE certification against the VPS pilot.

The bank-first question-paper subsystem (Batches 8b/8c + corrections): question
bank → deterministic blueprint solver → constrained AI gap-fill (candidates only)
→ submit/review/approve governance → publish gate → single-question corrections,
with principal-only validation (`approveEducation`).

Certifies the real flow: real auth (edge-minted school JWT), real DB persistence,
RBAC (viewEducation/manageEducation/approveEducation + school scope), the
deterministic solver (marks sum exactly, bank-first, no stub text), the syllabus
boundary, the governance lifecycle + publish gate, and the AI gap-fill path
(PASS if real candidates, BLOCKED if safe-fallback — never FAIL). Cleans up.
"""
import json, os, time, subprocess, urllib.request, urllib.error

BASE = "https://akshara.veloraunisexsalon.com"
ORG = "a1000000-0000-4000-8000-000000000001"
USER = "a3000000-0000-4000-8000-000000000001"
SCHOOL_A = "a2000000-0000-4000-8000-000000000001"
SOCK = os.path.expanduser("~/.ssh/akshara-cm.sock")
CERT_SUBJECT = f"CertSubject_{int(time.time())}"
results = []
paper_ids = []

def rec(check, label, detail=""):
    results.append((check, label, detail))
    print(f"  [{label:>7}] {check}  {detail}")

def http(method, path, token=None, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token: req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            raw = r.read().decode()
            try: return r.status, json.loads(raw)
            except: return r.status, raw
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try: return e.code, json.loads(raw)
        except: return e.code, raw
    except Exception as e:
        return 0, str(e)

def ssh(cmd, stdin=None):
    p = subprocess.run(["ssh", "-o", "ControlPath=" + SOCK, "akshara", cmd],
                       input=stdin, capture_output=True, text=True, timeout=120)
    return p.stdout.strip(), p.stderr.strip()

def db(sql):
    out, _ = ssh(f'docker exec akshara-postgres psql -U supabase_admin -d akshara_db -tAc "{sql}"')
    return out

def data(b): return (b.get("data") or {}) if isinstance(b, dict) else {}
def err(b): return (b.get("error") or {}) if isinstance(b, dict) else {}

MINT = '''
import { SignJWT } from "npm:jose";
const secret = new TextEncoder().encode(Deno.env.get("JWT_SECRET"));
const t = await new SignJWT({
  tenant_id: Deno.env.get("ORG"), organization_id: Deno.env.get("ORG"),
  school_id: Deno.env.get("SCHOOLID") === "null" ? null : Deno.env.get("SCHOOLID"),
  role: Deno.env.get("ROLE"), role_slugs: [Deno.env.get("ROLE")], primary_role: Deno.env.get("ROLE"),
  permissions: JSON.parse(Deno.env.get("PERMS")), permissions_version: 1,
  scope: Deno.env.get("SCOPE"), school_group_id: null, student_id: null,
  child_ids: [], session_id: "cert-qi",
}).setProtectedHeader({ alg: "HS256", typ: "JWT" })
  .setSubject(Deno.env.get("SUB")).setIssuedAt()
  .setExpirationTime(Math.floor(Date.now() / 1000) + 3600).sign(secret);
console.log(t);
'''

def mint(perms, role="schoolAdmin", scope="school", school_id=SCHOOL_A, sub=USER):
    env = (f'-e ORG={ORG} -e SCOPE={scope} -e SCHOOLID={school_id} -e SUB={sub} -e ROLE={role} '
           f"-e PERMS='{json.dumps(perms)}'")
    out, _ = ssh(f"docker exec -i {env} akshara-edge deno run -A -", stdin=MINT)
    tok = out.splitlines()[-1] if out else ""
    return tok if tok.count(".") == 2 else None

def gen_body(mix, total, allow_ai, chapters=None):
    return {"academicYearLabel": "2025-2026", "className": "10", "subjectName": CERT_SUBJECT,
            "chapters": chapters if chapters is not None else [], "difficulty": "easy",
            "totalMarks": total, "examType": "unit_test", "questionTypeMix": mix,
            "allowAiGapFill": allow_ai}

TEACHER = ["viewEducation", "manageEducation"]
PRINCIPAL = ["viewEducation", "manageEducation", "approveEducation"]
print("=== Question Intelligence LIVE certification (real VPS / school-JWT / DB / RBAC) ===\n")

s, b = http("GET", "/health")
rec("health", "PASS" if s == 200 and data(b).get("status") == "ok" else "FAIL", f"HTTP {s}")

teacher = mint(TEACHER, role="teacher")
principal = mint(PRINCIPAL, role="principal")
if not teacher or not principal:
    print("\nABORT: could not mint tokens"); raise SystemExit(1)

try:
    # 1. unauthenticated → 401
    s, _ = http("GET", "/education/question-bank")
    rec("rbac:unauth-rejected", "PASS" if s == 401 else "FAIL", f"HTTP {s}")

    # 2. read needs viewEducation (no-perm token → 403)
    no_perm = mint([], role="teacher")
    s, _ = http("GET", "/education/question-bank", token=no_perm)
    rec("rbac:read-needs-view", "PASS" if s == 403 else "FAIL", f"HTTP {s}")

    # 3. school scope required (org-scope token → 403)
    org_tok = mint(PRINCIPAL, role="schoolAdmin", scope="organization", school_id="null")
    s, _ = http("POST", "/education/question-papers/generate", token=org_tok,
                body=gen_body({"short_answer": 5}, 10, False))
    rec("rbac:school-scope-required", "PASS" if s == 403 else "FAIL", f"org-scope HTTP {s}")

    # 4. create 5 approved/active bank items (teacher, manageEducation)
    created_ok = True
    for i in range(5):
        s, b = http("POST", "/education/question-bank", token=teacher, body={
            "subjectName": CERT_SUBJECT, "chapter": "General", "difficulty": "easy",
            "questionType": "short_answer", "marks": 2,
            "questionText": f"Cert Q{i}: define concept number {i} precisely.",
            "answerText": f"Concept {i} is defined as the cert answer {i}.",
        })
        d = data(b)
        if not (s == 201 and d.get("status") == "active" and d.get("reviewStatus") == "approved"):
            created_ok = False
    rec("bank:create-approved-active", "PASS" if created_ok else "FAIL",
        "5 items source=teacher, status=active, reviewStatus=approved")

    # 5. list bank filtered by our subject → finds the 5
    s, b = http("GET", f"/education/question-bank?subjectName={CERT_SUBJECT}&pageSize=50", token=teacher)
    items = data(b).get("items") or []
    rec("bank:list-persisted", "PASS" if s == 200 and len(items) == 5 else "FAIL",
        f"HTTP {s} items={len(items)}")

    # 6. syllabus boundary — a non-syllabus chapter is rejected (422 OFF_SYLLABUS)
    s, b = http("POST", "/education/question-papers/generate", token=teacher,
                body=gen_body({"short_answer": 5}, 10, False, chapters=["Imaginary Off-Syllabus Chapter"]))
    rec("syllabus:off-syllabus-rejected", "PASS" if s == 422 and err(b).get("code") == "OFF_SYLLABUS"
        else "FAIL", f"HTTP {s} code={err(b).get('code')}")

    # 7. deterministic bank-first paper (no AI), marks sum EXACTLY, no gaps/stubs
    s, b = http("POST", "/education/question-papers/generate", token=teacher,
                body=gen_body({"short_answer": 5}, 10, False))
    d = data(b)
    p1 = d.get("paper") or {}
    if p1.get("id"): paper_ids.append(p1["id"])
    p1_items = d.get("items") or []
    marks_sum = sum((it.get("marks") or 0) for it in p1_items)
    ok_gen = (s == 201 and d.get("bankReuseCount") == 5 and d.get("unfilledGapCount") == 0
              and d.get("aiCandidateCount") == 0 and marks_sum == 10
              and p1.get("reviewStatus") == "draft"
              and all(it.get("source") == "bank" for it in p1_items))
    rec("solver:bank-first-exact", "PASS" if ok_gen else "FAIL",
        f"HTTP {s} reuse={d.get('bankReuseCount')} gaps={d.get('unfilledGapCount')} "
        f"marks={marks_sum} status={p1.get('reviewStatus')}")
    p1_id = p1.get("id")

    # 8. submit (teacher) → submitted
    s, b = http("POST", f"/education/question-papers/{p1_id}/submit", token=teacher)
    rec("governance:submit", "PASS" if s == 200 and data(b).get("paper", {}).get("reviewStatus") == "submitted"
        else "FAIL", f"HTTP {s} status={data(b).get('paper', {}).get('reviewStatus')}")

    # 9. publish gate — submitted-but-not-approved is blocked (409 PAPER_NOT_APPROVED)
    s, b = http("POST", f"/education/question-papers/{p1_id}/publish", token=principal)
    rec("gate:publish-needs-approval", "PASS" if s == 409 and err(b).get("code") == "PAPER_NOT_APPROVED"
        else "FAIL", f"HTTP {s} code={err(b).get('code')}")

    # 10. principal-only — teacher cannot review (403)
    s, _ = http("POST", f"/education/question-papers/{p1_id}/review", token=teacher,
                body={"decision": "approved"})
    rec("rbac:review-needs-approve", "PASS" if s == 403 else "FAIL", f"teacher review HTTP {s}")

    # 11. principal approves
    s, b = http("POST", f"/education/question-papers/{p1_id}/review", token=principal,
                body={"decision": "approved", "comments": "cert ok"})
    rec("governance:principal-approves", "PASS" if s == 200 and data(b).get("paper", {}).get("reviewStatus") == "approved"
        else "FAIL", f"HTTP {s} status={data(b).get('paper', {}).get('reviewStatus')}")

    # 12. principal publishes
    s, b = http("POST", f"/education/question-papers/{p1_id}/publish", token=principal)
    rec("governance:publish", "PASS" if s == 200 and data(b).get("reviewStatus") == "published"
        else "FAIL", f"HTTP {s} status={data(b).get('reviewStatus')}")

    # 13. published paper is locked to edits (409 PAPER_NOT_EDITABLE)
    if p1_items:
        s, b = http("PUT", f"/education/question-papers/{p1_id}/items/{p1_items[0]['id']}", token=teacher,
                    body={"questionText": "tamper"})
        rec("correction:published-locked", "PASS" if s == 409 and err(b).get("code") == "PAPER_NOT_EDITABLE"
            else "FAIL", f"HTTP {s} code={err(b).get('code')}")

    # 14. correction (A) — editing an APPROVED paper resets it to draft
    s, b = http("POST", "/education/question-papers/generate", token=teacher,
                body=gen_body({"short_answer": 5}, 10, False))
    p2 = data(b).get("paper") or {}
    p2_id = p2.get("id"); p2_items = data(b).get("items") or []
    if p2_id: paper_ids.append(p2_id)
    http("POST", f"/education/question-papers/{p2_id}/submit", token=teacher)
    http("POST", f"/education/question-papers/{p2_id}/review", token=principal, body={"decision": "approved"})
    s, b = http("PUT", f"/education/question-papers/{p2_id}/items/{p2_items[0]['id']}", token=teacher,
                body={"questionText": "Corrected cert question text.", "marks": 2})
    # paper should now be back to draft
    s2, b2 = http("GET", f"/education/question-papers/{p2_id}", token=teacher)
    rec("correction:edit-resets-approval", "PASS" if s == 200 and data(b2).get("paper", {}).get("reviewStatus") == "draft"
        else "FAIL", f"edit HTTP {s} -> status={data(b2).get('paper', {}).get('reviewStatus')}")

    # 15. AI gap-fill path — a slot the bank can't fill → AI candidate (pending) or honest gap
    s, b = http("POST", "/education/question-papers/generate", token=teacher,
                body=gen_body({"long_answer": 1}, 5, True))
    d = data(b)
    p3 = d.get("paper") or {}
    p3_id = p3.get("id"); p3_items = d.get("items") or []
    if p3_id: paper_ids.append(p3_id)
    ai_count = d.get("aiCandidateCount") or 0
    gap_count = d.get("unfilledGapCount") or 0
    if s == 201 and ai_count >= 1:
        rec("ai:gapfill-candidate", "PASS", f"aiCandidateCount={ai_count} (real AI, pending moderation)")
        # publish gate: a pending AI candidate blocks publish (409 PAPER_HAS_PENDING_ITEMS)
        s2, b2 = http("POST", f"/education/question-papers/{p3_id}/publish", token=principal)
        rec("gate:pending-ai-blocks-publish", "PASS" if s2 == 409 and err(b2).get("code") == "PAPER_HAS_PENDING_ITEMS"
            else "FAIL", f"HTTP {s2} code={err(b2).get('code')}")
        # moderate the pending candidate (reject) → no longer blocks
        cand = next((it for it in p3_items if it.get("source") == "ai_candidate"), None)
        if cand:
            s3, _ = http("POST", f"/education/question-papers/{p3_id}/items/{cand['id']}/moderate",
                         token=teacher, body={"decision": "rejected"})
            rec("ai:moderate-candidate", "PASS" if s3 == 200 else "FAIL", f"HTTP {s3}")
        else:
            rec("ai:moderate-candidate", "FAIL", "candidate item not in response")
    elif s == 201 and ai_count == 0:
        # safe-by-default: no stub written, gap reported honestly
        rec("ai:gapfill-candidate", "BLOCKED", f"AI unavailable — gap reported (unfilledGapCount={gap_count}), no stub")
        rec("gate:pending-ai-blocks-publish", "BLOCKED", "no AI candidate to gate on")
        rec("ai:moderate-candidate", "BLOCKED", "no AI candidate to moderate")
        no_stub = all(it.get("source") in ("bank",) for it in p3_items)
        rec("ai:no-stub-fabrication", "PASS" if no_stub and gap_count >= 1 else "FAIL",
            f"items all bank, gaps={gap_count}")
    else:
        rec("ai:gapfill-candidate", "FAIL", f"HTTP {s}")

    # 16. audit rows written for paper generation/publish (matched by paper entity_id)
    if paper_ids:
        id_list = ",".join("'" + pid + "'" for pid in paper_ids)
        a = db("select count(*) from audit_events where entity_id in (" + id_list + ")")
    else:
        a = "0"
    rec("audit:education-events", "PASS" if a and a.isdigit() and int(a) >= 1 else "FAIL", f"rows={a}")
finally:
    # cleanup via supabase_admin (bypasses RLS + the missing erp_tenant DELETE grant)
    if paper_ids:
        ids = ",".join("'" + pid + "'" for pid in paper_ids)
        db(f"delete from edu_question_paper_reviews where paper_id in ({ids})")
        db(f"delete from edu_question_paper_items where paper_id in ({ids})")
        db(f"delete from audit_events where entity_id in ({ids})")
        db(f"delete from edu_question_papers where id in ({ids})")
    db(f"delete from edu_question_bank_items where subject_name='{CERT_SUBJECT}'")
    left_p = db(f"select count(*) from edu_question_papers where subject_name='{CERT_SUBJECT}'")
    left_b = db(f"select count(*) from edu_question_bank_items where subject_name='{CERT_SUBJECT}'")
    rec("cleanup:rows-removed", "PASS" if left_p == "0" and left_b == "0" else "FAIL",
        f"papers={left_p} bank={left_b}")

print()
p = sum(1 for _, l, _ in results if l == "PASS")
f = sum(1 for _, l, _ in results if l == "FAIL")
bl = sum(1 for _, l, _ in results if l == "BLOCKED")
print(f"=== {p} PASS / {f} FAIL / {bl} BLOCKED ===")
raise SystemExit(1 if f else 0)
