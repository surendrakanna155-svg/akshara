#!/usr/bin/env python3
"""Live-mode certification for **Red Team Wave 3 — Session & Authorization
Enforcement** against the live VPS pilot. Real VPS + edge-minted scoped JWTs
(HS256 with the live JWT_SECRET, referencing REAL session rows + the LIVE
membership permissions_version) + real Postgres + real RBAC gates.

Source of truth: docs/RED_TEAM_MASTER_TRACKER.md (RT-16..RT-23).

Proves on the LIVE deployment, post-deploy:
  RT-16  Session revocation — a valid token works (200); after the session is
         revoked (logout), the SAME token is rejected 401 on the next request.
  RT-17  RBAC freshness — a valid token works; after the membership's
         permissions_version is bumped (demotion), the SAME token is rejected
         401 (PERMISSIONS_STALE). Version is restored so the DB is unchanged.
  RT-18  Entitlement enforcement — ENTITLEMENT_ENFORCEMENT=true on akshara-edge
         (deploy-precondition).
  RT-19  Payment authz — initiate/confirm reject a non-parent (school) scope 403;
         a parent scope passes the gate (not 403).
  RT-20  Approval cancel authz — a school user WITHOUT approval authority cannot
         cancel a real pending approval (403); a manager (manageManagement) can.
  RT-21  Audit ingestion — a parent (relationship) scope is rejected 403; a staff
         (school) scope ingests a batch (200).
  RT-22  View-slug writes — promotions/track, parent-meeting-summary, and
         approvals/audit each reject a view-only token (403) and admit a
         manage-tier token (not 403).
  RT-23  Webhook fail-closed — a forged Razorpay signature is rejected 403 even
         in stub mode (was accepted before).

Every fixture (sessions, approval, audit_events) uses dedicated `cf3…`/UUID ids
and is cleaned up. Re-runnable; the live DB is left unchanged.
"""
import json, os, subprocess, time, uuid

BASE = os.environ.get("API_BASE_URL", "https://api.nikshaos.in")
ORG = "a1000000-0000-4000-8000-000000000001"
USER = "a3000000-0000-4000-8000-000000000001"        # schoolAdmin in SCHOOL_A (version 2)
SCHOOL_A = "a2000000-0000-4000-8000-000000000001"
STUDENT_A = "a4000000-0000-4000-8000-000000000001"
GUARDIAN_A = "a3000000-0000-4000-8000-000000000003"  # active guardian of STUDENT_A
SOCK = os.path.expanduser("~/.ssh/akshara-cm.sock")
TS = str(int(time.time()))

# Dedicated fixtures (cleaned up at the end).
APPROVAL_ID = "cf300000-0000-4000-8000-000000000001"
seeded_sessions: list[str] = []

results = []


def rec(check, ok, detail=""):
    results.append((check, bool(ok), detail))
    print(f"  [{'PASS' if ok else 'FAIL':>4}] {check}  {detail}")


def http(method, path, token=None, body=None, headers=None):
    payload = json.dumps(body).encode() if body is not None else None
    import urllib.request, urllib.error
    req = urllib.request.Request(BASE + path, data=payload, method=method)
    if body is not None:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=90) as r:
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


def ssh(cmd, stdin=None):
    p = subprocess.run(["ssh", "-o", "ControlPath=" + SOCK, "akshara", cmd],
                       input=stdin, capture_output=True, text=True, timeout=90)
    return p.stdout.strip(), p.stderr.strip()


def db(sql):
    out, _ = ssh(
        'docker exec akshara-postgres psql -U supabase_admin -d akshara_db -tAc "'
        + sql.replace('"', '\\"') + '"')
    return out.strip()


def d(b):
    return (b.get("data") or {}) if isinstance(b, dict) else {}


def code(b):
    return (b.get("error") or {}).get("code") if isinstance(b, dict) else None


