# Future Vision — AI School Builder (AI-Configured School Operating System)

> **STATUS: FUTURE STRATEGIC INITIATIVE — DO NOT BUILD NOW.**
> Priority: HIGH. Captured 2026-06-20. This is a recorded vision, not an active task.
>
> **Implement only AFTER these are completed (hard prerequisites):**
> 1. Workspace Architecture Consolidation
> 2. Navigation Simplification
> 3. Mobile UX Modernization
> 4. Screen Consolidation
>
> Do not start any part of this until the owner confirms the four prerequisites
> above are done.

---

## The core idea

Akshara should **not** be a fixed ERP with hundreds of identical menus for every
school. It should become an **AI-configured School Operating System** that
**generates a different experience for every school** based on what that school
actually is.

Every school is different — CBSE, State Board, ICSE, residential, day, IIT
Foundation, NEET Foundation, corporate, small local — and most ERPs force them
all into the same UI. Akshara should do the opposite.

**Success metric:** a principal should feel *"This ERP looks like it was built
specifically for my school,"* not *"This is a generic ERP with hundreds of menus."*

---

## AI School Builder — onboarding interview

During first-time school startup setup, Akshara asks **structured questions**,
then the AI generates the school's tailored workspaces, navigation, dashboards,
and cards.

### School Profile
- **Board:** CBSE · ICSE · State Board · IB · Cambridge · Custom
- **School Type:** Day · Residential · Semi-Residential · Foundation · Coaching-Integrated
- **Student Strength:** <500 · 500–2000 · 2000–5000 · 5000+

### Facilities (which exist?)
Transport · Hostel · Library · Inventory · Smart Classes · Health Room · Mess · Cafeteria

### Academic Programs (what does the school provide?)
Regular Academics · IIT Foundation · NEET Foundation · Olympiad · NTSE · Coding ·
Robotics · Abacus · Spoken English

### Communication Preferences (preferred channels)
App Notifications · WhatsApp · SMS · Email

---

## AI output — what gets generated

### 1. Workspaces (role-scoped bundles of relevant modules)
- **Teacher Workspace:** Attendance · Homework · Exams · Messages
- **Finance Workspace:** Collections · Refunds · Concessions
- **Transport Workspace:** Routes · Vehicles · Drivers · Attendance
- **Hostel Workspace:** Rooms · Wardens · Mess

### 2. Dynamic navigation (users see ONLY relevant items)
- **Parent (Day School):** Attendance · Homework · Fees · Results · Messages
- **Parent (Residential):** + Hostel · Mess · Health
- **Parent (IIT Foundation):** Attendance · Homework · Fees · Results · Weekly
  Tests · JEE Progress · Rank Trends

### 3. Dynamic dashboards (KPIs by school type)
- **Day School Principal:** Attendance % · Fee Collection · Exam Performance
- **Foundation Principal:** Attendance % · Fee Collection · IIT Mock Test
  Rankings · Top Performers · Subject Analytics

### 4. Dynamic cards (quick actions by role)
- **Teacher:** Mark Attendance · Today's Classes · Pending Homework Review ·
  Pending Exam Marks
- **Parent:** Child Attendance · Fees Due · Homework Pending · Messages

---

## Question Intelligence Platform — future integration

A Question Paper Intelligence Platform that generates papers **within strict
curriculum boundaries**.

**Inputs:** Board · Class · Subject · Chapter · Blueprint · Difficulty

**Sources:** Previous question papers · Question banks · Syllabus PDFs · Teacher
question repositories · Foundation program material

**Hard guardrails the AI MUST respect:**
- Stay within syllabus boundaries
- Respect board curriculum
- Respect class level
- Respect blueprint weightage
- Respect difficulty level

**Examples:**
- *Class 8 CBSE Science* → must **NOT** generate Class 12 questions.
- *Class 6 IIT Foundation* → may generate advanced foundation-style questions,
  but still within the foundation curriculum the school selected.

---

## Example school configurations

**Example 1 — Small CBSE Day School**
- Enabled: Attendance · Homework · Exams · Fees · Messages
- Hidden: Hostel · Transport · Inventory · Health

**Example 2 — Residential School**
- Enabled: Attendance · Homework · Exams · Fees · Hostel · Mess · Health · Transport

**Example 3 — IIT Foundation School**
- Enabled: Attendance · Homework · Exams · Fees · Question Intelligence Platform ·
  Weekly Tests · Rank Analytics · JEE Progress Tracking

---

## Notes for whoever implements this later
- Much of the substrate already exists in the codebase and should be **reused, not
  rebuilt**: `SchoolCurriculum` enum + onboarding (`UnifiedOnboardingState`),
  the dynamic widgets/dashboard feature area, role-based permissions + route
  guards, and the per-persona read-models (parent/teacher/student entities).
- The "facilities exist?" answers map naturally onto the existing module/route
  visibility + permission system — dynamic navigation is largely a matter of
  gating already-built modules per school config, not new screens.
- This depends on the four consolidation prerequisites precisely because it
  generates UI on top of the workspace/navigation structure — that structure must
  be stable and simplified first, or the generator will encode today's complexity.
