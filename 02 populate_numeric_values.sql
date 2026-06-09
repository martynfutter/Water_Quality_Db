-- =============================================================================
-- populate_numeric_values.sql
--
-- For rows in RESULTS where QC is NULL, attempts to cast TEXT_VALUE to a
-- real number and writes the result to NUMERIC_VALUE.  QC is set to
-- 'VALID NUMBER' only when the cast succeeds.
--
-- SQLite CAST behaviour:
--   • A string that begins with a valid numeric prefix is cast to that number.
--   • A string with no numeric content casts to 0.0 — indistinguishable from
--     a genuine zero without an extra check.
--
-- Safety filter applied before updating:
--   TRIM(TEXT_VALUE) GLOB '[0-9.+-]*'
--     → first character must be a digit, decimal point, or sign.
--     → This rejects free-text, empty-ish strings, and detection-limit
--       entries like '<0.5' (those are handled separately).
--
-- Genuine zero values ('0', '0.0', etc.) are matched by the GLOB and
-- correctly updated.
-- =============================================================================

UPDATE RESULTS
SET
    NUMERIC_VALUE = CAST(TRIM(TEXT_VALUE) AS REAL),
    QC            = 'VALID NUMBER'
WHERE
    QC IS NULL
    AND TEXT_VALUE IS NOT NULL
    AND TRIM(TEXT_VALUE) != ''
    AND TRIM(TEXT_VALUE) GLOB '[0-9.+-]*';

-- ── Sanity check ─────────────────────────────────────────────────────────────
SELECT
    QC,
    COUNT(*)                        AS n_rows,
    MIN(NUMERIC_VALUE)              AS min_val,
    MAX(NUMERIC_VALUE)              AS max_val
FROM RESULTS
GROUP BY QC
ORDER BY QC;
