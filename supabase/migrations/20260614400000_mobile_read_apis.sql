-- v6.2 Sprint 4 Phase 4 — Parent, Teacher, Student mobile read APIs

CREATE TABLE parent_entities (
  id TEXT NOT NULL,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL,
  entity_type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (organization_id, school_id, student_id, entity_type, id)
);
CREATE INDEX idx_parent_entities_scope ON parent_entities (organization_id, school_id, student_id, entity_type);
CREATE TRIGGER parent_entities_updated_at BEFORE UPDATE ON parent_entities FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE teacher_entities (
  id TEXT NOT NULL,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  entity_type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (organization_id, school_id, entity_type, id)
);
CREATE INDEX idx_teacher_entities_org_school_type ON teacher_entities (organization_id, school_id, entity_type);
CREATE TRIGGER teacher_entities_updated_at BEFORE UPDATE ON teacher_entities FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE student_entities (
  id TEXT NOT NULL,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL,
  entity_type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (organization_id, school_id, student_id, entity_type, id)
);
CREATE INDEX idx_student_entities_scope ON student_entities (organization_id, school_id, student_id, entity_type);
CREATE TRIGGER student_entities_updated_at BEFORE UPDATE ON student_entities FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE parent_entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE parent_entities FORCE ROW LEVEL SECURITY;
ALTER TABLE teacher_entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_entities FORCE ROW LEVEL SECURITY;
ALTER TABLE student_entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_entities FORCE ROW LEVEL SECURITY;

CREATE POLICY parent_entities_parent_scope ON parent_entities
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'parent'
    AND school_id = app_current_school_id()
    AND student_id IN (
      SELECT sg.student_id
      FROM student_guardians sg
      WHERE sg.guardian_user_id = app_current_parent_user_id()
        AND sg.status = 'active'
    )
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'parent'
    AND school_id = app_current_school_id()
    AND student_id IN (
      SELECT sg.student_id
      FROM student_guardians sg
      WHERE sg.guardian_user_id = app_current_parent_user_id()
        AND sg.status = 'active'
    )
  );

CREATE POLICY teacher_entities_school_scope ON teacher_entities
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

CREATE POLICY student_entities_student_scope ON student_entities
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'student'
    AND school_id = app_current_school_id()
    AND student_id = app_current_student_id()
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'student'
    AND school_id = app_current_school_id()
    AND student_id = app_current_student_id()
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON parent_entities TO erp_tenant;
GRANT SELECT, INSERT, UPDATE, DELETE ON teacher_entities TO erp_tenant;
GRANT SELECT, INSERT, UPDATE, DELETE ON student_entities TO erp_tenant;

-- Parent mobile seeds (School A — linked student a4000000-0000-4000-8000-000000000001)
INSERT INTO parent_entities (id, organization_id, school_id, student_id, entity_type, payload) VALUES
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'snapshot_dashboard',
 '{"childName":"Ravi Kumar","childClass":"8-A","greetingEyebrow":"Good morning","greetingHeadline":"Ravi is on track today","schoolName":"Akshara Public School","unreadNotifications":2,"statusChips":[],"quickActions":[],"todaySummary":[],"notices":[],"events":[],"aiInsight":{"message":"Attendance steady this week.","actionLabel":"View details"}}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'snapshot_attendance',
 '{"month":"2026-06","childName":"Ravi Kumar","childClass":"8-A","kpi":{"attendancePercent":94,"absentDays":1,"lateDays":0},"calendarDays":[],"recentLogs":[],"unreadNotifications":0}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'snapshot_homework',
 '{"childName":"Ravi Kumar","childClass":"8-A","items":[],"insightMessage":"No pending homework.","insightActionLabel":"View all","unreadNotifications":0}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'snapshot_exams',
 '{"childName":"Ravi Kumar","childClass":"8-A","unreadNotifications":0,"upcomingExams":[],"examResults":[]}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'snapshot_timetable',
 '{"childName":"Ravi Kumar","childClass":"8-A","weekRangeLabel":"9–13 Jun","totalPeriodsThisWeek":30,"completedPeriodsToday":3,"upcomingPeriodsToday":2,"unreadNotifications":0,"days":[]}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'snapshot_fees',
 '{"childName":"Ravi Kumar","childClass":"8-A","summaryLabel":"Term 2 due","totalDue":4200,"installments":[],"unreadNotifications":0}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'snapshot_events',
 '{"childName":"Ravi Kumar","childClass":"8-A","upcomingEvents":[],"unreadNotifications":0}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'snapshot_profile',
 '{"parentName":"Suresh Kumar","phoneLabel":"+91 98765 43210","email":"suresh.kumar@email.com","schoolName":"Akshara Public School","unreadNotifications":2,"children":[{"id":"a4000000-0000-4000-8000-000000000001","name":"Ravi Kumar","classLabel":"8-A","isActive":true}]}'::jsonb),
('term_2', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'payment_summary',
 '{"installmentId":"term_2","title":"Term 2 Fees","amountDue":4200,"dueDateLabel":"15 Jun 2026","childName":"Ravi Kumar","lineItems":[]}'::jsonb),
('receipt_1', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'receipt',
 '{"id":"receipt_1","receiptNumber":"RCP-001","title":"Term 1 Payment","dateLabel":"1 Apr 2026","amount":4200,"paymentMethod":"UPI","statusLabel":"Paid","childName":"Ravi Kumar","childClass":"8-A","category":"Tuition","lineItems":[],"schoolName":"Akshara Public School"}'::jsonb),
