# Release Asset Audit — Akshara ERP iOS

**Release:** v17.1 (`v17.1-apple-distribution-readiness`)  
**Scope:** Document placeholders only — **no redesign in this release**

---

## Metadata

| Field | Value | Pilot OK? | Public store OK? |
|-------|-------|:---------:|:----------------:|
| App name | Akshara ERP | ✅ | ✅ |
| Bundle ID | `com.akshara.erp.aksharaErp` | ✅ | ✅ |
| Version | 17.1.0 | ✅ | ✅ |
| Build number | 171 | ✅ | ✅ |
| Deployment target | iOS 13.0 | ✅ | ✅ |

Sources: `pubspec.yaml`, `ios/Runner/Info.plist`

---

## App icon

| Check | Status | Notes |
|-------|--------|-------|
| Full icon set present | ✅ | All sizes in `AppIcon.appiconset/` |
| 1024×1024 marketing icon | ✅ | `Icon-App-1024x1024@1x.png` exists |
| **Brand uniqueness** | ⚠️ **Placeholder** | Flutter/Xcode default blue icon |
| Flutter validation warning | ⚠️ | `App icon is set to the default placeholder icon` |

**Pilot / internal TestFlight:** Acceptable — function over branding.  
**Public App Store release:** Replace entire `AppIcon.appiconset/` with Akshara-branded PNGs (1024×1024 source required).

**Required before public release (owner/design):**

1. Master icon 1024×1024 PNG (no transparency, no rounded corners — Apple masks automatically)
2. Regenerate all sizes or use Xcode asset catalog import
3. Re-archive and upload

**Do not change in v17.1** — document only per release scope.

---

## Launch screen

| Check | Status | Notes |
|-------|--------|-------|
| Launch storyboard | ✅ | `LaunchScreen.storyboard` + `LaunchImage.imageset` |
| Images present | ✅ | 1x, 2x, 3x PNGs |
| **Brand uniqueness** | ⚠️ **Placeholder** | Default Flutter launch image (white + logo) |
| Flutter validation warning | ⚠️ | `Launch image is set to the default placeholder icon` |

**Pilot / internal TestFlight:** Acceptable.  
**Public App Store release:** Replace `LaunchImage.imageset` assets or migrate to branded `LaunchScreen.storyboard` with Akshara colors/logo.

---

## Splash / branding summary

| Asset | Location | Replace before public? |
|-------|----------|:--------------------:|
| App icon (all sizes) | `ios/Runner/Assets.xcassets/AppIcon.appiconset/` | **Yes** |
| Launch image | `ios/Runner/Assets.xcassets/LaunchImage.imageset/` | **Yes** |
| Android launcher | `android/app/src/main/res/mipmap-*` | **Yes** (same branding pass) |

---

## Android note (cross-platform consistency)

When brand assets are ready, update Android and iOS in the same design pass for store consistency. Android pilot APK is **not blocked** by placeholder icons.

---

## Related

- [Apple-Go-Live-Checklist.md](Apple-Go-Live-Checklist.md)
- [TestFlight-Execution-Guide.md](TestFlight-Execution-Guide.md)
