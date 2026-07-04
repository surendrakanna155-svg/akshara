# PA-01 — Parent Dashboard (Mobile)

**Frame ID:** `PA-01-ParentDashboard-M`  
**Module map:** Parent.md `P-04-Dashboard-M`  
**Platform:** Mobile `390×844`  
**Shell:** `Shell/ParentMobileLayout`  
**Bottom nav active:** Home

---

## 1. Frame Metadata

| Property | Value |
|----------|-------|
| Frame size | `390×844` |
| Background | `color/surface-container-low` `#F8FAFC` |
| Safe area top | `59` (status bar overlay guide) |
| Safe area bottom | `34` (home indicator) |
| Content width | `358` (margin `16` L/R) |
| Scroll body height | ~`652` (844 − 56 AppBar − 80 BottomNav − 56 overlap) |
| Total scroll content | ~`920` (vertical scroll) |
| Grid | `grid/mobile-4` · 4 col · margin 16 · gutter 16 |
| Figma page | `📁 01 — Parent App / PA-01 Dashboard` |

---

## 2. Grid & Layout

| Zone | Y offset | Height | Width |
|------|----------|--------|-------|
| AppBar | 0 | 56 | 390 Fill |
| Scroll body | 56 | Hug (~920) | 358 |
| BottomNav | 764 | 80 | 390 Fill |

**Column spans (358 content):**

| Spans | Width |
|-------|-------|
| 4 col (full) | 358 |
| 2 col | 171 (gutter 16) |
| 1 col | 77.5 |

---

## 3. Layer Hierarchy

```
PA-01-ParentDashboard-M [390×844, clip content]
└── Shell/ParentMobileLayout [instance]
    ├── Nav/AppBar-Parent [390×56, fixed top]
    │   ├── LeftCluster [H, hug]
    │   │   └── Parent/ChildChip [instance, HasChevron=True]
    │   │       ├── Avatar/Child [32×32, radius full]
    │   │       ├── TextStack [V, gap 0]
    │   │       │   ├── Name ["Ravi Kumar", type/body/medium, semibold]
    │   │       │   └── Meta ["Class 8-A", type/body/small, on-surface-variant]
    │   │       └── Icon/expand_more [20]
    │   ├── Title [hidden on dashboard — chip acts as context]
    │   └── RightCluster [H, gap 4]
    │       ├── Actions/IconButton [AI, psychology, 48 hit]
    │       ├── Actions/IconButton [notifications, badge=2]
    │       └── Avatar/Parent [32×32]
    │
    ├── Main/ScrollContent [358×Fill, V, gap 16, pad 16 16 24 16]
    │   ├── Section/HeroGreeting [358×120]
    │   │   └── Card/Surface [Fill×Fill, radius 12, elevation/1, pad 16]
    │   │       ├── Row/Top [H, space-between]
    │   │       │   ├── Greeting [V, gap 4]
    │   │       │   │   ├── Eyebrow ["Good morning", type/body/small, variant]
    │   │       │   │   └── Headline ["Ravi's Day at a Glance", type/headline/small]
    │   │       │   └── SchoolLogo [40×40, radius 8]
    │   │       └── ChipRow [H, gap 8, pad 12 0 0 0]
    │   │           ├── Chip/Status [Present, success-container]
    │   │           ├── Chip/Status [₹4,200 due, warning-container]
    │   │           └── Chip/Status [2 msgs, primary-container]
    │   │
    │   ├── Section/QuickActions [358×104]
    │   │   └── Row [H, gap 12, space-between]
    │   │       ├── Parent/QuickActionCard [110×104, instance ×3]
    │   │       │   ├── IconCircle [40×40, primary-container]
    │   │       │   └── Label [type/label/medium, center]
    │   │       ├── [Pay Fee · payments]
    │   │       ├── [Contact Teacher · chat]
    │   │       └── [Report Card · description]
    │   │
    │   ├── Section/TodaySummary [358×Hug ~168]
    │   │   ├── SectionHeader [H, space-between, 32h]
    │   │   │   ├── Title ["Today", type/title/medium]
    │   │   │   └── Link ["See all", type/label/large, primary]
    │   │   └── CardGrid [V, gap 12]
    │   │       ├── SummaryRow/Attendance [358×48, H, pad 12 16, radius 8, stroke]
    │   │       │   ├── Icon [fact_check, 24, success]
    │   │       │   ├── Text ["Present · Marked 9:12 AM", type/body/medium, fill]
    │   │       │   └── Chevron [chevron_right, 20]
    │   │       ├── SummaryRow/Homework [358×48]
    │   │       │   └── Text ["2 homework due today", type/body/medium]
    │   │       └── SummaryRow/Fees [358×48]
    │   │           └── Text ["Term 2 installment due 12 Jun", type/body/medium]
    │   │
    │   ├── Section/Notices [358×140]
    │   │   ├── SectionHeader ["School Notices", type/title/medium]
    │   │   └── Carousel [H, gap 12, scroll horizontal, clip]
    │   │       └── NoticeCard [280×108, instance ×3]
    │   │           ├── Badge ["Urgent", error, optional]
    │   │           ├── Title [type/title/small, 2 lines max]
    │   │           └── Meta [date, type/body/small]
    │   │
    │   ├── Section/Events [358×Hug ~200]
    │   │   ├── SectionHeader ["Upcoming Events"]
    │   │   └── List [V, gap 0]
    │   │       └── EventRow [358×64, instance ×3]
    │   │           ├── DateBox [48×48, primary-container, radius 8]
    │   │           ├── Info [V, fill]
    │   │           └── Icon [chevron_right]
    │   │
    │   └── Section/AITip [358×88]
    │       └── AI/InsightCard [Fill×88, Accent=Primary]
    │           ├── Icon [psychology, 24]
    │           ├── Text ["Fee due in 5 days — pay early to avoid late fee", type/body/medium]
    │           └── Action [type/label/large, "Pay now"]
    │
    └── Nav/BottomBar-Parent [390×80, fixed bottom]
        └── Instance: App=Parent, ActiveTab=Home
```

