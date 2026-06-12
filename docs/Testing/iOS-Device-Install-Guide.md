# iOS Device Install Guide — Akshara ERP

**Release:** v17.2 (`v17.2-ios-device-install`)  
**Device:** Kanna's iPhone (`00008120-001131801A60201E`)  
**Bundle ID:** `com.akshara.erp.aksharaErp`

---

## Quick install (connected iPhone)

```bash
# 1. Recover caches if Xcode errors (build database, DerivedData)
./scripts/ios_build_recovery.sh

# 2. Build + install to connected device
./scripts/ios_device_install.sh
```

---

## First-time on device — trust developer

After install, iOS blocks launch until you trust the certificate:

1. On iPhone: **Settings** → **General** → **VPN & Device Management**
2. Under **Developer App**, tap **Apple Development: surendra303@gmail.com**
3. Tap **Trust** → **Trust** again

Then launch **Akshara ERP** from the home screen.

---

## Manual launch (after trust)

```bash
xcrun devicectl device process launch \
  --device 00008120-001131801A60201E \
  com.akshara.erp.aksharaErp
```

---

## Xcode build recovery

If you see:

- `Driver threw unable to load output file map`
- `error accessing build database`
- DerivedData corruption

Run:

```bash
./scripts/ios_build_recovery.sh
```

This clears Runner DerivedData, `flutter clean`, `pod install`, and validates env.

---

## Verification checklist

| Check | Expected |
|-------|----------|
| App icon on home screen | Akshara ERP |
| Splash / launch screen | Loads without crash |
| Login screen | Phone OTP entry visible |
| Staging API | Network calls to Supabase functions |
| Developer trust | Required once per certificate |

Demo accounts: [Demo-Accounts.md](Demo-Accounts.md)

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `flutter run` install fails | Use `./scripts/ios_device_install.sh` (devicectl) |
| Security / invalid code signature | Trust developer in Settings (above) |
| Device not listed | Unlock iPhone, accept "Trust This Computer" |
| Build database error | Run `ios_build_recovery.sh` |
| Native assets / xcrun fail | Ensure `scripts/ios/xcrun` on PATH via `xcode.env.local` |

---

## Related

- [iOS-Build-Guide.md](iOS-Build-Guide.md)
- [TestFlight-Execution-Guide.md](TestFlight-Execution-Guide.md)
