-- =============================================================================
-- 60_create_vw_inorganic_ratio.sql
--
-- Creates the view vw_inorganic_ratio.
--
-- Joins STOICHIOMETRY_INPUTS to THRESHOLDS (N_FORM = 'Inorganic') to produce
-- DIN:Total Phosphorus ratios alongside the corresponding threshold N and P
-- values from the literature.
--
-- Source tables:
--   STOICHIOMETRY_INPUTS  –  one row per sampling event; holds DIN and
--                            TOTAL_PHOSPHORUS (populated in steps 30 & 35)
--   THRESHOLDS            –  literature threshold values; N_FORM values are
--                            'Inorganic' and 'Total' (mixed case)
--
-- Columns returned:
--   SOURCE_ROWID     – sampling event identifier
--   N_FORM           – nitrogen form label from THRESHOLDS ('Inorganic')
--   TOTAL_PHOSPHORUS – measured total phosphorus (µg/l P)
--   N                – threshold N value (µg/l N) from THRESHOLDS
--   P                – threshold P value (µg/l P) from THRESHOLDS
--   RATIO            – DIN / TOTAL_PHOSPHORUS  (dimensionless, µg/l ÷ µg/l)
--
-- Notes:
--   * Only rows where DIN IS NOT NULL are included.
--   * NULLIF(TOTAL_PHOSPHORUS, 0) prevents division-by-zero; RATIO will be
--     NULL rather than an error if TOTAL_PHOSPHORUS = 0.
--   * The CROSS JOIN means each measured row is paired with every THRESHOLDS
--     row where N_FORM = 'Inorganic' (e.g. both Redfield and Bergström).
--     Filter on THRESHOLDS.SOURCE or THRESHOLDS.ID downstream if you want
--     a single threshold per sample.
-- =============================================================================

DROP VIEW IF EXISTS vw_inorganic_ratio;

CREATE VIEW vw_inorganic_ratio AS
SELECT
    SI.SOURCE_ROWID,
    T.N_FORM,
    SI.TOTAL_PHOSPHORUS,
    T.N,
    T.P,
    SI.DIN / NULLIF(SI.TOTAL_PHOSPHORUS, 0)  AS RATIO
FROM STOICHIOMETRY_INPUTS SI
CROSS JOIN THRESHOLDS T
WHERE SI.DIN   IS NOT NULL
  AND T.N_FORM  = 'INORGANIC';

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
FROM vw_inorganic_ratio R
JOIN THRESHOLDS T
    ON  T.N_FORM = R.N_FORM
    AND T.N      = R.N
    AND T.P      = R.P
GROUP BY T.SOURCE, T.N_FORM
ORDER BY T.SOURCE;
