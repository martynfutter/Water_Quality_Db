-- =============================================================================
-- create_vw_avg_nitrogen_by_location.sql
--
-- Creates the view vw_avg_nitrogen_by_location.
--
-- Returns average nitrogen values from vw_ratios grouped by LOCATION_ID
-- and N_FORM.
--
-- Join path:
--   vw_ratios.SOURCE_ROWID = SAMPLES.ROWID
--   SAMPLES.LOCATION_ID    = LOCATIONS.LOCATION_ID  (for reference)
--   SAMPLES.USE_SAMPLE     = 'Y'
--
-- Columns returned:
--   LOCATION_ID  – FK to LOCATIONS
--   N_FORM       – nitrogen form ('Inorganic' or 'Total')
--   AVG_N        – average nitrogen threshold N value across matched rows
--   N_SAMPLES    – count of rows contributing to the average
-- =============================================================================

DROP VIEW IF EXISTS vw_avg_nitrogen_by_location;

CREATE VIEW vw_avg_nitrogen_by_location AS
SELECT
    S.LOCATION_ID,
    R.N_FORM,
    AVG(R.NITROGEN) AS AVG_NITROGEN,
    COUNT(*)        AS N_SAMPLES
FROM vw_ratios R
JOIN SAMPLES S
    ON  S.ROWID       = R.SOURCE_ROWID
    AND S.USE_SAMPLE  = 'Y'
GROUP BY
    S.LOCATION_ID,
    R.N_FORM
ORDER BY
    S.LOCATION_ID,
    R.N_FORM;

-- =============================================================================
-- Sanity check
-- =============================================================================
SELECT *
FROM vw_avg_nitrogen_by_location
LIMIT 20;