#!/usr/bin/env python3
"""Firebase Cloud Messaging (HTTP v1) — LIVE certification against the VPS pilot.

Certifies the modern FCM HTTP v1 push stack end-to-end on the real server:
  • device-token registration through the EXISTING Communication Hub routes
    (`/parent|/student/device-tokens/register`) writing to `comm_device_tokens`,
  • RBAC (unauth rejected, mobile/school scope required),
  • the **real service account** mints a Google OAuth token and reaches the FCM
    v1 endpoint — proven by FCM returning INVALID_ARGUMENT for a bogus token
    (an invalid credential would instead return UNAUTHENTICATED),
  • push runs in v1 mode, NOT stub and NOT the retired legacy server-key API,
  • clean teardown.

Real VPS + real DB + school-scope JWT (minted on edge) + real Firebase project."""
import json, os, time, subprocess, urllib.request, urllib.error

BASE = "https://akshara.veloraunisexsalon.com"
ORG = "a1000000-0000-4000-8000-000000000001"
USER = "a3000000-0000-4000-8000-000000000001"
SCHOOL_A = "a2000000-0000-4000-8000-000000000001"
SOCK = os.path.expanduser("~/.ssh/akshara-cm.sock")
TOKEN_P = f"CERTFCM_PARENT_{int(time.time())}"
TOKEN_S = f"CERTFCM_STUDENT_{int(time.time())}"
results = []

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
                       input=stdin, capture_output=True, text=True, timeout=180)
    return p.stdout.strip(), p.stderr.strip()

def db(sql):
    out, _ = ssh(f'docker exec akshara-postgres psql -U supabase_admin -d akshara_db -tAc "{sql}"')
    return out

def data(b): return (b.get("data") or {}) if isinstance(b, dict) else {}

MINT = '''
import { SignJWT } from "npm:jose";
const secret = new TextEncoder().encode(Deno.env.get("JWT_SECRET"));
const t = await new SignJWT({
  tenant_id: Deno.env.get("ORG"), organization_id: Deno.env.get("ORG"),
  school_id: Deno.env.get("SCHOOLID") === "null" ? null : Deno.env.get("SCHOOLID"),
  role: Deno.env.get("ROLE"), role_slugs: [Deno.env.get("ROLE")], primary_role: Deno.env.get("ROLE"),
  permissions: [], permissions_version: 1,
  scope: Deno.env.get("SCOPE"), school_group_id: null, student_id: null,
  child_ids: [], session_id: "cert-fcm",
}).setProtectedHeader({ alg: "HS256", typ: "JWT" })
  .setSubject(Deno.env.get("SUB")).setIssuedAt()
  .setExpirationTime(Math.floor(Date.now() / 1000) + 3600).sign(secret);
console.log(t);
'''

def mint(role, scope, sub=USER, school_id=SCHOOL_A):
    env = (f'-e ORG={ORG} -e SCOPE={scope} -e SCHOOLID={school_id} -e SUB={sub} -e ROLE={role}')
    out, _ = ssh(f"docker exec -i {env} akshara-edge deno run -A -", stdin=MINT)
    tok = out.splitlines()[-1] if out else ""
    return tok if tok.count(".") == 2 else None

# In-container probe: exercise the DEPLOYED v1 client + provider config with the
# real service account env. Proves OAuth mint + v1 endpoint reachability + not-stub.
PROBE = '''
import { fcmV1Configured, fcmProjectId, sendFcmV1 } from "/app/_shared/communication/fcm_v1_client.ts";
import { loadNotificationProviderConfig } from "/app/_shared/communication/notification_provider_config.ts";
const cfg = loadNotificationProviderConfig();
const res = await sendFcmV1({ token: "DUMMY_INVALID_TOKEN_FOR_CERT", title: "cert", body: "cert" });
console.log(JSON.stringify({
  configured: fcmV1Configured(), project: fcmProjectId(),
  pushStub: cfg.push.stubMode, pushConfigured: cfg.push.configured,
  sendSuccess: res.success, error: (res.error || "").slice(0, 300),
}));
'''

def probe():
    out, err = ssh("docker exec -i akshara-edge deno run -A -", stdin=PROBE)
    line = [l for l in out.splitlines() if l.startswith("{")]
    try: return json.loads(line[-1]) if line else {"_raw": out, "_err": err}
    except Exception: return {"_raw": out, "_err": err}

print("=== FCM HTTP v1 push LIVE certification (real VPS / DB / RBAC / Firebase) ===\n")
s, b = http("GET", "/health")
rec("health", "PASS" if s == 200 and data(b).get("status") == "ok" else "FAIL", f"HTTP {s}")