MINT = '''
import { SignJWT } from "npm:jose";
const secret = new TextEncoder().encode(Deno.env.get("JWT_SECRET"));
const t = await new SignJWT({
  tenant_id: Deno.env.get("ORG"), organization_id: Deno.env.get("ORG"),
  school_id: Deno.env.get("SCHOOL") || null,
  role: Deno.env.get("ROLE"), role_slugs: [Deno.env.get("ROLE")], primary_role: Deno.env.get("ROLE"),
  permissions: JSON.parse(Deno.env.get("PERMS")),
  permissions_version: parseInt(Deno.env.get("VERSION") || "1", 10),
  scope: Deno.env.get("SCOPE") || "school", school_group_id: null,
  student_id: Deno.env.get("STUDENT_ID") || null,
  child_ids: JSON.parse(Deno.env.get("CHILD_IDS") || "[]"),
  session_id: Deno.env.get("SESSION_ID"),
}).setProtectedHeader({ alg: "HS256", typ: "JWT" })
  .setSubject(Deno.env.get("SUB")).setIssuedAt()
  .setExpirationTime(Math.floor(Date.now() / 1000) + 3600).sign(secret);
console.log(t);
'''


def seed_session(sub, scope, school):
    """Insert a real, live (non-revoked) sessions row and return its id."""
    sid = str(uuid.uuid4())
    db(f"INSERT INTO sessions (id, user_id, tenant_id, scope, context_school_id) "
       f"VALUES ('{sid}','{sub}','{ORG}','{scope}',{('NULL' if not school else chr(39)+school+chr(39))})")
    seeded_sessions.append(sid)
    return sid


def live_version(sub, school):
    v = db(f"SELECT permissions_version FROM school_memberships "
           f"WHERE user_id='{sub}' AND school_id='{school}' AND status='active' LIMIT 1")
    return v if v else "1"


def mint(perms, role="schoolAdmin", sub=USER, school=SCHOOL_A, scope="school",
         version=None, session_id=None, child_ids=None, student_id=None):
    if session_id is None:
        session_id = seed_session(sub, scope, school)
    if version is None:
        version = live_version(sub, school) if scope == "school" else "1"
    env = (f"-e ORG={ORG} -e SUB={sub} -e ROLE={role} -e SCHOOL={school or ''} "
           f"-e SCOPE={scope} -e VERSION={version} -e SESSION_ID={session_id} "
           f"-e STUDENT_ID={student_id or ''} -e CHILD_IDS='{json.dumps(child_ids or [])}' "
           f"-e PERMS='{json.dumps(perms)}'")
    out, _ = ssh(f"docker exec -i {env} akshara-edge deno run -A -", stdin=MINT)
    tok = out.splitlines()[-1] if out else ""
    return (tok, session_id) if tok.count(".") == 2 else (None, session_id)


def cleanup():
    for sid in seeded_sessions:
        db(f"DELETE FROM sessions WHERE id='{sid}'")
    db(f"DELETE FROM approval_audit_entries WHERE approval_request_id='{APPROVAL_ID}'")
    db(f"DELETE FROM approval_requests WHERE id='{APPROVAL_ID}'")
    db(f"DELETE FROM audit_events WHERE client_event_id LIKE 'cf3-rtw3-%'")
    db(f"DELETE FROM payment_intents WHERE idempotency_key LIKE 'cf3-rtw3-%'")
    # restore the cert user's membership version in case a probe left it bumped
    db(f"UPDATE school_memberships SET permissions_version=2 "
       f"WHERE user_id='{USER}' AND school_id='{SCHOOL_A}' AND permissions_version<>2")


print("=== Red Team Wave 3 LIVE certification (real VPS / scoped JWTs / sessions / RBAC) ===\n")

s, b = http("GET", "/health")
rec("health", s == 200 and d(b).get("status") == "ok", f"HTTP {s}")

who = db("SELECT current_user")
rec("live DB reachable via control socket", who == "supabase_admin", f"current_user={who}")

cleanup()  # start clean

# ── RT-18: entitlement enforcement on (deploy precondition) ──────────────────
print("\n-- RT-18 entitlement enforcement flag (deploy precondition) --")
ent, _ = ssh("docker exec akshara-edge printenv ENTITLEMENT_ENFORCEMENT")
rec("RT-18 ENTITLEMENT_ENFORCEMENT=true on akshara-edge", ent.strip() == "true", f"flag={ent.strip()!r}")

# ── RT-16: session revocation kills the token immediately ────────────────────
print("\n-- RT-16 session revocation (logout) blocks the old token immediately --")
admin_tok, admin_sid = mint(["viewManagement", "manageManagement"])
rec("minted live schoolAdmin token (real session + live version)", bool(admin_tok),
    f"session={admin_sid[:8]}")
