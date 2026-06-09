-- =============================================================================
-- fix_bracketed_values.sql
--
-- Finds RESULTS rows where QC IS NULL and TEXT_VALUE contains a '[' or ']'.
-- For each such row:
--
--   1. COMMENTS      ← original TEXT_VALUE (audit trail)
--   2. NUMERIC_VALUE ← TEXT_VALUE with brackets removed, comma→period, cast
--                      to REAL
--   3. QC            ← 'BRACKETS'
--
-- Only rows where the cleaned string is numeric (GLOB guard) are updated.
-- Rows where the de-bracketed string still cannot be parsed are left untouched.
--
-- SQLite has no single REPLACE for multiple characters, so two nested
-- REPLACE() calls are used — one for '[', one for ']'.
-- =============================================================================

UPDATE RESULTS
SET
    COMMENTS      = TEXT_VALUE,
    NUMERIC_VALUE = CAST(
                        REPLACE(
                            REPLACE(
                                REPLACE(TRIM(TEXT_VALUE), '[', ''),
                            ']', ''),
                        ',', '.')
                    AS REAL),
    QC            = 'BRACKETS'
WHERE
    QC IS NULL
    AND TEXT_VALUE IS NOT NULL
    AND (INSTR(TEXT_VALUE, '[') > 0 OR INSTR(TEXT_VALUE, ']') > 0)

    -- cleaned string must look numeric
    AND TRIM(
            REPLACE(
                REPLACE(
                    REPLACE(TRIM(TEXT_VALUE), '[', ''),
                ']', ''),
            ',', '.')
        ) GLOB '[0-9.+-]*'

    -- guard against nothing remaining after stripping brackets
    AND TRIM(
            REPLACE(
                REPLACE(TRIM(TEXT_VALUE), '[', ''),
            ']', '')
        ) != '';

-- ── Sanity check: review updated rows ────────────────────────────────────────
SELECT
    ID,
    SOURCE_ROWID,
    PARAMETER_NAME,
    TEXT_VALUE,
    COMMENTS      AS ORIGINAL_VALUE,
    NUMERIC_VALUE,
    QC
FROM RESULTS
WHERE QC = 'BRACKETS'
ORDER BY PARAMETER_NAME, SOURCE_ROWID;
