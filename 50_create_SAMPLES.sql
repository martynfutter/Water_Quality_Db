-- =============================================================================
-- 50_create_SAMPLES.sql
--
-- Creates and populates the SAMPLES table.
--
-- SAMPLES is the primary curated sample-level table, drawing together:
--   • Sample metadata from INTERIM_SAMPLES (dates, depths, identifiers)
--   • USE_SAMPLE flag from DUPLICATE_SOURCE_ROWIDS (Y = keep, N = discard)
--     Samples with no entry in DUPLICATE_SOURCE_ROWIDS are not duplicates
--     and are always retained (USE_SAMPLE defaults to 'Y').
--   • DATA_SOURCE_ID – FK to DATA_SOURCES, resolved by matching
--                      INTERIM_SAMPLES.SOURCE_NAME → DATA_SOURCES.SOURCE_NAME
--   • LOCATION_ID    – FK to INTERIM_LOCATIONS, resolved by matching
--                      INTERIM_SAMPLES.INTERIM_LOCATION_ID →
--                      INTERIM_LOCATIONS.LOCATION_ID
--
-- Type conversions applied on insert:
--   • PROVDATUM → ISO date string (YYYY-MM-DD) by back-transforming the
--     Excel Windows serial number stored in INTERIM_SAMPLES.
--     Excel epoch = 1899-12-30; conversion:
--       DATE('1899-12-30', '+' || CAST(serial AS INTEGER) || ' days')
--     Rows where PROVDATUM is 'MISSING' or non-numeric are stored as NULL.
--   • PROVTAGNINGSAR, PROVTAGNINGSMANAD, PROVTAGNINGSDAG → INTEGER
--     (NULL when INTERIM_SAMPLES value is 'MISSING' or non-numeric)
--   • MIN_PROVDJUP_M, MAX_PROVDJUP_M → REAL
--     (NULL when INTERIM_SAMPLES value is 'MISSING' or non-numeric)
--
-- DATESTAMP records the date on which this script was run.
-- =============================================================================

DROP TABLE IF EXISTS SAMPLES;

CREATE TABLE SAMPLES (
    ROWID             INTEGER  PRIMARY KEY,
    USE_SAMPLE        TEXT     NOT NULL DEFAULT 'Y',
    DATA_SOURCE_ID    INTEGER,
    LOCATION_ID       INTEGER,
    PROV_ID           TEXT     NOT NULL DEFAULT 'MISSING',
    PROVDATUM         TEXT,
    PROVTAGNINGSAR    INTEGER,
    PROVTAGNINGSMANAD INTEGER,
    PROVTAGNINGSDAG   INTEGER,
    MIN_PROVDJUP_M    REAL,
    MAX_PROVDJUP_M    REAL,
    UNDERSOKNINGSTYP  TEXT     NOT NULL DEFAULT 'MISSING',
    PROVKOMMENTAR     TEXT     NOT NULL DEFAULT 'MISSING',
    DATESTAMP         TEXT     NOT NULL
);

-- =============================================================================
-- Populate SAMPLES
--
-- JOIN logic:
--   • LEFT JOIN DUPLICATE_SOURCE_ROWIDS so that samples with no duplicate
--     record are still included; COALESCE supplies 'Y' for those rows.
--   • LEFT JOIN DATA_SOURCES on SOURCE_NAME to obtain DATA_SOURCE_ID.
--   • LEFT JOIN INTERIM_LOCATIONS on INTERIM_LOCATION_ID to obtain
--     LOCATION_ID.
--
-- PROVDATUM conversion:
--   NULLIF converts 'MISSING' → NULL. A further CASE guard ensures that
--   non-numeric strings also yield NULL rather than a junk date.
--   CAST(...AS INTEGER) truncates any fractional time component before
--   the date arithmetic.
--
-- NULL handling for other numeric columns:
--   CAST returns NULL for non-numeric strings in SQLite, so 'MISSING'
--   values automatically become NULL after NULLIF — no extra CASE needed.
-- =============================================================================

