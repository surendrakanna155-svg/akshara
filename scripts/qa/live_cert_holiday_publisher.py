#!/usr/bin/env python3
"""Holiday/Event Calendar + Marketing Publisher (Phase 1) — LIVE certification.

Workflow: Principal/Admin creates a holiday/event → AI poster + captions →
preview → principal approval → select destinations → publish only to the selected
channels. Phase-1 destinations: Parent/Student/Teacher/Staff apps (in-ERP via the
communication hub), WhatsApp (deep-link payload), School Website. Facebook/Instagram
are recorded as pending_connection (made real in Phase 2).

Real VPS + real DB + school-scope JWT (minted on edge) + RBAC + real fan-out."""
import json, os, time, subprocess, urllib.request, urllib.error

BASE = "https://akshara.veloraunisexsalon.com"
ORG = "a1000000-0000-4000-8000-000000000001"
USER = "a3000000-0000-4000-8000-000000000001"
SCHOOL_A = "a2000000-0000-4000-8000-000000000001"
SOCK = os.path.expanduser("~/.ssh/akshara-cm.sock")
TITLE = f"CertDiwali_{int(time.time())}"
results = []
created = {"promotion": None, "calendar": None}

def rec(c, l, d=""):
    results.append((c, l, d)); print(f"  [{l:>7}] {c}  {d}")

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
  child_ids: [], session_id: "cert-pub",
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

TEACHER = ["viewAchievementPromotion", "manageAchievementPromotion", "viewSchoolCalendar", "manageSchoolCalendar"]
PRINCIPAL = TEACHER + ["approveAchievementPromotion"]
ALL_DEST = ["parent_app", "student_app", "teacher_app", "staff_app", "whatsapp", "website", "facebook", "instagram"]
print("=== Holiday/Event + Publisher LIVE certification (real VPS / school-JWT / DB / RBAC) ===\n")

s, b = http("GET", "/health")
rec("health", "PASS" if s == 200 and data(b).get("status") == "ok" else "FAIL", f"HTTP {s}")

teacher = mint(TEACHER, role="teacher")
principal = mint(PRINCIPAL, role="principal")
if not teacher or not principal:
    print("\nABORT: token mint failed"); raise SystemExit(1)

