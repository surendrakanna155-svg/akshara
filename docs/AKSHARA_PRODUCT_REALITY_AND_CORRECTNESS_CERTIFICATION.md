<!-- ============================================================================
🔒 CANONICAL SOURCE — FROZEN (integrated into the roadmap 2026-07-11)
This document is the execution authority for the
AKSHARA PRODUCT REALITY & CORRECTNESS CERTIFICATION PROGRAM (PRC).
Roadmap section: docs/roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md → PROGRAM PRC
Per-item tracker:  docs/roadmap/PRODUCT_REALITY_CORRECTNESS_PROGRAM_TRACKER.md (IDs PRC-*)
Every numbered capability, dependency rule, invariant category and execution
rule below is MANDATORY. Do not edit, summarize, compress, reorganize or delete
any line of the body. Scope changes require explicit owner sign-off recorded in
the tracker's merged/conflict register — never a silent edit here.
============================================================================ -->

Update the canonical Akshara execution roadmap and progress tracker.

Do not execute the following audits now.

Schedule them as mandatory post-Adaptive-AI roadmap work, immediately after the Adaptive AI program and any mandatory EOS gate associated with it are complete.

Create a new program:

AKSHARA PRODUCT REALITY & CORRECTNESS CERTIFICATION PROGRAM

This program contains TWO SEPARATE sequential audit-and-fix waves.

Do not merge them.

Do not treat them as documentation-only reviews.

Both are implementation + certification waves.

⸻

WAVE A — REAL SCHOOL OPERATIONS CAPABILITY & CROSS-MODULE GAP AUDIT

MISSION:

Audit Akshara ERP as a real school operating system.

The question is not:

“Does this module or screen exist?”

The question is:

“Can a real school complete the full daily operation entirely inside Akshara without Excel, WhatsApp, paper registers, duplicate entry, hidden backend work, or disconnected module handoffs?”

Current code is authoritative.

For every capability:

1. Inspect the existing implementation.
2. Trace the complete real-world school workflow.
3. Identify upstream dependencies.
4. Identify downstream dependencies.
5. Trace UI → provider/controller → API → service → repository → database.
6. Verify role permissions.
7. Verify live vs mock/stub behaviour.
8. Verify cross-module propagation.
9. Verify dashboards, reports and intelligence receive correct data.
10. Classify the capability.
11. Fix only verified gaps.
12. Add regression tests.
13. Prove the final complete journey.

Use classifications:

* WORKING / LIVE
* PARTIAL
* MISSING
* WRONG UX / OPERATIONAL DESIGN
* MOCK / STUB
* DEVICE-GATED
* NOT APPLICABLE

Never create duplicate modules.

Extend the existing Akshara architecture wherever possible.

Mandatory capability checklist:

