/* ============================================================
   Akshara ERP — Development Progress Dashboard
   Vanilla JS. Loads progress.json / activity.json / prompts.json,
   renders the UI, auto-refreshes JSON every 30s, and drives the
   prompt-builder chat panel. HTML is never regenerated.
   ============================================================ */

'use strict';

const REFRESH_SECONDS = 30;
const HEALTH_STUCK_MIN = 15;   // "running" with no update older than this → Possible Stuck
const HEALTH_STALE_MIN = 8;    // running + quiet beyond this softens the "Running" bar toward amber
const STATUS_LABELS = {
  running: 'Running', completed: 'Completed', waiting: 'Waiting',
  blocked: 'Blocked', pending: 'Pending'
};
const LEVEL_ICONS = {
  start: '▶', done: '✔', commit: '◈', test: '✓', analyze: '⚙',
  blocked: '⛔', waiting: '⏸', info: '•', agent: '🤖'
};

/* ---- module state (survives refresh; not persisted in HTML) ---- */
let DATA = { progress: null, activity: null, prompts: null };
let collapsed = loadCollapsed();          // node ids the user has collapsed
let countdown = REFRESH_SECONDS;

/* ---------- tiny helpers ---------- */
const $ = (sel) => document.querySelector(sel);
const esc = (s) => String(s == null ? '' : s)
  .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;');

function loadCollapsed() {
  try { return new Set(JSON.parse(localStorage.getItem('akx.collapsed') || '[]')); }
  catch { return new Set(); }
}
function saveCollapsed() {
  try { localStorage.setItem('akx.collapsed', JSON.stringify([...collapsed])); } catch {}
}