s, _ = http("GET", "/approvals/pending", token=admin_tok)
rec("RT-16 valid token reaches a protected endpoint (200)", s == 200, f"HTTP {s}")
db(f"UPDATE sessions SET revoked_at=now() WHERE id='{admin_sid}'")
s, b = http("GET", "/approvals/pending", token=admin_tok)
rec("RT-16 after revoke, SAME token is rejected (401)", s == 401, f"HTTP {s} code={code(b)}")

# ── RT-17: permissions_version bump (demotion) blocks the old token ──────────
print("\n-- RT-17 RBAC freshness: stale permissions_version is rejected --")
rbac_tok, rbac_sid = mint(["viewManagement", "manageManagement"])
s, _ = http("GET", "/approvals/pending", token=rbac_tok)
rec("RT-17 token at live version works (200)", s == 200, f"HTTP {s}")
db(f"UPDATE school_memberships SET permissions_version=permissions_version+1 "
   f"WHERE user_id='{USER}' AND school_id='{SCHOOL_A}'")
s, b = http("GET", "/approvals/pending", token=rbac_tok)
rec("RT-17 after version bump, SAME token is rejected (401 PERMISSIONS_STALE)",
    s == 401 and code(b) == "PERMISSIONS_STALE", f"HTTP {s} code={code(b)}")
# a freshly-minted token at the NEW version works again
fresh_tok, _ = mint(["viewManagement", "manageManagement"],
                    version=str(int(live_version(USER, SCHOOL_A))))
s, _ = http("GET", "/approvals/pending", token=fresh_tok)
rec("RT-17 fresh token at the new version works (200)", s == 200, f"HTTP {s}")
db(f"UPDATE school_memberships SET permissions_version=2 "
   f"WHERE user_id='{USER}' AND school_id='{SCHOOL_A}'")  # restore

# ── RT-19: payment initiate/confirm scope gate ───────────────────────────────
print("\n-- RT-19 payment intents require parent scope --")
school_pay_tok, _ = mint(["manageFinance", "viewFinance"])
s, b = http("POST", "/payments/intents/initiate", token=school_pay_tok,
            body={"installment_id": "x", "amount": 100})
rec("RT-19 school scope rejected on initiate (403)", s == 403, f"HTTP {s} code={code(b)}")
s, b = http("POST", "/payments/intents/confirm", token=school_pay_tok,
            body={"payment_intent_id": "x"})
rec("RT-19 school scope rejected on confirm (403)", s == 403, f"HTTP {s} code={code(b)}")
parent_pay_tok, _ = mint([], role="parent", sub=GUARDIAN_A, scope="parent",
                         child_ids=[STUDENT_A])
s, b = http("POST", "/payments/intents/initiate", token=parent_pay_tok,
            body={"installment_id": "x", "amount": 100},
            headers={"Idempotency-Key": f"cf3-rtw3-pay-{TS}"})
rec("RT-19 parent scope passes the authz gate (not 403)", s != 403 and s != 0,
    f"HTTP {s} code={code(b)}")

# ── RT-20: approval cancel authorization ─────────────────────────────────────
print("\n-- RT-20 approval cancel requires approval authority --")
db(f"INSERT INTO approval_requests (id, organization_id, school_id, type, status, title, "
   f"summary, requester_id, requester_name, entity_type, entity_id, payload) "
   f"VALUES ('{APPROVAL_ID}','{ORG}','{SCHOOL_A}','staffLeave','pending','Cert RTW3', "
   f"'cert','someone-else','Someone','staffLeave','{APPROVAL_ID}','{{}}'::jsonb)")
lowpriv_tok, _ = mint(["viewManagement"])  # school scope, NO approve/manage authority, not requester
s, b = http("POST", f"/approvals/{APPROVAL_ID}/cancel", token=lowpriv_tok,
            body={"comment": "x"})
rec("RT-20 non-approver cannot cancel a pending approval (403)", s == 403,
    f"HTTP {s} code={code(b)}")
still_pending = db(f"SELECT status FROM approval_requests WHERE id='{APPROVAL_ID}'")
rec("RT-20 approval is still pending after the blocked cancel", still_pending == "pending",
    f"status={still_pending}")
mgr_tok, _ = mint(["viewManagement", "manageManagement"])
s, b = http("POST", f"/approvals/{APPROVAL_ID}/cancel", token=mgr_tok, body={"comment": "ok"})
rec("RT-20 a manager (manageManagement) can cancel (200)", s == 200, f"HTTP {s} code={code(b)}")

