// Live validation: authenticate against the production VPS backend and probe
// every GET endpoint the web pages consume. READ-ONLY (auth + GET only; no
// mutations). Reports status + a shape spot-check per endpoint; flags errors as
// gap candidates. Run: node web/scripts/live_validate.mjs
const BASE = process.env.API_BASE_URL || 'https://api.nikshaos.in/functions/v1/api';
const ADMIN = process.env.ADMIN_PHONE || '9876543210';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function post(path, body, token) {
  const res = await fetch(BASE + path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify(body),
  });
  return { status: res.status, json: await res.json().catch(() => null) };
}
async function get(path, token) {
  const res = await fetch(BASE + path, { headers: token ? { Authorization: `Bearer ${token}` } : {} });
  let json = null;
  try { json = await res.json(); } catch { /* non-json */ }
  return { status: res.status, json };
}

async function loginWithCooldown(phone) {
  for (let attempt = 0; attempt < 8; attempt++) {
    const r = await post('/auth/login', { identifier: phone, type: 'phone' });
    const d = r.json?.data;
    if (d?.otp && d?.sessionId) return d;
    const code = r.json?.error?.code;
    if (code === 'OTP_COOLDOWN') { process.stdout.write('  (cooldown, waiting 20s)\n'); await sleep(20000); continue; }
    throw new Error(`login failed for ${phone}: ${JSON.stringify(r.json?.error || r.status)}`);
  }
  throw new Error(`login cooldown never cleared for ${phone}`);
}

async function authenticate(phone, extra = {}) {
  const { otp, sessionId } = await loginWithCooldown(phone);
  const v = await post('/auth/verify-otp', { identifier: phone, type: 'phone', otp, sessionId, ...extra });
  const d = v.json?.data;
  const token = d?.accessToken || d?.token || d?.access_token;
  if (!token) throw new Error(`verify-otp failed: ${JSON.stringify(v.json)}`);
  return token;
}

// Endpoints the web pages GET, grouped by module.
const PROBES = [
  ['auth', ['/auth/me', '/auth/permissions']],
  ['sis', ['/sis/dashboard', '/sis/students', '/sis/transfers', '/sis/admissions-conversion']],
  ['admissions', ['/admissions/dashboard', '/admissions/leads', '/admissions/applications', '/admissions/approval-queue', '/admissions/documents', '/admissions/enrollments/pending', '/admissions/reports', '/admissions/settings']],
  ['hr', ['/hr/dashboard', '/hr/employees', '/hr/attendance', '/hr/leave', '/hr/payroll', '/hr/recruitment', '/hr/performance', '/hr/settings']],
  ['finance', ['/finance/dashboard', '/finance/collections', '/finance/student-accounts', '/finance/fee-structures', '/finance/fee-assignments', '/finance/defaulters', '/finance/refunds', '/finance/discounts', '/finance/payments/offline', '/finance/payments/qr', '/finance/collections/daily-summary', '/finance/intelligence/executive', '/finance/settings']],
  ['transport', ['/transport/dashboard', '/transport/routes', '/transport/vehicles', '/transport/drivers', '/transport/allocations', '/transport/attendance', '/transport/tracking', '/transport/reports', '/transport/settings']],
  ['library', ['/library/dashboard', '/library/catalog', '/library/issues', '/library/returns', '/library/members', '/library/fines', '/library/overdue', '/library/digital-resources', '/library/reports', '/library/settings']],
  ['hostel', ['/hostel/dashboard', '/hostel/students', '/hostel/rooms', '/hostel/attendance', '/hostel/leave', '/hostel/mess', '/hostel/visitors', '/hostel/reports']],
  ['inventory', ['/inventory/dashboard', '/inventory/assets', '/inventory/categories', '/inventory/allocations', '/inventory/maintenance', '/inventory/procurement', '/inventory/vendors', '/inventory/reports', '/inventory/intelligence/lifecycle', '/inventory/intelligence/copilot', '/inventory/stock', '/inventory/stock/approvals']],
  ['alumni', ['/alumni/dashboard', '/alumni/registry', '/alumni/campaigns', '/alumni/donations', '/alumni/events', '/alumni/mentorship', '/alumni/reports', '/alumni/settings']],
  ['academics', ['/academics/exams', '/academics/exams/progress', '/academic/timetables', '/academic/timetables/summary', '/academic/timetables/substitutions']],
  ['management', ['/management/dashboard', '/management/analytics', '/management/admissions-funnel', '/management/financial-health', '/management/academic-health', '/management/school-performance', '/management/tasks', '/management/settings']],
  ['director', ['/director/dashboard', '/director/schools', '/director/portfolio', '/director/revenue', '/director/admissions', '/director/growth', '/director/marketing', '/director/compliance', '/director/reports']],
  ['intelligence', ['/intelligence/priorities', '/intelligence/student-success/dashboard', '/intelligence/teacher-effectiveness/performance', '/intelligence/exam/analytics', '/intelligence/homework-intelligence/plan', '/intelligence/trust', '/intelligence/ai-economics']],
  ['attendance', ['/attendance/corrections', '/attendance/register', '/attendance/alerts/short-attendance']],
  ['schoolops', ['/school/subjects', '/school/rooms', '/school/lesson-logs', '/school/timetables/intelligence', '/school/academic/teacher-progress', '/school/pilot/dashboard']],
  ['communication', ['/communications/broadcasts/history', '/communications/delivery/metrics', '/communications/audience-segments', '/communications/templates']],
  ['dashboard-gap', ['/dashboard/overview']], // WEB-001
  ['sis-workflow-gap', ['/sis/promotion', '/sis/reshuffle', '/sis/section-balance']], // WEB-005
];

