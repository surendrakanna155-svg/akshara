-- v6.2 Sprint 4 Phase 2 — Hostel, Library, Inventory, Alumni read APIs

CREATE TABLE hostel_entities (
  id TEXT NOT NULL,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  entity_type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (organization_id, school_id, entity_type, id)
);
CREATE INDEX idx_hostel_entities_org_school_type ON hostel_entities (organization_id, school_id, entity_type);
CREATE TRIGGER hostel_entities_updated_at BEFORE UPDATE ON hostel_entities FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE library_entities (
  id TEXT NOT NULL,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  entity_type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (organization_id, school_id, entity_type, id)
);
CREATE INDEX idx_library_entities_org_school_type ON library_entities (organization_id, school_id, entity_type);
CREATE TRIGGER library_entities_updated_at BEFORE UPDATE ON library_entities FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE inventory_entities (
  id TEXT NOT NULL,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  entity_type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (organization_id, school_id, entity_type, id)
);
CREATE INDEX idx_inventory_entities_org_school_type ON inventory_entities (organization_id, school_id, entity_type);
CREATE TRIGGER inventory_entities_updated_at BEFORE UPDATE ON inventory_entities FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE alumni_entities (
  id TEXT NOT NULL,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  entity_type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (organization_id, school_id, entity_type, id)
);
CREATE INDEX idx_alumni_entities_org_school_type ON alumni_entities (organization_id, school_id, entity_type);
CREATE TRIGGER alumni_entities_updated_at BEFORE UPDATE ON alumni_entities FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DO $$
DECLARE
  t record;
BEGIN
  FOR t IN SELECT unnest(ARRAY['hostel_entities','library_entities','inventory_entities','alumni_entities']) AS tbl
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t.tbl);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', t.tbl);
    EXECUTE format(
      'CREATE POLICY %I ON %I FOR ALL USING (
         organization_id = app_current_tenant_id()
         AND app_current_scope() = ''school''
         AND school_id = app_current_school_id()
       ) WITH CHECK (
         organization_id = app_current_tenant_id()
         AND app_current_scope() = ''school''
         AND school_id = app_current_school_id()
       )',
      t.tbl || '_school_scope',
      t.tbl
    );
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON %I TO erp_tenant', t.tbl);
  END LOOP;
END $$;

-- Hostel School A seeds
INSERT INTO hostel_entities (id, organization_id, school_id, entity_type, payload) VALUES
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_dashboard',
 '{"aiInsight":"Hostel occupancy stable. 3 leave requests pending approval.","activeVisitorCount":2,"healthAlerts":[],"missingStudents":[],"occupancy":{"totalBeds":320,"occupiedBeds":294,"vacantBeds":26,"utilizationPercent":92},"kpis":[{"id":"occupied","value":"92%","label":"Occupied","accentName":"primary"}],"blockOccupancy":[],"sessionAttendance":[],"pendingLeave":[],"recentIncidents":[]}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_mess',
 '{"menuToday":{"breakfast":"Idli, Sambar","lunch":"Rice, Dal, Vegetables","dinner":"Chapati, Curry"},"dietaryNotes":[],"attendanceToday":288,"feedbackScore":"4.2"}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_visitors',
 '{"activeVisitors":[],"todayCheckIns":5,"pendingApprovals":1}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_reports',
 '{"catalog":[{"id":"rpt_occ","title":"Occupancy Report","description":"Block-wise bed utilization","lastGenerated":"5 Jun 2026"}],"occupancyTrend":[],"attendanceTrend":[]}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_occupancy',
 '{"totalBeds":320,"occupiedBeds":294,"vacantBeds":26,"utilizationPercent":92}'::jsonb),
('bf000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'student',
 '{"id":"bf000000-0000-4000-8000-000000000001","studentName":"Arjun Patel","admissionNumber":"ADM-2026-0138","classLabel":"10","block":"A","room":"A-204","bed":"2","sisStudentId":"SIS-STU-10421","status":"active","feePending":"₹0","parentAppLinked":true}'::jsonb);

INSERT INTO hostel_entities (id, organization_id, school_id, entity_type, payload) VALUES
('bf000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000002', 'student',
 '{"id":"bf000000-0000-4000-8000-000000000002","studentName":"Probe Student B","admissionNumber":"ADM-B","classLabel":"8","block":"B","room":"B-101","bed":"1","sisStudentId":"SIS-B","status":"active","feePending":"₹0","parentAppLinked":false}'::jsonb);