('notice_1', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'notice',
 '{"id":"notice_1","title":"PTM scheduled","dateLabel":"12 Jun 2026","isUrgent":false,"body":"Parent-teacher meeting on Friday."}'::jsonb),
('bh000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'probe',
 '{"id":"bh000000-0000-4000-8000-000000000001","label":"Parent Probe A"}'::jsonb);

INSERT INTO parent_entities (id, organization_id, school_id, student_id, entity_type, payload) VALUES
('bh000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000002', 'a4000000-0000-4000-8000-000000000002', 'probe',
 '{"id":"bh000000-0000-4000-8000-000000000002","label":"Parent Probe B"}'::jsonb);

-- Teacher mobile seeds (school scoped)
INSERT INTO teacher_entities (id, organization_id, school_id, entity_type, payload) VALUES
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_dashboard',
 '{"greetingHeadline":"Good morning, Meera","schoolName":"Akshara Public School","unreadNotifications":1,"todayClasses":[],"pendingTasks":[],"aiInsight":{"message":"2 classes need attendance today.","actionLabel":"Mark now"}}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_attendance_students',
 '{"classLabel":"8-A","dateLabel":"10 Jun 2026","students":[],"summary":{"present":0,"absent":0,"late":0}}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_timetable',
 '{"weekRangeLabel":"9–13 Jun","days":[],"unreadNotifications":0}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_leave_balance',
 '{"casual":{"total":12,"used":3,"remaining":9},"sick":{"total":10,"used":1,"remaining":9}}'::jsonb),
('class_8a', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'attendance_class',
 '{"id":"class_8a","label":"8-A Mathematics","studentCount":32,"pendingCount":5}'::jsonb),
('hw_1', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'homework_assignment',
 '{"id":"hw_1","title":"Algebra worksheet","classLabel":"8-A","dueLabel":"12 Jun","pendingReviews":3}'::jsonb),
('exam_1', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'upcoming_exam',
 '{"id":"exam_1","title":"Unit Test 2","classLabel":"8-A","dateLabel":"18 Jun 2026"}'::jsonb),
('mark_1', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'exam_mark',
 '{"id":"mark_1","studentName":"Ravi Kumar","subject":"Mathematics","scoreObtained":42,"maxScore":50}'::jsonb),
('leave_1', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'leave_request',
 '{"id":"leave_1","fromDateLabel":"1 Jun 2026","toDateLabel":"1 Jun 2026","status":"approved","type":"casual"}'::jsonb),
('thread_1', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'message_thread',
 '{"id":"thread_1","subject":"Class 8-A update","lastMessagePreview":"Reminder for tomorrow.","unreadCount":1}'::jsonb),
('bj000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'probe',
 '{"id":"bj000000-0000-4000-8000-000000000001","label":"Teacher Probe A"}'::jsonb);

INSERT INTO teacher_entities (id, organization_id, school_id, entity_type, payload) VALUES
('bj000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000002', 'probe',
 '{"id":"bj000000-0000-4000-8000-000000000002","label":"Teacher Probe B"}'::jsonb);

-- Student mobile seeds
INSERT INTO student_entities (id, organization_id, school_id, student_id, entity_type, payload) VALUES
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'snapshot_dashboard',
 '{"studentName":"Ravi Kumar","classLabel":"8-A","greetingHeadline":"Stay focused today","schoolName":"Akshara Public School","unreadNotifications":1,"todaySummary":[],"notices":[],"aiInsight":{"message":"Math homework due tomorrow.","actionLabel":"View homework"}}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'snapshot_attendance',
 '{"month":"2026-06","studentName":"Ravi Kumar","classLabel":"8-A","kpi":{"attendancePercent":94,"absentDays":1,"lateDays":0},"calendarDays":[],"recentLogs":[]}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'snapshot_exams',
 '{"studentName":"Ravi Kumar","classLabel":"8-A","upcomingExams":[],"examResults":[]}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'snapshot_timetable',
 '{"studentName":"Ravi Kumar","classLabel":"8-A","weekRangeLabel":"9–13 Jun","totalPeriodsThisWeek":30,"days":[]}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'snapshot_profile',
 '{"studentName":"Ravi Kumar","classLabel":"8-A","rollNumber":"8123","schoolName":"Akshara Public School","guardianName":"Suresh Kumar","unreadNotifications":0}'::jsonb),
('hw_1', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'homework_item',
 '{"id":"hw_1","subject":"Mathematics","title":"Algebra worksheet","dueLabel":"12 Jun","status":"pending"}'::jsonb),
('notice_1', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'notice',
 '{"id":"notice_1","title":"Sports day practice","dateLabel":"14 Jun 2026","isUrgent":false,"body":"Report to ground at 7 AM."}'::jsonb),
('bi000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001', 'probe',
 '{"id":"bi000000-0000-4000-8000-000000000001","label":"Student Probe A"}'::jsonb);

INSERT INTO student_entities (id, organization_id, school_id, student_id, entity_type, payload) VALUES
('bi000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000002', 'a4000000-0000-4000-8000-000000000002', 'probe',
 '{"id":"bi000000-0000-4000-8000-000000000002","label":"Student Probe B"}'::jsonb);
