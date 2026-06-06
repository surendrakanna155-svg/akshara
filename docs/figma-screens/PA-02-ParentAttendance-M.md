# PA-02 — Parent Attendance (Mobile)

**Frame ID:** `PA-02-ParentAttendance-M`  
**Module map:** Parent.md `P-06-Attendance-M`  
**Platform:** Mobile `390×844`  
**Shell:** `Shell/ParentMobileLayout`  
**Bottom nav active:** Academics

---

## 1. Frame Metadata

| Property | Value |
|----------|-------|
| Frame size | `390×844` |
| Background | `color/surface-container-low` |
| Content width | `358` |
| Scroll content height | ~`980` |
| Grid | `grid/mobile-4` |
| Figma page | `📁 01 — Parent App / PA-02 Attendance` |

---

## 2. Grid & Layout

| Zone | Height | Notes |
|------|--------|-------|
| AppBar | 56 | Title "Attendance" + ChildChip compact |
| Month selector | 48 | Prev/next month |
| Summary KPI strip | 88 | 3 compact metrics |
| Calendar | 320 | 7×5 grid cells |
| Legend | 32 | Present/Absent/Late/Holiday |
| Warning banner | 56 | Conditional chronic absent |
| Recent log list | Hug ~240 | Last 5 days detail |
| BottomNav | 80 | Academics active |

---

## 3. Layer Hierarchy

```
PA-02-ParentAttendance-M [390×844]
└── Shell/ParentMobileLayout
    ├── Nav/AppBar-Parent [390×56]
    │   ├── LeftCluster
    │   │   ├── IconButton/back [optional false on tab root]
    │   │   └── TitleStack [V]
    │   │       ├── Title ["Attendance", type/title/large]
    │   │       └── Subtitle ["Ravi Kumar · 8-A", type/body/small, variant]
    │   └── RightCluster [notifications, AI]
    │
    ├── Main/ScrollContent [358, V, gap 16, pad 16]
    │   ├── Nav/MonthSelector [358×48, H, space-between, center]
    │   │   ├── IconButton/chevron_left [48]
    │   │   ├── Label ["June 2026", type/title/medium]
    │   │   └── IconButton/chevron_right [48]
    │   │
    │   ├── Row/KPISummary [358×88, H, gap 8]
    │   │   ├── Data/KPI/Compact [115×88, Accent=Success]
    │   │   │   └── Label "94%" · Sub "This month"
    │   │   ├── Data/KPI/Compact [115×88, Accent=Error]
    │   │   │   └── Label "2" · Sub "Absent days"
    │   │   └── Data/KPI/Compact [115×88, Accent=Warning]
    │   │       └── Label "1" · Sub "Late"
    │   │
    │   ├── Card/Calendar [358×320, pad 12, radius 12, stroke]
    │   │   ├── Row/WeekdayHeaders [H, gap 0, 7 cells × 48w]
    │   │   │   └── Cell ["S","M","T","W","T","F","S", label/small]
    │   │   └── Grid/Days [V, gap 4, 5 rows]
    │   │       └── Row [H, gap 4, 7 × Parent/CalendarDayCell 48×48]
    │   │           Variants: Present|Absent|Late|Holiday|Empty|Future
    │   │
    │   ├── Row/Legend [358×32, H, gap 16, center]
    │   │   └── LegendItem [×4, H, gap 4, dot 8×8 + label small]
    │   │
    │   ├── Feedback/Banner [358×56, Type=Warning, Dismissible=False]
    │   │   └── "Ravi was absent 2 days this month — above class average"
    │   │
    │   ├── Section/RecentLog [358, V, gap 8]
    │   │   ├── SectionHeader ["Recent", type/title/medium]
    │   │   └── List [V, gap 8]
    │   │       └── Parent/AttendanceDayRow [358×64, ×5]
    │   │           ├── DateCol [48w, "4 Jun", type/label/medium]
    │   │           ├── StatusChip [Present|Absent|Late]
    │   │           ├── Detail ["Marked 9:05 AM", type/body/small, fill]
    │   │           └── Icon/info [tap → bottom sheet]
    │   │
    │   └── Spacer [16]
    │
    └── Nav/BottomBar-Parent [ActiveTab=Academics]
```

### Parent/CalendarDayCell anatomy

```
CalendarDayCell [48×48, radius 8]
├── DayNumber [type/label/medium, center]
└── DotIndicator [6×6, bottom, optional]
```

