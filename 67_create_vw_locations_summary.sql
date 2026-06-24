-- =============================================================================
-- 67_create_vw_locations_summary.sql
--
-- Creates the view vw_locations_summary.
--
-- Joins vw_locations_limiting_factors to vw_nitrogen_by_location_pivot
-- on LOCATION_ID, adding percentage columns for each limiting factor.
--
-- Additional columns:
--   N_PCT  – percentage of samples where nitrogen is limiting
--            = 100 * N_COUNT  / (N_COUNT + P_COUNT + NP_COUNT)
--   P_PCT  – percentage of samples where phosphorus is limiting
--            = 100 * P_COUNT  / (N_COUNT + P_COUNT + NP_COUNT)
--   NP_PCT – percentage of samples where co-limitation occurs
--            = 100 * NP_COUNT / (N_COUNT + P_COUNT + NP_COUNT)
--
-- Notes:
--   * CAST to REAL ensures floating-point division (integer division in
--     SQLite would truncate to 0 for values < 1).
--   * NULLIF guard prevents division by zero for locations where all
--     counts are 0.
--   * LEFT JOIN on vw_nitrogen_by_location_pivot so that all locations
--     in vw_locations_limiting_factors are retained even if nitrogen
--     averages are unavailable.
-- =============================================================================

DROP VIEW IF EXISTS vw_locations_summary;

CREATE VIEW vw_locations_summary AS
SELECT
    -- All columns from vw_locations_limiting_factors
    LF.LOCATION_ID,
    LF.OVERVAKNINGSSTATION,
    LF.STATIONSKOORDINAT_N_X,
    LF.STATIONSKOORDINAT_E_Y,
    LF.PROVPLATS,
    LF.PROVPLATSKOORDINAT_N_X,
    LF.PROVPLATSKOORDINAT_E_Y,
    LF.KOORDINATSYSTEM,
    LF.PROVTAGNINGSMEDIUM,
    LF.QC,
    LF.N_COUNT,
    LF.P_COUNT,
    LF.NP_COUNT,
    LF.AVG_TOTAL_PHOSPHORUS,

    -- Nitrogen averages from vw_nitrogen_by_location_pivot
    NP.AVG_DIN,
    NP.AVG_TOTAL_N,

    -- Limiting factor percentages
    100.0 * CAST(LF.N_COUNT  AS REAL) / NULLIF(LF.N_COUNT + LF.P_COUNT + LF.NP_COUNT, 0) AS N_PCT,
    100.0 * CAST(LF.P_COUNT  AS REAL) / NULLIF(LF.N_COUNT + LF.P_COUNT + LF.NP_COUNT, 0) AS P_PCT,
    100.0 * CAST(LF.NP_COUNT AS REAL) / NULLIF(LF.N_COUNT + LF.P_COUNT + LF.NP_COUNT, 0) AS NP_PCT

FROM vw_locations_limiting_factors LF
LEFT JOIN vw_nitrogen_by_location_pivot NP
    ON NP.LOCATION_ID = LF.LOCATION_ID

ORDER BY LF.LOCATION_ID;

-- =============================================================================
-- Sanity check: verify percentages sum to 100 for each location
-- =============================================================================
SELECT
    LOCATION_ID,
    N_PCT,
    P_PCT,
    NP_PCT,
    ROUND(N_PCT + P_PCT + NP_PCT, 6) AS TOTAL_PCT
FROM vw_locations_summary
LIMIT 20;