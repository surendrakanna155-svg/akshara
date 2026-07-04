# ST-01 — Student Dashboard (Mobile)

**Frame ID:** `ST-01-StudentDashboard-M`  
**Module map:** Student.md `S-04-Dashboard-M`  
**Platform:** Mobile `390×844`  
**Shell:** `Shell/StudentMobileLayout`  
**Bottom nav active:** Home

---

## 1. Frame Metadata

| Property | Value |
|----------|-------|
| Frame size | `390×844` |
| Background | `color/surface-container-low` |
| Content width | `358` |
| Scroll content height | ~`900` |
| Grid | `grid/mobile-4` |
| Figma page | `📁 02 — Student App / ST-01 Dashboard` |

---

## 2. Grid & Layout

| Zone | Height |
|------|--------|
| AppBar | 56 |
| Hero greeting | 96 |
| Timetable snippet | 160 |
| Quick actions | 104 |
| Status cards row | 88 |
| Announcement card | 120 |
| Homework due list | Hug ~200 |
| BottomNav | 80 |

---

## 3. Layer Hierarchy

```
ST-01-StudentDashboard-M [390×844]
└── Shell/StudentMobileLayout
    ├── Nav/AppBar-Student [390×56]
    │   ├── LeftCluster
    │   │   ├── Title ["Home", type/title/large]
    │   │   └── Student/ClassChip ["8-A", primary-container pill]
    │   └── RightCluster [AI, notifications, Avatar]
    │
    ├── Main/ScrollContent [358, V, gap 16, pad 16]
    │   ├── Section/Hero [358×96]
    │   │   └── Card [pad 16, radius 12, elevation/1]
    │   │       ├── Greeting ["Hey Ravi! 👋", type/headline/small]
    │   │       └── Sub ["Ready for Period 3?", type/body/medium, variant]
    │   │
    │   ├── Section/TimetableToday [358×160]
    │   │   ├── SectionHeader [H, space-between]
    │   │   │   ├── Title ["Today", type/title/medium]
    │   │   │   └── Link ["Full schedule", primary] → ST-09
    │   │   └── Card/ScheduleStrip [358×120, H, gap 8, pad 12, scroll clip]
    │   │       └── Student/PeriodPill [100×96, ×3 visible]
    │   │           ├── Time ["10:30", type/label/medium]
    │   │           ├── Subject ["Science", type/body/medium, 2 lines]
    │   │           ├── Teacher ["Mrs. Rao", type/body/small]
    │   │           └── State [Now|Next|Later]
    │   │
    │   ├── Section/QuickActions [358×104]
    │   │   └── Row [H, gap 12]
    │   │       ├── Student/QuickAction [173×104]
    │   │       │   └── ["Join Class", videocam, primary — if live]
    │   │       └── Student/QuickAction [173×104]
    │   │           └── ["Submit HW", assignment, warning if overdue]
    │   │
    │   ├── Row/StatusCards [358×88, H, gap 12]
    │   │   ├── Data/KPI/Compact [173×88, Success]
    │   │   │   └── Present today
    │   │   └── Data/KPI/Compact [173×88, Warning]
    │   │       └── 2 HW due
    │   │
    │   ├── Card/Announcement [358×120, primary-container]
    │   │   ├── Badge ["School", type/label/small]
    │   │   ├── Title ["Sports day practice cancelled", type/title/small]
    │   │   └── Meta ["Posted 2h ago", type/body/small]
    │   │
    │   ├── Section/HomeworkDue [358, V, gap 8]
    │   │   ├── SectionHeader ["Due soon", link See all → ST-06]
    │   │   └── List [V, gap 8]
    │   │       └── Academic/HomeworkCard [358×80, ×2]
    │   │           ├── SubjectIcon [40×40, circle]
    │   │           ├── Content [V, fill]
    │   │           │   ├── Title ["Algebra worksheet", type/body/large]
    │   │           │   └── Meta ["Math · Due tomorrow", type/body/small]
    │   │           └── Chip [Pending|Overdue]
    │   │
    │   └── Spacer [24]
    │
    └── Nav/BottomBar-Student [ActiveTab=Home]
```

### Student/PeriodPill states

| State | Border | Background |
|-------|--------|--------------|
| Now | 2px primary | primary-container |
| Next | 1px outline | surface |
| Later | 1px outline | surface @ 60% |

---

