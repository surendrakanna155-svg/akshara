-- v6.2 Sprint 4 Phase 1 — Transport + HR read APIs (JSONB entity store)

CREATE TABLE transport_entities (
  id TEXT NOT NULL,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  entity_type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (organization_id, school_id, entity_type, id)
);

CREATE INDEX idx_transport_entities_org_school_type
  ON transport_entities (organization_id, school_id, entity_type);

CREATE TRIGGER transport_entities_updated_at
  BEFORE UPDATE ON transport_entities
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE hr_entities (
  id TEXT NOT NULL,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  entity_type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (organization_id, school_id, entity_type, id)
);

CREATE INDEX idx_hr_entities_org_school_type
  ON hr_entities (organization_id, school_id, entity_type);

CREATE TRIGGER hr_entities_updated_at
  BEFORE UPDATE ON hr_entities
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE transport_entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE transport_entities FORCE ROW LEVEL SECURITY;
ALTER TABLE hr_entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_entities FORCE ROW LEVEL SECURITY;

CREATE POLICY transport_entities_school_scope ON transport_entities
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

CREATE POLICY hr_entities_school_scope ON hr_entities
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON transport_entities TO erp_tenant;
GRANT SELECT, INSERT, UPDATE, DELETE ON hr_entities TO erp_tenant;

-- ── Transport School A seed ────────────────────────────────────────────────

