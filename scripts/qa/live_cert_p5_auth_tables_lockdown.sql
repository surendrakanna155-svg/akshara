-- PRC P5 (red-team Round 4/5) — sessions + otp_requests RLS lockdown LIVE CERT.
-- Proves the auth tables are no longer reachable by anon while the service-role
-- auth flow (read + write) still works under FORCE RLS. Run after mig 20260897.
--
-- Run: docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -f - < this
DO $$
DECLARE anon_s int:=0; anon_o int:=0; svc_s int:=0; svc_o int:=0; ins_ok int:=0; upd_ok int:=0; ru uuid;
BEGIN
  SET ROLE anon;
  BEGIN PERFORM 1 FROM sessions LIMIT 1; EXCEPTION WHEN insufficient_privilege THEN anon_s:=1; END;
  BEGIN PERFORM 1 FROM otp_requests LIMIT 1; EXCEPTION WHEN insufficient_privilege THEN anon_o:=1; END;
  RESET ROLE;
  SELECT id INTO ru FROM users LIMIT 1;
  SET ROLE service_role;
  BEGIN PERFORM count(*) FROM sessions; svc_s:=1; EXCEPTION WHEN OTHERS THEN svc_s:=0; END;
  BEGIN PERFORM count(*) FROM otp_requests; svc_o:=1; EXCEPTION WHEN OTHERS THEN svc_o:=0; END;
  BEGIN
    INSERT INTO sessions(id,user_id,tenant_id,scope)
      VALUES ('f8000000-0000-4000-8000-0000000000aa', ru, 'a1000000-0000-4000-8000-000000000001', 'school');
    ins_ok:=1;
    UPDATE sessions SET revoked_at=now() WHERE id='f8000000-0000-4000-8000-0000000000aa'; IF FOUND THEN upd_ok:=1; END IF;
    DELETE FROM sessions WHERE id='f8000000-0000-4000-8000-0000000000aa';
  EXCEPTION WHEN OTHERS THEN NULL; END;
  RESET ROLE;
  RAISE NOTICE 'anon denied s/o=%/% (expect 1/1) · service_role read s/o=%/% write ins/upd=%/% (expect all 1)',
    anon_s, anon_o, svc_s, svc_o, ins_ok, upd_ok;
  IF anon_s=1 AND anon_o=1 AND svc_s=1 AND svc_o=1 AND ins_ok=1 AND upd_ok=1 THEN RAISE NOTICE '== ✅ PASS =='; ELSE RAISE NOTICE '== ❌ FAIL =='; END IF;
END $$;
-- Verified on prod 2026-07-17 after 20260897: anon denied 1/1 · service_role read 1/1 · write ins/upd 1/1 → PASS. Auth flow intact.
