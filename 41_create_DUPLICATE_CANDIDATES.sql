-- =============================================================================
-- 41_create_DUPLICATE_CANDIDATES.sql
--
-- Creates and populates the table DUPLICATE_CANDIDATES from
-- vw_source_rowid_stats.
--
-- Groups by the four summary statistics and counts how many SOURCE_ROWIDs
-- share identical values across all four. Any group with N_SOURCE_ROWIDS > 1
-- is a candidate set of duplicate samples.
--
-- Columns:
--   TUPLE_ID            – system-generated primary key
--   N_PARAMETERS        – count of parameters with a non-NULL NUMERIC_VALUE
--   SUM_NUMERIC_VALUE   – sum   of NUMERIC_VALUE across all parameters
--   AVG_NUMERIC_VALUE   – mean  of NUMERIC_VALUE across all parameters
--   STDEV_NUMERIC_VALUE – population standard deviation of NUMERIC_VALUE
--   N_SOURCE_ROWIDS     – count of SOURCE_ROWIDs sharing these statistics
--
-- Ordered by N_SOURCE_ROWIDS descending so the most duplicated groups
-- appear first.
-- =============================================================================

DROP TABLE IF EXISTS DUPLICATE_CANDIDATES;

CREATE TABLE DUPLICATE_CANDIDATES (
    TUPLE_ID            INTEGER PRIMARY KEY AUTOINCREMENT,
    N_PARAMETERS        INTEGER,
    SUM_NUMERIC_VALUE   REAL,
    AVG_NUMERIC_VALUE   REAL,
    STDEV_NUMERIC_VALUE REAL,
    N_SOURCE_ROWIDS     INTEGER
);

-- =============================================================================
-- Populate from vw_source_rowid_stats
-- =============================================================================

INSERT INTO DUPLICATE_CANDIDATES (
    N_PARAMETERS,
    SUM_NUMERIC_VALUE,
    AVG_NUMERIC_VALUE,
    STDEV_NUMERIC_VALUE,
    N_SOURCE_ROWIDS
)
SELECT
    N_PARAMETERS,
    SUM_NUMERIC_VALUE,
    AVG_NUMERIC_VALUE,
    STDEV_NUMERIC_VALUE,
    COUNT(SOURCE_ROWID)     AS N_SOURCE_ROWIDS
FROM vw_source_rowid_stats
GROUP BY
    N_PARAMETERS,
    SUM_NUMERIC_VALUE,
    AVG_NUMERIC_VALUE,
    STDEV_NUMERIC_VALUE
ORDER BY N_SOURCE_ROWIDS DESC;

-- =============================================================================
-- Sanity check: row counts and duplicate candidate groups
-- =============================================================================

SELECT
    COUNT(*)                            AS total_tuples,
    SUM(CASE WHEN N_SOURCE_ROWIDS > 1
             THEN 1 ELSE 0 END)         AS duplicate_groups,
    SUM(CASE WHEN N_SOURCE_ROWIDS > 1
             THEN N_SOURCE_ROWIDS
             ELSE 0 END)                AS total_source_rowids_in_duplicate_groups
FROM DUPLICATE_CANDIDATES;

-- Preview duplicate candidate groups
SELECT *
FROM DUPLICATE_CANDIDATES
WHERE N_SOURCE_ROWIDS > 1
ORDER BY N_SOURCE_ROWIDS DESC;
