-- =============================================================================
-- delete_placeholder_rows.sql
--
-- Removes rows from RESULTS where TEXT_VALUE is a placeholder or artefact:
--
--   1. "XXXX…" entries  – dummy/masked values written by the data provider
--                         (matched with LIKE 'X%' to catch any length)
--   2. "Column…" entries – column-header artefacts that ended up as data rows
--                          (matched with LIKE 'Column%', case-insensitive)
--
-- A preview SELECT is run first so you can inspect what will be removed
-- before the DELETE executes.  Comment out the DELETE and run the SELECT
-- alone if you want to review before committing.
-- =============================================================================

-- ── Preview: rows that will be deleted ───────────────────────────────────────
SELECT
    ID,
    SOURCE_ROWID,
    PARAMETER_NAME,
    TEXT_VALUE,
    QC
FROM RESULTS
WHERE
    UPPER(TRIM(TEXT_VALUE)) LIKE 'X%'
    OR UPPER(TRIM(TEXT_VALUE)) LIKE 'COLUMN%'
ORDER BY PARAMETER_NAME, SOURCE_ROWID;

-- ── Delete ────────────────────────────────────────────────────────────────────
DELETE FROM RESULTS
WHERE
    UPPER(TRIM(TEXT_VALUE)) LIKE 'X%'
    OR UPPER(TRIM(TEXT_VALUE)) LIKE 'COLUMN%';

-- ── Confirm: rows remaining per QC flag ──────────────────────────────────────
SELECT
    QC,
    COUNT(*) AS n_rows
FROM RESULTS
GROUP BY QC
ORDER BY QC;
