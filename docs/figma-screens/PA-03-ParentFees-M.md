# PA-03 — Parent Fees (Mobile)

**Frame ID:** `PA-03-ParentFees-M`  
**Module map:** Parent.md `P-09-Fees-M`  
**Platform:** Mobile `390×844`  
**Shell:** `Shell/ParentMobileLayout`  
**Bottom nav active:** Fees

---

## 1. Frame Metadata

| Property | Value |
|----------|-------|
| Frame size | `390×844` |
| Background | `color/surface-container-low` |
| Content width | `358` |
| Scroll content height | ~`1040` |
| Grid | `grid/mobile-4` |
| Figma page | `📁 01 — Parent App / PA-03 Fees` |

---

## 2. Grid & Layout

| Zone | Height |
|------|--------|
| AppBar | 56 |
| Fee hero card | 160 |
| Progress section | 72 |
| Installment timeline | Hug ~280 |
| Fee breakdown accordion | Hug ~200 |
| Sticky CTA zone | 72 (above bottom nav) |
| BottomNav | 80 |

**Note:** Sticky `Pay Now` bar overlays scroll at Y=692 (844−80−72)

---

## 3. Layer Hierarchy

```
PA-03-ParentFees-M [390×844]
└── Shell/ParentMobileLayout
    ├── Nav/AppBar-Parent [390×56]
    │   ├── Title ["Fees", type/title/large]
    │   └── RightCluster [notifications, receipt icon → history]
    │
    ├── Main/ScrollContent [358, V, gap 16, pad 16 16 88 16]
    │   │   └── extra bottom pad for sticky CTA
    │   │
    │   ├── Parent/FeeDueCard [358×160, instance, elevation/2]
    │   │   ├── TopRow [H, space-between]
    │   │   │   ├── Label ["Total Pending", type/body/small, variant]
    │   │   │   └── Chip ["Overdue", error, if applicable]
    │   │   ├── Amount ["₹4,200", type/headline/medium, error]
    │   │   ├── SubRow ["Due 12 Jun 2026 · Term 2", type/body/medium]
    │   │   └── MetaRow [H, gap 16]
    │   │       ├── Item ["Paid: ₹18,800", success]
    │   │       └── Item ["Annual: ₹23,000", variant]
    │   │
    │   ├── Section/Progress [358×72]
    │   │   └── Card [pad 16, radius 12, stroke]
    │   │       ├── Row [H, space-between]
    │   │       │   ├── Text ["Collection progress", type/body/medium]
    │   │       │   └── Pct ["82%", type/title/medium, success]
    │   │       └── Cell/ProgressBar [358−32, 8h, 82% fill, success]
    │   │
    │   ├── Section/Timeline [358, V, gap 12]
    │   │   ├── SectionHeader ["Installments", type/title/medium]
    │   │   └── Timeline [V, gap 0, pad 0 0 0 8]
    │   │       ├── Parent/FeeInstallmentRow [358×72, ×4]
    │   │       │   ├── Rail [24w, line + dot]
    │   │       │   ├── Content [V, gap 4, fill]
    │   │       │   │   ├── Title ["Term 1", type/body/large, semibold]
    │   │       │   │   ├── Meta ["Paid 15 Apr · ₹8,000", type/body/small]
    │   │       │   │   └── StatusChip [Paid, success]
    │   │       │   └── Action [receipt icon if paid]
    │   │       ├── Row Term2 [Due, warning, primary CTA text]
    │   │       ├── Row Term3 [Upcoming, neutral]
    │   │       └── Row Term4 [Upcoming, neutral]
    │   │
    │   ├── Section/Breakdown [358, V, gap 8]
    │   │   ├── SectionHeader ["Fee breakdown"]
    │   │   └── Accordion [V, gap 8]
    │   │       ├── AccordionItem/Expanded [358×Hug]
    │   │       │   ├── Header [56h, H, space-between, "Tuition"]
    │   │       │   └── Body [pad 0 16 16]
    │   │       │       └── LineItem [×3, H, space-between, 32h]
    │   │       ├── AccordionItem/Collapsed ["Transport"]
    │   │       └── AccordionItem/Collapsed ["Activity"]
    │   │
    │   └── LinkRow [358×48, center]
    │       └── Button/Text ["View payment history", primary]
    │
    ├── Sticky/CTABar [390×72, fixed above BottomNav, fill surface, stroke top]
    │   ├── LeftStack [V]
    │   │   ├── Label ["Amount due", type/body/small]
    │   │   └── Value ["₹4,200", type/title/medium]
    │   └── Button/Filled ["Pay Now", FullWidth=False, 160w]
    │
    └── Nav/BottomBar-Parent [ActiveTab=Fees]
```

