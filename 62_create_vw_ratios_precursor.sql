-- =============================================================================
-- 62_create_vw_ratios_precursor.sql
--
-- Creates the view vw_ratios_precursor.
--
-- A simple UNION ALL of vw_inorganic_ratio and vw_total_ratio, combining
-- DIN-based and Total N-based N:P ratios into a single view.
--
-- Columns (identical in both branches):
--   SOURCE_ROWID     – sampling event identifier
--   N_FORM           – 'Inorganic' or 'Total' (from THRESHOLDS)
--   NITROGEN         – measured N value (µg/l N); DIN or TOTAL_N
--   TOTAL_PHOSPHORUS – measured total phosphorus (µg/l P)
--   N                – threshold N value from THRESHOLDS
--   P                – threshold P value from THRESHOLDS
--   RATIO            – NITROGEN / TOTAL_PHOSPHORUS
-- =============================================================================

DROP VIEW IF EXISTS vw_ratios_precursor;

CREATE VIEW vw_ratios_precursor AS

    SELECT * FROM vw_inorganic_ratio

    UNION ALL

    SELECT * FROM vw_total_ratio;

-- =============================================================================
-- Sanity check: row counts and RATIO ranges per N_FORM and SOURCE
-- =============================================================================
SELECT
    T.SOURCE,
    R.N_FORM,
    COUNT(*)        AS n_rows,
    MIN(R.RATIO)    AS min_ratio,
    MAX(R.RATIO)    AS max_ratio,
    AVG(R.RATIO)    AS mean_ratio
FROM vw_ratios_precursor R
JOIN THRESHOLDS T
    ON  T.N_FORM = R.N_FORM
    AND T.N      = R.N
    AND T.P      = R.P
GROUP BY R.N_FORM, T.SOURCE
ORDER BY R.N_FORM, T.SOURCE;
