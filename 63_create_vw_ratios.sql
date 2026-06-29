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
-- FIX (vs original): added WHERE RATIO IS NOT NULL so that rows where
-- TOTAL_PHOSPHORUS = 0 (nullified by NULLIF in the upstream ratio views)
-- are excluded entirely rather than falling into the ELSE branch and being
-- misclassified as 'NP'. Without this guard, NULL-ratio rows inflate
-- NP_COUNT and cause proportions in vw_year_limiting_factors (and
-- vw_locations_limiting_factors) to not sum to 100%.
--
-- Columns:
--   SOURCE_ROWID     – sampling event identifier
--   N_FORM           – nitrogen form label ('Inorganic' or 'Total')
--   NITROGEN         – measured N value (µg/l N)
--   TOTAL_PHOSPHORUS – measured total phosphorus (µg/l P)
--   N                – threshold N value from THRESHOLDS
--   P                – threshold P value from THRESHOLDS
--   RATIO            – measured N : P ratio (never NULL in this view)
--   LIMITING_FACTOR  – 'N', 'P', or 'NP'
-- =============================================================================

DROP VIEW IF EXISTS vw_ratios;

CREATE VIEW vw_ratios AS
SELECT
    SOURCE_ROWID,
    N_FORM,
    NITROGEN,
    TOTAL_PHOSPHORUS,
    N,
    P,
    RATIO,
    CASE
        WHEN RATIO < N THEN 'N'
        WHEN RATIO > P THEN 'P'
        ELSE                'NP'
    END AS LIMITING_FACTOR
FROM vw_ratios_precursor
WHERE RATIO IS NOT NULL;    -- exclude rows where TP = 0 (NULLIF guard upstream)

-- =============================================================================
-- Sanity check 1: row counts per N_FORM and LIMITING_FACTOR
-- (no NULL LIMITING_FACTOR rows should appear)
-- =============================================================================
SELECT
    N_FORM,
    LIMITING_FACTOR,
    COUNT(*)    AS n_rows
FROM vw_ratios
GROUP BY N_FORM, LIMITING_FACTOR
ORDER BY N_FORM, LIMITING_FACTOR;

-- =============================================================================
-- Sanity check 2: confirm no NULL ratios remain
-- =============================================================================
SELECT COUNT(*) AS null_ratio_rows
FROM vw_ratios
WHERE RATIO IS NULL;