INSERT INTO SAMPLES (
    ROWID,
    USE_SAMPLE,
    DATA_SOURCE_ID,
    LOCATION_ID,
    PROV_ID,
    PROVDATUM,
    PROVTAGNINGSAR,
    PROVTAGNINGSMANAD,
    PROVTAGNINGSDAG,
    MIN_PROVDJUP_M,
    MAX_PROVDJUP_M,
    UNDERSOKNINGSTYP,
    PROVKOMMENTAR,
    DATESTAMP
)
SELECT
    IS_.ROWID,

    -- USE_SAMPLE: from DUPLICATE_SOURCE_ROWIDS if present, else 'Y'
    COALESCE(DSR.USE_SAMPLE, 'Y')                            AS USE_SAMPLE,

    -- DATA_SOURCE_ID: FK resolved via SOURCE_NAME
    DS.DATA_SOURCE_ID                                        AS DATA_SOURCE_ID,

    -- LOCATION_ID: FK resolved via INTERIM_LOCATION_ID
    IL.LOCATION_ID                                           AS LOCATION_ID,

    -- Sample identifier (kept as TEXT)
    IS_.PROV_ID,

    -- PROVDATUM: back-transform Excel Windows serial → ISO date (YYYY-MM-DD)
    -- Excel epoch is 1899-12-30 on Windows.
    -- Guard: only convert when the value looks like a positive integer.
    CASE
        WHEN NULLIF(IS_.PROVDATUM, 'MISSING') IS NOT NULL
         AND CAST(IS_.PROVDATUM AS INTEGER) > 0
         AND CAST(IS_.PROVDATUM AS REAL)    = CAST(IS_.PROVDATUM AS INTEGER)
            THEN DATE('1899-12-30',
                      '+' || CAST(IS_.PROVDATUM AS INTEGER) || ' days')
        ELSE NULL
    END                                                      AS PROVDATUM,

    -- Date components: cast to INTEGER (NULL if 'MISSING' or non-numeric)
    CAST(NULLIF(IS_.PROVTAGNINGSAR,    'MISSING') AS INTEGER) AS PROVTAGNINGSAR,
    CAST(NULLIF(IS_.PROVTAGNINGSMANAD, 'MISSING') AS INTEGER) AS PROVTAGNINGSMANAD,
    CAST(NULLIF(IS_.PROVTAGNINGSDAG,   'MISSING') AS INTEGER) AS PROVTAGNINGSDAG,

    -- Depths: cast to REAL (NULL if 'MISSING' or non-numeric)
    CAST(NULLIF(IS_.MIN_PROVDJUP_M, 'MISSING') AS REAL)      AS MIN_PROVDJUP_M,
    CAST(NULLIF(IS_.MAX_PROVDJUP_M, 'MISSING') AS REAL)      AS MAX_PROVDJUP_M,

    IS_.UNDERSOKNINGSTYP,
    IS_.PROVKOMMENTAR,

    DATE('now')                                              AS DATESTAMP

FROM INTERIM_SAMPLES IS_

    -- Duplicate flag (non-duplicates produce a NULL row → COALESCE to 'Y')
    LEFT JOIN DUPLICATE_SOURCE_ROWIDS DSR
        ON DSR.SOURCE_ROWID = IS_.ROWID

    -- Data source FK
    LEFT JOIN DATA_SOURCES DS
        ON DS.SOURCE_NAME = IS_.SOURCE_NAME

    -- Location FK
    LEFT JOIN INTERIM_LOCATIONS IL
        ON IL.LOCATION_ID = IS_.INTERIM_LOCATION_ID

ORDER BY IS_.ROWID;

-- =============================================================================
-- Sanity checks
-- =============================================================================

-- Row count and USE_SAMPLE breakdown
SELECT
    COUNT(*)                                               AS total_samples,
    SUM(CASE WHEN USE_SAMPLE = 'Y' THEN 1 ELSE 0 END)     AS use_y,
    SUM(CASE WHEN USE_SAMPLE = 'N' THEN 1 ELSE 0 END)     AS use_n,
    MIN(DATESTAMP)                                         AS datestamp
FROM SAMPLES;

-- Check FK coverage
SELECT
    SUM(CASE WHEN DATA_SOURCE_ID IS NULL THEN 1 ELSE 0 END) AS missing_data_source_id,
    SUM(CASE WHEN LOCATION_ID    IS NULL THEN 1 ELSE 0 END) AS missing_location_id
FROM SAMPLES;

-- Check PROVDATUM conversion: confirm NULL rate and date range
SELECT
    COUNT(*)                                               AS total_rows,
    SUM(CASE WHEN PROVDATUM IS NULL THEN 1 ELSE 0 END)     AS provdatum_null,
    MIN(PROVDATUM)                                         AS earliest_date,
    MAX(PROVDATUM)                                         AS latest_date
FROM SAMPLES;

-- Preview
SELECT *
FROM SAMPLES
ORDER BY ROWID
LIMIT 20;
