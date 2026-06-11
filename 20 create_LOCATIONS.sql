-- =============================================================================
-- Create and populate LOCATIONS from INTERIM_LOCATIONS
-- Only rows where LOCATION_ID = LOCATION_ID_TO_USE are included
-- Coordinate columns stored as INTEGER, QC column added
-- =============================================================================

DROP TABLE IF EXISTS LOCATIONS;

CREATE TABLE LOCATIONS (
    LOCATION_ID            INTEGER PRIMARY KEY,
    OVERVAKNINGSSTATION    TEXT    NOT NULL DEFAULT 'MISSING',
    STATIONSKOORDINAT_N_X  INTEGER,
    STATIONSKOORDINAT_E_Y  INTEGER,
    PROVPLATS              TEXT    NOT NULL DEFAULT 'MISSING',
    PROVPLATSKOORDINAT_N_X INTEGER,
    PROVPLATSKOORDINAT_E_Y INTEGER,
    KOORDINATSYSTEM        TEXT    NOT NULL DEFAULT 'MISSING',
    PROVTAGNINGSMEDIUM     TEXT    NOT NULL DEFAULT 'MISSING',
    QC                     TEXT
);

-- =============================================================================
-- Populate from INTERIM_LOCATIONS
-- Only rows where LOCATION_ID = LOCATION_ID_TO_USE
-- Coordinate columns cast to INTEGER
-- =============================================================================

INSERT INTO LOCATIONS (
    LOCATION_ID,
    OVERVAKNINGSSTATION,
    STATIONSKOORDINAT_N_X,
    STATIONSKOORDINAT_E_Y,
    PROVPLATS,
    PROVPLATSKOORDINAT_N_X,
    PROVPLATSKOORDINAT_E_Y,
    KOORDINATSYSTEM,
    PROVTAGNINGSMEDIUM,
    QC
)
SELECT
    LOCATION_ID,
    OVERVAKNINGSSTATION,
    CAST(STATIONSKOORDINAT_N_X  AS INTEGER),
    CAST(STATIONSKOORDINAT_E_Y  AS INTEGER),
    PROVPLATS,
    CAST(PROVPLATSKOORDINAT_N_X AS INTEGER),
    CAST(PROVPLATSKOORDINAT_E_Y AS INTEGER),
    KOORDINATSYSTEM,
    PROVTAGNINGSMEDIUM,
    NULL  AS QC
FROM INTERIM_LOCATIONS
WHERE LOCATION_ID = LOCATION_ID_TO_USE;

-- =============================================================================
-- Quick sanity check
-- =============================================================================

SELECT
    'INTERIM_LOCATIONS (filtered)' AS "Source",
    COUNT(*)                        AS "Row count"
FROM INTERIM_LOCATIONS
WHERE LOCATION_ID = LOCATION_ID_TO_USE

UNION ALL

SELECT
    'LOCATIONS',
    COUNT(*)
FROM LOCATIONS;