1. Transport enrolment, route operations, fleet maintenance and Finance integration.
2. Admission → student transport requirement → transport enrolment.
3. Transport required / not required / own transport / parent pickup-drop handling.
4. Existing student enabling or stopping transport later.
5. Effective-dated transport changes.
6. Mid-month and mid-year transport changes.
7. Route and stop assignment.
8. Route capacity and vehicle capacity.
9. Transport fee applicability based only on eligible transport students.
10. Route/stop/distance/one-way/two-way transport fee policy where supported by school configuration.
11. Active transport student count.
12. Transport cost per active transport student.
13. Transport income vs expense.
14. Bus-wise maintenance.
15. Fuel/diesel expenses.
16. Service history and reminders.
17. Tyres, batteries and repairs.
18. Insurance, fitness, permit and transport compliance.
19. Driver profile and licence validity.
20. Driver → vehicle and route assignment.
21. Driver leave and sudden absence.
22. Substitute driver assignment.
23. Temporary driver and route assignments.
24. GPS source architecture verification.
25. Driver-phone GPS continuity where applicable.
26. Driver replacement → GPS source transfer.
27. GPS stale/offline/permission-revoked states.
28. Parent transport visibility and operational notifications.
29. Finance transport visibility.
30. Principal transport intelligence.
31. School storage quota management.
32. Plan-based storage allocation.
33. Photos, videos and document storage accounting.
34. Storage usage dashboard.
35. Storage warning, soft limit, hard limit and overage.
36. Archive, cleanup, compression and retention.
37. AI credit/token wallet.
38. School-wise AI balance and usage.
39. Feature-wise AI usage.
40. AI low-balance alerts.
41. AI recharge/top-up.
42. AI hard/soft limits.
43. Admin AI credit adjustment.
44. Central AI provider key management.
45. Secure Super Admin provider configuration.
46. Provider key rotation.
47. Provider enable/disable and fallback.
48. Provider health and failure alerts.
49. School AI isolation through entitlements, quotas and credits rather than per-school API keys.
50. SaaS plan limit runtime enforcement.
51. Storage limits.
52. AI limits.
53. SMS limits.
54. User/student/staff limits.
55. Branch/school limits.
56. Feature entitlement enforcement.
57. Upgrade, downgrade, renewal and grace-period behaviour.
58. Simple syllabus progress capture.
59. Teacher chapter/topic progress.
60. Completed/in-progress state.
61. Optional note.
62. Homework linkage.
63. Photo-based progress evidence.
64. No mandatory syllabus timetable dependency.
65. HOD and Principal syllabus visibility.
66. Fee structure bulk assignment.
67. Class-wise and section-wise fee structures.
68. Academic-year fee structures.
69. Bulk student assignment.
70. Student-specific overrides.
71. Scholarship, concession and sibling discount.
72. Transport fee integration.
73. Mid-year admission fee behaviour.
74. Class-transfer fee behaviour.
75. Fee revision and arrears.
76. Marketing AI generation production wiring.
77. Admission/festival/event/achievement poster generation.
78. School branding and templates.
79. AI image/text generation.
80. Marketing approval workflow.
81. AI quota usage integration.
82. Facebook and Instagram production integration.
83. OAuth and secure token storage.
84. Token refresh and expiry.
85. Reconnect flow.
86. Schedule and publish.
87. Publishing failure and retry.
88. Publishing history.
89. Analytics where applicable.
90. Cross-module operational cost intelligence.
91. Transport costs.
92. Fleet costs.
93. Asset and repair costs.
94. Event costs.
95. Inventory and procurement costs.
96. Marketing costs.
97. Finance integration.
98. Principal cost intelligence.
99. Budget vs actual.
100. Cost anomaly detection.
101. Complaint / issue ticket system.
102. Issue photo/video evidence.
103. Classroom/location and asset linkage.
104. Assignment to staff/vendor.
105. Expense linkage.
106. SLA/age/escalation.
107. Resolution proof and reopen.
108. Principal pending-issue visibility.
109. Student early pickup / gate pass.
110. Parent request.
111. School approval.
112. Security visibility.
113. QR/OTP verification.
114. Authorized pickup-person verification.
115. Student release and timestamp.
116. Duplicate-use prevention.
117. Emergency/manual override.
118. Audit trail.
119. School health / infirmary records.
120. Illness and injury records.
121. First aid.
122. Parent notification and acknowledgement.
123. Pickup and hospital escalation.
124. Incident history.
125. Medication authorization.
126. Medication administration audit.
127. Health-data role privacy.
128. Staff workload intelligence.
129. Class and subject load.
130. Period count and free periods.
131. Substitution burden.
132. Non-teaching duties.
133. Exam and event duties.
134. Uneven workload detection.
135. HOD and Principal visibility.
136. Certificate request desk.
137. Bonafide certificate.
138. Study certificate.
139. Transfer certificate.
140. Fee certificate.
141. Request and approval.
142. Data validation.
143. Auto-generation.
144. School template.
145. Authorized signature/stamp workflow.
146. QR/verification code where applicable.
147. PDF and digital delivery.
148. Certificate history and audit trail.

Mandatory dependency rule:

Never certify a final metric or dashboard independently from the data lifecycle that feeds it.

Example:

Transport Cost Per Student

must be traced as:

Admission
→ Transport Requirement
→ Transport Enrolment
→ Effective Date
→ Route/Stop Assignment
→ Transport Fee Applicability
→ Active Transport Student Count
→ Vehicle Operations
→ Maintenance/Fuel Expenses
→ Finance
→ Cost Calculation
→ Principal Dashboard

If any dependency is broken, partial, mocked or incorrectly designed, the final capability is not WORKING / LIVE.

