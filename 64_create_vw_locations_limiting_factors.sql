-- =============================================================================
-- 64_create_vw_locations_limiting_factors.sql
--
-- Creates the view vw_locations_limiting_factors.
--
-- Joins LOCATIONS to vw_ratios via SAMPLES, producing one row per LOCATION
-- with counts of each LIMITING_FACTOR value ('N', 'P', 'NP') and the average
-- TOTAL_PHOSPHORUS across all retained samples at that location.
--
-- Join path:
--   LOCATIONS.LOCATION_ID = SAMPLES.LOCATION_ID
--   SAMPLES.ROWID         = vw_ratios.SOURCE_ROWID
--   SAMPLES.USE_SAMPLE    = 'Y'
--
-- Columns returned:
--   All columns from LOCATIONS, plus:
--   N_COUNT              – count of vw_ratios rows where LIMITING_FACTOR = 'N'
--   P_COUNT              – count of vw_ratios rows where LIMITING_FACTOR = 'P'
--   NP_COUNT             – count of vw_ratios rows where LIMITING_FACTOR = 'NP'
--   AVG_TOTAL_PHOSPHORUS – average TOTAL_PHOSPHORUS (µg/l P) across matched rows
--
-- Notes:
--   * vw_ratios may return multiple rows per SOURCE_ROWID (one per matching
--     THRESHOLDS row). All counts and AVG_TOTAL_PHOSPHORUS therefore reflect
--     threshold × sample combinations, not unique samples. Filter vw_ratios
--     by a specific THRESHOLDS.ID or SOURCE upstream if you want per-sample
--     counts.
--   * Locations with no matching retained samples will not appear in the
--     view. Change JOIN to LEFT JOIN on SAMPLES if you want all LOCATIONS
--     regardless.
-- =============================================================================

DROP VIEW IF EXISTS vw_locations_limiting_factors;

CREATE VIEW vw_locations_limiting_factors AS
SELECT
    -- All LOCATIONS columns
    L.LOCATION_ID,
    L.OVERVAKNINGSSTATION,
    L.STATIONSKOORDINAT_N_X,
    L.STATIONSKOORDINAT_E_Y,
    L.PROVPLATS,
    L.PROVPLATSKOORDINAT_N_X,
    L.PROVPLATSKOORDINAT_E_Y,
    L.KOORDINATSYSTEM,
    L.PROVTAGNINGSMEDIUM,
    L.QC,

    -- Counts of each LIMITING_FACTOR
    COUNT(CASE WHEN R.LIMITING_FACTOR = 'N'  THEN 1 END)  AS N_COUNT,
    COUNT(CASE WHEN R.LIMITING_FACTOR = 'P'  THEN 1 END)  AS P_COUNT,
    COUNT(CASE WHEN R.LIMITING_FACTOR = 'NP' THEN 1 END)  AS NP_COUNT,

    -- Average total phosphorus across matched rows
    AVG(R.TOTAL_PHOSPHORUS)                                AS AVG_TOTAL_PHOSPHORUS

FROM LOCATIONS L
JOIN SAMPLES S
    ON  S.LOCATION_ID  = L.LOCATION_ID
    AND S.USE_SAMPLE   = 'Y'
JOIN vw_ratios R
    ON  R.SOURCE_ROWID = S.ROWID

GROUP BY
    L.LOCATION_ID,
    L.OVERVAKNINGSSTATION,
    L.STATIONSKOORDINAT_N_X,
    L.STATIONSKOORDINAT_E_Y,
    L.PROVPLATS,
    L.PROVPLATSKOORDINAT_N_X,
    L.PROVPLATSKOORDINAT_E_Y,
    L.KOORDINATSYSTEM,
    L.PROVTAGNINGSMEDIUM,
    L.QC

ORDER BY L.LOCATION_ID;

-- =============================================================================
-- Sanity check: row count, total counts per LIMITING_FACTOR, and AVG_TP range
-- =============================================================================
SELECT
    COUNT(*)                    AS n_locations,
    SUM(N_COUNT)                AS total_n,
    SUM(P_COUNT)                AS total_p,
    SUM(NP_COUNT)               AS total_np,
    MIN(AVG_TOTAL_PHOSPHORUS)   AS min_avg_tp,
    MAX(AVG_TOTAL_PHOSPHORUS)   AS max_avg_tp,
    AVG(AVG_TOTAL_PHOSPHORUS)   AS grand_mean_tp
FROM vw_locations_limiting_factors;