| Variant | Fill | Text | Dot |
|---------|------|------|-----|
| Present | `success-container` | on-surface | — |
| Absent | `error-container` | error | — |
| Late | `warning-container` | on-surface | — |
| Holiday | `surface-container-highest` | variant | — |
| Empty | transparent | variant 38% | — |
| Future | transparent | variant | — |
| Selected | stroke 2px primary | — | — |

---

## 4. Auto-Layout Settings

| Layer | Direction | Gap | Padding | Sizing |
|-------|-----------|-----|---------|--------|
| MonthSelector | H | 0 | 0 | Fill×48 |
| KPI Row | H | 8 | 0 | Fill×88 |
| Calendar card | V | 8 | 12 | Fill×320 |
| Weekday row | H | 0 | 0 | Fill×24 |
| Day grid row | H | 4 | 0 | Fill×48 |
| Legend | H | 16 | 0 | Fill×32 |
| AttendanceDayRow | H | 12 | 12,16 | Fill×64 |
| Recent list | V | 8 | — | Fill×Hug |

---

## 5. Component Instances

| Instance | Path | Properties |
|----------|------|------------|
| Shell | `Shell/ParentMobileLayout` | — |
| KPI Compact ×3 | `Data/KPI/Compact` | Accent, Label, Sub |
| CalendarDayCell ×35 | `Parent/CalendarDayCell` | Day, Variant |
| Banner | `Feedback/Banner` | Type=Warning |
| AttendanceDayRow ×5 | `Parent/AttendanceDayRow` | Date, Status, Detail |
| BottomBar | `Nav/BottomBar` | ActiveTab=**Academics** |

---

## 6. Exact Dimensions

| Element | W×H |
|---------|-----|
| Month selector | 358×48 |
| KPI compact card | 115×88 | (358−16)/3 |
| Calendar card | 358×320 |
| Day cell | 48×48 |
| Weekday header cell | 48×24 |
| Legend row | 358×32 |
| Banner | 358×56 |
| Day row | 358×64 |

### June 2026 sample data

| Day | Status |
|-----|--------|
| 1–3 | Holiday |
| 4 | Present |
| 5 | Absent |
| 6 | Present |
| … | (fill grid) |

---

## 7. Constraints

| Layer | Constraints |
|-------|-------------|
| Calendar grid cells | Fixed 48×48 |
| KPI cards | Equal width thirds |
| Day rows | Left · Right fill |
| Banner | Left · Right fill |
| Month label | Center |

---

## 8. Variants Used

| Component | Variants |
|-----------|----------|
| `CalendarDayCell` | Present, Absent, Late, Holiday, Empty, Selected |
| `Data/KPI/Compact` | Success, Error, Warning |
| `Feedback/Banner` | Type=**Warning** |
| `Chip/Status` | Present=success · Absent=error · Late=warning |
| `Nav/BottomBar` | ActiveTab=**Academics** |

---

## 9. Responsive Rules

| Breakpoint | Change |
|------------|--------|
| 390×844 | 48px day cells |
| 428×926 | Day cells 52px · calendar 372w |
| Tablet | Center column max 480 · show week list sidebar (T frame) |

---

## 10. Prototype Links

| Hotspot | Destination |
|---------|-------------|
| Calendar day cell | `Overlays/BottomSheet` DayDetail (Present/Absent/Late/Holiday copy) |
| Day row info | Same bottom sheet |
| Month prev/next | Swap variant frame (May/June) |
| KPI Absent | Scroll to banner + highlight absent cells |
| BottomNav Home | `PA-01-ParentDashboard-M` |
| BottomNav Fees | `PA-03-ParentFees-M` |
| Back (if pushed) | `PA-01-ParentDashboard-M` |

### Bottom sheet: DayDetail `390×Auto`

```
Title: "Thursday, 5 June 2026"
Status chip
Body: "Absent — no mark recorded by 10:00 AM"
Note: "Contact class teacher if incorrect" + Button Text
```

---

## 11. Build Sequence

| Step | Task |
|------|------|
| 1 | Frame + Shell instance |
| 2 | AppBar with title + subtitle |
| 3 | Month selector row |
| 4 | 3× KPI Compact |
| 5 | Build CalendarDayCell component (7 variants) |
| 6 | Assemble 5×7 grid in card |
| 7 | Legend row |
| 8 | Warning banner instance |
| 9 | 5× AttendanceDayRow |
| 10 | BottomBar Academics active |
| 11 | Create DayDetail bottom sheet component |
| 12 | Prototype: cell → sheet |
| 13 | Sample absent/present states for review |

**Total:** ~100 min

---

**End of PA-02 build specification**
