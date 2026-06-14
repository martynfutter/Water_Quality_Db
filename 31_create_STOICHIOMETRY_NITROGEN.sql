-- =============================================================================
-- 31_create_STOICHIOMETRY_NITROGEN.sql
--
-- Creates and populates STOICHIOMETRY_NITROGEN as a wide-format (crosstab)
-- table of nitrogen fractions for N:P stoichiometry analysis.
--
-- Rows:    SOURCE_ROWID values present in STOICHIOMETRY_INPUTS
-- Columns: one per NAME_TO_USE where ELEMENT = 'NITROGEN' in
--          vw_results_with_lookup; values taken from NUMERIC_VALUE
--
-- Step 1 (documentation) – confirm the nitrogen NAME_TO_USE values and their
--         coverage before the pivot is built.  Review this output carefully;
--         if new NAME_TO_USE values appear after a data reload the pivot
--         columns below must be updated to match.
--
-- Step 2 – DROP / CREATE / INSERT the wide table.
-- =============================================================================


-- =============================================================================
-- STEP 1  Nitrogen NAME_TO_USE inventory (confirmed values shown below)
--
-- NAME_TO_USE                   n_rows  n_numeric  min_val   max_val
-- AMMONIUM_AS_N                  25822      25822      0.0   14400.0
-- NITRATE_AS_N                   32174      32174      1.0    2690.0
-- NITRITE_AS_N                    8334       8334      0.0     124.0
-- ORGANIC_NITROGEN_AS_N            194        194     40.0     510.0
-- TOTAL_KJELDAHL_NITROGEN_AS_N   15680      15680      8.0    2400.0
-- TOTAL_NITROGEN                 24530      24530      0.5   24000.0
-- =============================================================================

SELECT
    NAME_TO_USE,
    COUNT(*)                AS n_rows,
    COUNT(NUMERIC_VALUE)    AS n_numeric,
    MIN(NUMERIC_VALUE)      AS min_val,
    MAX(NUMERIC_VALUE)      AS max_val
FROM vw_results_with_lookup
WHERE ELEMENT = 'NITROGEN'
GROUP BY NAME_TO_USE
ORDER BY NAME_TO_USE;


-- =============================================================================
-- STEP 2  Create STOICHIOMETRY_NITROGEN
--
-- The pivot uses conditional aggregation:
--   MAX(CASE WHEN NAME_TO_USE = '<name>' THEN NUMERIC_VALUE END)
-- MAX() collapses the group to one row per SOURCE_ROWID; if a SOURCE_ROWID
-- has more than one NUMERIC_VALUE for a given NAME_TO_USE the largest is kept.
-- =============================================================================

DROP TABLE IF EXISTS STOICHIOMETRY_NITROGEN;

CREATE TABLE STOICHIOMETRY_NITROGEN (
    SOURCE_ROWID                  INTEGER PRIMARY KEY,
    DATESTAMP                     TEXT    NOT NULL,
    AMMONIUM_AS_N                 REAL,
    NITRATE_AS_N                  REAL,
    NITRITE_AS_N                  REAL,
    ORGANIC_NITROGEN_AS_N         REAL,
    TOTAL_KJELDAHL_NITROGEN_AS_N  REAL,
    TOTAL_NITROGEN                REAL
);

INSERT INTO STOICHIOMETRY_NITROGEN (
    SOURCE_ROWID,
    DATESTAMP,
    AMMONIUM_AS_N,
    NITRATE_AS_N,
    NITRITE_AS_N,
    ORGANIC_NITROGEN_AS_N,
    TOTAL_KJELDAHL_NITROGEN_AS_N,
    TOTAL_NITROGEN
)
SELECT
    si.SOURCE_ROWID,
    datetime('now')                                                                              AS DATESTAMP,
    MAX(CASE WHEN v.NAME_TO_USE = 'AMMONIUM_AS_N'                THEN v.NUMERIC_VALUE END)      AS AMMONIUM_AS_N,
    MAX(CASE WHEN v.NAME_TO_USE = 'NITRATE_AS_N'                 THEN v.NUMERIC_VALUE END)      AS NITRATE_AS_N,
    MAX(CASE WHEN v.NAME_TO_USE = 'NITRITE_AS_N'                 THEN v.NUMERIC_VALUE END)      AS NITRITE_AS_N,
    MAX(CASE WHEN v.NAME_TO_USE = 'ORGANIC_NITROGEN_AS_N'        THEN v.NUMERIC_VALUE END)      AS ORGANIC_NITROGEN_AS_N,
    MAX(CASE WHEN v.NAME_TO_USE = 'TOTAL_KJELDAHL_NITROGEN_AS_N' THEN v.NUMERIC_VALUE END)      AS TOTAL_KJELDAHL_NITROGEN_AS_N,
    MAX(CASE WHEN v.NAME_TO_USE = 'TOTAL_NITROGEN'               THEN v.NUMERIC_VALUE END)      AS TOTAL_NITROGEN
FROM STOICHIOMETRY_INPUTS si
LEFT JOIN vw_results_with_lookup v
       ON v.SOURCE_ROWID = si.SOURCE_ROWID
      AND v.ELEMENT      = 'NITROGEN'
GROUP BY si.SOURCE_ROWID
ORDER BY si.SOURCE_ROWID;


-- =============================================================================
-- STEP 3  Sanity check — row counts and coverage per nitrogen fraction
-- =============================================================================

SELECT
    COUNT(*)                             AS n_rows,
    COUNT(AMMONIUM_AS_N)                 AS n_ammonium_as_n,
    COUNT(NITRATE_AS_N)                  AS n_nitrate_as_n,
    COUNT(NITRITE_AS_N)                  AS n_nitrite_as_n,
    COUNT(ORGANIC_NITROGEN_AS_N)         AS n_organic_nitrogen_as_n,
    COUNT(TOTAL_KJELDAHL_NITROGEN_AS_N)  AS n_total_kjeldahl_nitrogen_as_n,
    COUNT(TOTAL_NITROGEN)                AS n_total_nitrogen
FROM STOICHIOMETRY_NITROGEN;