async function switchToSchool(token) {
  const me = await get('/auth/me', token);
  const d = me.json?.data || {};
  const schools = d.schools || d.availableSchools || d.memberships || [];
  const schoolId = (Array.isArray(schools) && (schools[0]?.id || schools[0]?.schoolId)) || d.schoolId;
  const orgId = d.organizationId || d.orgId;
  if (schoolId) {
    const sw = await post('/auth/context/switch', { scope: 'school', schoolId }, token);
    const t = sw.json?.data?.accessToken;
    if (t) return { token: t, schoolId, orgId, scope: 'school' };
  }
  if (orgId) {
    const sw = await post('/auth/context/switch', { scope: 'organization', organizationId: orgId }, token);
    const t = sw.json?.data?.accessToken;
    if (t) return { token: t, schoolId, orgId, scope: 'organization' };
  }
  return { token, schoolId, orgId, scope: d.scope || 'default' };
}

function shapeNote(json) {
  const d = json?.data;
  if (d == null) return json?.error ? `ERR:${json.error.code}` : 'null';
  if (Array.isArray(d)) return `array[${d.length}]`;
  if (typeof d === 'object') {
    if (Array.isArray(d.items)) return `{items[${d.items.length}]${d.total != null ? `,total:${d.total}` : ''}}`;
    if (Array.isArray(d.kpis)) return `{kpis[${d.kpis.length}]}`;
    if (Array.isArray(d.queue)) return `{queue[${d.queue.length}]}`;
    return `{${Object.keys(d).slice(0, 6).join(',')}}`;
  }
  return typeof d;
}

async function main() {
  console.log(`# Live validation against ${BASE}\n`);
  console.log('Authenticating admin…');
  const adminToken = await authenticate(ADMIN);
  const ctx = await switchToSchool(adminToken);
  console.log(`Context: scope=${ctx.scope} school=${ctx.schoolId || '-'} org=${ctx.orgId || '-'}\n`);
  const token = ctx.token;

  const results = [];
  let ok = 0, err = 0;
  for (const [mod, paths] of PROBES) {
    for (const p of paths) {
      const r = await get(p, token);
      const good = r.status >= 200 && r.status < 300;
      if (good) ok++; else err++;
      results.push({ mod, path: p, status: r.status, shape: shapeNote(r.json) });
      console.log(`${good ? '✅' : '❌'} ${String(r.status).padEnd(3)} ${p.padEnd(48)} ${results[results.length - 1].shape}`);
    }
  }
  console.log(`\n# Summary: ${ok} OK, ${err} non-2xx of ${ok + err} probes`);
  const gaps = results.filter((r) => !(r.status >= 200 && r.status < 300));
  if (gaps.length) {
    console.log('\n# Non-2xx (gap candidates / auth-scope issues):');
    for (const g of gaps) console.log(`  ${g.status} ${g.path} — ${g.shape}`);
  }
  const { writeFileSync } = await import('node:fs');
  writeFileSync(new URL('./live_validate_results.json', import.meta.url), JSON.stringify({ base: BASE, ctx: { scope: ctx.scope }, ok, err, results }, null, 2));
}

main().catch((e) => { console.error('FATAL:', e.message); process.exit(1); });