function fmtClock(d) {
  return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
}
function fmtDateTime(iso) {
  if (!iso) return '—';
  const d = new Date(iso);
  if (isNaN(d)) return String(iso);
  return d.toLocaleString([], { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
}
function fmtDuration(ms) {
  if (ms == null || isNaN(ms) || ms < 0) return '—';
  const s = Math.floor(ms / 1000);
  const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60;
  if (h > 0) return `${h}h ${m}m`;
  if (m > 0) return `${m}m ${sec}s`;
  return `${sec}s`;
}

/* ============================================================
   DATA LOADING
   ============================================================ */
async function fetchJSON(name, fallback) {
  try {
    const res = await fetch(`${name}?t=${Date.now()}`, { cache: 'no-store' });
    if (!res.ok) throw new Error(`${name}: HTTP ${res.status}`);
    return await res.json();
  } catch (err) {
    // Live runtime files (progress/activity) are gitignored and may be absent on a fresh
    // clone — fall back to the committed *.seed.json starting snapshot.
    if (!fallback) throw err;
    const res = await fetch(`${fallback}?t=${Date.now()}`, { cache: 'no-store' });
    if (!res.ok) throw new Error(`${name} & ${fallback}: HTTP ${res.status}`);
    return await res.json();
  }
}

async function loadData(manual) {
  setLive('loading');
  setRefreshState('loading…');
  try {
    const [progress, activity, prompts] = await Promise.all([
      fetchJSON('progress.json', 'progress.seed.json'),
      fetchJSON('activity.json', 'activity.seed.json'),
      fetchJSON('prompts.json'),
    ]);
    DATA = { progress, activity, prompts };
    hideBanner();
    renderAll();
    setLive('ok');
    setRefreshState('ok · ' + fmtClock(new Date()));
  } catch (err) {
    handleLoadError(err);
    setLive('error');
    setRefreshState('error');
  }
  if (manual) {
    const b = $('#refreshBtn'); b.classList.remove('spin'); void b.offsetWidth; b.classList.add('spin');
  }
}

/* live refresh pill in the header: pending → loading → ok(flash) / error */
function setLive(state) {
  const el = $('#liveIndicator');
  const txt = $('#liveText');
  if (!el) return;
  el.classList.remove('live-ok', 'live-loading', 'live-error', 'flash');
  if (state === 'loading') { el.classList.add('live-loading'); txt.textContent = 'refreshing…'; }
  else if (state === 'ok') { el.classList.add('live-ok'); txt.textContent = 'live'; void el.offsetWidth; el.classList.add('flash'); }
  else if (state === 'error') { el.classList.add('live-error'); txt.textContent = 'offline'; }
}

function handleLoadError(err) {
  const isFile = location.protocol === 'file:';
  const banner = $('#banner');
  banner.className = 'banner err';
  banner.innerHTML = isFile
    ? `Could not read the JSON files over <code>file://</code> (browsers block local fetch). ` +
      `Serve this folder over HTTP — run <code>python3 -m http.server 8787</code> inside ` +
      `<code>tools/progress-dashboard/</code> and open <code>http://localhost:8787</code>. ` +
      `<span style="color:var(--text-faint)">(${esc(err.message)})</span>`
    : `Failed to load dashboard data: <code>${esc(err.message)}</code>. ` +
      `Check that progress.json / activity.json / prompts.json exist and are valid JSON.`;
  banner.classList.remove('hidden');
}
function hideBanner() { $('#banner').classList.add('hidden'); }
function setRefreshState(t) { $('#refreshState').textContent = t; }

/* ============================================================
   RENDER — top-level
   ============================================================ */
function renderAll() {
  const p = DATA.progress;
  if (!p) return;
  renderHeader(p.meta);
  renderHealth();
  renderCurrentStatus(p.currentStatus);
  renderRoadmap(p.roadmap || []);
  renderAgents(p.agents || []);
  renderWorkspace(p.workspace || {});
  renderActivity(DATA.activity);
  renderToday(p.todaySummary || {});
  renderNext(p.nextRoadmap || {});
  renderSystem(p.systemStatus || {});
  renderChips(DATA.prompts);
}

/* ---------- header ---------- */
function renderHeader(m = {}) {
  $('#hBranch').textContent = m.branch || '—';
  $('#hCommit').textContent = m.commit || '—';
  $('#hRoadmap').textContent = m.roadmapVersion || '—';
  $('#hSession').textContent = m.session || '—';
  $('#hUser').textContent = m.user || '—';
  $('#hUpdated').textContent = fmtDateTime(m.lastUpdated);

  const pct = Math.max(0, Math.min(100, Number(m.overallProgress) || 0));
  $('#overallRing').style.setProperty('--pct', pct);
  $('#overallPct').textContent = pct + '%';
  document.title = `[${pct}%] Akshara Dev Progress`;
}

/* ---------- current status ---------- */
function renderCurrentStatus(cs = {}) {
  const status = (cs.status || 'pending').toLowerCase();
  const pill = $('#csPill');
  pill.style.color = `var(--${status}, var(--pending))`;
  pill.style.background = `var(--${status}-soft, var(--pending-soft))`;
  pill.querySelector('.dot').style.background = `var(--${status}, var(--pending))`;
  $('#csStatus').textContent = STATUS_LABELS[status] || cs.status || '—';

  const cells = [
    ['Phase', cs.phase, 'wide big'],
    ['Wave', cs.wave, ''],
    ['Task', cs.task, 'wide'],
    ['Module', cs.module, 'mono'],
    ['Directory', cs.directory, 'mono'],
    ['File', cs.file, 'mono'],
    ['Running Since', fmtDateTime(cs.runningSince), ''],
    ['Elapsed', '<span data-elapsed="' + esc(cs.runningSince || '') + '">—</span>', 'raw'],
    ['Est. Remaining', cs.estimatedRemaining, ''],
  ];
  $('#csGrid').innerHTML = cells.map(([k, v, cls]) => {
    const raw = (cls || '').includes('raw');
    const vcls = (cls || '').replace('raw', '').trim();
    return `<div class="cs-cell ${(cls||'').includes('wide') ? 'wide' : ''}">
        <div class="k">${esc(k)}</div>
        <div class="v ${vcls}">${raw ? v : esc(v || '—')}</div>
      </div>`;
  }).join('');
  updateElapsed();
}

/* ---------- roadmap tree ---------- */
function renderRoadmap(nodes) {
  $('#legend').innerHTML = ['running','completed','waiting','blocked','pending']
    .map(s => `<span class="lg"><i style="background:var(--${s})"></i>${STATUS_LABELS[s]}</span>`).join('');
  $('#roadmapTree').innerHTML = nodes.map(n => renderNode(n, 0)).join('');
  // wire toggles
  $('#roadmapTree').querySelectorAll('.node-row.has-kids').forEach(row => {
    row.addEventListener('click', () => {
      const id = row.dataset.id;
      if (collapsed.has(id)) collapsed.delete(id); else collapsed.add(id);
      saveCollapsed();
      renderRoadmap(DATA.progress.roadmap || []);
    });
  });
}

function renderNode(node, depth) {
  const kids = node.children || [];
  const hasKids = kids.length > 0;
  const isOpen = !collapsed.has(node.id);
  const st = (node.status || 'pending').toLowerCase();
  const detail = node.detail ? `<span class="node-detail">${esc(node.detail)}</span>` : '';
  const badge = `<span class="node-badge b-${st}">${STATUS_LABELS[st] || st}</span>`;

  const row = `
    <div class="node-row ${hasKids ? 'has-kids' : 'leaf'}" data-id="${esc(node.id)}">
      <span class="chevron">${hasKids ? '▶' : ''}</span>
      <span class="s-dot s-${st}"></span>
      <span class="node-label">${esc(node.label)}</span>
      ${depth === 0 ? '' : badge}
      ${detail}
    </div>`;

  const children = hasKids && isOpen
    ? `<div class="node-children">${kids.map(c => renderNode(c, depth + 1)).join('')}</div>`
    : '';

  return `<div class="node ${isOpen ? 'open' : ''}">${row}${children}</div>`;
}

/* ---------- agents ---------- */
function renderAgents(agents) {
  $('#agentCount').textContent = agents.length;
  if (!agents.length) { $('#agentsList').innerHTML = `<div class="empty">No active agents.</div>`; return; }
  $('#agentsList').innerHTML = agents.map(a => {
    const st = (a.status || 'running').toLowerCase();
    const pct = Math.max(0, Math.min(100, Number(a.progress) || 0));
    return `<div class="agent">
      <div class="agent-top">
        <span class="agent-name"><span class="s-dot s-${st}"></span>${esc(a.name)}</span>
        <span class="node-badge b-${st}">${STATUS_LABELS[st] || st}</span>
      </div>
      <div class="agent-task">${esc(a.task || '—')}</div>
      ${a.file ? `<div class="agent-file">${esc(a.file)}</div>` : ''}
      <div class="agent-meta">
        <div class="progress-bar"><div class="progress-fill" style="width:${pct}%"></div></div>
        <span class="agent-pct">${pct}%</span>
      </div>
      <div class="agent-since">started ${fmtDateTime(a.started)}</div>
    </div>`;
  }).join('');
}

/* ---------- workspace ---------- */
function renderWorkspace(w) {
  const filePills = (arr, cls) => (arr || []).map(f =>
    `<span class="file-pill ${cls}">${esc(f.split('/').pop())}</span>`).join('') || '<span class="ws-row"><span class="v">—</span></span>';
  const clean = w.workspaceClean;
  $('#workspace').innerHTML = `
    <div class="ws-row"><span class="k">Editing</span><span class="v mono">${esc(w.currentlyEditing || '—')}</span></div>
    <div class="ws-row"><span class="k">Working dir</span><span class="v mono">${esc(w.workingDirectory || '—')}</span></div>
    <div class="ws-row"><span class="k">Created</span><span class="file-pills">${filePills(w.filesCreated, 'add')}</span></div>
    <div class="ws-row"><span class="k">Modified</span><span class="file-pills">${filePills(w.filesModified, 'mod')}</span></div>
    <div class="ws-row"><span class="k">Deleted</span><span class="file-pills">${filePills(w.filesDeleted, 'del')}</span></div>
    <div class="ws-row"><span class="k">Git status</span><span class="v">${esc(w.gitStatus || '—')}</span></div>
    <div class="ws-row"><span class="k">Last commit</span><span class="v mono">${esc(w.lastCommit || '—')}</span></div>
    <div class="ws-row"><span class="k">Clean?</span>
      <span class="ws-clean ${clean ? 'yes' : 'no'}">${clean ? '● Clean' : '○ Dirty'}</span></div>`;
}

/* ---------- activity log ---------- */
function renderActivity(activity) {
  const entries = ((activity && activity.entries) || []).slice();
  // newest first (by timestamp when present, else keep given order)
  entries.sort((a, b) => new Date(b.timestamp || 0) - new Date(a.timestamp || 0));
  const list = entries.slice(0, 100);
  $('#activityCount').textContent = list.length;
  if (!list.length) { $('#activityLog').innerHTML = `<div class="empty">No activity yet.</div>`; return; }
  $('#activityLog').innerHTML = list.map(e => {
    const lv = (e.level || 'info').toLowerCase();
    const ico = LEVEL_ICONS[lv] || '•';
    const time = e.time || (e.timestamp ? fmtClock(new Date(e.timestamp)) : '');
    return `<div class="log-item lv-${lv}">
      <span class="log-time">${esc(time)}</span>
      <span class="log-body"><span class="log-ico">${ico}</span><span class="log-msg">${esc(e.message)}</span></span>
    </div>`;
  }).join('');
}

/* ---------- today summary ---------- */
function renderToday(t) {
  const tiles = [
    ['Tasks', t.tasksCompleted, 'good'],
    ['Commits', t.commits, 'info'],
    ['Created', t.filesCreated, 'info'],
    ['Modified', t.filesModified, 'info'],
    ['Tests', t.testsPassed, 'good'],
    ['Analyze', t.analyze, 'good'],
    ['Failures', t.failures, Number(t.failures) > 0 ? 'bad' : 'good'],
  ];
  $('#today').innerHTML = tiles.map(([lbl, num, cls]) =>
    `<div class="tile ${cls}"><div class="num">${esc(num == null ? '—' : num)}</div><div class="lbl">${esc(lbl)}</div></div>`
  ).join('');
}

/* ---------- next roadmap ---------- */
function renderNext(n) {
  const rows = [
    ['Next task', n.nextTask],
    ['Dependency', n.dependency],
    ['Reason if blocked', n.reasonIfBlocked],
    ['Owner gate', n.ownerGate, 'gate'],
    ['Estimated start', n.estimatedStart],
  ];
  $('#next').innerHTML = rows.map(([k, v, cls]) =>
    `<div class="kv"><span class="k">${esc(k)}</span><span class="v ${cls || ''}">${esc(v || '—')}</span></div>`
  ).join('');
}

/* ---------- system status ---------- */
function renderSystem(s) {
  const items = [
    ['Branch', s.branch, 'mono'],
    ['Git', s.git],
    ['Workspace', s.workspace],
    ['Flutter Analyze', s.flutterAnalyze],
    ['Tests', s.tests],
    ['Build', s.build],
    ['Mode', s.currentMode],
  ];
  const okWords = /clean|0|pass|no issues|green/i;
  $('#system').innerHTML = items.map(([k, v, mono]) => {
    const good = v && okWords.test(String(v));
    const dot = (k === 'Git' || k === 'Workspace')
      ? `<span class="s-dot s-${good ? 'completed' : 'waiting'}"></span>` : '';
    return `<div class="sys-item"><span class="k">${esc(k)}</span>
      <span class="v ${mono || ''}">${dot}${esc(v || '—')}</span></div>`;
  }).join('');
}

/* ============================================================
   ELAPSED / RUNNING TIME  (ticks every second, no re-fetch)
   ============================================================ */
function updateElapsed() {
  const now = Date.now();
  document.querySelectorAll('[data-elapsed]').forEach(el => {
    const iso = el.getAttribute('data-elapsed');
    if (!iso) { el.textContent = '—'; return; }
    const started = new Date(iso).getTime();
    el.textContent = isNaN(started) ? '—' : fmtDuration(now - started);
  });
  $('#hNow').textContent = fmtClock(new Date());
}

/* ============================================================
   CLAUDE HEALTH  (Running / Idle / Blocked / Possible Stuck)
   Derived from currentStatus.status + age of meta.lastUpdated.
   Recomputed every second so it can cross the stuck threshold live.
   ============================================================ */
function computeHealth(now) {
  const p = DATA.progress;
  if (!p) return null;
  const status = ((p.currentStatus && p.currentStatus.status) || 'pending').toLowerCase();
  const updatedIso = p.meta && p.meta.lastUpdated;
  const updated = updatedIso ? new Date(updatedIso).getTime() : NaN;
  const ageMs = isNaN(updated) ? null : Math.max(0, now - updated);
  const ageMin = ageMs == null ? null : ageMs / 60000;

  if (status === 'blocked') {
    return { key: 'blocked', state: 'Blocked', color: 'blocked',
      reason: 'Current task is blocked — it needs a resolution before work can continue.', ageMs };
  }
  if (status === 'running') {
    if (ageMin != null && ageMin > HEALTH_STUCK_MIN) {
      return { key: 'stuck', state: 'Possible Stuck', color: 'waiting',
        reason: `Marked "running" but no update for ${fmtDuration(ageMs)} (> ${HEALTH_STUCK_MIN}m). It may have stalled — worth a check.`, ageMs };
    }
    return { key: 'running', state: 'Running', color: 'running',
      reason: 'Actively working — progress reported recently.', ageMs };
  }
  if (status === 'waiting') {
    return { key: 'idle', state: 'Idle', color: 'completed',
      reason: 'Paused — waiting on a dependency or an owner gate.', ageMs };
  }
  // completed / pending
  return { key: 'idle', state: 'Idle', color: 'completed',
    reason: status === 'completed'
      ? 'Last task complete — awaiting the next instruction.'
      : 'Idle — no task currently in progress.', ageMs };
}

function renderHealth() {
  const card = $('#healthCard');
  if (!card) return;
  const h = computeHealth(Date.now());
  if (!h) return;

  card.style.setProperty('--health', `var(--${h.color})`);
  card.style.setProperty('--health-soft', `var(--${h.color}-soft)`);
  card.classList.toggle('pulsing', h.key === 'running');

  $('#healthState').textContent = h.state;
  $('#healthReason').textContent = h.reason;
  $('#healthAgo').textContent = h.ageMs == null
    ? 'no data'
    : (h.ageMs < 45000 ? 'updated just now' : `updated ${fmtDuration(h.ageMs)} ago`);

  // meter: for "running" it fills as it goes quiet (toward the stuck line);
  // for idle/blocked/stuck it's a full state-colored bar.
  const stuckMs = HEALTH_STUCK_MIN * 60000;
  let pct;
  if (h.key === 'running') {
    pct = h.ageMs == null ? 6 : Math.max(6, Math.min(100, (h.ageMs / stuckMs) * 100));
  } else {
    pct = 100;
  }
  $('#healthMeter').style.width = pct + '%';
}

/* ============================================================
   CHAT / PROMPT BUILDER
   ============================================================ */
function renderChips(prompts) {
  const chips = (prompts && prompts.chips) || [];
  $('#chatChips').innerHTML = chips.map(c =>
    `<button class="p-chip" type="button">${esc(c)}</button>`).join('');
  $('#chatChips').querySelectorAll('.p-chip').forEach(btn => {
    btn.addEventListener('click', () => {
      const input = $('#chatInput');
      input.value = btn.textContent;
      input.focus();
      $('#preparedPrompt').classList.add('hidden');
    });
  });
}

function buildContextSnapshot() {
  const cs = (DATA.progress && DATA.progress.currentStatus) || {};
  const n = (DATA.progress && DATA.progress.nextRoadmap) || {};
  const tpl = (DATA.prompts && DATA.prompts.contextTemplate) ||
    '\n\n---\nContext: phase={phase}, wave={wave}, task={task} ({status}), next={next}\n';
  return tpl
    .replace('{phase}', cs.phase || '—')
    .replace('{wave}', cs.wave || '—')
    .replace('{task}', cs.task || '—')
    .replace('{status}', cs.status || '—')
    .replace('{next}', n.nextTask || '—');
}

function preparePrompt() {
  const base = $('#chatInput').value.trim();
  if (!base) { $('#chatInput').focus(); return ''; }
  const withCtx = $('#ctxToggle').checked ? base + buildContextSnapshot() : base;
  const out = $('#preparedPrompt');
  out.textContent = withCtx;
  out.classList.remove('hidden');
  return withCtx;
}

async function copyPrompt() {
  const text = ($('#preparedPrompt').classList.contains('hidden'))
    ? preparePrompt()
    : $('#preparedPrompt').textContent;
  if (!text) return;
  try {
    await navigator.clipboard.writeText(text);
  } catch {
    // fallback for non-secure contexts
    const ta = document.createElement('textarea');
    ta.value = text; document.body.appendChild(ta); ta.select();
    try { document.execCommand('copy'); } catch {}
    document.body.removeChild(ta);
  }
  const btn = $('#copyBtn');
  const orig = btn.textContent;
  btn.textContent = 'Copied ✓'; btn.classList.add('copied');
  setTimeout(() => { btn.textContent = orig; btn.classList.remove('copied'); }, 1600);
}

/* ============================================================
   THEME
   ============================================================ */
function initTheme() {
  const saved = localStorage.getItem('akx.theme') || 'dark';
  document.documentElement.setAttribute('data-theme', saved);
  $('#themeBtn').textContent = saved === 'dark' ? '☾' : '☀';
}
function toggleTheme() {
  const cur = document.documentElement.getAttribute('data-theme');
  const next = cur === 'dark' ? 'light' : 'dark';
  document.documentElement.setAttribute('data-theme', next);
  $('#themeBtn').textContent = next === 'dark' ? '☾' : '☀';
  try { localStorage.setItem('akx.theme', next); } catch {}
}

/* ============================================================
   REFRESH LOOP
   ============================================================ */
function tickCountdown() {
  countdown -= 1;
  if (countdown <= 0) { countdown = REFRESH_SECONDS; loadData(false); }
  $('#refreshCountdown').textContent = countdown;
}

/* ============================================================
   INIT
   ============================================================ */
function init() {
  initTheme();
  $('#refreshBtn').addEventListener('click', () => { countdown = REFRESH_SECONDS; loadData(true); });
  $('#themeBtn').addEventListener('click', toggleTheme);
  $('#askBtn').addEventListener('click', preparePrompt);
  $('#copyBtn').addEventListener('click', copyPrompt);
  $('#clearBtn').addEventListener('click', () => {
    $('#chatInput').value = '';
    $('#preparedPrompt').classList.add('hidden');
    $('#chatInput').focus();
  });

  loadData(false);
  setInterval(tickCountdown, 1000);  // countdown + drives 30s auto-refresh
  setInterval(() => { updateElapsed(); renderHealth(); }, 1000);  // live elapsed, clock & health
}

document.addEventListener('DOMContentLoaded', init);