At completion, run the full affected regression gates and EOS.

Only then continue to Wave B.

⸻

WAVE B — PRODUCT CORRECTNESS, INVARIANT & EDGE-CASE CERTIFICATION

MISSION:

Certify that existing Akshara functionality remains mathematically, financially, temporally, logically and operationally correct under real-world boundary conditions.

This is NOT a new-feature wave.

Do not invent product features.

Audit the existing product and all workflows certified by Wave A.

The core question is:

“Is every existing Akshara result correct at normal values, boundary values, extreme values, date transitions, money precision cases, repeated actions, concurrent actions and cross-module propagation?”

Build an exhaustive invariant and edge-case inventory from the ACTUAL codebase.

At minimum audit:

MONEY AND FINANCE CORRECTNESS

* Integer and decimal amounts
* Paise precision
* Floating-point leakage
* Decimal arithmetic
* Rounding policy
* Half-up / configured rounding behaviour where applicable
* ₹0
* Negative values
* Extremely small amounts
* Extremely large amounts
* Invalid precision
* ₹999.995-type boundaries
* Line-item rounding vs final-total rounding
* Round-off ledger treatment
* Discounts
* Concessions
* Scholarships
* Sibling discounts
* Multiple discount interaction
* Tax/discount order where applicable
* Partial payment
* Split payment
* Overpayment
* Underpayment
* Advance payment
* Refund
* Partial refund
* Duplicate payment
* Reversed payment
* Failed payment
* Pending payment
* Idempotency
* Arrears
* Carry-forward
* Credit balance
* Outstanding balance
* Budget vs actual
* Income vs expense
* Cost per student
* Cost per active transport student
* Indian currency formatting
* Indian digit grouping
* Export precision
* Report precision

DATE AND TIME CORRECTNESS

* February 28
* February 29
* Leap year
* Non-leap century
* Leap century
* Month end
* 30-day month
* 31-day month
* Year end
* Calendar-year transition
* Academic-year transition
* Midnight
* Date rollover
* IST behaviour
* UTC ↔ IST conversion
* Server/client timezone differences
* Future dates
* Past dates
* Invalid dates
* DOB calculations
* February 29 DOB
* Student age
* Admission age eligibility
* Fee due dates
* Holiday due dates
* Exam dates
* Attendance dates
* Leave dates
* Driver leave dates
* Certificate dates
* Effective-dated transport assignments
* Start/end inclusive boundaries
* Expiry boundaries
* Insurance/permit/licence expiry
* Same-day changes

PERIOD AND PRORATION CORRECTNESS

* Monthly periods
* Quarterly periods
* Annual periods
* Academic-year periods
* Mid-month admission
* Mid-year admission
* Mid-month transport start
* Mid-month transport stop
* Route change
* Fee change
* Staff joining mid-month
* Staff leaving mid-month
* Salary proration
* Attendance denominator
* Working-day denominator
* Holidays
* Unexpected closures
* Exam periods
* Period overlap
* Missing period
* Duplicate period

CALCULATOR AND FORMULA TRUTH

Identify every formula in the actual product.

At minimum verify:

* Fee totals
* Fee outstanding
* Collection totals
* Discounts
* Concessions
* Refund totals
* Payroll
* Salary components
* Attendance percentage
* Marks percentage
* GPA/grade where applicable
* Rank
* Class averages
* Exam analytics
* Budget vs actual
* Inventory valuation
* Asset costs
* Operational costs
* Transport costs
* Cost per student
* Cost per transport student
* AI usage/credit calculations
* Storage quota calculations
* SMS quota calculations

For every formula create a canonical definition.

Prove identical input produces equivalent truth across:

DATABASE
→ SERVICE
→ API
→ FLUTTER UI
→ DASHBOARD
→ REPORT
→ PDF
→ EXCEL/CSV EXPORT
→ AI/COPILOT ANSWER WHERE APPLICABLE

No layer may independently reinterpret the same business formula.

BOUNDARY AND EXTREME VALUES

Test:

* Zero records
* One record
* Maximum expected records
* Large school
* Large class
* Large fee ledger
* Large attendance history
* Large media usage
* Large AI usage history
* Empty strings
* Unicode
* Telugu text
* Long names
* Long addresses
* Long notes
* Duplicate names
* Same student names
* Missing optional data
* Deleted referenced data
* Archived data
* Historical academic years