INSERT INTO transport_entities (id, organization_id, school_id, entity_type, payload) VALUES
(
  'default',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'snapshot_dashboard',
  '{
    "aiInsight": "Route 08 — West shows recurring delays at Hitech City. Consider stop reorder or alternate path. 2 students unassigned — link to SIS-02 registry.",
    "kpis": [
      {"id": "active_buses", "value": "18", "label": "Active Buses", "accentName": "primary"},
      {"id": "on_time", "value": "94%", "label": "On-Time Rate", "accentName": "success"},
      {"id": "delayed", "value": "2", "label": "Delayed", "accentName": "error"},
      {"id": "picked", "value": "842", "label": "Students Picked", "accentName": "success"},
      {"id": "driver_absent", "value": "1", "label": "Driver Absent", "accentName": "warning"},
      {"id": "fuel", "value": "₹84K", "label": "Fuel Cost (MTD)", "accentName": "neutral", "detail": "Finance integration placeholder"}
    ],
    "vehicleAssignments": [
      {"id": "va_1", "busNumber": "BUS-07", "routeName": "Route 12 — North", "driverName": "Ramesh Kumar", "shift": "am", "studentCount": 42, "trackingStatus": "moving", "etaLabel": "4 min"},
      {"id": "va_2", "busNumber": "BUS-03", "routeName": "Route 08 — West", "driverName": "Suresh Naidu", "shift": "am", "studentCount": 38, "trackingStatus": "delayed", "etaLabel": "12 min late"},
      {"id": "va_3", "busNumber": "BUS-02", "routeName": "Route 05 — Central", "driverName": "Vijay Reddy", "shift": "am", "studentCount": 45, "trackingStatus": "idle", "etaLabel": "At stop"}
    ],
    "activeDelays": [
      "Route 08 — West delayed 12 min (traffic at Hitech City)",
      "BUS-11 GPS offline since 7:42 AM"
    ],
    "routePerformance": [
      {"routeName": "Route 12 — North", "onTimePercent": "96%", "avgDelayMinutes": 3, "utilizationPercent": 88, "incidents": 0},
      {"routeName": "Route 08 — West", "onTimePercent": "82%", "avgDelayMinutes": 11, "utilizationPercent": 76, "incidents": 1},
      {"routeName": "Route 05 — Central", "onTimePercent": "94%", "avgDelayMinutes": 4, "utilizationPercent": 90, "incidents": 0}
    ],
    "occupancy": {"totalCapacity": 860, "allocatedSeats": 842, "unassignedStudents": 2, "utilizationPercent": 88}
  }'::jsonb
),
(
  'default',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'snapshot_occupancy',
  '{"totalCapacity": 860, "allocatedSeats": 842, "unassignedStudents": 2, "utilizationPercent": 88}'::jsonb
),
(
  'default',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'snapshot_tracking',
  '{
    "mapPlaceholderLabel": "Live map integration — Google Maps / Mapbox",
    "integrationNote": "GPS architecture placeholder. Future: real-time bus tracking in Parent App (PA route info) and Student app.",
    "parentAppRoute": "/parent/dashboard",
    "vehicles": [
      {"busNumber": "BUS-07", "routeName": "Route 12 — North", "driverName": "Ramesh Kumar", "status": "moving", "speedKph": 32, "lastPing": "30 sec ago", "nextStop": "Green Park Gate", "studentCount": 42, "etaMinutes": 4, "latitude": 17.4502, "longitude": 78.3965},
      {"busNumber": "BUS-03", "routeName": "Route 08 — West", "driverName": "Suresh Naidu", "status": "delayed", "speedKph": 18, "lastPing": "1 min ago", "nextStop": "Hitech City", "studentCount": 38, "etaMinutes": 12, "latitude": 17.4438, "longitude": 78.3812}
    ]
  }'::jsonb
),
(
  'default',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'snapshot_reports',
  '{
    "catalog": [
      {"id": "rpt_on_time", "title": "On-Time Performance", "description": "Route punctuality trend and delay analysis", "lastGenerated": "5 Jun 2026"},
      {"id": "rpt_occupancy", "title": "Seat Utilization", "description": "Capacity vs allocated seats by route", "lastGenerated": "3 Jun 2026"}
    ],
    "onTimeTrend": [
      {"label": "Jan", "amountLakhs": 92.0, "targetLakhs": 95.0},
      {"label": "Feb", "amountLakhs": 93.5, "targetLakhs": 95.0},
      {"label": "Mar", "amountLakhs": 94.0, "targetLakhs": 95.0}
    ],
    "delayByRoute": [
      {"label": "Route 08 — West", "value": 11, "percent": 45},
      {"label": "Route 12 — North", "value": 3, "percent": 12}
    ],
    "fuelTrend": [
      {"label": "Jan", "amountLakhs": 7.2, "targetLakhs": 7.0},
      {"label": "Feb", "amountLakhs": 7.8, "targetLakhs": 7.5}
    ]
  }'::jsonb
),
(
  'default',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'snapshot_settings',
  '{
    "defaultShift": "both",
    "sections": [
      {
        "id": "general",
        "title": "General",
        "items": [
          {"id": "default_shift", "label": "Default shift", "value": "Both AM & PM", "description": "Applied to new route allocations", "editable": true},
          {"id": "gps_provider", "label": "GPS provider", "value": "Placeholder — Mapbox", "description": "Live tracking integration", "editable": false}
        ]
      }
    ]
  }'::jsonb
),
(
  'be000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'route',
  '{
    "id": "be000000-0000-4000-8000-000000000001",
    "name": "Route 12 — North",
    "stopCount": 8,
    "distanceKm": "14.2 km",
    "amDeparture": "6:45 AM",
    "pmDeparture": "3:30 PM",
    "assignedBus": "BUS-07",
    "studentCount": 42,
    "status": "active",
    "shift": "both",
    "stops": [
      {"id": "stop_1", "name": "Lake View Colony", "sequence": 1, "scheduledTime": "7:05 AM", "status": "completed", "latitude": 17.4484, "longitude": 78.3908},
      {"id": "stop_2", "name": "Green Park Gate", "sequence": 2, "scheduledTime": "7:18 AM", "status": "next", "latitude": 17.4521, "longitude": 78.4012}
    ]
  }'::jsonb
),
(
  'route_08',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'route',
  '{
    "id": "route_08",
    "name": "Route 08 — West",
    "stopCount": 6,
    "distanceKm": "11.8 km",
    "amDeparture": "6:55 AM",
    "pmDeparture": "3:40 PM",
    "assignedBus": "BUS-03",
    "studentCount": 38,
    "status": "active",
    "shift": "both",
    "stops": []
  }'::jsonb
),
(
  'veh_7',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'vehicle',
  '{"id": "veh_7", "busNumber": "BUS-07", "registration": "TS 09 AB 4521", "capacity": 48, "routeName": "Route 12 — North", "gpsDeviceId": "GPS-TR-007", "insuranceExpiry": "Dec 2026", "fitnessExpiry": "Aug 2026", "status": "active", "occupancyPercent": 88}'::jsonb
),
(
  'drv_1',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'driver',
  '{"id": "drv_1", "name": "Ramesh Kumar", "licenseNumber": "DL-TS-2018-4521", "licenseExpiry": "Mar 2028", "phone": "+91 98765 22001", "assignedBus": "BUS-07", "attendancePercent": "98%", "rating": "4.8", "status": "active"}'::jsonb
),
(
  'alloc_1',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'allocation',
  '{"id": "alloc_1", "studentName": "Arjun Patel", "admissionNumber": "ADM-2026-0138", "classLabel": "10", "pickupStop": "Lake View Colony", "dropStop": "Akshara Main Gate", "routeName": "Route 12 — North", "busNumber": "BUS-07", "shift": "both", "sisStudentId": "SIS-STU-10421"}'::jsonb
),
(
  'att_1',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'attendance',
  '{"id": "att_1", "studentName": "Arjun Patel", "stopName": "Lake View Colony", "routeName": "Route 12 — North", "scheduledTime": "7:05 AM", "actualTime": "7:06 AM", "status": "picked", "parentNotified": false, "shift": "am"}'::jsonb
);

