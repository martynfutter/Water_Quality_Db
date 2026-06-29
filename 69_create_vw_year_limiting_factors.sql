-- =============================================================================
-- 69_create_vw_year_limiting_factors.sql
--
-- Creates the view vw_year_limiting_factors.
--
-- Mirrors vw_locations_limiting_factors but groups by calendar year
-- (SAMPLES.PROVTAGNINGSAR) rather than by location, producing one row
-- per year with counts and proportions of each LIMITING_FACTOR value
-- and the average TOTAL_PHOSPHORUS across all retained samples in that year.
--
-- Join path:
--   SAMPLES.ROWID         = vw_ratios.SOURCE_ROWID
--   SAMPLES.USE_SAMPLE    = 'Y'
--
-- Columns returned:
--   PROVTAGNINGSAR       – calendar year (INTEGER)
--   N_COUNT              – count of vw_ratios rows where LIMITING_FACTOR = 'N'
--   P_COUNT              – count of vw_ratios rows where LIMITING_FACTOR = 'P'
--   NP_COUNT             – count of vw_ratios rows where LIMITING_FACTOR = 'NP'
--   TOTAL_COUNT          – total count of all vw_ratios rows for that year
--   PCT_N                – proportion N-limited  (0–100)
--   PCT_P                – proportion P-limited  (0–100)
--   PCT_NP               – proportion NP co-limited (0–100)
--   AVG_TOTAL_PHOSPHORUS – average TOTAL_PHOSPHORUS (µg/l P) across matched rows
--
-- Notes:
--   * vw_ratios may return multiple rows per SOURCE_ROWID (one per matching
--     THRESHOLDS row). All counts, proportions and AVG_TOTAL_PHOSPHORUS
--     therefore reflect threshold × sample combinations, not unique samples.
--     Filter vw_ratios by a specific THRESHOLDS.ID or N_FORM upstream if
--     you want per-sample counts.
--   * Years with no retained samples will not appear in the view.
-- =============================================================================

DROP VIEW IF EXISTS vw_year_limiting_factors;

CREATE VIEW vw_year_limiting_factors AS
SELECT
    S.PROVTAGNINGSAR,

    -- Counts
    COUNT(CASE WHEN R.LIMITING_FACTOR = 'N'  THEN 1 END)       AS N_COUNT,
    COUNT(CASE WHEN R.LIMITING_FACTOR = 'P'  THEN 1 END)       AS P_COUNT,
    COUNT(CASE WHEN R.LIMITING_FACTOR = 'NP' THEN 1 END)       AS NP_COUNT,
    COUNT(*)                                                    AS TOTAL_COUNT,

    -- Proportions (0–100), guarded against divide-by-zero
    CASE WHEN COUNT(*) > 0
        THEN ROUND(100.0 * COUNT(CASE WHEN R.LIMITING_FACTOR = 'N'  THEN 1 END) / COUNT(*), 2)
        ELSE NULL END                                           AS PCT_N,
    CASE WHEN COUNT(*) > 0
        THEN ROUND(100.0 * COUNT(CASE WHEN R.LIMITING_FACTOR = 'P'  THEN 1 END) / COUNT(*), 2)
        ELSE NULL END                                           AS PCT_P,
    CASE WHEN COUNT(*) > 0
        THEN ROUND(100.0 * COUNT(CASE WHEN R.LIMITING_FACTOR = 'NP' THEN 1 END) / COUNT(*), 2)
        ELSE NULL END                                           AS PCT_NP,

    -- Average total phosphorus
    AVG(R.TOTAL_PHOSPHORUS)                                     AS AVG_TOTAL_PHOSPHORUS

FROM SAMPLES S
JOIN vw_ratios R
    ON  R.SOURCE_ROWID = S.ROWID

WHERE S.USE_SAMPLE     = 'Y'
  AND S.PROVTAGNINGSAR IS NOT NULL

GROUP BY S.PROVTAGNINGSAR

ORDER BY S.PROVTAGNINGSAR;

-- =============================================================================
-- Sanity check: spot-check that proportions sum to 100 for each year,
-- and review overall TP range
-- =============================================================================
SELECT
    COUNT(*)                        AS n_years,
    SUM(N_COUNT)                    AS total_n,
    SUM(P_COUNT)                    AS total_p,
    SUM(NP_COUNT)                   AS total_np,
    MIN(PCT_N + PCT_P + PCT_NP)     AS min_pct_sum,
    MAX(PCT_N + PCT_P + PCT_NP)     AS max_pct_sum,
    MIN(AVG_TOTAL_PHOSPHORUS)       AS min_avg_tp,
    MAX(AVG_TOTAL_PHOSPHORUS)       AS max_avg_tp,
    AVG(AVG_TOTAL_PHOSPHORUS)       AS grand_mean_tp
FROM vw_year_limiting_factors;
