-- =============================================================================
-- fix_detection_limits.sql
--
-- Finds RESULTS rows where TEXT_VALUE contains a '<' (below-detection-limit
-- notation, e.g. '<0.5', '< 0,5').  For each such row:
--
--   1. COMMENTS      ← original TEXT_VALUE (audit trail)
--   2. NUMERIC_VALUE ← number extracted after '<', comma→period, divided by 2
--   3. QC            ← 'HALF DETECT'
--
-- Only rows where:
--   • QC IS NULL           (not already processed)
--   • TEXT_VALUE LIKE '<%' (starts with '<')
--   • the remainder after stripping '<' and whitespace is numeric
--     (same GLOB guard used in earlier scripts)
--
-- are updated.  Rows where the string after '<' cannot be parsed as a number
-- are left untouched.
-- =============================================================================

UPDATE RESULTS
SET
    COMMENTS      = TEXT_VALUE,
    NUMERIC_VALUE = CAST(
                        REPLACE(
                            TRIM(SUBSTR(TEXT_VALUE, INSTR(TEXT_VALUE, '<') + 1)),
                            ',', '.'
                        ) AS REAL
                    ) / 2.0,
    QC            = 'HALF DETECT'
WHERE
    QC IS NULL
    AND TEXT_VALUE IS NOT NULL
    AND INSTR(TEXT_VALUE, '<') > 0

    -- the part after '<' must look numeric once trimmed and comma-normalised
    AND TRIM(
            REPLACE(
                TRIM(SUBSTR(TEXT_VALUE, INSTR(TEXT_VALUE, '<') + 1)),
                ',', '.'
            )
        ) GLOB '[0-9.]*'

    -- guard against a bare '<' with nothing numeric after it
    AND TRIM(SUBSTR(TEXT_VALUE, INSTR(TEXT_VALUE, '<') + 1)) != '';

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
WHERE QC = 'HALF DETECT'
ORDER BY PARAMETER_NAME, SOURCE_ROWID;
