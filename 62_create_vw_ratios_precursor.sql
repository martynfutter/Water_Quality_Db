-- =============================================================================
-- 62_create_vw_ratios_precursor.sql
--
-- Creates the view vw_ratios_precursor as a UNION ALL of:
--   vw_inorganic_ratio  –  DIN / TOTAL_PHOSPHORUS ratios (N_FORM = 'Inorganic')
--   vw_total_ratio      –  TOTAL_N / TOTAL_PHOSPHORUS ratios (N_FORM = 'Total')
--
-- Columns (identical in both branches):
--   SOURCE_ROWID     – sampling event identifier
--   N_FORM           – nitrogen form label from THRESHOLDS
--   TOTAL_PHOSPHORUS – measured total phosphorus (µg/l P)
--   N                – threshold N value (µg/l N) from THRESHOLDS
--   P                – threshold P value (µg/l P) from THRESHOLDS
--   RATIO            – measured N : P ratio (dimensionless)
-- =============================================================================

DROP VIEW IF EXISTS vw_ratios_precursor;

CREATE VIEW vw_ratios_precursor AS

    SELECT
        SOURCE_ROWID,
        N_FORM,
        TOTAL_PHOSPHORUS,
        N,
        P,
        RATIO
    FROM vw_inorganic_ratio

    UNION ALL

    SELECT
        SOURCE_ROWID,
        N_FORM,
        TOTAL_PHOSPHORUS,
        N,
        P,
        RATIO
    FROM vw_total_ratio;

-- =============================================================================
-- Sanity check: row counts per N_FORM
-- =============================================================================
SELECT
    N_FORM,
    COUNT(*)        AS n_rows,
    MIN(RATIO)      AS min_ratio,
    MAX(RATIO)      AS max_ratio,
    AVG(RATIO)      AS mean_ratio
FROM vw_ratios_precursor
GROUP BY N_FORM
ORDER BY N_FORM;
