-- =============================================================================
-- diag_pct_sum.sql
--
-- Diagnostic queries to identify why PCT_N + PCT_P + PCT_NP != 100
-- for some years in vw_year_limiting_factors.
--
-- Run these in order; each narrows down the cause.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Query 1: Which years have proportions that don't sum to 100?
-- Shows the actual sum and the gap from 100.
-- -----------------------------------------------------------------------------
SELECT
    PROVTAGNINGSAR,
    N_COUNT,
    P_COUNT,
    NP_COUNT,
    TOTAL_COUNT,
    PCT_N,
    PCT_P,
    PCT_NP,
    ROUND(PCT_N + PCT_P + PCT_NP, 2)        AS PCT_SUM,
    ROUND(100 - (PCT_N + PCT_P + PCT_NP), 2) AS GAP_FROM_100
FROM vw_year_limiting_factors
WHERE ABS(100 - (PCT_N + PCT_P + PCT_NP)) > 0.1   -- ignore tiny rounding gaps
ORDER BY GAP_FROM_100 DESC;

-- -----------------------------------------------------------------------------
-- Query 2: For the affected years, how many vw_ratios rows have a NULL
-- LIMITING_FACTOR? (Should be zero after the fix to script 63 -- if not,
-- the fix didn't take effect.)
-- -----------------------------------------------------------------------------
SELECT
    S.PROVTAGNINGSAR,
    COUNT(*)                                            AS total_rows,
    COUNT(R.LIMITING_FACTOR)                            AS non_null_lf,
    SUM(CASE WHEN R.LIMITING_FACTOR IS NULL THEN 1 END) AS null_lf_rows,
    SUM(CASE WHEN R.RATIO           IS NULL THEN 1 END) AS null_ratio_rows
FROM SAMPLES S
JOIN vw_ratios R ON R.SOURCE_ROWID = S.ROWID
WHERE S.USE_SAMPLE = 'Y'
GROUP BY S.PROVTAGNINGSAR
HAVING null_lf_rows > 0 OR null_ratio_rows > 0
ORDER BY S.PROVTAGNINGSAR;

-- -----------------------------------------------------------------------------
-- Query 3: Per affected year, how many rows exist per N_FORM?
-- If INORGANIC and TOTAL row counts differ, the denominator (TOTAL_COUNT)
-- is inflated relative to what a single N_FORM would give.
-- -----------------------------------------------------------------------------
SELECT
    S.PROVTAGNINGSAR,
    R.N_FORM,
    COUNT(*)    AS n_rows
FROM SAMPLES S
JOIN vw_ratios R ON R.SOURCE_ROWID = S.ROWID
WHERE S.USE_SAMPLE = 'Y'
GROUP BY S.PROVTAGNINGSAR, R.N_FORM
ORDER BY S.PROVTAGNINGSAR, R.N_FORM;

-- -----------------------------------------------------------------------------
-- Query 4: Confirm whether N_COUNT + P_COUNT + NP_COUNT = TOTAL_COUNT.
-- If not, there are rows in vw_ratios whose LIMITING_FACTOR is not
-- 'N', 'P' or 'NP' (i.e. NULL slipping through).
-- -----------------------------------------------------------------------------
SELECT
    PROVTAGNINGSAR,
    N_COUNT + P_COUNT + NP_COUNT    AS SUM_OF_COUNTS,
    TOTAL_COUNT,
    TOTAL_COUNT - (N_COUNT + P_COUNT + NP_COUNT) AS UNACCOUNTED_ROWS
FROM vw_year_limiting_factors
WHERE TOTAL_COUNT != (N_COUNT + P_COUNT + NP_COUNT)
ORDER BY UNACCOUNTED_ROWS DESC;
