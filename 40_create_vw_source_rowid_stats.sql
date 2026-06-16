-- =============================================================================
-- 40_create_vw_source_rowid_stats.sql
--
-- Creates the view vw_source_rowid_stats from RESULTS.
--
-- The view aggregates by SOURCE_ROWID across all parameters, computing
-- summary statistics over NUMERIC_VALUE. This is the first step toward
-- identifying duplicate samples — SOURCE_ROWIDs with identical statistics
-- are candidates for further inspection.
--
-- Columns:
--   SOURCE_ROWID        – sampling event identifier (links to RAW_DATA)
--   N_PARAMETERS        – count of parameters with a non-NULL NUMERIC_VALUE
--   SUM_NUMERIC_VALUE   – sum   of NUMERIC_VALUE across all parameters
--   AVG_NUMERIC_VALUE   – mean  of NUMERIC_VALUE across all parameters
--   STDEV_NUMERIC_VALUE – population standard deviation of NUMERIC_VALUE
--                         (SQLite has no built-in STDDEV; computed manually
--                          as SQRT( AVG(x²) - AVG(x)² ))
--                         NULL when fewer than 2 values are present
--
-- Only rows where NUMERIC_VALUE IS NOT NULL contribute to the aggregates.
-- =============================================================================

DROP VIEW IF EXISTS vw_source_rowid_stats;

CREATE VIEW vw_source_rowid_stats AS
SELECT
    SOURCE_ROWID,
    COUNT(NUMERIC_VALUE)                                        AS N_PARAMETERS,
    SUM(NUMERIC_VALUE)                                          AS SUM_NUMERIC_VALUE,
    AVG(NUMERIC_VALUE)                                          AS AVG_NUMERIC_VALUE,
    CASE
        WHEN COUNT(NUMERIC_VALUE) < 2 THEN 0.0
        ELSE SQRT(
                 AVG(NUMERIC_VALUE * NUMERIC_VALUE) -
                 AVG(NUMERIC_VALUE) * AVG(NUMERIC_VALUE)
             )
    END                                                         AS STDEV_NUMERIC_VALUE
FROM RESULTS
WHERE NUMERIC_VALUE IS NOT NULL
GROUP BY SOURCE_ROWID
ORDER BY SOURCE_ROWID;

-- =============================================================================
-- Sanity check: preview first 10 rows
-- =============================================================================
SELECT *
FROM vw_source_rowid_stats
LIMIT 10;
