-- =============================================================================
-- 66_create_vw_nitrogen_by_location_pivot.sql
--
-- Creates the view vw_nitrogen_by_location_pivot.
--
-- Pivots vw_avg_nitrogen_by_location so that each LOCATION_ID appears on
-- a single row with separate columns for DIN and Total N averages.
--
-- Columns returned:
--   LOCATION_ID  – unique location identifier
--   AVG_DIN      – AVG_NITROGEN where N_FORM = 'INORGANIC'
--   AVG_TOTAL_N  – AVG_NITROGEN where N_FORM = 'TOTAL'
--
-- Notes:
--   * All unique LOCATION_IDs are returned, including those that have data
--     for only one N_FORM; the other column will be NULL for those rows.
-- =============================================================================

DROP VIEW IF EXISTS vw_nitrogen_by_location_pivot;

CREATE VIEW vw_nitrogen_by_location_pivot AS
SELECT
    LOCATION_ID,
    MAX(CASE WHEN N_FORM = 'INORGANIC' THEN AVG_NITROGEN END) AS AVG_DIN,
    MAX(CASE WHEN N_FORM = 'TOTAL'     THEN AVG_NITROGEN END) AS AVG_TOTAL_N
FROM vw_avg_nitrogen_by_location
GROUP BY
    LOCATION_ID
ORDER BY
    LOCATION_ID;

-- =============================================================================
-- Sanity check
-- =============================================================================
SELECT *
FROM vw_nitrogen_by_location_pivot
LIMIT 20;