-- Library School A seeds
INSERT INTO library_entities (id, organization_id, school_id, entity_type, payload) VALUES
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_dashboard',
 '{"aiInsight":"Circulation up 8% this month. 12 overdue items need follow-up.","kpis":[{"id":"books","value":"12,400","label":"Total Books","accentName":"primary"}],"categoryDistribution":[],"recentIssues":[],"overdueSummary":{"count":12,"totalFines":"₹1,240"}}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_fines',
 '{"totalOutstanding":"₹1,240","records":[],"waivedThisMonth":"₹320"}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_digital_resources',
 '{"resources":[{"id":"dr_1","title":"JSTOR Access","type":"database","accessUrl":"https://example.com/jstor","status":"active"}],"usageThisMonth":842}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_reports',
 '{"catalog":[{"id":"rpt_circ","title":"Circulation Report","description":"Monthly issue/return stats","lastGenerated":"4 Jun 2026"}],"circulationTrend":[],"popularTitles":[]}'::jsonb),
('bf100000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'catalog',
 '{"id":"bf100000-0000-4000-8000-000000000001","isbn":"978-0143127741","title":"The Guide","author":"R.K. Narayan","category":"Fiction","totalCopies":5,"availableCopies":3,"shelf":"A-12","status":"available"}'::jsonb);

INSERT INTO library_entities (id, organization_id, school_id, entity_type, payload) VALUES
('bf100000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000002', 'catalog',
 '{"id":"bf100000-0000-4000-8000-000000000002","isbn":"978-0000000000","title":"Probe Book B","author":"Author B","category":"Reference","totalCopies":1,"availableCopies":1,"shelf":"B-01","status":"available"}'::jsonb);

-- Inventory School A seeds
INSERT INTO inventory_entities (id, organization_id, school_id, entity_type, payload) VALUES
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_dashboard',
 '{"aiInsight":"12 assets due for maintenance this month.","kpis":[{"id":"assets","value":"1,842","label":"Total Assets","accentName":"primary"}],"categoryBreakdown":[],"maintenanceDue":[],"recentProcurement":[]}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_reports',
 '{"catalog":[{"id":"rpt_assets","title":"Asset Register","description":"Full asset inventory export","lastGenerated":"3 Jun 2026"}],"valueTrend":[],"maintenanceTrend":[]}'::jsonb),
('bf200000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'asset',
 '{"id":"bf200000-0000-4000-8000-000000000001","assetTag":"AST-2024-001","name":"Smart Board","category":"Electronics","location":"Lab 1","purchaseDate":"2024-06-01","value":"₹85,000","status":"active","assignedTo":"Science Dept","financeAssetId":"FIN-AST-001","lastAudit":"May 2026"}'::jsonb);

INSERT INTO inventory_entities (id, organization_id, school_id, entity_type, payload) VALUES
('bf200000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000002', 'asset',
 '{"id":"bf200000-0000-4000-8000-000000000002","assetTag":"AST-B-001","name":"Probe Asset B","category":"Furniture","location":"Block B","purchaseDate":"2024-01-01","value":"₹10,000","status":"active","financeAssetId":"FIN-B","lastAudit":"Jan 2026"}'::jsonb);

-- Alumni School A seeds
INSERT INTO alumni_entities (id, organization_id, school_id, entity_type, payload) VALUES
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_dashboard',
 '{"aiInsight":"Alumni engagement rising. 3 upcoming reunion events.","kpis":[{"id":"registered","value":"2,400","label":"Registered Alumni","accentName":"primary"}],"recentGraduates":[],"upcomingEvents":[],"donationSummary":{"totalReceived":"₹12.4L","pledgedAmount":"₹2.1L","pendingAmount":"₹45K"}}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_reports',
 '{"catalog":[{"id":"rpt_eng","title":"Engagement Report","description":"Alumni activity summary","lastGenerated":"2 Jun 2026"}],"donationTrend":[],"eventAttendance":[]}'::jsonb),
('default', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'snapshot_settings',
 '{"sections":[{"id":"portal","title":"Alumni Portal","items":[{"id":"registration","label":"Self-registration","value":"Enabled","description":"Graduates can register online","editable":true}]}]}'::jsonb),
('bf300000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'alumni',
 '{"id":"bf300000-0000-4000-8000-000000000001","name":"Priya Sharma","batchYear":"2018","program":"CBSE XII","currentRole":"Software Engineer","city":"Hyderabad","email":"priya@example.com","phone":"+91 98765 00001","engagementStatus":"active","sisStudentId":"SIS-ALU-001","totalDonated":"₹25,000","lastEventAttended":"Reunion 2024"}'::jsonb);

INSERT INTO alumni_entities (id, organization_id, school_id, entity_type, payload) VALUES
('bf300000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000002', 'alumni',
 '{"id":"bf300000-0000-4000-8000-000000000002","name":"Probe Alumni B","batchYear":"2019","program":"CBSE XII","currentRole":"Analyst","city":"Bangalore","email":"b@example.com","phone":"+91 98765 00002","engagementStatus":"inactive","sisStudentId":"SIS-ALU-B","totalDonated":"₹0","lastEventAttended":"—"}'::jsonb);
