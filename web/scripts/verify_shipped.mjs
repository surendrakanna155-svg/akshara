// Verify the ERP-WT-001..011 endpoints the ERP lane marked 🟢 delivered are
// actually live. READ-ONLY. Reuses the cached session token (no OTP). Run after a
// session is cached at /tmp/live-session.json.
import fs from 'node:fs';
const API = 'https://api.nikshaos.in/functions/v1/api';
const s = JSON.parse(fs.readFileSync('/tmp/live-session.json', 'utf8'));
async function get(p) {
  const r = await fetch(API + p, { headers: { Authorization: `Bearer ${s.token}`, 'X-Tenant-Id': s.tenantId, 'X-School-Id': s.schoolId } });
  let j = null; try { j = await r.json(); } catch { /* */ }
  return { status: r.status, j };
}
function shape(j) {
  const d = j?.data; if (d == null) return j?.error ? `ERR:${j.error.code}` : 'null';
  if (Array.isArray(d)) return `array[${d.length}]`;
  if (Array.isArray(d.items)) return `items[${d.items.length}]${d.total != null ? `/total ${d.total}` : ''}`;
  if (typeof d === 'object') return `{${Object.keys(d).slice(0, 6).join(',')}}`;
  return typeof d;
}
// The endpoints the ERP lane flipped to delivered (WEB/ERP-WT-001..011).
const CHECKS = [
  ['ERP-WT-001', '/dashboard/overview'],
  ['ERP-WT-007', '/finance/student-accounts'],
  ['ERP-WT-008', '/academics/exams/progress'],
  ['ERP-WT-009', '/school/pilot/dashboard'],
  ['ERP-WT-010a', '/communications/analytics/summary'],
  ['ERP-WT-010b', '/communications/analytics/parent-adoption'],
  ['ERP-WT-006a', '/intelligence/trust'],
  ['ERP-WT-006b', '/intelligence/ai-economics'],
  ['ERP-WT-005a', '/sis/promotion'],
  ['ERP-WT-005b', '/sis/reshuffle'],
  ['ERP-WT-005c', '/sis/section-balance'],
  ['ERP-WT-005d', '/sis/academic-assignment'],
  ['ERP-WT-004a', '/inventory/stock'],
  ['ERP-WT-004b', '/inventory/stock/approvals'],
];
console.log(`# Verify shipped ERP-WT endpoints (session role=${s.role}, school=${s.schoolId})\n`);
const out = [];
let ok = 0, gated = 0, bad = 0;
for (const [id, p] of CHECKS) {
  const r = await get(p);
  const good = r.status >= 200 && r.status < 300;
  const isGate = r.status === 403 && r.j?.error?.code === 'MODULE_DISABLED';
  if (good) ok++; else if (isGate) gated++; else bad++;
  const mark = good ? '✅' : isGate ? '🔒' : '❌';
  out.push({ id, path: p, status: r.status, shape: shape(r.j), good, isGate });
  console.log(`${mark} ${id.padEnd(12)} ${String(r.status).padEnd(4)} ${p.padEnd(42)} ${shape(r.j)}`);
}
console.log(`\n# ${ok} live-200, ${gated} entitlement-gated(403), ${bad} still-failing of ${CHECKS.length}`);
fs.writeFileSync('/tmp/verify-shipped.json', JSON.stringify(out, null, 2));