-- Transport School B probe fixture
INSERT INTO transport_entities (id, organization_id, school_id, entity_type, payload) VALUES
(
  'be000000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  'route',
  '{"id": "be000000-0000-4000-8000-000000000002", "name": "Probe Route B", "stopCount": 1, "distanceKm": "5.0 km", "amDeparture": "7:00 AM", "pmDeparture": "3:00 PM", "assignedBus": "BUS-99", "studentCount": 10, "status": "active", "shift": "am", "stops": []}'::jsonb
);

-- ── HR School A seed ─────────────────────────────────────────────────────────

INSERT INTO hr_entities (id, organization_id, school_id, entity_type, payload) VALUES
(
  'default',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'snapshot_dashboard',
  '{
    "aiInsight": "Teacher attrition risk elevated in Mathematics — review workload for Priya Sharma (Class 8-B) and cross-check Management performance KPIs.",
    "managementKpiNote": "Teacher attendance 96% MTD feeds Management dashboard (MG-01 teacher_avg KPI).",
    "kpis": [
      {"id": "total_employees", "value": "148", "label": "Total Employees", "accentName": "primary"},
      {"id": "present_today", "value": "142", "label": "Present Today", "accentName": "success"},
      {"id": "on_leave", "value": "6", "label": "On Leave", "accentName": "warning"},
      {"id": "open_positions", "value": "4", "label": "Open Positions", "accentName": "primary"}
    ],
    "headcountTrend": [{"label": "Jan", "amountLakhs": 14.2, "targetLakhs": 14.0}, {"label": "Jun", "amountLakhs": 14.8, "targetLakhs": 15.0}],
    "attendanceTrend": [{"label": "W1", "amountLakhs": 94.0, "targetLakhs": 95.0}, {"label": "W4", "amountLakhs": 96.0, "targetLakhs": 95.0}],
    "pendingLeave": [{"id": "lv_1", "employeeName": "Sunita Nair", "leaveType": "sick", "days": 3, "submittedOn": "2026-06-04"}],
    "recruitmentSnapshot": [{"id": "cand_1", "name": "Deepa Krishnan", "role": "Physics Teacher", "department": "academics", "appliedOn": "2026-05-28", "stage": "interview", "experience": "6 years", "source": "Referral"}]
  }'::jsonb
),
(
  'default',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'snapshot_attendance',
  '{
    "records": [
      {"id": "att_1", "employeeId": "be100000-0000-4000-8000-000000000001", "employeeName": "Priya Sharma", "department": "academics", "date": "2026-06-06", "checkIn": "8:02 AM", "checkOut": "3:45 PM", "status": "present", "geoVerified": true, "faceVerified": true}
    ],
    "attendanceTrend": [{"label": "Mon", "amountLakhs": 95.0, "targetLakhs": 95.0}],
    "departmentBreakdown": [{"label": "Academics", "value": 82, "percent": 96}],
    "summaryNote": "Geo + face verification enabled for teachers."
  }'::jsonb
),
(
  'default',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'snapshot_leave',
  '{
    "pendingCount": 2,
    "integrationNote": "Leave approvals sync with Teacher app TA-07.",
    "requests": [
      {"id": "lv_req_1", "employeeId": "be100000-0000-4000-8000-000000000001", "employeeName": "Priya Sharma", "department": "academics", "leaveType": "earned", "fromDate": "2026-05-20", "toDate": "2026-05-22", "days": 3, "status": "approved", "approver": "Rajesh Iyer", "reason": "Family function"}
    ],
    "leaveByType": [{"label": "Casual", "value": 12, "percent": 40}]
  }'::jsonb
),
(
  'default',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'snapshot_payroll',
  '{
    "financeIntegrationNote": "Payroll posts to Finance FN-05 salary disbursement.",
    "financeRoute": "/finance/payroll",
    "runs": [{"id": "pay_1", "period": "May 2026", "employeeCount": 148, "grossAmount": 1480000, "netAmount": 1320000, "status": "processed", "processedOn": "2026-06-01"}],
    "entries": [{"id": "entry_1", "employeeId": "be100000-0000-4000-8000-000000000001", "employeeName": "Priya Sharma", "department": "academics", "basicPay": 45000, "allowances": 8000, "deductions": 5000, "netPay": 48000, "status": "processed"}],
    "salaryTrend": [{"label": "Jan", "amountLakhs": 13.2, "targetLakhs": 13.0}]
  }'::jsonb
),
(
  'default',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'snapshot_recruitment',
  '{
    "openPositions": 4,
    "candidates": [{"id": "cand_1", "name": "Deepa Krishnan", "role": "Physics Teacher", "department": "academics", "appliedOn": "2026-05-28", "stage": "interview", "experience": "6 years", "source": "Referral"}],
    "pipelineCounts": [{"label": "Interview", "value": 2, "percent": 50}],
    "hiringTrend": [{"label": "Q1", "amountLakhs": 3.0, "targetLakhs": 4.0}]
  }'::jsonb
),
(
  'default',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'snapshot_performance',
  '{
    "managementInsight": "Mathematics department reviews due this cycle.",
    "reviews": [{"id": "rev_1", "employeeId": "be100000-0000-4000-8000-000000000001", "employeeName": "Priya Sharma", "department": "academics", "cycle": "annual", "rating": 4.5, "status": "completed", "reviewer": "Rajesh Iyer", "dueDate": "2026-06-30"}],
    "ratingDistribution": [{"label": "4-5", "value": 45, "percent": 60}],
    "completionTrend": [{"label": "Q1", "amountLakhs": 80.0, "targetLakhs": 90.0}]
  }'::jsonb
),
(
  'default',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'snapshot_settings',
  '{
    "defaultDepartment": "academics",
    "sections": [
      {
        "id": "general",
        "title": "General",
        "items": [
          {"id": "default_department", "label": "Default department", "value": "Academics", "description": "Applied to new employee records", "editable": true}
        ]
      }
    ]
  }'::jsonb
),
(
  'be100000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'employee',
  '{"id": "be100000-0000-4000-8000-000000000001", "name": "Priya Sharma", "employeeCode": "EMP-101", "department": "academics", "role": "teacher", "designation": "Mathematics Teacher", "email": "priya.sharma@akshara.edu", "phone": "+91 98765 43210", "joinDate": "2019-06-01", "status": "active", "teacherAppLinked": true, "classLabel": "8-B"}'::jsonb
),
(
  'HR-EMP-102',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'employee',
  '{"id": "HR-EMP-102", "name": "Mrs. Rao", "employeeCode": "EMP-102", "department": "academics", "role": "teacher", "designation": "English Teacher", "email": "mrs.rao@akshara.edu", "phone": "+91 98765 43211", "joinDate": "2018-04-15", "status": "active", "teacherAppLinked": true, "classLabel": "7-A"}'::jsonb
);

-- HR School B probe fixture
INSERT INTO hr_entities (id, organization_id, school_id, entity_type, payload) VALUES
(
  'be100000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  'employee',
  '{"id": "be100000-0000-4000-8000-000000000002", "name": "Probe Employee B", "employeeCode": "EMP-B", "department": "administration", "role": "staff", "designation": "Probe Staff", "email": "probe.b@akshara.edu", "phone": "+91 90000 00002", "joinDate": "2020-01-01", "status": "active"}'::jsonb
);