## 4. Auto-Layout Settings

| Layer | Direction | Gap | Padding | Sizing |
|-------|-----------|-----|---------|--------|
| Hero card | V | 8 | 16 | Fill×96 |
| Schedule strip | H | 8 | 12 | Fill×120 |
| PeriodPill | V | 4 | 8 | 100×96 |
| Quick actions | H | 12 | — | Fill×104 |
| Status row | H | 12 | — | Fill×88 |
| Announcement | V | 8 | 16 | Fill×120 |
| Homework list | V | 8 | — | Fill×Hug |
| HomeworkCard | H | 12 | 12,16 | Fill×80 |

---

## 5. Component Instances

| Instance | Path | Properties |
|----------|------|------------|
| Shell | `Shell/StudentMobileLayout` | — |
| ClassChip | `Student/ClassChip` | Label=8-A |
| PeriodPill ×3 | `Student/PeriodPill` | State=Now/Next/Later |
| QuickAction ×2 | `Student/QuickAction` | Icon, Label, Emphasis |
| KPI Compact ×2 | `Data/KPI/Compact` | Success, Warning |
| HomeworkCard ×2 | `Academic/HomeworkCard` | Status |
| BottomBar | `Nav/BottomBar` | App=**Student**, ActiveTab=**Home** |

---

## 6. Exact Dimensions

| Element | W×H |
|---------|-----|
| Hero | 358×96 |
| Timetable section | 358×160 |
| Period pill | 100×96 |
| Quick action | 173×104 |
| KPI compact | 173×88 |
| Announcement | 358×120 |
| Homework card | 358×80 |
| Class chip | Hug×28 |

### Sample periods

| Time | Subject | State |
|------|---------|-------|
| 10:30 | Science | Now |
| 11:30 | English | Next |
| 14:00 | PE | Later |

---

## 7. Constraints

| Layer | Constraints |
|-------|-------------|
| Period pills | Hug width · fixed height · horizontal scroll |
| Quick actions | Equal 173w |
| KPI pair | Equal width |
| Homework cards | Left · Right fill |
| Announcement | Left · Right fill |

---

## 8. Variants Used

| Component | Variants |
|-----------|----------|
| `Student/PeriodPill` | **Now** · Next · Later |
| `Student/QuickAction` | Join Class (primary) · Submit HW (warning) |
| `Data/KPI/Compact` | Success · Warning |
| `Academic/HomeworkCard` | Pending · **Overdue** |
| `Nav/BottomBar` | App=Student · ActiveTab=**Home** |
| Join Class | Visible when online class live (boolean) |

---

## 9. Responsive Rules

| Breakpoint | Change |
|------------|--------|
| 390×844 | 2 quick actions · 2 KPIs |
| 428×926 | Period pill 108w · actions 190w |
| Tablet | Timetable full width table (T frame ST-09 embed) |

---

## 10. Prototype Links

| Hotspot | Destination |
|---------|-------------|
| Full schedule | `ST-09-Timetable-M` |
| Join Class | `ST-10-OnlineClass-M` |
| Submit HW | `ST-07-HomeworkSubmit-M` |
| KPI Present | `ST-05-Attendance-M` |
| KPI HW due | `ST-06-HomeworkList-M` |
| Homework card | `ST-07-HomeworkDetail-M` |
| Announcement | `ST-15-Notifications-M` detail |
| See all homework | `ST-06-HomeworkList-M` |
| BottomNav Learn | `ST-06-HomeworkList-M` |
| BottomNav Schedule | `ST-09-Timetable-M` |
| BottomNav Results | `ST-12-ExamResults-M` |
| AI icon | `ST-18-AIAssistant-M` |
| Bell | `ST-15-Notifications-M` |

---

## 11. Build Sequence

| Step | Task |
|------|------|
| 1 | Frame + Student shell |
| 2 | AppBar + ClassChip |
| 3 | Hero greeting card |
| 4 | Build PeriodPill (3 state variants) |
| 5 | Timetable horizontal strip |
| 6 | QuickAction component ×2 |
| 7 | KPI compact pair |
| 8 | Announcement card |
| 9 | HomeworkCard ×2 |
| 10 | BottomBar Home active |
| 11 | Boolean: Join Class visible if live |
| 12 | Prototype all links |
| 13 | Variant frame: no live class |

**Total:** ~85 min

---

**End of ST-01 build specification**