REPEATED ACTION AND IDEMPOTENCY

Test:

* Double tap
* Rapid repeated tap
* Retry after timeout
* Refresh during mutation
* Navigate away during mutation
* App restart during mutation
* Network failure after server success
* Client receives no response after successful DB write
* Repeated approval
* Repeated payment callback
* Repeated attendance submission
* Repeated certificate generation
* Repeated gate-pass verification
* Repeated transport assignment
* Repeated social publish request

One logical action must not create unintended duplicate business records.

CONCURRENCY AND RACE CONDITIONS

Audit realistic concurrent operations:

* Two admins edit the same student
* Two Finance users record payment
* Teacher and admin update attendance
* Two approvers act on one request
* Driver replacement while trip starts
* Route assignment while student transport status changes
* Fee structure changes during payment
* Inventory issue during stock update
* Storage upload at quota boundary
* AI requests at credit boundary
* Social token refresh during publish

Define and test conflict behaviour.

Never allow silent data corruption.

CROSS-MODULE TRUTH CONSISTENCY

For every important mutation identify all affected modules.

Example:

Student stops transport

must correctly affect:

* Student profile
* Transport enrolment
* Route manifest
* Vehicle occupancy
* Parent tracking
* Transport fee applicability
* Future billing
* Active transport student count
* Cost-per-student denominator
* Principal dashboard
* Transport reports

Build a mutation propagation matrix.

Prove stale dashboards and stale reports do not silently present conflicting truth.

DELETE, ARCHIVE AND HISTORICAL INTEGRITY

Audit:

* Soft delete
* Hard delete where legally/product-appropriate
* Archive
* Restore
* Referential integrity
* Historical reports
* Academic-year history
* Student withdrawal
* Staff exit
* Vehicle retirement
* Route retirement
* Deleted media
* Deleted user
* School deactivation

Historical financial and operational truth must not be corrupted by current-state deletion.

EXPORT AND REPORT CONSISTENCY

Verify:

* PDF
* CSV
* Excel where supported
* Print views
* Dashboard totals
* Detailed reports

Test:

* Same totals
* Same date range
* Same timezone
* Same rounding
* Same filters
* Same inclusion/exclusion rules

Exports must not calculate business truth differently from the product.

AI / COPILOT TRUTH BOUNDARY

Where AI answers questions about Akshara data:

Verify:

* AI receives correct scoped data
* Tenant isolation
* Role isolation
* Correct date range
* Correct currency values
* Correct calculated totals
* No invented records
* No stale summary presented as current
* Deterministic calculations are not delegated unnecessarily to AI
* AI explanation does not override canonical business calculations

Financial, attendance, fee, marks and operational calculations must come from deterministic product truth.

AI may explain.

AI must not invent the calculation result.

FAILURE AND RECOVERY

Test:

* API timeout
* Database timeout
* Partial dependency failure
* Storage failure
* AI provider failure
* SMS failure
* Social provider failure
* GPS stale/offline
* Export failure
* Background task failure

Verify:

* No false success
* No duplicate mutation
* No silent data loss
* Clear user feedback
* Safe retry
* Recoverable state
* Audit trail where required

⸻

PROGRAM EXECUTION RULE

When the Adaptive AI program completes:

1. Automatically begin Wave A if no higher-priority blocking production gate exists.
2. Complete Wave A.
3. Fix verified operational and cross-module gaps.
4. Run regression and EOS.
5. Automatically begin Wave B.
6. Derive the exhaustive invariant/edge-case inventory from the then-current codebase.
7. Execute correctness certification.
8. Fix verified defects.
9. Add regression tests.
10. Run complete affected regression gates.
11. Run final EOS.
12. Update roadmap, progress tracker, findings, certification reports and EOS ledger.

Do not stop after producing audit documents.

Do not return a list of findings and wait for the owner to choose each defect.

Continue autonomously through verified fixes unless:

* a product-policy decision is genuinely ambiguous,
* a destructive migration requires owner approval,
* an external paid provider/credential is required,
* or physical-device-only verification is impossible locally.

In those cases classify the exact blocker and continue all other runnable work.

Preserve all existing certified behaviour.

