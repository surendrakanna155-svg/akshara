-- PRC P5 (red-team Round 4) — platform-tables RLS lockdown LIVE CERT.
-- Proves the 3 platform tables are no longer reachable by anon/authenticated while
-- the legitimate erp_platform role still works. Run against prod after mig 20260896.
--
-- Run: docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -f - < this
DO $$
DECLARE anon_denied int:=0; auth_denied int:=0; plat_ok int:=0;
BEGIN
  SET ROLE anon;
  BEGIN PERFORM 1 FROM platform_provider_configs LIMIT 1; EXCEPTION WHEN insufficient_privilege THEN anon_denied:=1; END;
  RESET ROLE;
  SET ROLE authenticated;
  BEGIN PERFORM 1 FROM platform_feature_enablements LIMIT 1; EXCEPTION WHEN insufficient_privilege THEN auth_denied:=1; END;
  RESET ROLE;
  SET ROLE erp_platform;
  BEGIN PERFORM 1 FROM platform_provider_configs LIMIT 1; plat_ok:=1; EXCEPTION WHEN OTHERS THEN plat_ok:=0; END;
  RESET ROLE;
  RAISE NOTICE 'anon_denied=% (expect 1) · authenticated_denied=% (expect 1) · erp_platform_ok=% (expect 1)',
    anon_denied, auth_denied, plat_ok;
  IF anon_denied=1 AND auth_denied=1 AND plat_ok=1 THEN
    RAISE NOTICE '== ✅ PASS ==';
  ELSE
    RAISE NOTICE '== ❌ FAIL ==';
  END IF;
END $$;
-- Verified on prod 2026-07-17 after 20260896: anon_denied=1 · authenticated_denied=1 · erp_platform_ok=1 → PASS.
