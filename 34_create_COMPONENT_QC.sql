-- =============================================================================
-- 34_create_COMPONENT_QC.sql
--
-- Creates and populates COMPONENT_QC from the distinct COMPONENTS values
-- found in vw_DIN and vw_total_n.
--
-- Where the same COMPONENTS string appears in both views, a single row is
-- kept (UNION deduplicates). SOURCE_VIEW records which view(s) the value
-- came from; where it appears in both it is recorded as 'vw_DIN, vw_total_n'.
--
-- NULL COMPONENTS values are excluded.
-- =============================================================================

DROP TABLE IF EXISTS COMPONENT_QC;

CREATE TABLE COMPONENT_QC (
    COMPONENT_QC_ID  INTEGER PRIMARY KEY AUTOINCREMENT,
    COMPONENTS       TEXT    NOT NULL,
    SOURCE_VIEW      TEXT    NOT NULL
);

-- =============================================================================
-- Populate: distinct COMPONENTS across both views, noting source
-- =============================================================================

INSERT INTO COMPONENT_QC (COMPONENTS, SOURCE_VIEW)
SELECT
    COMPONENTS,
    CASE
        WHEN EXISTS (SELECT 1 FROM vw_DIN     d WHERE d.COMPONENTS = u.COMPONENTS)
         AND EXISTS (SELECT 1 FROM vw_total_n t WHERE t.COMPONENTS = u.COMPONENTS)
            THEN 'vw_DIN, vw_total_n'
        WHEN EXISTS (SELECT 1 FROM vw_DIN     d WHERE d.COMPONENTS = u.COMPONENTS)
            THEN 'vw_DIN'
        ELSE 'vw_total_n'
    END AS SOURCE_VIEW
FROM (
    SELECT COMPONENTS FROM vw_DIN      WHERE COMPONENTS IS NOT NULL
    UNION
    SELECT COMPONENTS FROM vw_total_n  WHERE COMPONENTS IS NOT NULL
) u
ORDER BY COMPONENTS;

-- =============================================================================
-- Sanity check
-- =============================================================================

SELECT
    COMPONENT_QC_ID,
    COMPONENTS,
    SOURCE_VIEW
FROM COMPONENT_QC
ORDER BY COMPONENT_QC_ID;