Do not weaken tests to create green results.

Do not confuse feature breadth with product correctness.

The goal is not to add more features.

The goal is to make the existing Akshara ERP operate as one connected, mathematically correct, financially correct, temporally correct, edge-case-safe, production-grade school operating system.


AKSHARA ERP — REAL SCHOOL OPERATIONS CAPABILITY & CROSS-MODULE GAP AUDIT
MISSION
Audit Akshara ERP as a real school operating system.
Do not ask only:
“Does this module exist?”
Ask:
“Can a real school complete this operation fully inside Akshara without Excel, WhatsApp, paper registers, duplicate entry, or hidden backend work?”
Current code is authoritative.
Do not assume a feature is missing.
Do not assume an existing screen means the workflow is complete.
For every capability:
1. Inspect current implementation.
2. Trace the complete user journey.
3. Trace cross-module dependencies.
4. Verify UI → API → service → repository → database.
5. Verify role permissions.
6. Verify live vs mock/stub behaviour.
7. Verify downstream reporting and intelligence.
8. Classify the capability.
9. Fix only verified gaps.
10. Add regression tests.
11. Prove the final complete journey.
CLASSIFICATION
Use exactly:
* WORKING / LIVE
* PARTIAL
* MISSING
* WRONG UX / OPERATIONAL DESIGN
* MOCK / STUB
* DEVICE-GATED
* NOT APPLICABLE
Never create duplicate modules when an existing Akshara module can be extended.

⸻

