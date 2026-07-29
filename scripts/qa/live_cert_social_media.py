#!/usr/bin/env python3
"""Social Media Integration (Phase 2) — LIVE certification against the VPS pilot.

Certifies everything buildable WITHOUT real Meta credentials (the server is in
dry-run until the owner sets META_APP_ID/SECRET and completes Meta App Review):
RBAC on connect/list/disconnect, AES-GCM **encrypted** token storage, OAuth login
URL with the required publish scopes, and the publisher posting to Facebook/Instagram
via the connected account (dry-run records the exact Graph request) vs
`pending_connection` when no account is linked.

Real VPS + real DB + school-scope JWT (minted on edge) + RBAC + encrypted tokens."""
import json, os, time, subprocess, urllib.request, urllib.error

BASE = os.environ.get("API_BASE_URL", "https://api.nikshaos.in")
ORG = "a1000000-0000-4000-8000-000000000001"
USER = "a3000000-0000-4000-8000-000000000001"
SCHOOL_A = "a2000000-0000-4000-8000-000000000001"
SOCK = os.path.expanduser("~/.ssh/akshara-cm.sock")
TITLE = f"CertSocial_{int(time.time())}"
results = []
promo_ids = []

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
  child_ids: [], session_id: "cert-soc",
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

# perms: include publisher perms to drive an end-to-end publish to social
TEACHER = ["viewSocialConnections", "manageSocialConnections",
           "viewAchievementPromotion", "manageAchievementPromotion"]
PRINCIPAL = TEACHER + ["approveAchievementPromotion"]

def publish_promo(principal, dests):
    s, b = http("POST", "/promotions", token=principal,
                body={"subjectType": "festival", "title": TITLE, "description": "social cert"})
    pid = data(b).get("id"); promo_ids.append(pid)
    http("POST", f"/promotions/{pid}/generate", token=principal)
    http("POST", f"/promotions/{pid}/approve", token=principal)
    s, b = http("POST", f"/promotions/{pid}/publish", token=principal, body={"destinations": dests})
    return data(b).get("publishResults") or {}

print("=== Social Media Integration (Phase 2) LIVE certification (real VPS / DB / RBAC / encryption) ===\n")
s, b = http("GET", "/health")
rec("health", "PASS" if s == 200 and data(b).get("status") == "ok" else "FAIL", f"HTTP {s}")

teacher = mint(TEACHER, role="teacher")
principal = mint(PRINCIPAL, role="principal")
if not teacher or not principal:
    print("\nABORT: token mint failed (is the VPS control socket open?)"); raise SystemExit(1)

try:
    # 1. unauth → 401
    s, _ = http("GET", "/social/connections")
    rec("rbac:unauth-rejected", "PASS" if s == 401 else "FAIL", f"HTTP {s}")

    # 2. read needs viewSocialConnections (no-perm → 403)
    s, _ = http("GET", "/social/connections", token=mint([], role="teacher"))
    rec("rbac:read-needs-view", "PASS" if s == 403 else "FAIL", f"HTTP {s}")

    # 3. connect/start returns an OAuth login URL with the publish scopes
    s, b = http("POST", "/social/connect/start", token=teacher, body={})
    d = data(b)
    ok_start = (s == 200 and "instagram_content_publish" in (d.get("loginUrl") or "")
                and d.get("encryptionConfigured") is True)
    rec("oauth:login-url-scopes", "PASS" if ok_start else "FAIL",
        f"HTTP {s} dryRun={d.get('dryRun')} encConfigured={d.get('encryptionConfigured')}")

    # 4. connect needs manage (view-only token → 403)
    s, _ = http("POST", "/social/connect/start", token=mint(["viewSocialConnections"], role="teacher"), body={})
    rec("rbac:connect-needs-manage", "PASS" if s == 403 else "FAIL", f"HTTP {s}")

    # 5. connect/complete stores a connection (dry-run demo) with an ENCRYPTED token
    s, b = http("POST", "/social/connect/complete", token=teacher, body={})
    conns = data(b).get("connections") or []
    conn_id = conns[0].get("id") if conns else None
    rec("connect:stores-connection", "PASS" if s == 201 and conn_id else "FAIL",
        f"HTTP {s} connections={len(conns)}")

    # 6. token is encrypted at rest (no plaintext 'DRYRUN_PAGE_TOKEN' in the column)
    enc = db(f"select left(encrypted_page_token,0)||case when encrypted_page_token like '%DRYRUN_PAGE_TOKEN%' then 'PLAIN' else 'ENC' end from social_media_connections where id='{conn_id}'") if conn_id else ""
    rec("security:token-encrypted-at-rest", "PASS" if enc == "ENC" else "FAIL", f"stored={enc}")

    # 7. list shows the connection without exposing the token
    s, b = http("GET", "/social/connections", token=teacher)
    items = data(b).get("items") or []
    has_token_field = any("encrypted_page_token" in (it or {}) or "token" in (it or {}) for it in items)
    rec("connections:list-no-token", "PASS" if s == 200 and items and not has_token_field else "FAIL",
        f"HTTP {s} items={len(items)}")

    # 8. publisher posts to FB/IG via the connected account → dry_run (records the Graph request)
    pr = publish_promo(principal, ["facebook", "instagram"])
    fb, ig = pr.get("facebook") or {}, pr.get("instagram") or {}
    ok_pub = fb.get("status") == "dry_run" and ig.get("status") == "dry_run" and fb.get("request")
    rec("publish:via-connection-dryrun", "PASS" if ok_pub else "FAIL",
        f"fb={fb.get('status')} ig={ig.get('status')}")

    # 9. disconnect removes the connection
    s, _ = http("DELETE", f"/social/connections/{conn_id}", token=teacher)
    rec("connect:disconnect", "PASS" if s == 200 else "FAIL", f"HTTP {s}")

    # 10. with no connection, FB/IG fall back to pending_connection
    pr2 = publish_promo(principal, ["facebook", "instagram"])
    ok_pending = (pr2.get("facebook") or {}).get("status") == "pending_connection"
    rec("publish:pending-without-connection", "PASS" if ok_pending else "FAIL",
        f"fb={(pr2.get('facebook') or {}).get('status')}")

    # 11. unauth disconnect → 401
    s, _ = http("DELETE", f"/social/connections/{conn_id}")
    rec("rbac:unauth-disconnect", "PASS" if s == 401 else "FAIL", f"HTTP {s}")
finally:
    for pid in promo_ids:
        if pid:
            db(f"delete from comm_recipients where broadcast_id in (select id from comm_broadcasts where title='{TITLE}')")
            db(f"delete from comm_broadcasts where title='{TITLE}'")
            db(f"delete from notification_deliveries where rendered_subject='{TITLE}'")
            db(f"delete from school_website_posts where source_promotion_id='{pid}'")
            db(f"delete from audit_events where entity_id='{pid}'")
            db(f"delete from achievement_promotions where id='{pid}'")
    db(f"delete from social_media_connections where school_id='{SCHOOL_A}' and page_name like 'Demo School Page%'")
    left = db(f"select count(*) from achievement_promotions where title='{TITLE}'")
    left_s = db(f"select count(*) from social_media_connections where page_name like 'Demo School Page%'")
    rec("cleanup:rows-removed", "PASS" if left == "0" and left_s == "0" else "FAIL",
        f"promotions={left} connections={left_s}")

print()
p = sum(1 for _, l, _ in results if l == "PASS")
f = sum(1 for _, l, _ in results if l == "FAIL")
print(f"=== {p} PASS / {f} FAIL ===")
raise SystemExit(1 if f else 0)
