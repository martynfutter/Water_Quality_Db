-- =============================================================================
-- 32_create_vw_DIN.sql
--
-- Creates view vw_DIN from STOICHIOMETRY_NITROGEN.
--
-- Columns:
--   SOURCE_ROWID  – primary key from STOICHIOMETRY_NITROGEN
--   DIN_AS_N      – Dissolved Inorganic Nitrogen (µg/l N), calculated as:
--                     CASE 1: NH4 + NO2 + NO3  (all three present)
--                     CASE 2: NH4 + NO3         (NO2 absent)
--                     CASE 3: NO3 only           (NH4 and NO2 both absent)
--                     NULL if none of the above conditions can be met
--   COMPONENTS    – text description of which fractions were summed
--
-- Rows where NITRATE_AS_N IS NULL are excluded (no meaningful DIN can be
-- computed); they will not appear in the view.
-- =============================================================================

DROP VIEW IF EXISTS vw_DIN;

CREATE VIEW vw_DIN AS
SELECT
    SOURCE_ROWID,

    CASE
        -- All three species present
        WHEN AMMONIUM_AS_N  IS NOT NULL
         AND NITRITE_AS_N   IS NOT NULL
         AND NITRATE_AS_N   IS NOT NULL
            THEN AMMONIUM_AS_N + NITRITE_AS_N + NITRATE_AS_N

        -- Ammonium + nitrate present; nitrite absent
        WHEN AMMONIUM_AS_N  IS NOT NULL
         AND NITRITE_AS_N   IS NULL
         AND NITRATE_AS_N   IS NOT NULL
            THEN AMMONIUM_AS_N + NITRATE_AS_N

        -- Nitrate only
        WHEN AMMONIUM_AS_N  IS NULL
         AND NITRITE_AS_N   IS NULL
         AND NITRATE_AS_N   IS NOT NULL
            THEN NITRATE_AS_N

        ELSE NULL
    END AS DIN_AS_N,

    CASE
        WHEN AMMONIUM_AS_N  IS NOT NULL
         AND NITRITE_AS_N   IS NOT NULL
         AND NITRATE_AS_N   IS NOT NULL
            THEN 'AMMONIUM_AS_N, NITRITE_AS_N and NITRATE_AS_N'

        WHEN AMMONIUM_AS_N  IS NOT NULL
         AND NITRITE_AS_N   IS NULL
         AND NITRATE_AS_N   IS NOT NULL
            THEN 'AMMONIUM_AS_N and NITRATE_AS_N'

        WHEN AMMONIUM_AS_N  IS NULL
         AND NITRITE_AS_N   IS NULL
         AND NITRATE_AS_N   IS NOT NULL
            THEN 'NITRATE_AS_N'

        ELSE NULL
    END AS COMPONENTS

FROM STOICHIOMETRY_NITROGEN
WHERE
    -- Only include rows where at least one of the defined cases applies
    NITRATE_AS_N IS NOT NULL;


-- =============================================================================
-- Sanity check: row counts per COMPONENTS value
-- =============================================================================
SELECT
    COMPONENTS,
    COUNT(*)            AS n_rows,
    MIN(DIN_AS_N)       AS min_din,
    MAX(DIN_AS_N)       AS max_din,
    AVG(DIN_AS_N)       AS mean_din
FROM vw_DIN
GROUP BY COMPONENTS
ORDER BY COMPONENTS;
