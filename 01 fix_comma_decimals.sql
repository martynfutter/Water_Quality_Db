-- =============================================================================
-- fix_comma_decimals.sql
--
-- Finds RESULTS rows where TEXT_VALUE contains a comma (European decimal
-- separator), replaces the comma with a period, stores the corrected string
-- in COMMENTS, then casts it to a decimal number into NUMERIC_VALUE and
-- sets QC = 'COMMA FIXED'.
--
-- Only rows that:
--   1. Have a comma in TEXT_VALUE
--   2. Produce a valid number after the substitution
-- are updated.  Rows where the comma-replaced string still cannot be cast
-- to a number (e.g. free-text with commas) are left untouched.
--
-- SQLite does not have a native IS_NUMERIC() function, so validity is tested
-- with a CAST: SQLite returns 0.0 for non-numeric strings, so we additionally
-- check that the original string starts with a digit, '<', '+', or '-' after
-- trimming — this guards against accidentally "fixing" text that happens to
-- contain a comma.
-- =============================================================================

UPDATE RESULTS
SET
    COMMENTS      = REPLACE(TRIM(TEXT_VALUE), ',', '.'),
    NUMERIC_VALUE = CAST(REPLACE(TRIM(TEXT_VALUE), ',', '.') AS REAL),
    QC            = 'COMMA FIXED'
WHERE
    -- must contain at least one comma
    INSTR(TEXT_VALUE, ',') > 0

    -- after replacing comma, the string must look numeric:
    -- first non-whitespace character is a digit, sign, or decimal point
    AND TRIM(TEXT_VALUE) GLOB '[0-9.+-]*'

    -- the cast must actually yield a non-zero number OR the string is
    -- literally '0' / '0,0' etc. (avoid matching pure-text strings)
    AND (
        CAST(REPLACE(TRIM(TEXT_VALUE), ',', '.') AS REAL) != 0.0
        OR TRIM(REPLACE(TRIM(TEXT_VALUE), ',', '.')) IN ('0', '0.0', '0.00', '0.000')
    );

-- ── Sanity check: review what was updated ────────────────────────────────────
SELECT
    ID,
    SOURCE_ROWID,
    PARAMETER_NAME,
    TEXT_VALUE,
    COMMENTS      AS FIXED_STRING,
    NUMERIC_VALUE,
    QC
FROM RESULTS
WHERE QC = 'COMMA FIXED'
ORDER BY PARAMETER_NAME, SOURCE_ROWID;