try:
    # 1. unauth → 401
    s, _ = http("GET", "/school-calendar")
    rec("rbac:unauth-rejected", "PASS" if s == 401 else "FAIL", f"HTTP {s}")

    # 2. read needs viewSchoolCalendar (no-perm → 403)
    s, _ = http("GET", "/school-calendar", token=mint([], role="teacher"))
    rec("rbac:read-needs-view", "PASS" if s == 403 else "FAIL", f"HTTP {s}")

    # 3. principal/admin creates a holiday (manageSchoolCalendar)
    s, b = http("POST", "/school-calendar", token=teacher,
                body={"eventDate": "2026-11-08", "title": TITLE, "eventType": "festival",
                      "description": "Diwali — school closed, festive greetings."})
    cal = data(b); created["calendar"] = cal.get("id")
    rec("calendar:create", "PASS" if s == 201 and cal.get("eventType") == "festival" else "FAIL",
        f"HTTP {s} id={cal.get('id')}")

    # 4. calendar lists the event
    s, b = http("GET", f"/school-calendar?eventType=festival", token=teacher)
    found = any(e.get("id") == created["calendar"] for e in (data(b).get("items") or []))
    rec("calendar:list", "PASS" if s == 200 and found else "FAIL", f"HTTP {s}")

    # 5. create a publication linked to the holiday (subjectType festival)
    s, b = http("POST", "/promotions", token=teacher,
                body={"subjectType": "festival", "calendarEventId": created["calendar"],
                      "title": TITLE, "description": "Wishing all families a happy Diwali."})
    promo = data(b); created["promotion"] = promo.get("id")
    rec("publisher:create", "PASS" if s == 201 and promo.get("subjectType") == "festival"
        and promo.get("status") == "draft" else "FAIL", f"HTTP {s} status={promo.get('status')}")
    pid = created["promotion"]

    # 6. generate AI poster + captions (subject-aware → festival greeting, not "achievement")
    s, b = http("POST", f"/promotions/{pid}/generate", token=teacher)
    g = data(b); wa = ((g.get("assets") or {}).get("whatsapp") or {}).get("caption", "")
    ok_gen = (s == 200 and g.get("status") == "pending_approval"
              and "Diwali" in wa and "Proud moment" not in wa)
    rec("publisher:generate-subject-aware", "PASS" if ok_gen else "FAIL",
        f"HTTP {s} status={g.get('status')} caption={wa[:48]!r}")

    # 7. publish before approval → blocked (409)
    s, b = http("POST", f"/promotions/{pid}/publish", token=principal, body={"destinations": ["parent_app"]})
    rec("gate:publish-needs-approval", "PASS" if s == 409 and err(b).get("code") == "PROMOTION_NOT_APPROVED"
        else "FAIL", f"HTTP {s} code={err(b).get('code')}")

    # 8. principal-only — teacher cannot approve (403)
    s, _ = http("POST", f"/promotions/{pid}/approve", token=teacher)
    rec("rbac:approve-needs-principal", "PASS" if s == 403 else "FAIL", f"teacher approve HTTP {s}")

    # 9. principal approves
    s, b = http("POST", f"/promotions/{pid}/approve", token=principal)
    rec("approval:principal-approves", "PASS" if s == 200 and data(b).get("status") == "approved"
        else "FAIL", f"HTTP {s} status={data(b).get('status')}")

    # 10. publish with NO destinations → 422
    s, b = http("POST", f"/promotions/{pid}/publish", token=principal, body={"destinations": []})
    rec("publish:requires-destination", "PASS" if s == 422 else "FAIL", f"HTTP {s}")

    # 11. publish to selected destinations → fan-out
    s, b = http("POST", f"/promotions/{pid}/publish", token=principal, body={"destinations": ALL_DEST})
    pub = data(b); pr = pub.get("publishResults") or {}
    ok_pub = s == 200 and pub.get("status") == "published"
    rec("publish:to-selected-channels", "PASS" if ok_pub else "FAIL",
        f"HTTP {s} status={pub.get('status')}")

    # 12. in-ERP delivery (parent/student/teacher/staff apps) actually queued
    app_ok = all((pr.get(c) or {}).get("status") == "sent" for c in
                 ["parent_app", "student_app", "teacher_app", "staff_app"])
    total = sum((pr.get(c) or {}).get("recipientCount", 0) for c in
                ["parent_app", "student_app", "teacher_app", "staff_app"])
    delivered = db(f"select count(*) from notification_deliveries where rendered_subject='{TITLE}'")
    rec("publish:in-erp-delivery", "PASS" if app_ok and delivered.isdigit() and int(delivered) == total
        and total >= 1 else "FAIL", f"results_sent={app_ok} recipientCount={total} deliveries={delivered}")

    # 13. WhatsApp deep-link payload prepared
    rec("publish:whatsapp-deeplink", "PASS" if (pr.get("whatsapp") or {}).get("status") == "ready"
        and (pr.get("whatsapp") or {}).get("shareText") else "FAIL", f"{pr.get('whatsapp')}")

    # 14. School Website post created
    web = db(f"select count(*) from school_website_posts where title='{TITLE}'")
    rec("publish:website-post", "PASS" if (pr.get("website") or {}).get("status") == "published"
        and web == "1" else "FAIL", f"results={pr.get('website')} db_rows={web}")

    # 15. Facebook/Instagram recorded as pending_connection (Phase 2)
    soc_ok = all((pr.get(c) or {}).get("status") == "pending_connection" for c in ["facebook", "instagram"])
    rec("publish:social-pending-phase2", "PASS" if soc_ok else "FAIL",
        f"fb={(pr.get('facebook') or {}).get('status')} ig={(pr.get('instagram') or {}).get('status')}")

    # 16. unauth publish → 401
    s, _ = http("POST", f"/promotions/{pid}/publish", body={"destinations": ["parent_app"]})
    rec("rbac:unauth-publish", "PASS" if s == 401 else "FAIL", f"HTTP {s}")
finally:
    pid = created["promotion"]
    if pid:
        db(f"delete from comm_recipients where broadcast_id in (select id from comm_broadcasts where title='{TITLE}')")
        db(f"delete from comm_broadcasts where title='{TITLE}'")
        db(f"delete from notification_deliveries where rendered_subject='{TITLE}'")
        db(f"delete from school_website_posts where source_promotion_id='{pid}'")
        db(f"delete from audit_events where entity_id='{pid}'")
        db(f"delete from achievement_promotions where id='{pid}'")
    if created["calendar"]:
        db(f"delete from audit_events where entity_id='{created['calendar']}'")
        db(f"delete from school_calendar_events where id='{created['calendar']}'")
    left = db(f"select count(*) from achievement_promotions where title='{TITLE}'")
    left_c = db(f"select count(*) from school_calendar_events where title='{TITLE}'")
    rec("cleanup:rows-removed", "PASS" if left == "0" and left_c == "0" else "FAIL",
        f"promotions={left} calendar={left_c}")

print()
p = sum(1 for _, l, _ in results if l == "PASS")
f = sum(1 for _, l, _ in results if l == "FAIL")
bl = sum(1 for _, l, _ in results if l == "BLOCKED")
print(f"=== {p} PASS / {f} FAIL / {bl} BLOCKED ===")
raise SystemExit(1 if f else 0)
