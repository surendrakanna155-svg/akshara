-- v6.2 Sprint 4 Phase 3 — Management + Control Center read APIs

CREATE TABLE management_entities (
  id TEXT NOT NULL,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  entity_type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (organization_id, school_id, entity_type, id)
);
CREATE INDEX idx_management_entities_org_school_type ON management_entities (organization_id, school_id, entity_type);
CREATE TRIGGER management_entities_updated_at BEFORE UPDATE ON management_entities FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE control_center_entities (
  id TEXT NOT NULL,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  entity_type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (organization_id, entity_type, id)
);
CREATE INDEX idx_control_center_entities_org_type ON control_center_entities (organization_id, entity_type);
CREATE TRIGGER control_center_entities_updated_at BEFORE UPDATE ON control_center_entities FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE management_entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE management_entities FORCE ROW LEVEL SECURITY;
ALTER TABLE control_center_entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE control_center_entities FORCE ROW LEVEL SECURITY;

CREATE POLICY management_entities_school_scope ON management_entities
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

CREATE POLICY control_center_entities_org_scope ON control_center_entities
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'organization'
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'organization'
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON management_entities TO erp_tenant;
GRANT SELECT, INSERT, UPDATE, DELETE ON control_center_entities TO erp_tenant;

-- Management School A snapshots
INSERT INTO management_entities (id, organization_id, school_id, entity_type, payload) VALUES
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_dashboard',
 '{"aiInsight":"Revenue on track. 5 approvals pending principal sign-off.","kpis":[{"id":"revenue","value":"₹2.4Cr","label":"Revenue MTD","accentName":"primary"}],"revenueTrend":[],"expenseBreakdown":[],"approvalQueue":[],"admissionsSnapshot":{"leadsMtd":42,"confirmed":28,"joined":18,"conversionRate":"43%","recentConversions":[]},"feeSnapshot":{"collectedMtd":"₹1.2Cr","outstanding":"₹45L","collectionRate":"87%","defaulterCount":12}}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_analytics',
 '{"enrollmentTrend":[],"attendanceTrend":[],"feeCollectionTrend":[],"aiInsight":"Analytics placeholder."}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_admissions_funnel',
 '{"stages":[{"stage":"lead","count":120},{"stage":"confirmed","count":45}],"conversionRate":"38%","aiInsight":"Funnel healthy."}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_financial_health',
 '{"collectedMtd":"₹1.2Cr","outstanding":"₹45L","collectionRate":"87%","expenseRatio":"62%","aiInsight":"Financial health stable."}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_academic_health',
 '{"avgAttendance":"94%","passRate":"98%","teacherShortage":2,"aiInsight":"Academic metrics strong."}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_school_performance',
 '{"schools":[{"name":"Akshara Main","score":92,"rank":1}],"benchmarkNote":"Group benchmark placeholder."}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_tasks',
 '{"pendingApprovals":[],"overdueTasks":3,"aiInsight":"3 tasks overdue."}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_settings',
 '{"sections":[{"id":"general","title":"General","items":[{"id":"fiscal_year","label":"Fiscal year","value":"Apr–Mar","editable":true}]}]}'::jsonb),
('bg000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'probe',
 '{"id":"bg000000-0000-4000-8000-000000000001","label":"Probe A"}'::jsonb);

INSERT INTO management_entities (id, organization_id, school_id, entity_type, payload) VALUES
('bg000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000002', 'probe',
 '{"id":"bg000000-0000-4000-8000-000000000002","label":"Probe B"}'::jsonb);

-- Control Center org snapshots + list seeds
INSERT INTO control_center_entities (id, organization_id, entity_type, payload) VALUES
('default', 'a1000000-0000-4000-8000-000000000001', 'snapshot_dashboard',
 '{"aiInsight":"Platform MRR growing 12% QoQ. 2 schools at renewal risk.","kpis":[{"id":"schools","value":"24","label":"Active Schools","accentName":"primary"}],"schoolGrowthTrend":[],"revenueTrend":[],"planDistribution":[],"recentTickets":[]}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'snapshot_subscriptions',
 '{"activePlans":[{"plan":"enterprise","count":8},{"plan":"standard","count":16}],"mrrLakhs":18.4,"churnRate":"2%"}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'snapshot_billing',
 '{"invoicesDue":3,"collectedMtdLakhs":16.2,"overdueLakhs":1.1}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'snapshot_crm',
 '{"pipeline":[{"stage":"lead","count":15},{"stage":"trial","count":6}],"conversionRate":"28%"}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'snapshot_customer_success',
 '{"healthScores":[{"band":"green","count":18},{"band":"amber","count":4}],"npsScore":62}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'snapshot_analytics',
 '{"usageTrend":[],"featureAdoption":[],"aiInsight":"Analytics placeholder."}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'snapshot_monitoring',
 '{"uptimePercent":99.9,"incidentsOpen":1,"avgResponseMs":142}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'snapshot_roles',
 '{"roles":[{"slug":"schoolAdmin","permissions":42},{"slug":"teacher","permissions":12}]}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'snapshot_settings',
 '{"sections":[{"id":"platform","title":"Platform","items":[{"id":"support_email","label":"Support email","value":"support@akshara.edu","editable":true}]}]}'::jsonb),
('bg100000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 'school',
 '{"id":"bg100000-0000-4000-8000-000000000001","name":"Akshara School A","plan":"enterprise","studentCount":842,"status":"active","createdDate":"2024-01-15","mrrLakhs":2.4,"healthScore":92,"region":"South","tenantId":"a2000000-0000-4000-8000-000000000001"}'::jsonb),
('bg100000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001', 'school',
 '{"id":"bg100000-0000-4000-8000-000000000002","name":"Akshara School B","plan":"standard","studentCount":520,"status":"active","createdDate":"2024-06-01","mrrLakhs":1.2,"healthScore":85,"region":"South","tenantId":"a2000000-0000-4000-8000-000000000002"}'::jsonb),
('ticket_1', 'a1000000-0000-4000-8000-000000000001', 'support_ticket',
 '{"id":"ticket_1","subject":"Billing query","schoolName":"Akshara School A","status":"open","priority":"medium","slaRemaining":"4h","assignee":"Support Team","createdDate":"2026-06-08"}'::jsonb),
('wl_1', 'a1000000-0000-4000-8000-000000000001', 'white_label',
 '{"schoolId":"a2000000-0000-4000-8000-000000000001","schoolName":"Akshara School A","logoUrl":"","primaryColorHex":"#1565C0","customDomain":"","loginBackgroundUrl":"","isPublished":false}'::jsonb);
