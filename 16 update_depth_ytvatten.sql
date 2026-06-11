-- =============================================================================
-- update_depth_ytvatten.sql
--
-- Updates MIN_PROVDJUP_M and MAX_PROVDJUP_M in INTERIM_SAMPLES where:
--   • Both depth columns are 'MISSING'
--   • UNDERSOKNINGSTYP = 'ytvatten' (case-insensitive)
--
-- Sets both depth fields to '1.0' and PROVKOMMENTAR to
-- 'depth assumed for ytvatten'.
--
-- Note: PROVKOMMENTAR is overwritten unconditionally here (any prior value
-- is replaced) because the condition already fully describes the situation.
-- If you prefer to preserve existing non-MISSING comments, see the
-- conditional append pattern used in update_depth_from_undersokningstyp.sql.
-- =============================================================================


-- =============================================================================
-- Preview: inspect rows that will be updated
-- =============================================================================
SELECT
    ROWID,
    UNDERSOKNINGSTYP,
    MIN_PROVDJUP_M,
    MAX_PROVDJUP_M,
    PROVKOMMENTAR
FROM INTERIM_SAMPLES
WHERE
    MIN_PROVDJUP_M  = 'MISSING'
    AND MAX_PROVDJUP_M = 'MISSING'
    AND UPPER(TRIM(UNDERSOKNINGSTYP)) = 'YTVATTEN'
ORDER BY ROWID;


-- =============================================================================
-- UPDATE
-- =============================================================================
UPDATE INTERIM_SAMPLES
SET
    MIN_PROVDJUP_M = '1.0',
    MAX_PROVDJUP_M = '1.0',
    PROVKOMMENTAR  = 'depth assumed for ytvatten'
WHERE
    MIN_PROVDJUP_M  = 'MISSING'
    AND MAX_PROVDJUP_M = 'MISSING'
    AND UPPER(TRIM(UNDERSOKNINGSTYP)) = 'YTVATTEN';


-- =============================================================================
-- Verification: review updated rows
-- =============================================================================
SELECT
    ROWID,
    UNDERSOKNINGSTYP,
    MIN_PROVDJUP_M,
    MAX_PROVDJUP_M,
    PROVKOMMENTAR
FROM INTERIM_SAMPLES
WHERE PROVKOMMENTAR = 'depth assumed for ytvatten'
ORDER BY ROWID;


-- =============================================================================
-- Summary count
-- =============================================================================
SELECT
    COUNT(*) AS rows_updated
FROM INTERIM_SAMPLES
WHERE PROVKOMMENTAR = 'depth assumed for ytvatten';
