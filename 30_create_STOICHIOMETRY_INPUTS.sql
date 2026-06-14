-- =============================================================================
-- 30_create_STOICHIOMETRY_INPUTS.sql
--
-- Creates and populates STOICHIOMETRY_INPUTS as the base table for
-- N:P stoichiometry analysis.
--
-- Source:  vw_results_with_lookup
-- Key:     SOURCE_ROWID (one row per source sampling event)
-- Columns added here:
--   DATESTAMP        – date/time the query was executed (SQLite datetime)
--   TOTAL_PHOSPHORUS – VALUE from vw_results_with_lookup where
--                      NAME_TO_USE = 'TOTAL_PHOSPHORUS', non-NULL only
--
-- Additional N:P columns are intended to be added to this table
-- in subsequent steps.
-- =============================================================================

DROP TABLE IF EXISTS STOICHIOMETRY_INPUTS;

CREATE TABLE STOICHIOMETRY_INPUTS (
    SOURCE_ROWID      INTEGER PRIMARY KEY,
    DATESTAMP         TEXT    NOT NULL,
    TOTAL_PHOSPHORUS  REAL
);

-- =============================================================================
-- Populate: one row per SOURCE_ROWID that has a non-NULL TOTAL_PHOSPHORUS
-- =============================================================================

INSERT INTO STOICHIOMETRY_INPUTS (
    SOURCE_ROWID,
    DATESTAMP,
    TOTAL_PHOSPHORUS
)
SELECT
    SOURCE_ROWID,
    datetime('now')  AS DATESTAMP,
    NUMERIC_VALUE    AS TOTAL_PHOSPHORUS
FROM vw_results_with_lookup
WHERE
    NAME_TO_USE   = 'TOTAL_PHOSPHORUS'
    AND NUMERIC_VALUE     IS NOT NULL
ORDER BY SOURCE_ROWID;

-- =============================================================================
-- Sanity check
-- =============================================================================
SELECT
    COUNT(*)                    AS n_rows,
    MIN(TOTAL_PHOSPHORUS)       AS min_tp,
    MAX(TOTAL_PHOSPHORUS)       AS max_tp,
    AVG(TOTAL_PHOSPHORUS)       AS mean_tp,
    MIN(DATESTAMP)              AS datestamp
FROM STOICHIOMETRY_INPUTS;
