-- =============================================================================
-- 63_create_vw_ratios.sql
--
-- Creates the view vw_ratios from vw_ratios_precursor, adding a
-- LIMITING_FACTOR column derived from RATIO relative to the threshold
-- N and P values from THRESHOLDS.
--
-- LIMITING_FACTOR logic:
--   RATIO < N  → 'N'   (nitrogen is limiting)
--   RATIO > P  → 'P'   (phosphorus is limiting)
--   otherwise  → 'NP'  (co-limitation)
--
-- Columns:
--   SOURCE_ROWID     – sampling event identifier
--   N_FORM           – nitrogen form label ('Inorganic' or 'Total')
--   TOTAL_PHOSPHORUS – measured total phosphorus (µg/l P)
--   N                – threshold N value from THRESHOLDS
--   P                – threshold P value from THRESHOLDS
--   RATIO            – measured N : P ratio
--   LIMITING_FACTOR  – 'N', 'P', or 'NP'
-- =============================================================================

DROP VIEW IF EXISTS vw_ratios;

CREATE VIEW vw_ratios AS
SELECT
    SOURCE_ROWID,
    N_FORM,
    TOTAL_PHOSPHORUS,
    N,
    P,
    RATIO,
    CASE
        WHEN RATIO < N THEN 'N'
        WHEN RATIO > P THEN 'P'
        ELSE                'NP'
    END AS LIMITING_FACTOR
FROM vw_ratios_precursor;

-- =============================================================================
-- Sanity check: row counts per N_FORM and LIMITING_FACTOR
-- =============================================================================
SELECT
    N_FORM,
    LIMITING_FACTOR,
    COUNT(*)    AS n_rows
FROM vw_ratios
GROUP BY N_FORM, LIMITING_FACTOR
ORDER BY N_FORM, LIMITING_FACTOR;
