# NIKSHA OS — app trailer

> **Target length: 75 seconds.** Long enough to show the product working, short
> enough that a principal watches to the end.
> Two cuts: **75s** (website, sales meetings) and a **30s** cut (WhatsApp, Play
> Store promo video) marked ⚡ below.
>
> **Rule for every frame: record the real app.** No mockups, no After Effects
> fakery, no invented numbers. A principal who has used any ERP can tell, and the
> moment they catch one faked screen they stop believing the rest.

---

## Setup before recording

| Item | Value |
|---|---|
| Device | Real Android phone, 1080×2400. Emulator only if no device — its scrolling looks synthetic. |
| Build | Demo tenant, fully seeded (`scripts/demo_school_seed.py`) |
| Recording | `adb shell screenrecord --bit-rate 12000000 --size 1080x2400` or the phone's own recorder |
| Battery/status bar | Full battery, full signal, no notifications. Use Android's demo mode: `adb shell settings put global sysui_demo_allowed 1` |
| Motion | Slow, deliberate scrolls. Fast swipes read as nervous. |
| Data | Realistic Indian names, realistic fee amounts. Nothing offensive, nothing that looks like a placeholder. |

⚠️ **Never film a real child's name, photo or medical information.** Use the demo
tenant only.

---

## 75-second script

### 0:00–0:06 — Cold open ⚡
**Visual:** Black. White text, one line at a time.
**Text:** "A principal spends 40 minutes finding one student's file." → "NIKSHA OS does it in 4 seconds."
**Audio:** Low ambient pad starts.

> Open on the problem, not the logo. Nobody cares about the logo yet.

### 0:06–0:14 — Login ⚡
**Visual:** Phone. Enter mobile number → OTP → principal dashboard resolves.
**Caption:** "One number. One OTP. No passwords to forget."
**Note:** Do not speed-ramp this. Showing that login is genuinely 2 taps is the point.

### 0:14–0:30 — Student 360 ⚡ *(the hero — give it the most time)*
**Visual:** Tap search → type a surname → results appear → tap → Student 360 opens.
Then ONE slow scroll down the whole page.
**Caption:** "Search by name, ERP number or student ID."
**Then:** "Photo. Parents' numbers. Marks. Attendance. Leave. Bus route. Fees. One screen."
**Note:** Let the care-alert banner sit on screen for a beat — it is the moment
that lands with anyone who has run a school.

### 0:30–0:40 — Teacher attendance
**Visual:** Teacher opens their class. Taps 3 absentees. Saves. Confirmation.
**Caption:** "Mark the 3 absent. Not all 60."
**Note:** Show the count of 60 on screen so the saving is obvious.

### 0:40–0:50 — Marks entry → parent sees it
**Visual:** Split or hard cut. Teacher types marks, presses Enter, moves down the
column. Principal approves. Publish. **Cut to a parent's phone** — the marks are there.
**Caption:** "Teacher enters. Principal approves. Parent sees. In that order."
**Note:** This sequence sells the *governance*, which is what a serious school is
actually buying. Do not shortcut the approval step to make it look faster.

### 0:50–1:00 — Fees
**Visual:** Parent's fee screen — dues, breakdown, payment history, receipt download.
**Caption:** "Every rupee accounted for, and a receipt the parent can keep."

### 1:00–1:08 — Range
**Visual:** Fast, rhythmic cuts (≈1s each): transport route, timetable, homework,
library, inventory, staff attendance, dark mode.
**Caption:** "And the rest of the school."

### 1:08–1:15 — Close ⚡
**Visual:** Logo on the brand gradient.
**Text:** "NIKSHA OS — the whole school, in one app."
**Then:** "Now on Google Play."
**Audio:** Resolve, out.

---

## 30-second cut ⚡

Keep only: cold open (0:00–0:06) → login (0:06–0:12) → **Student 360 (0:12–0:24)**
→ close (0:24–0:30).

Student 360 carries the whole short cut. If only one thing is remembered, it
should be that.

---

## Captions

Burn them in. Most of this will be watched **on mute** in a WhatsApp group.

- Font: the app's own type, white, semi-bold
- Position: lower third, above the nav bar
- Every caption ≤ 8 words
- ≥ 4:1 contrast against the frame behind it

---

## What NOT to put in the trailer

1. **The Question Paper / QIE module** — hidden in V1. Showing it promises something the app does not do yet.
2. **AI features** — not the V1 story, and it invites "so it's a ChatGPT wrapper?"
3. **The payment step completing** — the gateway SDK is not wired. Show dues and receipts, never a fake success.
4. **Any web-app footage** — the web surface is view-only and owner-frozen.
5. **Speed-ramped scrolling** — makes real performance look suspicious.
6. **Competitor names.** Beat them in the demo, not in the trailer.

---

## Music

Instrumental, optimistic, no vocals. **Confirm the licence covers commercial use
and Play Store distribution** — a copyright strike on a Play promo video is a
slow, stupid problem to unwind. YouTube Audio Library or a paid Artlist/Epidemic
licence both work.
