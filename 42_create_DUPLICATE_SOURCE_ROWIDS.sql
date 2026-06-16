-- =============================================================================
-- 42_create_DUPLICATE_SOURCE_ROWIDS.sql
--
-- Creates and populates the table DUPLICATE_SOURCE_ROWIDS.
--
-- Joins DUPLICATE_CANDIDATES to vw_source_rowid_stats on all four summary
-- statistic columns to recover the individual SOURCE_ROWIDs belonging to
-- each duplicate group (TUPLE_ID).
--
-- Only groups where N_SOURCE_ROWIDS > 1 are included (i.e. genuine
-- duplicate candidates).
--
-- Columns:
--   TUPLE_ID            – FK to DUPLICATE_CANDIDATES.TUPLE_ID
--   SOURCE_ROWID        – individual sampling event identifier
--   N_SOURCE_ROWIDS     – number of SOURCE_ROWIDs in this duplicate group
--   DATESTAMP           – date the query was run
-- =============================================================================

DROP TABLE IF EXISTS DUPLICATE_SOURCE_ROWIDS;

CREATE TABLE DUPLICATE_SOURCE_ROWIDS (
    TUPLE_ID        INTEGER NOT NULL,
    SOURCE_ROWID    INTEGER NOT NULL,
    N_SOURCE_ROWIDS INTEGER NOT NULL,
    DATESTAMP       TEXT    NOT NULL
);

-- =============================================================================
-- Populate by joining DUPLICATE_CANDIDATES back to vw_source_rowid_stats
-- on all four summary statistic columns
-- =============================================================================

INSERT INTO DUPLICATE_SOURCE_ROWIDS (
    TUPLE_ID,
    SOURCE_ROWID,
    N_SOURCE_ROWIDS,
    DATESTAMP
)
SELECT
    DC.TUPLE_ID,
    VS.SOURCE_ROWID,
    DC.N_SOURCE_ROWIDS,
    DATE('now')             AS DATESTAMP
FROM DUPLICATE_CANDIDATES DC
JOIN vw_source_rowid_stats VS
    ON  VS.N_PARAMETERS        = DC.N_PARAMETERS
    AND VS.SUM_NUMERIC_VALUE   = DC.SUM_NUMERIC_VALUE
    AND VS.AVG_NUMERIC_VALUE   = DC.AVG_NUMERIC_VALUE
    AND (
            VS.STDEV_NUMERIC_VALUE = DC.STDEV_NUMERIC_VALUE
         OR (VS.STDEV_NUMERIC_VALUE IS NULL AND DC.STDEV_NUMERIC_VALUE IS NULL)
        )
WHERE DC.N_SOURCE_ROWIDS > 1
ORDER BY DC.TUPLE_ID, VS.SOURCE_ROWID;

-- =============================================================================
-- Sanity check
-- =============================================================================

SELECT
    COUNT(*)                    AS total_rows,
    COUNT(DISTINCT TUPLE_ID)    AS duplicate_groups,
    COUNT(DISTINCT SOURCE_ROWID) AS distinct_source_rowids,
    MIN(DATESTAMP)              AS datestamp
FROM DUPLICATE_SOURCE_ROWIDS;

-- Preview
SELECT *
FROM DUPLICATE_SOURCE_ROWIDS
ORDER BY TUPLE_ID, SOURCE_ROWID
LIMIT 20;
