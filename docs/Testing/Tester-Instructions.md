# Tester Instructions — Akshara ERP Pilot

**Thank you for helping test Akshara!**  
**Build version:** 16.6.0 (166) · **Environment:** Staging demo school

---

## Android testers

### 1. Install APK

1. Receive `app-release.apk` from the team (email, Drive, or QR link)
2. On your Android phone: **Settings → Security → Install unknown apps** → allow your file browser
3. Open the APK file → **Install**
4. Open **Akshara ERP**

> **Tip:** If install is blocked, ensure you downloaded the complete file (~70 MB).

### 2. Login

**With internet (recommended):**

| Role | Phone number |
|------|--------------|
| Parent | `9000100001` |
| Teacher | `9000000001` |
| Principal (ERP) | `9876543210` |
| Student | `9876543212` |

1. Enter phone number → **Send OTP**
2. Enter OTP (check with team if not received — staging shows OTP in API response)
3. App opens your role dashboard

**Without internet (demo only):**

1. Select role on login screen (Parent / Teacher / Student / Staff)
2. Enter OTP: `123456`
3. For Principal: choose **Staff** → role **Principal**

### 3. Test workflows

Spend **15–20 minutes** on your assigned role:

| Role | Try this |
|------|----------|
| Parent | Dashboard → Attendance → Fees → Notifications |
| Teacher | Dashboard → Attendance → Homework |
| Student | Dashboard → Homework → Timetable → Exams |
| Principal | Management → Intelligence → Finance |

Full checklist: `docs/Testing/Device-Test-Plan.md`

### 4. Submit bugs

Use `docs/Testing/Bug-Report-Template.md`:

- Device model + Android version
- Role + screen name
- What you expected vs what happened
- Screenshot

Send to the team contact or save in shared folder.

---

## iPhone testers (TestFlight)

### 1. Install via TestFlight

1. Install **TestFlight** from the App Store (if not installed)
2. Open the invite email from Akshara team → **View in TestFlight**
3. Tap **Install** on **Akshara ERP**
4. Open from TestFlight or home screen

> **Note:** TestFlight builds require the team to upload an IPA first. See `docs/Testing/iOS-Build-Guide.md` for build Mac setup.

### 2. Login

Same phones as Android table above. Use Wi‑Fi or mobile data.

### 3. Test workflows

Same as Android — focus on:

- Safe area (notch / Dynamic Island)
- Keyboard on login
- Swipe-back navigation
- Scrolling smoothness on dashboard

### 4. Submit bugs

Same template as Android. Include **iOS version** (Settings → General → About).

---

## What NOT to test

- Do not test with real parent/student PII
- Do not share OTP codes publicly
- Do not expect production payment processing (staging only)
- Alumni, transport GPS map, and some ERP sub-modules are incomplete — stick to core flows above

---

## FAQ

**Q: I see "Unable to load dashboard"**  
A: Check internet. Tap **Try again**. If persistent, report as bug with screenshot.

**Q: OTP not received**  
A: Staging may return OTP in API logs only. Ask team for current OTP or use mock login `123456`.

**Q: Wrong dashboard after login**  
A: Logout. Confirm phone matches your assigned role in demo accounts doc.

**Q: App looks different from screenshots**  
A: Expected — staging data varies. Report only if layout breaks or crashes.

---

## Reference docs

| Doc | Purpose |
|-----|---------|
| `docs/Testing/Demo-Accounts.md` | All test phones + journeys |
| `docs/Testing/Device-Test-Plan.md` | Full test matrix |
| `docs/Testing/Bug-Report-Template.md` | How to report issues |
| `docs/Testing/iOS-Build-Guide.md` | TestFlight setup (team) |

**Contact:** Your Akshara pilot coordinator
