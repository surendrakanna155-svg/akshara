# TA-01 — Teacher Dashboard (Mobile)

**Frame ID:** `TA-01-TeacherDashboard-M`  
**Module map:** Teacher.md `T-04-Dashboard-M`  
**Platform:** Mobile `390×844`  
**Shell:** `Shell/TeacherMobileLayout`  
**Bottom nav active:** Home

---

## 1. Frame Metadata

| Property | Value |
|----------|-------|
| Frame size | `390×844` |
| Background | `color/surface-container-low` |
| Content width | `358` |
| Scroll content height | ~`960` |
| Grid | `grid/mobile-4` |
| Figma page | `📁 03 — Teacher App / TA-01 Dashboard` |

---

## 2. Grid & Layout

| Zone | Height |
|------|--------|
| AppBar | 56 |
| Greeting + status chips | 72 |
| Staff check-in card | 88 |
| Alert banner (attendance pending) | 56 |
| Today's classes | Hug ~240 |
| Tasks row | Hug ~160 |
| Messages preview | Hug ~120 |
| Class teacher card (conditional) | 88 |
| BottomNav | 80 |

---

## 3. Layer Hierarchy

```
TA-01-TeacherDashboard-M [390×844]
└── Shell/TeacherMobileLayout
    ├── Nav/AppBar-Teacher [390×56]
    │   ├── LeftCluster
    │   │   ├── Title ["Dashboard", type/title/large]
    │   │   └── PeriodChip ["Period 3 · 10:30", type/body/small, primary-container]
    │   └── RightCluster [AI, notifications badge=1, Avatar]
    │
    ├── Main/ScrollContent [358, V, gap 16, pad 16]
    │   ├── Row/Greeting [358×72, H, space-between, center]
    │   │   ├── TextStack [V, gap 4]
    │   │   │   ├── Eyebrow ["Friday, 5 Jun", type/body/small, variant]
    │   │   │   └── Name ["Good morning, Priya", type/headline/small]
    │   │   └── Weather/Optional [hidden v1]
    │   │
    │   ├── Card/StaffCheckIn [358×88, H, pad 16, radius 12, stroke]
    │   │   ├── IconContainer [40×40, success-container, check_circle]
    │   │   ├── TextStack [V, fill]
    │   │   │   ├── Title ["Checked in", type/body/large, semibold]
    │   │   │   └── Meta ["9:02 AM · Geo+Face verified", type/body/small]
    │   │   └── Button/Text ["View", primary] → TA-05
    │   │   └── ALT variant: Not checked in → Button Filled "Check in now"
    │   │
    │   ├── Feedback/Banner [358×56, Type=Warning]
    │   │   └── "Attendance not marked for Class 8-A · Period 1"
    │   │   └── Trailing action "Mark now"
    │   │
    │   ├── Section/TodayClasses [358, V, gap 12]
    │   │   ├── SectionHeader [H, space-between]
    │   │   │   ├── Title ["Today's Classes", type/title/medium]
    │   │   │   └── Link ["Timetable", primary]
    │   │   └── List [V, gap 8]
    │   │       └── Teacher/ClassCard [358×72, ×3]
    │   │           ├── TimeCol [56w, "09:00", type/label/medium]
    │   │           ├── Info [V, fill]
    │   │           │   ├── Subject ["Mathematics · 8-A", type/body/large]
    │   │           │   └── Room ["Room 204", type/body/small, variant]
    │   │           └── StatusBadge [Done|Now|Upcoming]
    │   │
    │   ├── Section/Tasks [358, V, gap 12]
    │   │   ├── SectionHeader ["Tasks", type/title/medium]
    │   │   └── Grid [H, gap 12, wrap]
    │   │       ├── TaskTile [173×72, instance ×2]
    │   │       │   ├── Icon [assignment, 24]
    │   │       │   ├── Count ["5", type/headline/small]
    │   │       │   └── Label ["HW to review", type/body/small]
    │   │       └── TaskTile ["3 unread messages"]
    │   │
    │   ├── Section/Messages [358, V, gap 8]
    │   │   ├── SectionHeader ["Messages", link See all]
    │   │   └── Comm/MessagePreviewRow [358×64, ×2]
    │   │       ├── Avatar [40]
    │   │       ├── Preview [parent name + snippet, fill]
    │   │       └── Badge [unread dot]
    │   │
    │   ├── Card/ClassTeacher [358×88, optional, primary-container 8%]
    │   │   ├── Icon [groups, 24]
    │   │   ├── Text ["Class Teacher · 8-A Dashboard", type/body/large]
    │   │   └── Chevron → TA-19
    │   │
    │   └── Spacer [16]
    │
    └── Nav/BottomBar-Teacher [ActiveTab=Home]
```