# ── RT-21: audit ingestion requires staff scope ──────────────────────────────
print("\n-- RT-21 audit batch ingestion requires a staff scope --")
parent_audit_tok, _ = mint([], role="parent", sub=GUARDIAN_A, scope="parent",
                           child_ids=[STUDENT_A])
ev = {"id": f"cf3-rtw3-{TS}-1", "type": "test.event", "timestamp": "2026-06-27T00:00:00Z",
      "category": "system"}
s, b = http("POST", "/audit/events/batch", token=parent_audit_tok, body={"events": [ev]})
rec("RT-21 parent (relationship) scope rejected from audit ingestion (403)", s == 403,
    f"HTTP {s} code={code(b)}")
staff_audit_tok, _ = mint(["viewManagement"])
ev2 = {"id": f"cf3-rtw3-{TS}-2", "type": "test.event", "timestamp": "2026-06-27T00:00:00Z",
       "category": "system"}
s, b = http("POST", "/audit/events/batch", token=staff_audit_tok, body={"events": [ev2]})
rec("RT-21 staff (school) scope ingests a batch (200)",
    s == 200 and d(b).get("acceptedCount") == 1, f"HTTP {s} accepted={d(b).get('acceptedCount')}")

# ── RT-22: view-slug write gates now require manage slugs ─────────────────────
print("\n-- RT-22 write-via-view-slug routes now require manage slugs --")
# (1) promotions/track
view_promo_tok, _ = mint(["viewAchievementPromotion"])
s, b = http("POST", f"/promotions/{uuid.uuid4()}/track", token=view_promo_tok,
            body={"metric": "views"})
rec("RT-22 promotions/track rejects a view-only token (403)", s == 403, f"HTTP {s} code={code(b)}")
manage_promo_tok, _ = mint(["manageAchievementPromotion"])
s, b = http("POST", f"/promotions/{uuid.uuid4()}/track", token=manage_promo_tok,
            body={"metric": "views"})
rec("RT-22 promotions/track admits a manage token (not 403)", s != 403, f"HTTP {s} code={code(b)}")
# (2) parent-meeting-summary
view_te_tok, _ = mint(["viewTeacherEffectiveness"])
s, b = http("POST", "/intelligence/teacher-effectiveness/parent-meeting-summary",
            token=view_te_tok, body={})
rec("RT-22 parent-meeting-summary rejects a view-only token (403)", s == 403,
    f"HTTP {s} code={code(b)}")
manage_te_tok, _ = mint(["manageLessonLogs"])
s, b = http("POST", "/intelligence/teacher-effectiveness/parent-meeting-summary",
            token=manage_te_tok, body={})
rec("RT-22 parent-meeting-summary admits a manage token (not 403)", s != 403,
    f"HTTP {s} code={code(b)}")
# (3) approvals/audit (record)
view_mgmt_tok, _ = mint(["viewManagement"])
s, b = http("POST", "/approvals/audit", token=view_mgmt_tok,
            body={"approval_request_id": APPROVAL_ID, "action": "submitted",
                  "actor_id": "x", "actor_name": "x"})
rec("RT-22 approvals/audit rejects a view-only token (403)", s == 403, f"HTTP {s} code={code(b)}")
manage_mgmt_tok, _ = mint(["manageManagement"])
s, b = http("POST", "/approvals/audit", token=manage_mgmt_tok,
            body={})  # missing fields → 422 proves it passed authz
rec("RT-22 approvals/audit admits a manage token (not 403)", s != 403, f"HTTP {s} code={code(b)}")

# ── RT-23: webhook signature fail-closed ─────────────────────────────────────
print("\n-- RT-23 forged Razorpay webhook signature is rejected (fail-closed) --")
s, b = http("POST", "/webhooks/razorpay",
            body={"id": "evt_forged", "event": "payment.captured", "payload": {}},
            headers={"X-Razorpay-Signature": "forged_bad_signature"})
rec("RT-23 forged webhook signature rejected (403)", s == 403, f"HTTP {s} code={code(b)}")

cleanup()
passed = sum(1 for _, ok, _ in results if ok)
total = len(results)
print(f"\n=== Red Team Wave 3: {passed}/{total} checks passed ===")
for c, ok, det in results:
    if not ok:
        print(f"  FAIL: {c}  {det}")
raise SystemExit(0 if passed == total else 1)
