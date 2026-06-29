-- =============================================================================
-- create_vw_samples_per_year.sql
--
-- Creates the view vw_samples_per_year.
--
-- Shows the number of samples per calendar year from the SAMPLES table.
-- Counts both all samples and only retained samples (USE_SAMPLE = 'Y').
--
-- Columns:
--   PROVTAGNINGSAR    – calendar year (INTEGER)
--   N_SAMPLES_TOTAL   – count of all samples in that year
--   N_SAMPLES_USE_Y   – count of retained samples (USE_SAMPLE = 'Y') only
-- =============================================================================

DROP VIEW IF EXISTS vw_samples_per_year;

CREATE VIEW vw_samples_per_year AS
SELECT
    PROVTAGNINGSAR,
    COUNT(*)                                                    AS N_SAMPLES_TOTAL,
    SUM(CASE WHEN USE_SAMPLE = 'Y' THEN 1 ELSE 0 END)          AS N_SAMPLES_USE_Y
FROM SAMPLES
WHERE PROVTAGNINGSAR IS NOT NULL
GROUP BY PROVTAGNINGSAR
ORDER BY PROVTAGNINGSAR;

-- =============================================================================
-- Preview
-- =============================================================================
SELECT *
FROM vw_samples_per_year;
