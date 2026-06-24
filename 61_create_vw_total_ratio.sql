-- =============================================================================
-- 61_create_vw_total_ratio.sql
--
-- Creates the view vw_total_ratio.
--
-- Joins STOICHIOMETRY_INPUTS to THRESHOLDS (N_FORM = 'Total') and
-- returns one row per SOURCE_ROWID / threshold combination where TOTAL_N
-- is not NULL.
--
-- Columns:
--   SOURCE_ROWID     – sampling event identifier
--   N_FORM           – nitrogen form label from THRESHOLDS ('Total')
--   NITROGEN         – measured TOTAL_N value (µg/l N)
--   TOTAL_PHOSPHORUS – measured total phosphorus (µg/l P)
--   N                – threshold N value from THRESHOLDS
--   P                – threshold P value from THRESHOLDS
--   RATIO            – TOTAL_N / TOTAL_PHOSPHORUS (NULLIF guard prevents
--                      division by zero; returns NULL if TP = 0)
-- =============================================================================

DROP VIEW IF EXISTS vw_total_ratio;

CREATE VIEW vw_total_ratio AS
SELECT
    SI.SOURCE_ROWID,
    T.N_FORM,
    SI.TOTAL_N                                      AS NITROGEN,
    SI.TOTAL_PHOSPHORUS,
    T.N,
    T.P,
    SI.TOTAL_N / NULLIF(SI.TOTAL_PHOSPHORUS, 0)     AS RATIO
FROM STOICHIOMETRY_INPUTS SI
CROSS JOIN THRESHOLDS T
WHERE SI.TOTAL_N IS NOT NULL
  AND T.N_FORM    = 'TOTAL';

-- =============================================================================
-- Sanity check
-- =============================================================================
SELECT
    T.SOURCE,
    COUNT(*)        AS n_rows,
    MIN(R.RATIO)    AS min_ratio,
    MAX(R.RATIO)    AS max_ratio,
    AVG(R.RATIO)    AS mean_ratio
FROM vw_total_ratio R
JOIN THRESHOLDS T
    ON  T.N_FORM = R.N_FORM
    AND T.N      = R.N
    AND T.P      = R.P
GROUP BY T.SOURCE
ORDER BY T.SOURCE;
