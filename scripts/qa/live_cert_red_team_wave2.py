#!/usr/bin/env python3
"""Live-mode certification for **Red Team Wave 2 — Tenant & Privacy (RLS)**
against the live VPS pilot. Real VPS + real Postgres + real RLS evaluated under
the unprivileged `erp_tenant` role (the exact role the edge functions use), with
the per-request tenant GUCs (app.scope / app.school_id / app.parent_user_id …)
set the same way `withTenantContext` sets them.

Source of truth: docs/RED_TEAM_MASTER_TRACKER.md (RT-09..RT-15).

Methodology: every behavioural probe runs inside a single transaction that
  (1) optionally seeds a fixture row as the superuser (bypasses RLS),
  (2) `SET LOCAL ROLE erp_tenant` + sets the persona GUCs,
  (3) attempts the read/write the finding describes,
  (4) ROLLBACKs.
Nothing is committed — the live DB is untouched and the script is re-runnable.
This is the same rolled-back-probe method that originally REPRODUCED RT-09..14.

Proves on the LIVE database, post-deploy:
  RT-09  parent_academic_summaries — a NON-guardian parent reads a child's
         summary → 0 rows (leak closed); the real guardian still reads 1.
  RT-10  parent_engagement_snapshots — any parent scope → 0 rows (staff-only);
         school scope still reads the row.
  RT-11  parent_meeting_summaries — any parent scope → 0 rows; school scope reads.
  RT-12  comm_messages — a non-participant parent reads a private thread → 0 rows
         and an INSERT into it is DENIED; the owning parent reads its own msg = 1.
  RT-13  school_memory_events — a parent INSERT is DENIED (write closed) while a
         parent SELECT still works (read intentionally open).
  RT-14  domain_events — a school-A context INSERT tagged school-B is DENIED;
         the same-school insert is allowed.
  RT-15  platform_secret_vault — RLS is ENABLED + FORCED with a deny-all policy.
Plus static policy assertions that each new predicate is actually installed.
"""
import subprocess, time

ORG = "a1000000-0000-4000-8000-000000000001"
SCHOOL_A = "a2000000-0000-4000-8000-000000000001"
SCHOOL_B = "a2000000-0000-4000-8000-000000000002"
STUDENT_A = "a4000000-0000-4000-8000-000000000001"
GUARDIAN_A = "a3000000-0000-4000-8000-000000000003"      # real active guardian of STUDENT_A
THREAD_A = "d1000000-0000-4000-8000-000000000001"        # comm_thread owned by GUARDIAN_A in SCHOOL_A
STRANGER = "a3000000-0000-4000-8000-0000000000ee"        # parent who guardians nobody
SOCK = "~/.ssh/akshara-cm.sock"

results = []


def rec(check, ok, detail=""):
    results.append((check, bool(ok), detail))
    print(f"  [{'PASS' if ok else 'FAIL':>4}] {check}  {detail}")


def sql(stmt):
    """Run SQL on the live DB (superuser). Returns stripped stdout."""
    p = subprocess.run(
        ["ssh", "-o", "ControlPath=" + SOCK, "akshara",
         "docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -qtA -v ON_ERROR_STOP=0"],
        input=stmt, capture_output=True, text=True, timeout=90)
    return (p.stdout + p.stderr).strip()


def probe(body, scope, school, parent=None, user=None, seed=""):
    """Run `body` as erp_tenant under the given persona, inside a rolled-back txn.
    `seed` (optional) runs first as superuser to plant a fixture row."""
    gucs = [
        f"SET LOCAL app.tenant_id='{ORG}'",
        f"SET LOCAL app.scope='{scope}'",
        f"SET LOCAL app.school_id='{school}'",
    ]
    if parent:
        gucs.append(f"SET LOCAL app.parent_user_id='{parent}'")
    gucs.append(f"SET LOCAL app.user_id='{user or parent or GUARDIAN_A}'")
    stmt = "BEGIN;\n"
    if seed:
        stmt += seed + "\n"
    stmt += "SET LOCAL ROLE erp_tenant;\n"
    stmt += ";\n".join(gucs) + ";\n"
    stmt += body + "\n"
    stmt += "ROLLBACK;\n"
    return sql(stmt)


def denied(out):
    return ("row-level security" in out.lower()) or ("permission denied" in out.lower())


print("=== Red Team Wave 2 LIVE certification (real VPS / erp_tenant role / real RLS) ===\n")

# ── Connectivity ────────────────────────────────────────────────────────────
who = sql("SELECT current_user;")
rec("live DB reachable via control socket", who == "supabase_admin", f"current_user={who}")

# ── Static: the hardened policies are actually deployed ─────────────────────
print("\n-- Policy predicates are installed (post-deploy) --")
rec("RT-09 parent_academic_summaries_access has guardian pin",
    sql("SELECT count(*) FROM pg_policies WHERE tablename='parent_academic_summaries' AND policyname='parent_academic_summaries_access' AND qual LIKE '%student_guardians%' AND with_check LIKE '%student_guardians%'") == "1")
