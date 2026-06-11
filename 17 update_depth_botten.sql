-- =============================================================================
-- update_depth_botten.sql
--
-- Updates MIN_PROVDJUP_M and MAX_PROVDJUP_M in INTERIM_SAMPLES where:
--   • Both depth columns are 'MISSING'
--   • UNDERSOKNINGSTYP = 'botten' (case-insensitive)
--
-- Sets both depth fields to '20.0' and PROVKOMMENTAR to
-- 'depth assumed for botten'.
--
-- Note: PROVKOMMENTAR is overwritten unconditionally (any prior value is
-- replaced). The preview SELECT lets you confirm affected rows before
-- running the UPDATE.
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
    AND UPPER(TRIM(UNDERSOKNINGSTYP)) = 'BOTTEN'
ORDER BY ROWID;


-- =============================================================================
-- UPDATE
-- =============================================================================
UPDATE INTERIM_SAMPLES
SET
    MIN_PROVDJUP_M = '20.0',
    MAX_PROVDJUP_M = '20.0',
    PROVKOMMENTAR  = 'depth assumed for botten'
WHERE
    MIN_PROVDJUP_M  = 'MISSING'
    AND MAX_PROVDJUP_M = 'MISSING'
    AND UPPER(TRIM(UNDERSOKNINGSTYP)) = 'BOTTEN';


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
WHERE PROVKOMMENTAR = 'depth assumed for botten'
ORDER BY ROWID;


-- =============================================================================
-- Summary count
-- =============================================================================
SELECT
    COUNT(*) AS rows_updated
FROM INTERIM_SAMPLES
WHERE PROVKOMMENTAR = 'depth assumed for botten';
