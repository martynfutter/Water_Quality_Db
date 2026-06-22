-- =============================================================================
-- 51_create_vw_provdatum_mismatch.sql
--
-- Creates the view vw_provdatum_mismatch.
--
-- Identifies rows in SAMPLES where PROVDATUM (back-transformed from the
-- Excel serial) does not match the date constructed from the three integer
-- components PROVTAGNINGSAR, PROVTAGNINGSMANAD, PROVTAGNINGSDAG.
--
-- The constructed date uses PRINTF to zero-pad month and day to two digits:
--   PRINTF('%04d-%02d-%02d', PROVTAGNINGSAR, PROVTAGNINGSMANAD, PROVTAGNINGSDAG)
--
-- Rows are included when:
--   • Both PROVDATUM and all three date components are non-NULL, AND
--   • PROVDATUM <> the constructed date string.
--
-- Rows where any of the five values is NULL are excluded — a NULL cannot
-- confirm or deny a mismatch, so they are a separate data-quality concern.
-- =============================================================================

DROP VIEW IF EXISTS vw_provdatum_mismatch;

CREATE VIEW vw_provdatum_mismatch AS
SELECT
    ROWID,
    PROVDATUM,
    PROVTAGNINGSAR,
    PROVTAGNINGSMANAD,
    PROVTAGNINGSDAG,
    PRINTF('%04d-%02d-%02d',
           PROVTAGNINGSAR,
           PROVTAGNINGSMANAD,
           PROVTAGNINGSDAG)          AS CONSTRUCTED_DATE
FROM SAMPLES
WHERE
    -- Both sides must be present
    PROVDATUM         IS NOT NULL
    AND PROVTAGNINGSAR    IS NOT NULL
    AND PROVTAGNINGSMANAD IS NOT NULL
    AND PROVTAGNINGSDAG   IS NOT NULL
    -- And they must disagree
    AND PROVDATUM <> PRINTF('%04d-%02d-%02d',
                            PROVTAGNINGSAR,
                            PROVTAGNINGSMANAD,
                            PROVTAGNINGSDAG)
ORDER BY ROWID;

-- =============================================================================
-- Sanity check
-- =============================================================================

SELECT COUNT(*) AS mismatch_count FROM vw_provdatum_mismatch;

SELECT * FROM vw_provdatum_mismatch LIMIT 20;
