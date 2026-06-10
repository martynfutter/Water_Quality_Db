-- =============================================================================
-- Create and populate SAMPLE_LOCATION_BACKBONE
-- Joins INTERIM_SAMPLES to INTERIM_LOCATIONS to carry forward
-- LOCATION_ID_TO_USE alongside each sample's ROWID
-- =============================================================================

DROP TABLE IF EXISTS SAMPLE_LOCATION_BACKBONE;

CREATE TABLE SAMPLE_LOCATION_BACKBONE (
    ROWID                INTEGER PRIMARY KEY,
    INTERIM_LOCATION_ID  INTEGER NOT NULL,
    LOCATION_ID_TO_USE   INTEGER NOT NULL
);

-- =============================================================================
-- Populate via join on INTERIM_SAMPLES.INTERIM_LOCATION_ID = INTERIM_LOCATIONS.LOCATION_ID
-- =============================================================================

INSERT INTO SAMPLE_LOCATION_BACKBONE (
    ROWID,
    INTERIM_LOCATION_ID,
    LOCATION_ID_TO_USE
)
SELECT
    IS_.ROWID,
    IS_.INTERIM_LOCATION_ID,
    IL.LOCATION_ID_TO_USE
FROM INTERIM_SAMPLES  IS_
JOIN INTERIM_LOCATIONS IL
    ON IS_.INTERIM_LOCATION_ID = IL.LOCATION_ID;

-- =============================================================================
-- Sanity check
-- =============================================================================

SELECT
    'INTERIM_SAMPLES'         AS "Table",
    COUNT(*)                  AS "Row count"
FROM INTERIM_SAMPLES

UNION ALL

SELECT
    'SAMPLE_LOCATION_BACKBONE',
    COUNT(*)
FROM SAMPLE_LOCATION_BACKBONE;