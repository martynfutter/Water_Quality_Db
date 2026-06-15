-- =============================================================================
-- 33_create_vw_total_n.sql
--
-- Creates view vw_total_n from STOICHIOMETRY_NITROGEN, joining to vw_DIN
-- for Case 3.
--
-- Columns:
--   SOURCE_ROWID          – primary key from STOICHIOMETRY_NITROGEN
--   TOTAL_NITROGEN_AS_N   – Total nitrogen (µg/l N), calculated as:
--
--     CASE 1: TOTAL_NITROGEN is not null
--               → use TOTAL_NITROGEN directly
--
--     CASE 2: TOTAL_NITROGEN is null,
--             NITRATE_AS_N is not null,
--             TOTAL_KJELDAHL_NITROGEN_AS_N is not null
--               → NITRATE_AS_N + TOTAL_KJELDAHL_NITROGEN_AS_N
--
--     CASE 3: TOTAL_NITROGEN is null,
--             TOTAL_KJELDAHL_NITROGEN_AS_N is null,
--             ORGANIC_NITROGEN_AS_N is not null,
--             vw_DIN.DIN_AS_N is not null
--               → ORGANIC_NITROGEN_AS_N + vw_DIN.DIN_AS_N
--               COMPONENTS = vw_DIN.COMPONENTS || ' and ORGANIC_NITROGEN'
--
--   COMPONENTS            – text description of which fractions were used
--
-- Rows where none of the three cases can be satisfied are excluded from
-- the view.
-- =============================================================================

DROP VIEW IF EXISTS vw_total_n;

CREATE VIEW vw_total_n AS
SELECT
    sn.SOURCE_ROWID,

    CASE
        -- Case 1: direct TOTAL_NITROGEN measurement
        WHEN sn.TOTAL_NITROGEN IS NOT NULL
            THEN sn.TOTAL_NITROGEN

        -- Case 2: Kjeldahl + nitrate
        WHEN sn.TOTAL_NITROGEN               IS NULL
         AND sn.TOTAL_KJELDAHL_NITROGEN_AS_N IS NOT NULL
         AND sn.NITRATE_AS_N                 IS NOT NULL
            THEN sn.TOTAL_KJELDAHL_NITROGEN_AS_N + sn.NITRATE_AS_N

        -- Case 3: organic nitrogen + DIN from vw_DIN
        WHEN sn.TOTAL_NITROGEN               IS NULL
         AND sn.TOTAL_KJELDAHL_NITROGEN_AS_N IS NULL
         AND sn.ORGANIC_NITROGEN_AS_N        IS NOT NULL
         AND d.DIN_AS_N                      IS NOT NULL
            THEN sn.ORGANIC_NITROGEN_AS_N + d.DIN_AS_N

        ELSE NULL
    END AS TOTAL_NITROGEN_AS_N,

    CASE
        WHEN sn.TOTAL_NITROGEN IS NOT NULL
            THEN 'TOTAL_NITROGEN'

        WHEN sn.TOTAL_NITROGEN               IS NULL
         AND sn.TOTAL_KJELDAHL_NITROGEN_AS_N IS NOT NULL
         AND sn.NITRATE_AS_N                 IS NOT NULL
            THEN 'NITRATE and TOTAL_KJELDAHL_NITROGEN'

        WHEN sn.TOTAL_NITROGEN               IS NULL
         AND sn.TOTAL_KJELDAHL_NITROGEN_AS_N IS NULL
         AND sn.ORGANIC_NITROGEN_AS_N        IS NOT NULL
         AND d.DIN_AS_N                      IS NOT NULL
            THEN d.COMPONENTS || ' and ORGANIC_NITROGEN'

        ELSE NULL
    END AS COMPONENTS

FROM STOICHIOMETRY_NITROGEN sn
LEFT JOIN vw_DIN d
    ON d.SOURCE_ROWID = sn.SOURCE_ROWID
WHERE
    -- Exclude rows where no case can be satisfied
    sn.TOTAL_NITROGEN IS NOT NULL

    OR (    sn.TOTAL_KJELDAHL_NITROGEN_AS_N IS NOT NULL
        AND sn.NITRATE_AS_N                 IS NOT NULL )

    OR (    sn.TOTAL_KJELDAHL_NITROGEN_AS_N IS NULL
        AND sn.ORGANIC_NITROGEN_AS_N        IS NOT NULL
        AND d.DIN_AS_N                      IS NOT NULL );


-- =============================================================================
-- Sanity check: row counts and value ranges per COMPONENTS value
-- =============================================================================
SELECT
    COMPONENTS,
    COUNT(*)                    AS n_rows,
    MIN(TOTAL_NITROGEN_AS_N)    AS min_total_n,
    MAX(TOTAL_NITROGEN_AS_N)    AS max_total_n,
    AVG(TOTAL_NITROGEN_AS_N)    AS mean_total_n
FROM vw_total_n
GROUP BY COMPONENTS
ORDER BY COMPONENTS;