rec("RT-09 old org+school-only policy removed",
    sql("SELECT count(*) FROM pg_policies WHERE tablename='parent_academic_summaries' AND policyname='parent_academic_summaries_scope'") == "0")
rec("RT-10 parent_engagement_scope restricted to school scope",
    sql("SELECT count(*) FROM pg_policies WHERE tablename='parent_engagement_snapshots' AND policyname='parent_engagement_scope' AND qual LIKE '%school%' AND qual NOT LIKE '%parent%'") == "1")
rec("RT-11 parent_meeting_summaries_scope restricted to school scope",
    sql("SELECT count(*) FROM pg_policies WHERE tablename='parent_meeting_summaries' AND policyname='parent_meeting_summaries_scope' AND qual NOT LIKE '%parent%'") == "1")
rec("RT-12 comm_messages_thread now checks comm_threads participation",
    sql("SELECT count(*) FROM pg_policies WHERE tablename='comm_messages' AND policyname='comm_messages_thread' AND qual LIKE '%comm_threads%' AND with_check LIKE '%comm_threads%'") == "1")
rec("RT-13 school_memory_events split into read + school-only write policies",
    sql("SELECT count(*) FROM pg_policies WHERE tablename='school_memory_events' AND policyname IN ('school_memory_events_read','school_memory_events_write')") == "2")
rec("RT-14 domain_events_school_insert now pins school_id",
    sql("SELECT count(*) FROM pg_policies WHERE tablename='domain_events' AND policyname='domain_events_school_insert' AND with_check LIKE '%school_id%'") == "1")
rec("RT-15 platform_secret_vault RLS enabled + forced",
    sql("SELECT relrowsecurity::text||relforcerowsecurity::text FROM pg_class WHERE relname='platform_secret_vault'") == "truetrue")
rec("RT-15 platform_secret_vault deny-all policy present",
    sql("SELECT count(*) FROM pg_policies WHERE tablename='platform_secret_vault' AND policyname='platform_secret_vault_deny_all'") == "1")

# ── RT-09: cross-family academic summary leak ───────────────────────────────
print("\n-- RT-09 parent academic summary: guardian pin enforced --")
own = probe(f"SELECT count(*) FROM parent_academic_summaries WHERE student_id='{STUDENT_A}';",
            "parent", SCHOOL_A, parent=GUARDIAN_A)
rec("RT-09 real guardian still reads own child's summary (=1)", own.splitlines()[-1] == "1", f"rows={own.splitlines()[-1]}")
foreign = probe(f"SELECT count(*) FROM parent_academic_summaries WHERE student_id='{STUDENT_A}';",
                "parent", SCHOOL_A, parent=STRANGER)
rec("RT-09 NON-guardian parent reads child's summary → 0 (leak closed)", foreign.splitlines()[-1] == "0", f"rows={foreign.splitlines()[-1]}")

# ── RT-10: parent engagement snapshot leak ──────────────────────────────────
print("\n-- RT-10 parent engagement snapshot: parent scope denied, staff only --")
seed_eng = (f"INSERT INTO parent_engagement_snapshots (organization_id, school_id, parent_user_id, engagement_score) "
            f"VALUES ('{ORG}','{SCHOOL_A}','{STRANGER}',99);")
as_parent = probe("SELECT count(*) FROM parent_engagement_snapshots;", "parent", SCHOOL_A, parent=STRANGER, seed=seed_eng)
rec("RT-10 parent scope reads engagement snapshots → 0", as_parent.splitlines()[-1] == "0", f"rows={as_parent.splitlines()[-1]}")
as_staff = probe("SELECT count(*) FROM parent_engagement_snapshots;", "school", SCHOOL_A, seed=seed_eng)
rec("RT-10 staff (school scope) still reads the snapshot (=1)", as_staff.splitlines()[-1] == "1", f"rows={as_staff.splitlines()[-1]}")

# ── RT-11: parent meeting summary leak ──────────────────────────────────────
print("\n-- RT-11 parent meeting summary: parent scope denied, staff only --")
seed_mtg = (f"INSERT INTO parent_meeting_summaries (organization_id, school_id, teacher_user_id, student_id, meeting_date, summary_json) "
            f"VALUES ('{ORG}','{SCHOOL_A}','{GUARDIAN_A}','{STUDENT_A}',CURRENT_DATE,'{{}}'::jsonb);")
m_parent = probe("SELECT count(*) FROM parent_meeting_summaries;", "parent", SCHOOL_A, parent=STRANGER, seed=seed_mtg)
rec("RT-11 parent scope reads meeting summaries → 0", m_parent.splitlines()[-1] == "0", f"rows={m_parent.splitlines()[-1]}")
m_staff = probe("SELECT count(*) FROM parent_meeting_summaries;", "school", SCHOOL_A, seed=seed_mtg)
rec("RT-11 staff (school scope) still reads the meeting summary (=1)", m_staff.splitlines()[-1] == "1", f"rows={m_staff.splitlines()[-1]}")

