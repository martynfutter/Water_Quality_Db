-- =============================================================================
-- Add INTERIM_LOCATION_ID column to INTERIM_SAMPLES and populate it
-- by matching all 8 location columns against INTERIM_LOCATIONS
-- =============================================================================

ALTER TABLE INTERIM_SAMPLES
    ADD COLUMN INTERIM_LOCATION_ID INTEGER;

-- =============================================================================
-- Populate by joining on all 8 location fields
-- =============================================================================

UPDATE INTERIM_SAMPLES
SET INTERIM_LOCATION_ID = (
    SELECT IL.LOCATION_ID
    FROM INTERIM_LOCATIONS IL
    WHERE IL.OVERVAKNINGSSTATION    = INTERIM_SAMPLES.OVERVAKNINGSSTATION
      AND IL.STATIONSKOORDINAT_N_X  = INTERIM_SAMPLES.STATIONSKOORDINAT_N_X
      AND IL.STATIONSKOORDINAT_E_Y  = INTERIM_SAMPLES.STATIONSKOORDINAT_E_Y
      AND IL.PROVPLATS              = INTERIM_SAMPLES.PROVPLATS
      AND IL.PROVPLATSKOORDINAT_N_X = INTERIM_SAMPLES.PROVPLATSKOORDINAT_N_X
      AND IL.PROVPLATSKOORDINAT_E_Y = INTERIM_SAMPLES.PROVPLATSKOORDINAT_E_Y
      AND IL.KOORDINATSYSTEM        = INTERIM_SAMPLES.KOORDINATSYSTEM
      AND IL.PROVTAGNINGSMEDIUM     = INTERIM_SAMPLES.PROVTAGNINGSMEDIUM
);

-- =============================================================================
-- Verification: check row counts and any unmatched rows (should be zero)
-- =============================================================================

SELECT
    COUNT(*)                                        AS "Total rows",
    COUNT(INTERIM_LOCATION_ID)                      AS "Rows with INTERIM_LOCATION_ID populated",
    COUNT(*) - COUNT(INTERIM_LOCATION_ID)           AS "Unmatched rows (should be 0)"
FROM INTERIM_SAMPLES;