1. TRANSPORT ENROLMENT, ROUTE OPERATIONS, FLEET MAINTENANCE & FINANCE INTEGRATION
This must be audited as one connected operational domain.
Do not audit GPS, routes, buses, students, maintenance, and finance as isolated features.
1.1 Student Transport Requirement
Not every student uses school transport.
Verify Akshara has an explicit student transport state such as:
* Transport required
* Transport not required
* Own transport
* Parent pickup/drop
* Other configured transport mode
Verify the state is not inferred incorrectly merely because a student exists in a class or school.
A non-transport student must never automatically appear in:
* Bus occupancy
* Route passenger list
* Stop list
* Transport fee assignment
* Transport cost-per-student calculation
* Parent bus tracking
* Transport alerts
1.2 Admission → Transport Integration
During admission, verify the school can capture:
* Does the student require school transport?
* Pickup location
* Drop location, if different
* Preferred/nearest stop where applicable
* Transport start date
* One-way or two-way transport where supported
* Special transport note where applicable
If Transport Required = YES:
The admission workflow must create or initiate the student’s transport enrolment.
Expected flow:
Admission → Transport Required = YES → Pickup/Drop Information → Transport Enrolment → Route/Stop Assignment → Vehicle/Route Passenger Mapping → Transport Fee Applicability → Parent Transport Visibility
If Transport Required = NO:
The student must remain outside transport operational and financial calculations.
Verify whether admission completion:
* Automatically creates transport enrolment
* Creates a pending transport assignment
* Notifies the transport administrator
* Requires a safe manual assignment step
Determine the correct existing Akshara architecture and extend it rather than creating duplicate data.
1.3 Existing Student Transport Enrolment
Verify transport can be enabled later for an existing student.
Example:
Student joined in June without school transport.
In August, parent requests school transport.
Required journey:
Student Profile / Transport Request → Enable Transport → Effective Date → Pickup/Drop → Route/Stop Assignment → Transport Fee Adjustment → Parent Visibility
Also verify transport can be stopped.
Required journey:
Stop Transport → Effective Date → Remove Future Route Passenger Assignment → Stop Future Transport Fee Applicability → Preserve Historical Transport Records → Recalculate Current Transport Metrics
Historical records must not be deleted.
1.4 Mid-Month / Mid-Year Transport Changes
Verify:
* Transport starts mid-month
* Transport stops mid-month
* Student changes home address
* Student changes pickup stop
* Student changes route
* Student changes from one-way to two-way transport
* Student temporarily stops transport
* Student resumes transport
Verify impact on:
* Passenger manifests
* Route capacity
* Transport fees
* Parent tracking
* Cost analytics
* Historical reporting
Do not silently rewrite historical route assignments.
Use effective dates or equivalent temporal assignment architecture.
1.5 Route and Stop Assignment
Verify:
* Route creation
* Route direction
* Stops
* Stop order
* Pickup time
* Drop time
* Students assigned per stop
* Route capacity
* Vehicle capacity
* Student count
* Route change
* Stop change
* Temporary route reassignment
Verify a student can only appear on the correct active route manifest.
Check duplicate assignment protection.
Check whether one student can accidentally be active on multiple conflicting routes.
1.6 Transport Fee Integration
Verify transport enrolment is connected to fee applicability.
Do not assume every student pays transport fees.
Verify:
Transport Required = NO → No transport fee by default
Transport Required = YES → Correct transport fee rule applies
Audit whether transport fee can be based on:
* Route
* Stop
* Distance/slab
* One-way/two-way service
* Flat school transport fee
* School-configured fee policy
Verify:
* Admission-time transport enrolment
* Existing student enabling transport
* Transport stopping
* Route change
* Stop change
* Mid-year changes
* Concession/override
All correctly affect fee applicability.
Do not duplicate the Finance fee engine.
Transport must provide applicability and required fee context to the existing fee architecture.
1.7 Transport Student Count
Define transport student count correctly.
It must count only students with an active school transport enrolment for the relevant period.
Do not use:
* Total school students
* Total class students
* Historical transport users
* Students with an old route record
Verify counts by:
* School
* Branch
* Route
* Vehicle
* Academic year
* Month/reporting period
1.8 Transport Cost Per Student
This metric is valid only when transport enrolment data is correct.
Verify:
Transport Cost Per Active Transport Student
Eligible Transport Operational Cost / Active Transport Student Count
Eligible costs may include, according to school accounting policy:
* Fuel/diesel
* Vehicle repairs
* Service
* Tyres
* Batteries
* Insurance allocation
* Fitness/permit costs
* GPS/device costs
* Driver operational costs
* Other configured transport expenses
Do not divide transport costs by total school student strength.
Support:
* School-wide transport cost per student
* Route-wise cost per student
* Vehicle-wise cost per student
* Monthly trend
* Academic-year trend
Verify zero-student and incomplete-data handling.
Never display misleading financial metrics when the denominator or expense mapping is incomplete.
1.9 Transport Income vs Expense
Verify transport-related fee income can be compared with transport operational expenses.
Required visibility:
* Transport fee billed
* Transport fee collected
* Transport fee outstanding
* Transport operating cost
* Route-wise cost where data supports it
* Vehicle-wise cost
* Cost per transport student
* Income vs expense
* Surplus/deficit
Finance and Principal must see the correct authorized views.
1.10 Fleet Maintenance
Verify:
* Bus-wise maintenance records
* Fuel/diesel expenses
* Service history
* Next-service reminders
* Odometer-based service where supported
* Tyres
* Battery
* Repairs
* Insurance expiry
* Fitness expiry
* Permit expiry
* Pollution/compliance records where applicable
* GPS device maintenance
* Vehicle documents
* Vendor/payable linkage
* Attachments/bills
* Maintenance history
Required journey:
Vehicle → Maintenance / Fuel / Compliance Expense → Finance → Transport Cost Analytics → Principal Visibility
1.11 Driver Assignment
Verify:
* Driver profile
* Licence details
* Licence expiry
* Driver availability
* Driver → vehicle assignment
* Driver → route assignment
* Effective dates
* Temporary assignment
* Assignment history
Do not assume a vehicle permanently belongs to one driver.
1.12 Driver Leave / Absence
Audit the real operational failure case:
Assigned driver is absent.
Required journey:
Driver Absent → Route At Risk → Transport Team Alert → Available Substitute Driver Identified → Substitute Assigned → Vehicle/Route Access Updated → GPS Source Validated → Parents Notified If Operationally Necessary → Route Completed → Temporary Assignment Expires → Original Assignment Restored
Verify:
* Driver leave integration
* Sudden absence/manual absence
* Substitute driver availability
* Licence validity
* Conflicting route assignment
* Acknowledgement
* Audit trail
1.13 GPS Source and Driver Change
Determine the actual Akshara GPS architecture.
Explicitly verify whether live location comes from:
* Dedicated vehicle GPS hardware
* Driver phone
* Driver app
* Third-party GPS provider
* Mock/stub source
If GPS depends on the driver’s phone:
Verify driver replacement correctly transfers operational GPS responsibility.
Example:
Driver A assigned to Route 5 → Driver A absent → Driver B assigned → Driver B receives route → Driver B starts trip → Driver B device becomes active GPS source → Parent sees correct bus location
The old driver’s phone must not continue as the active route location source.
Verify:
* Background location permission
* GPS disabled
* Permission revoked
* No internet
* Stale location
* Driver app killed
* Wrong driver starts trip
* Two drivers attempt to start same route
* Trip end
* Temporary assignment expiry
1.14 Principal and Finance Visibility
Principal dashboard should be able to understand:
* Active transport students
* Students without completed route assignment
* Route capacity problems
* Vehicles under maintenance
* Driver absence impact
* Routes at operational risk
* Transport fee outstanding
* Transport operating cost
* Cost per active transport student
* High-cost vehicles
* High-cost routes
* Upcoming compliance expiry
* Maintenance anomalies
Finance should see:
* Transport expenses
* Expense source
* Vehicle/route linkage where available
* Vendor/payables
* Transport income
* Outstanding transport fees
* Income vs expense
Do not expose operational controls to unauthorized Finance roles.