---

## 4. Auto-Layout Settings

| Layer | Direction | Align | Gap | Padding | Sizing |
|-------|-----------|-------|-----|---------|--------|
| Shell root | V | Top | 0 | 0 | Fill×Fill |
| AppBar | H | Center | 8 | 0 16 | Fill×Fixed 56 |
| LeftCluster | H | Center | 8 | — | Hug |
| RightCluster | H | Center | 4 | — | Hug |
| Main/ScrollContent | V | Top | 16 | 16,16,24,16 | Fill×Hug |
| Hero Card inner | V | Top | 12 | 16 | Fill×Fill |
| QuickActions Row | H | Top | 12 | — | Fill×Fixed 104 |
| TodaySummary | V | Top | 12 | — | Fill×Hug |
| SummaryRow | H | Center | 12 | 12,16 | Fill×Fixed 48 |
| Notices Carousel | H | Top | 12 | — | Fill×Fixed 140 |
| Events List | V | Top | 0 | — | Fill×Hug |
| EventRow | H | Center | 12 | 8,0 | Fill×Fixed 64 |
| BottomBar | H | Space between | 0 | 8,0,34,0 | Fill×Fixed 80 |

---

## 5. Component Instances

| Instance | Library path | Properties |
|----------|--------------|------------|
| Shell | `Shell/ParentMobileLayout` | — |
| ChildChip | `Parent/ChildChip` | Name, Class, HasChevron=True |
| QuickActionCard ×3 | `Parent/QuickActionCard` | Icon, Label, Variant |
| IconButton ×2 | `Actions/IconButton` | Icon, Badge |
| InsightCard | `AI/InsightCard` | Accent=Primary, HasAction=True |
| BottomBar | `Nav/BottomBar` | App=Parent, ActiveTab=Home |
| Chip/Status ×3 | `Actions/Chip` | Type=Assist, Selected=False |

---

## 6. Exact Dimensions

| Element | W×H | Notes |
|---------|-----|-------|
| Frame | 390×844 | — |
| AppBar | 390×56 | — |
| ChildChip | Hug×40 | min touch 48 |
| QuickActionCard | 110×104 | (358−24)/3 ≈ 110.67 → 110 |
| Hero card | 358×120 | — |
| NoticeCard | 280×108 | carousel peek |
| EventRow | 358×64 | — |
| AI Insight | 358×88 | — |
| BottomNav | 390×80 | includes safe 34 |