### Teacher/ClassCard status badges

| Badge | Color | When |
|-------|-------|------|
| Done | success | Period ended + attendance marked |
| Now | primary | Current period |
| Upcoming | neutral | Future |

---

## 4. Auto-Layout Settings

| Layer | Direction | Gap | Padding | Sizing |
|-------|-----------|-----|---------|--------|
| Greeting row | H | 0 | 0 | Fill×72 |
| Staff check-in card | H | 12 | 16 | Fill×88 |
| Class list | V | 8 | — | Fill×Hug |
| ClassCard | H | 12 | 12,16 | Fill×72 |
| Tasks grid | H | 12 | — | Fill×Hug |
| TaskTile | V | 4 | 12 | 173×72 |
| Message row | H | 12 | 8,0 | Fill×64 |
| Class teacher card | H | 12 | 16 | Fill×88 |

---

## 5. Component Instances

| Instance | Path | Properties |
|----------|------|------------|
| Shell | `Shell/TeacherMobileLayout` | — |
| Banner | `Feedback/Banner` | Type=Warning, HasAction=True |
| ClassCard ×3 | `Teacher/ClassCard` | Time, Subject, Status |
| TaskTile ×2 | `Teacher/TaskTile` | Icon, Count, Label |
| MessagePreviewRow ×2 | `Comm/MessagePreviewRow` | Unread |
| BottomBar | `Nav/BottomBar` | App=**Teacher**, ActiveTab=**Home** |
| Button | `Actions/Button` | Text or Filled per check-in state |

---

## 6. Exact Dimensions

| Element | W×H |
|---------|-----|
| Greeting block | 358×72 |
| Check-in card | 358×88 |
| Banner | 358×56 |
| Class card | 358×72 |
| Task tile | 173×72 |
| Message row | 358×64 |
| Class teacher card | 358×88 |
| Period chip | Hug×28 |

### Sample schedule

| Time | Class | Status |
|------|-------|--------|
| 09:00 | Math 8-A | Done |
| 11:00 | Math 9-B | Now |
| 14:00 | Math 8-A | Upcoming |

---

## 7. Constraints

| Layer | Constraints |
|-------|-------------|
| Class cards | Left · Right fill |
| Task tiles | Fixed 173w (2-col) |
| Check-in CTA | Hug right |
| Banner action | Hug right |
| Class teacher card | Left · Right fill |

---

## 8. Variants Used

| Component | Variants |
|-----------|----------|
| Staff check-in card | **CheckedIn** vs **NotCheckedIn** |
| `Teacher/ClassCard` | Status=Done · **Now** · Upcoming |
| `Feedback/Banner` | Warning + action |
| `Nav/BottomBar` | App=Teacher · ActiveTab=**Home** |
| Class teacher card | Visible=**True** (class teacher role) |

---

## 9. Responsive Rules

| Breakpoint | Change |
|------------|--------|
| 390×844 | 2 task tiles per row |
| 428×926 | Task tiles 190w |
| Tablet | Optional split: schedule left · tasks right (T frame) |

---

## 10. Prototype Links

| Hotspot | Destination |
|---------|-------------|
| Check in now | `TA-05-StaffCheckIn-M` |
| View check-in | `TA-05-StaffCheckIn-M` read-only |
| Banner Mark now | `TA-06-MarkAttendance-M` |
| Class card tap | `TA-06-MarkAttendance-M` filtered class |
| HW to review tile | `TA-09-HomeworkList-M` |
| Messages tile | `TA-13-Messages-M` |
| Message row | `TA-14-Thread-M` |
| Timetable link | `TA-12-Timetable-M` |
| Class Teacher card | `TA-19-ClassDashboard-M` |
| BottomNav Classes | `TA-06-MarkAttendance-M` |
| BottomNav Teach | `TA-08-CreateHomework-M` |
| BottomNav Messages | `TA-13-Messages-M` |

---

## 11. Build Sequence

| Step | Task |
|------|------|
| 1 | Frame + Teacher shell |
| 2 | AppBar + PeriodChip component |
| 3 | Greeting row |
| 4 | Staff check-in card (2 variants) |
| 5 | Warning banner |
| 6 | Build ClassCard component |
| 7 | 3 class instances |
| 8 | TaskTile ×2 |
| 9 | MessagePreviewRow ×2 |
| 10 | Class teacher optional card |
| 11 | BottomBar Home |
| 12 | Component properties for check-in boolean |
| 13 | Prototype links |
| 14 | Variant: NotCheckedIn default for demo |

**Total:** ~95 min

---

**End of TA-01 build specification**