⸻

2. SCHOOL STORAGE QUOTA MANAGEMENT
Verify:
* School-wise storage allocation
* Plan-based GB limits
* Photos
* Videos
* Documents
* Current usage
* Usage by category
* Warning thresholds
* Hard/soft limits
* Overage handling
* Upgrade flow
* Archive
* Cleanup
* Compression
* Retention policy
* Deleted-file lifecycle
* Super Admin visibility
Verify all school media-producing modules use the same quota accounting system.

⸻

3. AI CREDIT / TOKEN WALLET
Verify:
* School-wise AI credits
* Usage tracking
* Feature-wise AI usage
* Balance
* Low-balance alerts
* Hard limit
* Soft limit
* Recharge/top-up
* Renewal credits
* Admin adjustment
* Promotional credits
* Usage history
* Cost visibility
* Abuse protection
All AI-consuming modules must use one governed usage/credit architecture.

⸻

4. CENTRAL AI PROVIDER KEY MANAGEMENT
Verify:
* Platform-level provider keys
* Secure Super Admin UI
* Add/update provider configuration
* Key rotation
* Provider enable/disable
* Provider fallback
* Health check
* Secret masking
* Audit trail
* Failure alerts
Schools must not manually configure provider API keys.
School isolation must happen through:
* Entitlements
* Quotas
* Credits
* Usage policy
Not separate provider-key setup.

⸻

5. SAAS PLAN LIMIT ENFORCEMENT
Verify actual runtime enforcement for:
* Storage
* AI credits
* SMS
* Users
* Students
* Staff
* Branches/schools
* Feature access
* Marketing generation
* Social publishing
* Relevant reports/exports
Verify:
* Warning
* Soft limit
* Hard limit
* Upgrade
* Grace period
* Renewal
* Downgrade
* Super Admin override
Do not certify configuration tables alone.
Prove enforcement through real workflows.

⸻

6. SIMPLE SYLLABUS PROGRESS CAPTURE
Do not require a mandatory syllabus timetable.
Verify a simple teacher workflow:
Class → Subject → Chapter/Topic → Completed / In Progress → Optional Note → Optional Homework Link → Optional Photo → Save
Verify:
* Teacher update history
* Progress percentage
* HOD visibility
* Principal visibility
* Section comparison
* Delayed progress alerts
Prefer low-friction daily teacher interaction.

⸻

7. FEE STRUCTURE BULK ASSIGNMENT
Verify:
* Class-wise structure
* Section-wise structure
* Academic-year structure
* Bulk assignment
* Individual override
* Scholarship
* Concession
* Sibling discount
* Transport fee applicability
* Optional components
* Mid-year admission
* Class transfer
* Fee revision
* Arrears
* Audit history
Required journey:
Create Fee Structure → Assign Class/Section → Bulk Apply → Student Exceptions → Collection → Reports
Transport fee must respect active student transport enrolment.

⸻