### Sample content (design)

| Field | Value |
|-------|-------|
| Child name | Ravi Kumar |
| Class | 8-A |
| Attendance | Present |
| Fee due | ₹4,200 |
| Unread messages | 2 |

---

## 7. Constraints

| Layer | Constraints |
|-------|-------------|
| AppBar | Top · Left · Right · Fixed height |
| Main/ScrollContent | Top (below AppBar) · Left · Right · Hug height |
| BottomBar | Bottom · Left · Right · Fixed height |
| QuickActionCard | Fill width equal (use fixed 110 in 3-col) |
| Carousel cards | Hug width · fixed height |
| Summary rows | Left · Right · Fill width |

---

## 8. Variants Used

| Component | Variant values |
|-----------|----------------|
| `Nav/BottomBar` | App=**Parent** · ActiveTab=**Home** |
| `Parent/QuickActionCard` | Default (×3 different icons) |
| `Actions/Chip` | Type=Assist · colors: success, warning, primary |
| `AI/InsightCard` | Accent=**Primary** · HasAction=**True** |
| `Actions/IconButton` | State=Default · notifications HasBadge=True |
| `Parent/ChildChip` | HasChevron=**True** |

---

## 9. Responsive Rules

| Breakpoint | Frame | Changes |
|------------|-------|---------|
| Mobile `390×844` | **This frame** | 3 quick actions · horizontal notice scroll |
| Mobile Large `428×926` | `PA-01-ParentDashboard-M-L` | Content 396w · QuickAction 124w |
| Tablet `834×1194` | `PA-01-ParentDashboard-T` | Optional side margin max 480 centered · 4 quick actions 2×2 |

---

## 10. Prototype Links

| Hotspot | Trigger | Destination |
|---------|---------|-------------|
| ChildChip | Tap | `P-D-01` ChildSwitch overlay |
| QuickAction Pay Fee | Tap | `PA-03-ParentFees-M` |
| QuickAction Contact Teacher | Tap | `PA-13-Messages-M` (future) |
| QuickAction Report Card | Tap | `PA-12-ReportCards-M` (future) |
| Summary Attendance row | Tap | `PA-02-ParentAttendance-M` |
| Summary Homework row | Tap | `PA-07-Homework-M` (future) |
| Summary Fees row | Tap | `PA-03-ParentFees-M` |
| Notice card | Tap | `PA-18-Notifications-M` detail |
| Event row | Tap | `PA-17-Events-M` (future) |
| AI Pay now | Tap | `PA-03-ParentFees-M` |
| Bell icon | Tap | `PA-18-Notifications-M` |
| AI icon | Tap | `PA-22-AICopilot-M` (future) |
| BottomNav Academics | Tap | `PA-02-ParentAttendance-M` |
| BottomNav Fees | Tap | `PA-03-ParentFees-M` |
| BottomNav Messages | Tap | `PA-13-Messages-M` |
| BottomNav More | Tap | `PA-25-More-M` |

---

## 11. Build Sequence

| Step | Task | Time est. |
|------|------|-----------|
| 1 | Place frame `390×844` · apply `grid/mobile-4` | 2m |
| 2 | Instance `Shell/ParentMobileLayout` | 3m |
| 3 | Configure AppBar: ChildChip + 2 IconButtons + Avatar | 8m |
| 4 | Build Hero card section (120h) | 10m |
| 5 | Place 3× `Parent/QuickActionCard` | 8m |
| 6 | Build Today summary 3 rows | 12m |
| 7 | Build Notice carousel (3 cards) | 15m |
| 8 | Build Events list (3 rows) | 10m |
| 9 | Instance `AI/InsightCard` | 5m |
| 10 | Set BottomBar ActiveTab=Home | 2m |
| 11 | Wire prototype links §10 | 15m |
| 12 | Accessibility pass: labels, contrast | 10m |

**Total:** ~90 min

---

**End of PA-01 build specification**
