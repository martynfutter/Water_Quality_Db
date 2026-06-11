-- =============================================================================
-- 22_update_locations_from_rt90.sql
--
-- Updates LOCATIONS with converted SWEREF99TM coordinates from RT90_TO_SWEREF99.
--
-- Only rows where both station coordinates were successfully converted
-- (i.e. SWEREF99TM_STATIONSKOORDINAT_N and _E are not NULL) are updated.
-- Provplats coordinates are updated where available but are not required.
--
-- QC is set to 'coordinates from RT90' for all updated rows.
-- The original LOCATIONS table coordinates are overwritten in place.
-- =============================================================================


-- =============================================================================
-- Preview: inspect what will be updated before committing
-- =============================================================================
SELECT
    L.LOCATION_ID,
    L.KOORDINATSYSTEM,
    L.STATIONSKOORDINAT_N_X                 AS stn_n_before,
    R.SWEREF99TM_STATIONSKOORDINAT_N        AS stn_n_after,
    L.STATIONSKOORDINAT_E_Y                 AS stn_e_before,
    R.SWEREF99TM_STATIONSKOORDINAT_E        AS stn_e_after,
    L.PROVPLATSKOORDINAT_N_X                AS prv_n_before,
    R.SWEREF99TM_PROVPLATSKOORDINAT_N       AS prv_n_after,
    L.PROVPLATSKOORDINAT_E_Y                AS prv_e_before,
    R.SWEREF99TM_PROVPLATSKOORDINAT_E       AS prv_e_after,
    R.EASTING_TRUNCATION_FIXED
FROM LOCATIONS L
JOIN RT90_TO_SWEREF99 R
    ON L.LOCATION_ID = R.LOCATION_ID
WHERE
    R.SWEREF99TM_STATIONSKOORDINAT_N IS NOT NULL
    AND R.SWEREF99TM_STATIONSKOORDINAT_E IS NOT NULL
ORDER BY L.LOCATION_ID;


-- =============================================================================
-- UPDATE station coordinates, provplats coordinates, and QC flag
-- =============================================================================
UPDATE LOCATIONS
SET
    STATIONSKOORDINAT_N_X  = (
        SELECT SWEREF99TM_STATIONSKOORDINAT_N
        FROM RT90_TO_SWEREF99
        WHERE RT90_TO_SWEREF99.LOCATION_ID = LOCATIONS.LOCATION_ID
    ),
    STATIONSKOORDINAT_E_Y  = (
        SELECT SWEREF99TM_STATIONSKOORDINAT_E
        FROM RT90_TO_SWEREF99
        WHERE RT90_TO_SWEREF99.LOCATION_ID = LOCATIONS.LOCATION_ID
    ),
    PROVPLATSKOORDINAT_N_X = (
        SELECT SWEREF99TM_PROVPLATSKOORDINAT_N
        FROM RT90_TO_SWEREF99
        WHERE RT90_TO_SWEREF99.LOCATION_ID = LOCATIONS.LOCATION_ID
    ),
    PROVPLATSKOORDINAT_E_Y = (
        SELECT SWEREF99TM_PROVPLATSKOORDINAT_E
        FROM RT90_TO_SWEREF99
        WHERE RT90_TO_SWEREF99.LOCATION_ID = LOCATIONS.LOCATION_ID
    ),
    KOORDINATSYSTEM        = 'SWEREF99TM',
    QC                     = 'coordinates from RT90'
WHERE
    LOCATION_ID IN (
        SELECT LOCATION_ID
        FROM RT90_TO_SWEREF99
        WHERE
            SWEREF99TM_STATIONSKOORDINAT_N IS NOT NULL
            AND SWEREF99TM_STATIONSKOORDINAT_E IS NOT NULL
    );


-- =============================================================================
-- Verification: row counts by QC flag after update
-- =============================================================================
SELECT
    QC,
    KOORDINATSYSTEM,
    COUNT(*) AS n_rows
FROM LOCATIONS
GROUP BY QC, KOORDINATSYSTEM
ORDER BY QC, KOORDINATSYSTEM;


-- =============================================================================
-- Verification: check for any remaining non-SWEREF rows in LOCATIONS
-- (these would be rows with no match in RT90_TO_SWEREF99 or where
--  conversion yielded NULL — worth inspecting manually)
-- =============================================================================
SELECT
    LOCATION_ID,
    KOORDINATSYSTEM,
    STATIONSKOORDINAT_N_X,
    STATIONSKOORDINAT_E_Y,
    QC
FROM LOCATIONS
WHERE UPPER(KOORDINATSYSTEM) NOT LIKE '%SWEREF%'
ORDER BY LOCATION_ID;