8. MARKETING AI GENERATION — PRODUCTION WIRING
Verify:
* Admission posters
* Festival posters
* Event posters
* Achievement posters
* Social content
* School logo
* Branding
* Brand colours
* Templates
* AI image generation
* AI text generation
* Approval
* AI quota usage
* Generation history
* Regenerate/edit
* Download/share
* Actual production provider wiring

⸻

9. FACEBOOK / INSTAGRAM INTEGRATION
Verify:
* Account/page connection
* OAuth
* Secure token storage
* Token refresh
* Expiry
* Reconnect
* Schedule post
* Publish now
* Image publishing
* Video publishing where supported
* Caption
* Failed-post handling
* Retry
* Publishing history
* Disconnect
* Permission failure
* Analytics where applicable
* Audit trail
Do not certify UI-only integration.

⸻

10. CROSS-MODULE OPERATIONAL COST INTELLIGENCE
Verify expense integration from:
* Transport
* Fleet maintenance
* Assets
* Repairs
* Events
* Inventory
* Procurement
* Marketing
* Other school operations
Required visibility:
* Finance
* Principal
* Department/module-wise cost
* Monthly trends
* Budget vs actual
* Cost anomalies
* AI operational insights

⸻

11. COMPLAINT / ISSUE TICKET SYSTEM
Verify:
* Issue creation
* Photo/video
* Location/classroom
* Category
* Priority
* Assignment
* Responsible staff/vendor
* Status
* Comments
* Expense linkage
* Asset linkage
* SLA/age
* Escalation
* Resolution proof
* Reopen
* Principal pending visibility
Required journey:
Report → Assign → Repair → Expense → Resolve → Principal Visibility

⸻

12. STUDENT EARLY PICKUP / GATE PASS
Verify:
* Parent request
* Reason
* Pickup person
* Approval
* Parent notification
* Security visibility
* QR/OTP
* Authorized-person verification
* Student release
* Timestamp
* Rejection
* Emergency override
* Duplicate-use prevention
* Audit trail
Required journey:
Parent Request → Approval → Gate Verification → Student Release → Audit Log

⸻

13. SCHOOL HEALTH / INFIRMARY RECORD
Verify:
* Illness
* Injury
* Incident notes
* First aid
* Handling staff
* Parent notification
* Parent acknowledgement
* Pickup
* Hospital escalation
* Emergency contact
* Incident history
* Repeat incident visibility
* Medication authorization
* Medication administration audit
* Attachments
* Role-based privacy
Medication must not be stored as casual notes only.

⸻

14. STAFF WORKLOAD INTELLIGENCE
Verify:
* Class load
* Subject load
* Period count
* Free periods
* Substitution burden
* Repeated substitutions
* Non-teaching duties
* Exam duties
* Event duties
* Uneven workload detection
* Department comparison
* Principal/HOD visibility
* Alerts
* Historical trends

⸻

15. CERTIFICATE REQUEST DESK
Verify requests for:
* Bonafide Certificate
* Study Certificate
* Transfer Certificate
* Fee Certificate
* Configured certificate types
Verify:
* Request
* Details/reason
* Approval
* Rejection
* Data validation
* Auto-generation
* School template
* Authorized signature/stamp workflow
* QR/verification code where applicable
* PDF
* Digital delivery
* Download
* History
* Audit trail
Required journey:
Request → Review → Approve → Generate → Deliver

⸻

FINAL CROSS-MODULE AUDIT RULE
For every capability, identify upstream and downstream dependencies.
Example:
Transport Cost Per Student
must not be audited as one dashboard formula.
Trace:
Admission → Transport Requirement → Transport Enrolment → Route/Stop Assignment → Active Date Range → Transport Fee Applicability → Vehicle/Route Operations → Transport Expenses → Finance → Active Transport Student Count → Cost Calculation → Principal Dashboard
If any dependency is missing, partial, mock, or incorrectly designed:
The final capability is not WORKING / LIVE.
Document the exact broken dependency.
Run GSTACK impact analysis.
Extend existing architecture.
Fix only verified gaps.
Add regression coverage.
Prove the complete cross-module journey.
Never create duplicate modules.
Never mark a capability complete because isolated screens or tables exist.
The final question remains:
“Can a real school perform this operation completely and correctly inside Akshara without Excel, WhatsApp, paper registers, duplicate entry, or hidden manual backend work?”
