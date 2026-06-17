-- =============================================================================
-- 44_update_DUPLICATE_SOURCE_ROWIDS.sql
--
-- Updates DUPLICATE_SOURCE_ROWIDS for groups where N_SOURCE_ROWIDS = 2.
--
-- For each TUPLE_ID with exactly two SOURCE_ROWIDs, sets USE_SAMPLE = 'N'
-- and DATESTAMP to the current date and time for the smaller of the two
-- SOURCE_ROWID values. The larger SOURCE_ROWID (i.e. the later/retained
-- sample) is left unchanged with USE_SAMPLE = 'Y'.
--
-- Only rows where N_SOURCE_ROWIDS = 2 are affected; groups with more than
-- two duplicates are left untouched for manual review.
-- =============================================================================

-- =============================================================================
-- Preview: inspect rows that will be updated before committing
-- =============================================================================
SELECT
    DSR.TUPLE_ID,
    DSR.SOURCE_ROWID,
    DSR.N_SOURCE_ROWIDS,
    DSR.USE_SAMPLE,
    DSR.DATESTAMP
FROM DUPLICATE_SOURCE_ROWIDS DSR
WHERE
    DSR.N_SOURCE_ROWIDS = 2
    AND DSR.SOURCE_ROWID = (
        SELECT MIN(DSR2.SOURCE_ROWID)
        FROM DUPLICATE_SOURCE_ROWIDS DSR2
        WHERE DSR2.TUPLE_ID = DSR.TUPLE_ID
    )
ORDER BY DSR.TUPLE_ID;

-- =============================================================================
-- Update: set USE_SAMPLE = 'N' and DATESTAMP for the smaller SOURCE_ROWID
-- in each pair
-- =============================================================================
UPDATE DUPLICATE_SOURCE_ROWIDS
SET
    USE_SAMPLE = 'N',
    DATESTAMP  = DATETIME('now')
WHERE
    N_SOURCE_ROWIDS = 2
    AND SOURCE_ROWID = (
        SELECT MIN(DSR2.SOURCE_ROWID)
        FROM DUPLICATE_SOURCE_ROWIDS DSR2
        WHERE DSR2.TUPLE_ID = DUPLICATE_SOURCE_ROWIDS.TUPLE_ID
    );

-- =============================================================================
-- Verification: review updated rows
-- =============================================================================
SELECT
    TUPLE_ID,
    SOURCE_ROWID,
    N_SOURCE_ROWIDS,
    USE_SAMPLE,
    DATESTAMP
FROM DUPLICATE_SOURCE_ROWIDS
WHERE N_SOURCE_ROWIDS = 2
ORDER BY TUPLE_ID, SOURCE_ROWID;

-- =============================================================================
-- Summary counts
-- =============================================================================
SELECT
    USE_SAMPLE,
    COUNT(*)    AS n_rows
FROM DUPLICATE_SOURCE_ROWIDS
WHERE N_SOURCE_ROWIDS = 2
GROUP BY USE_SAMPLE;
