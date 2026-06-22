-- =============================================================================
-- 18_create_DATA_SOURCES.sql
--
-- Creates and populates the DATA_SOURCES lookup table.
-- Extracts distinct SOURCE_NAME values from INTERIM_SAMPLES and assigns
-- each a unique integer DATA_SOURCE_ID.
--
-- Optionally: adds a DATA_SOURCE_ID foreign-key column to INTERIM_SAMPLES
-- and populates it by joining back to DATA_SOURCES on SOURCE_NAME.
--
-- Run after scripts 10–17 (INTERIM_SAMPLES must exist and be populated).
-- Safe to re-run: DROP IF EXISTS guards the table creation.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Create DATA_SOURCES
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS DATA_SOURCES;

CREATE TABLE DATA_SOURCES (
    DATA_SOURCE_ID  INTEGER PRIMARY KEY AUTOINCREMENT,
    SOURCE_NAME     TEXT    NOT NULL UNIQUE
);

-- -----------------------------------------------------------------------------
-- 2. Populate with distinct SOURCE_NAME values from INTERIM_SAMPLES
--    Ordered alphabetically so IDs are stable across re-runs on the same data.
-- -----------------------------------------------------------------------------

INSERT INTO DATA_SOURCES (SOURCE_NAME)
SELECT DISTINCT SOURCE_NAME
FROM   INTERIM_SAMPLES
WHERE  SOURCE_NAME IS NOT NULL
  AND  SOURCE_NAME != 'MISSING'
ORDER  BY SOURCE_NAME;

-- -----------------------------------------------------------------------------
-- 3. Sanity check
-- -----------------------------------------------------------------------------

SELECT
    COUNT(*)                    AS "Distinct source names loaded",
    MIN(DATA_SOURCE_ID)         AS "First ID",
    MAX(DATA_SOURCE_ID)         AS "Last ID"
FROM DATA_SOURCES;

-- Preview
SELECT *
FROM   DATA_SOURCES
ORDER  BY DATA_SOURCE_ID;

-- =============================================================================
-- OPTIONAL — Add DATA_SOURCE_ID back to INTERIM_SAMPLES as a foreign key
-- =============================================================================
-- Uncomment the block below if you want INTERIM_SAMPLES to carry a numeric
-- DATA_SOURCE_ID column (e.g. to avoid repeated text joins downstream).
-- -----------------------------------------------------------------------------

-- ALTER TABLE INTERIM_SAMPLES
--     ADD COLUMN DATA_SOURCE_ID INTEGER;
--
-- UPDATE INTERIM_SAMPLES
-- SET DATA_SOURCE_ID = (
--     SELECT DS.DATA_SOURCE_ID
--     FROM   DATA_SOURCES DS
--     WHERE  DS.SOURCE_NAME = INTERIM_SAMPLES.SOURCE_NAME
-- );
--
-- -- Verify: no NULLs expected (every SOURCE_NAME should resolve)
-- SELECT
--     COUNT(*)                                    AS "Total rows",
--     COUNT(DATA_SOURCE_ID)                       AS "Rows with DATA_SOURCE_ID",
--     COUNT(*) - COUNT(DATA_SOURCE_ID)            AS "Unmatched rows (should be 0)"
-- FROM INTERIM_SAMPLES;