# ── RT-12: comm_messages cross-thread read + injection ──────────────────────
print("\n-- RT-12 communication hub: thread-participation enforced --")
seed_msg = (f"INSERT INTO comm_messages (thread_id, organization_id, school_id, sender_user_id, sender_role, body) "
            f"VALUES ('{THREAD_A}','{ORG}','{SCHOOL_A}','{GUARDIAN_A}','parent','PRIVATE-MSG-FOR-FAMILY-A');")
owner = probe(f"SELECT count(*) FROM comm_messages WHERE thread_id='{THREAD_A}' AND body='PRIVATE-MSG-FOR-FAMILY-A';",
              "parent", SCHOOL_A, parent=GUARDIAN_A, seed=seed_msg)
rec("RT-12 owning parent reads its own thread message (=1)", owner.splitlines()[-1] == "1", f"rows={owner.splitlines()[-1]}")
intruder = probe(f"SELECT count(*) FROM comm_messages WHERE thread_id='{THREAD_A}';",
                 "parent", SCHOOL_A, parent=STRANGER, seed=seed_msg)
rec("RT-12 non-participant parent reads the private thread → 0 (leak closed)", intruder.splitlines()[-1] == "0", f"rows={intruder.splitlines()[-1]}")
inject = probe(f"INSERT INTO comm_messages (thread_id, organization_id, school_id, sender_user_id, sender_role, body) "
               f"VALUES ('{THREAD_A}','{ORG}','{SCHOOL_A}','{STRANGER}','parent','INJECTED') RETURNING 1;",
               "parent", SCHOOL_A, parent=STRANGER)
rec("RT-12 non-participant parent INSERT into the thread is DENIED", denied(inject) and "\n1" not in ("\n" + inject), f"out={inject.splitlines()[-1][:60]}")

# ── RT-13: school memory write scope ────────────────────────────────────────
print("\n-- RT-13 school memories: parent write denied, read kept --")
p_read = probe("SELECT count(*) >= 0 FROM school_memory_events;", "parent", SCHOOL_A, parent=GUARDIAN_A)
rec("RT-13 parent SELECT on school memories still works (read open)", p_read.splitlines()[-1] in ("t", "true"), f"out={p_read.splitlines()[-1]}")
p_write = probe(f"INSERT INTO school_memory_events (organization_id, school_id, title, category) "
                f"VALUES ('{ORG}','{SCHOOL_A}','probe','other') RETURNING 1;",
                "parent", SCHOOL_A, parent=GUARDIAN_A)
rec("RT-13 parent INSERT into school memories is DENIED (write closed)", denied(p_write) and p_write.splitlines()[-1] != "1", f"out={p_write.splitlines()[-1][:60]}")
s_write = probe(f"INSERT INTO school_memory_events (organization_id, school_id, title, category) "
                f"VALUES ('{ORG}','{SCHOOL_A}','probe','other') RETURNING 1;",
                "school", SCHOOL_A)
rec("RT-13 staff (school scope) INSERT still allowed (=1)", s_write.splitlines()[-1] == "1", f"out={s_write.splitlines()[-1]}")

# ── RT-14: domain_events cross-school pollution ─────────────────────────────
print("\n-- RT-14 audit/domain_events: school_id pinned on insert --")
cross = probe(f"INSERT INTO domain_events (organization_id, school_id, event_type, source_module) "
              f"VALUES ('{ORG}','{SCHOOL_B}','probe','cert') RETURNING 1;",
              "school", SCHOOL_A)
rec("RT-14 school-A context INSERT tagged school-B is DENIED", denied(cross) and cross.splitlines()[-1] != "1", f"out={cross.splitlines()[-1][:60]}")
same = probe(f"INSERT INTO domain_events (organization_id, school_id, event_type, source_module) "
             f"VALUES ('{ORG}','{SCHOOL_A}','probe','cert') RETURNING 1;",
             "school", SCHOOL_A)
rec("RT-14 same-school (school-A) INSERT still allowed (=1)", same.splitlines()[-1] == "1", f"out={same.splitlines()[-1]}")

# ── RT-15: secret vault defence-in-depth ────────────────────────────────────
print("\n-- RT-15 platform secret vault: RLS deny-all (defence in depth) --")
vault = probe("SELECT count(*) FROM platform_secret_vault;", "school", SCHOOL_A)
rec("RT-15 erp_tenant cannot read the vault (no grant AND/OR RLS deny-all)",
    denied(vault) or vault.splitlines()[-1] == "0", f"out={vault.splitlines()[-1][:60]}")

passed = sum(1 for _, ok, _ in results if ok)
total = len(results)
print(f"\n=== Red Team Wave 2: {passed}/{total} checks passed ===")
for c, ok, det in results:
    if not ok:
        print(f"  FAIL: {c}  {det}")
raise SystemExit(0 if passed == total else 1)
