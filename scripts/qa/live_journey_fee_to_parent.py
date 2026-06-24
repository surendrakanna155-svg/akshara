#!/usr/bin/env python3
"""A4 cross-persona spine journey (live VPS): admin records a fee collection ->
parent sees the new receipt. Proves the write-by-staff -> visible-to-parent loop
end to end, then restores by cancelling the collection."""
import json, urllib.request, urllib.error, sys
BASE = "https://akshara.veloraunisexsalon.com"
SCHOOL = "a2000000-0000-4000-8000-000000000001"
ADMIN, PARENT = "+919876543210", "+919876543211"
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

def items(b):
    d = b.get("data") if isinstance(b, dict) else b
    if isinstance(d, dict):
        for k in ("items", "receipts", "collections", "invoices"):
            if isinstance(d.get(k), list): return d[k]
    return d if isinstance(d, list) else []

admin, parent = login(ADMIN), login(PARENT)
print("=== A4 journey: fee collection (admin) -> receipt visible to parent ===")
rec("admin login", bool(admin)); rec("parent login", bool(parent))

# 1. admin reads invoices, find one with outstanding > 0
s, b = http("GET", "/finance/invoices", admin)
rec("admin GET /finance/invoices", s == 200, f"HTTP {s}")
inv = next((i for i in items(b) if float(i.get("outstandingAmount", i.get("outstanding_amount", 0)) or 0) > 0), None)
if not inv: inv = (items(b) or [None])[0]
inv_id = inv.get("id") if inv else None
print(f"  invoice: {inv_id} outstanding={inv.get('outstandingAmount', inv.get('outstanding_amount')) if inv else None}")

# 2. parent baseline receipts
s, b = http("GET", "/parent/receipts", parent); base = len(items(b))
rec("parent GET /parent/receipts (baseline)", s == 200, f"HTTP {s} count={base}")

# 3. admin records a small collection -> creates a receipt
coll_id = None
if inv_id:
    s, b = http("POST", "/finance/collections", admin,
                {"invoiceId": inv_id, "amountCollected": 500, "paymentMethod": "cash"})
    d = b.get("data", {}) if isinstance(b, dict) else {}
    coll_id = (d.get("collection") or {}).get("id") or d.get("collectionId") or d.get("id")
    rec("admin POST /finance/collections", s in (200, 201), f"HTTP {s} collection={coll_id}")
else:
    rec("admin POST /finance/collections", False, "no invoice available")

# 4. parent sees the new receipt (the cross-persona assertion)
s, b = http("GET", "/parent/receipts", parent); after = len(items(b))
rec("parent sees new receipt", s == 200 and after > base, f"HTTP {s} {base}->{after}")

# 5. restore: cancel the collection
if coll_id:
    s, b = http("POST", f"/finance/collections/{coll_id}/cancel", admin, {})
    print(f"  restore (cancel collection): HTTP {s}")

ok = all(results)
print(f"\nA4 fee->receipt->parent journey: {'PASS' if ok else 'FAIL'} ({sum(results)}/{len(results)})")
sys.exit(0 if ok else 1)
