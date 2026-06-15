-- =============================================================================
-- 35_add_DIN_to_STOICHIOMETRY_INPUTS.sql
--
-- Adds two columns to STOICHIOMETRY_INPUTS:
--   DIN      REAL  – Dissolved Inorganic Nitrogen (µg/l N) from vw_DIN
--   DIN_QC   INTEGER – Foreign key to COMPONENT_QC.COMPONENT_QC_ID
--
-- DIN      is populated where vw_DIN.SOURCE_ROWID = STOICHIOMETRY_INPUTS.SOURCE_ROWID
-- DIN_QC   is populated by matching vw_DIN.COMPONENTS to COMPONENT_QC.COMPONENTS
-- =============================================================================

ALTER TABLE STOICHIOMETRY_INPUTS ADD COLUMN DIN     REAL;
ALTER TABLE STOICHIOMETRY_INPUTS ADD COLUMN DIN_QC  INTEGER;

-- =============================================================================
-- Populate DIN and DIN_QC
-- =============================================================================

UPDATE STOICHIOMETRY_INPUTS
SET
    DIN = (
        SELECT d.DIN_AS_N
        FROM vw_DIN d
        WHERE d.SOURCE_ROWID = STOICHIOMETRY_INPUTS.SOURCE_ROWID
    ),
    DIN_QC = (
        SELECT cq.COMPONENT_QC_ID
        FROM vw_DIN d
        JOIN COMPONENT_QC cq
            ON cq.COMPONENTS = d.COMPONENTS
        WHERE d.SOURCE_ROWID = STOICHIOMETRY_INPUTS.SOURCE_ROWID
    ),
    DATESTAMP = datetime('now')
WHERE EXISTS (
    SELECT 1
    FROM vw_DIN d
    WHERE d.SOURCE_ROWID = STOICHIOMETRY_INPUTS.SOURCE_ROWID
      AND d.DIN_AS_N IS NOT NULL
);

-- =============================================================================
-- Sanity check
-- =============================================================================

SELECT
    COUNT(*)            AS total_rows,
    COUNT(DIN)          AS rows_with_DIN,
    COUNT(DIN_QC)       AS rows_with_DIN_QC,
    MIN(DIN)            AS min_DIN,
    MAX(DIN)            AS max_DIN,
    AVG(DIN)            AS mean_DIN
FROM STOICHIOMETRY_INPUTS;
