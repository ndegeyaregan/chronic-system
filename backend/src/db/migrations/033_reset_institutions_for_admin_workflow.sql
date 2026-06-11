-- ============================================================
-- 033_reset_institutions_for_admin_workflow.sql
--
-- One-time soft-delete of every institution currently in the DB so
-- that the admin can start curating the catalogue from a clean
-- slate via the portal + the Flutter "Sync from Sanlam" button.
--
-- Runs at most once: we record a flag in `system_state` so that
-- subsequent invocations of `migrate.js` are no-ops and do NOT wipe
-- newly-added institutions.
-- ============================================================

-- 1. Idempotent flag table to track one-shot data migrations.
CREATE TABLE IF NOT EXISTS system_state (
  key         TEXT PRIMARY KEY,
  value       TEXT,
  applied_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

-- 2. One-shot guard + soft delete.
DO $$
DECLARE
  v_already_done   BOOLEAN;
  v_hospitals_hit  INTEGER;
  v_pharmacies_hit INTEGER;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM system_state
     WHERE key = 'institutions_wiped_for_admin_workflow'
  ) INTO v_already_done;

  IF v_already_done THEN
    RAISE NOTICE 'Skipping institution wipe — already applied.';
    RETURN;
  END IF;

  UPDATE hospitals
     SET is_deleted = TRUE,
         deleted_at = NOW()
   WHERE is_deleted = FALSE;
  GET DIAGNOSTICS v_hospitals_hit = ROW_COUNT;

  UPDATE pharmacies
     SET is_deleted = TRUE,
         deleted_at = NOW()
   WHERE is_deleted = FALSE;
  GET DIAGNOSTICS v_pharmacies_hit = ROW_COUNT;

  INSERT INTO system_state (key, value)
  VALUES (
    'institutions_wiped_for_admin_workflow',
    format('hospitals=%s pharmacies=%s', v_hospitals_hit, v_pharmacies_hit)
  );

  RAISE NOTICE 'Soft-deleted % hospitals and % pharmacies.',
    v_hospitals_hit, v_pharmacies_hit;
END $$;