parent = mint("parent", "parent")
student = mint("student", "student", sub="a3000000-0000-4000-8000-000000000002")
if not parent or not student:
    print("\nABORT: token mint failed (is the VPS control socket open?)"); raise SystemExit(1)

try:
    # 1. unauth register → 401
    s, _ = http("POST", "/parent/device-tokens/register", body={"platform": "android", "token": TOKEN_P})
    rec("rbac:unauth-rejected", "PASS" if s == 401 else "FAIL", f"HTTP {s}")

    # 2. wrong scope (organization/director) → 403
    wrong = mint("director", "organization")
    s, _ = http("POST", "/parent/device-tokens/register", token=wrong,
                body={"platform": "android", "token": TOKEN_P})
    rec("rbac:mobile-scope-required", "PASS" if s == 403 else "FAIL", f"HTTP {s}")

    # 3. parent registers an FCM token via the existing route → 201
    s, b = http("POST", "/parent/device-tokens/register", token=parent,
                body={"platform": "android", "token": TOKEN_P})
    rec("register:parent", "PASS" if s == 201 and data(b).get("registered") else "FAIL", f"HTTP {s}")

    # 4. token row persisted in comm_device_tokens (real DB)
    cnt = db(f"select count(*) from comm_device_tokens where token='{TOKEN_P}' and platform='android' and is_active=true")
    rec("register:row-persisted", "PASS" if cnt == "1" else "FAIL", f"rows={cnt}")

    # 5. student registers via the student route → 201
    s, b = http("POST", "/student/device-tokens/register", token=student,
                body={"platform": "ios", "token": TOKEN_S})
    rec("register:student", "PASS" if s == 201 and data(b).get("registered") else "FAIL", f"HTTP {s}")

    # 6. idempotent re-register (ON CONFLICT) → still 201, single row
    http("POST", "/parent/device-tokens/register", token=parent,
         body={"platform": "android", "token": TOKEN_P})
    cnt = db(f"select count(*) from comm_device_tokens where token='{TOKEN_P}'")
    rec("register:idempotent", "PASS" if cnt == "1" else "FAIL", f"rows={cnt}")

    # 7. deployed FCM v1 client is configured with the real service account
    p = probe()
    rec("fcm:configured", "PASS" if p.get("configured") and p.get("project") == "akshara-erp" else "FAIL",
        f"project={p.get('project')}")

    # 8. push runs in v1 mode, NOT stub
    rec("fcm:not-stub", "PASS" if p.get("pushStub") is False and p.get("pushConfigured") is True else "FAIL",
        f"stub={p.get('pushStub')} configured={p.get('pushConfigured')}")

    # 9. real OAuth + v1 endpoint reached: FCM rejects the bogus token with
    #    INVALID_ARGUMENT (an invalid service account would be UNAUTHENTICATED)
    err = p.get("error", "")
    reached = (p.get("sendSuccess") is False and "INVALID_ARGUMENT" in err
               and "UNAUTHENTICATED" not in err and "PERMISSION_DENIED" not in err)
    rec("fcm:v1-endpoint-reached", "PASS" if reached else "FAIL",
        f"send={p.get('sendSuccess')} err={err[:80]}")

    # 10. retired legacy server-key API is gone from the deployed sender
    legacy, _ = ssh("grep -c 'fcm/send' /opt/akshara/functions/_shared/communication/notification_providers.ts || true")
    rec("fcm:legacy-removed", "PASS" if legacy.strip() in ("0", "") else "FAIL", f"legacy_refs={legacy.strip()}")

    # 11. unregister (parent) → 200, row deactivated
    s, _ = http("POST", "/parent/device-tokens/unregister", token=parent, body={"token": TOKEN_P})
    active = db(f"select count(*) from comm_device_tokens where token='{TOKEN_P}' and is_active=true")
    rec("unregister:parent", "PASS" if s == 200 and active == "0" else "FAIL", f"HTTP {s} active={active}")
finally:
    db(f"delete from comm_device_tokens where token in ('{TOKEN_P}','{TOKEN_S}')")
    left = db(f"select count(*) from comm_device_tokens where token in ('{TOKEN_P}','{TOKEN_S}')")
    rec("cleanup:rows-removed", "PASS" if left == "0" else "FAIL", f"remaining={left}")

print()
p_ = sum(1 for _, l, _ in results if l == "PASS")
f_ = sum(1 for _, l, _ in results if l == "FAIL")
print(f"=== {p_} PASS / {f_} FAIL ===")
raise SystemExit(1 if f_ else 0)