---

## 4. Auto-Layout Settings

| Layer | Direction | Gap | Padding | Sizing |
|-------|-----------|-----|---------|--------|
| FeeDueCard | V | 8 | 20 | Fill×160 |
| Progress card | V | 8 | 16 | Fill×72 |
| Timeline | V | 0 | — | Fill×Hug |
| InstallmentRow | H | 12 | 12,0 | Fill×72 |
| Accordion item header | H | — | 16 | Fill×56 |
| Line item | H | — | 0 | Fill×32 |
| Sticky CTA | H | Space-between | 12,16 | Fill×72 |
| Pay button | — | — | 16,14 | Fixed 160×48 |

---

## 5. Component Instances

| Instance | Path | Properties |
|----------|------|------------|
| FeeDueCard | `Parent/FeeDueCard` | Amount, DueDate, HasOverdue |
| ProgressBar | `Cell/ProgressBar` | Value=82, Accent=Success |
| InstallmentRow ×4 | `Parent/FeeInstallmentRow` | Status: Paid/Due/Upcoming |
| Accordion | `Data/Accordion` | Items=3, Expanded=0 |
| Button/Filled | `Actions/Button` | Type=Filled, Label=Pay Now |
| BottomBar | `Nav/BottomBar` | ActiveTab=**Fees** |

---

## 6. Exact Dimensions

| Element | W×H |
|---------|-----|
| Fee hero | 358×160 |
| Progress card | 358×72 |
| Installment row | 358×72 |
| Accordion header | 358×56 |
| Sticky CTA bar | 390×72 |
| Pay Now button | 160×48 |
| Timeline rail dot | 12×12 |
| Progress track | 326×8 |

### Sample data

| Installment | Amount | Status |
|-------------|--------|--------|
| Term 1 | ₹8,000 | Paid |
| Term 2 | ₹4,200 | Due 12 Jun |
| Term 3 | ₹5,400 | Upcoming |
| Term 4 | ₹5,400 | Upcoming |

---

## 7. Constraints

| Layer | Constraints |
|-------|-------------|
| Sticky CTA | Bottom (above nav 80) · Left · Right |
| FeeDueCard | Left · Right fill |
| Pay button | Right · Center vertical |
| Scroll content | Top below AppBar · bottom pad 88 for CTA |
| Accordion | Left · Right fill |

---

## 8. Variants Used

| Component | Variants |
|-----------|----------|
| `Parent/FeeDueCard` | HasOverdue=**True** |
| `Parent/FeeInstallmentRow` | Paid · **Due** · Upcoming |
| `Chip/Status` | Overdue=error · Paid=success · Due=warning |
| `Cell/ProgressBar` | 82% success tier |
| `Actions/Button` | Filled · Default |
| `Nav/BottomBar` | ActiveTab=**Fees** |
| `Data/Accordion` | Expanded index 0 |

---

## 9. Responsive Rules

| Breakpoint | Change |
|------------|--------|
| 390×844 | Sticky CTA + bottom nav |
| 428×926 | Wider cards 396 |
| Tablet | Hide sticky — Pay button in hero card · single column 480 centered |

---

## 10. Prototype Links

| Hotspot | Destination |
|---------|-------------|
| Pay Now (sticky) | `PA-10-FeePayment-M` (future) |
| Pay Now on Due row | `PA-10-FeePayment-M` pre-selected Term 2 |
| Receipt icon (paid row) | `PA-11-Receipt-M` |
| View payment history | List frame / bottom sheet |
| Receipt app bar icon | Payment history list |
| BottomNav Home | `PA-01-ParentDashboard-M` |
| BottomNav Academics | `PA-02-ParentAttendance-M` |

### Payment flow (reference)

`PA-03` → `PA-10` Razorpay → `PA-11` Receipt → back to `PA-03` success state variant

---

## 11. Build Sequence

| Step | Task |
|------|------|
| 1 | Frame + Shell |
| 2 | AppBar "Fees" + receipt icon |
| 3 | Build `Parent/FeeDueCard` if not in library |
| 4 | Progress card + ProgressBar |
| 5 | Build `FeeInstallmentRow` component (3 status variants) |
| 6 | Assemble timeline 4 rows |
| 7 | Accordion breakdown 3 items |
| 8 | Payment history text button |
| 9 | Sticky CTA bar (fixed position) |
| 10 | BottomBar Fees active |
| 11 | Duplicate frame: `PA-03-AllPaid-M` variant |
| 12 | Prototype Pay → PA-10 |
| 13 | Test scroll: CTA always visible |

**Total:** ~110 min

---

**End of PA-03 build specification**
