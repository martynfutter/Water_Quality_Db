-- =============================================================================
-- 61_create_vw_total_ratio.sql
--
-- Creates the view vw_total_ratio.
--
-- Joins STOICHIOMETRY_INPUTS to THRESHOLDS (N_FORM = 'Total') to produce
-- Total N : Total Phosphorus ratios alongside the corresponding threshold
-- N and P values from the literature.
--
-- Source tables:
--   STOICHIOMETRY_INPUTS  –  one row per sampling event; holds TOTAL_N and
--                            TOTAL_PHOSPHORUS (populated in steps 30 & 36)
--   THRESHOLDS            –  literature threshold values; N_FORM values are
--                            'Inorganic' and 'Total' (mixed case)
--
-- Columns returned:
--   SOURCE_ROWID     – sampling event identifier
--   N_FORM           – nitrogen form label from THRESHOLDS ('Total')
--   TOTAL_PHOSPHORUS – measured total phosphorus (µg/l P)
--   N                – threshold N value (µg/l N) from THRESHOLDS
--   P                – threshold P value (µg/l P) from THRESHOLDS
--   RATIO            – TOTAL_N / TOTAL_PHOSPHORUS  (dimensionless, µg/l ÷ µg/l)
--
-- Notes:
--   * Only rows where TOTAL_N IS NOT NULL are included.
--   * NULLIF(TOTAL_PHOSPHORUS, 0) prevents division-by-zero; RATIO will be
--     NULL rather than an error if TOTAL_PHOSPHORUS = 0.
--   * The CROSS JOIN means each measured row is paired with every THRESHOLDS
--     row where N_FORM = 'Total' (Redfield ID=2, Paerl ID=4, Bergström ID=5).
--     Filter on THRESHOLDS.ID or THRESHOLDS.SOURCE downstream if you want
--     a single threshold per sample.
-- =============================================================================

DROP VIEW IF EXISTS vw_total_ratio;

CREATE VIEW vw_total_ratio AS
SELECT
    SI.SOURCE_ROWID,
    T.N_FORM,
    SI.TOTAL_PHOSPHORUS,
    T.N,
    T.P,
    SI.TOTAL_N / NULLIF(SI.TOTAL_PHOSPHORUS, 0)  AS RATIO
FROM STOICHIOMETRY_INPUTS SI
CROSS JOIN THRESHOLDS T
WHERE SI.TOTAL_N  IS NOT NULL
  AND T.N_FORM     = 'TOTAL';

-- =============================================================================
-- Sanity check: row counts and RATIO ranges per threshold source
-- =============================================================================
SELECT
    T.SOURCE,
    T.N_FORM,
    COUNT(*)         AS n_rows,
    MIN(R.RATIO)     AS min_ratio,
    MAX(R.RATIO)     AS max_ratio,
    AVG(R.RATIO)     AS mean_ratio
FROM vw_total_ratio R
JOIN THRESHOLDS T
    ON  T.N_FORM = R.N_FORM
    AND T.N      = R.N
    AND T.P      = R.P
GROUP BY T.SOURCE, T.N_FORM
ORDER BY T.SOURCE;
