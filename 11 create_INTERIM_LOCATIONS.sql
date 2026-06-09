-- =============================================================================
-- Create and populate INTERIM_LOCATIONS in water_quality.db (SQLite)
-- Source: INTERIM_SAMPLES table
-- Contains a primary key and unique combinations of location-related columns
-- =============================================================================

DROP TABLE IF EXISTS INTERIM_LOCATIONS;

CREATE TABLE INTERIM_LOCATIONS (
    LOCATION_ID            INTEGER PRIMARY KEY AUTOINCREMENT,
    LOCATION_ID_TO_USE     INTEGER NOT NULL DEFAULT -1,
    OVERVAKNINGSSTATION    TEXT    NOT NULL DEFAULT 'MISSING',
    STATIONSKOORDINAT_N_X  TEXT    NOT NULL DEFAULT 'MISSING',
    STATIONSKOORDINAT_E_Y  TEXT    NOT NULL DEFAULT 'MISSING',
    PROVPLATS              TEXT    NOT NULL DEFAULT 'MISSING',
    PROVPLATSKOORDINAT_N_X TEXT    NOT NULL DEFAULT 'MISSING',
    PROVPLATSKOORDINAT_E_Y TEXT    NOT NULL DEFAULT 'MISSING',
    KOORDINATSYSTEM        TEXT    NOT NULL DEFAULT 'MISSING',
    PROVTAGNINGSMEDIUM     TEXT    NOT NULL DEFAULT 'MISSING'
);

-- =============================================================================
-- Populate with unique combinations of the location columns
-- =============================================================================

INSERT INTO INTERIM_LOCATIONS (
    OVERVAKNINGSSTATION,
    STATIONSKOORDINAT_N_X,
    STATIONSKOORDINAT_E_Y,
    PROVPLATS,
    PROVPLATSKOORDINAT_N_X,
    PROVPLATSKOORDINAT_E_Y,
    KOORDINATSYSTEM,
    PROVTAGNINGSMEDIUM
)
SELECT DISTINCT
    OVERVAKNINGSSTATION,
    STATIONSKOORDINAT_N_X,
    STATIONSKOORDINAT_E_Y,
    PROVPLATS,
    PROVPLATSKOORDINAT_N_X,
    PROVPLATSKOORDINAT_E_Y,
    KOORDINATSYSTEM,
    PROVTAGNINGSMEDIUM
FROM INTERIM_SAMPLES
ORDER BY
    OVERVAKNINGSSTATION,
    PROVPLATS;

-- =============================================================================
-- Quick row-count check
-- =============================================================================
SELECT
    'INTERIM_SAMPLES'   AS "Table",
    COUNT(*)            AS "Row count"
FROM INTERIM_SAMPLES

UNION ALL

SELECT
    'INTERIM_LOCATIONS',
    COUNT(*)
FROM INTERIM_LOCATIONS;
