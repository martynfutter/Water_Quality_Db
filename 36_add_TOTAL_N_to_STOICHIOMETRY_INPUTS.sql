-- =============================================================================
-- 36_add_TOTAL_N_to_STOICHIOMETRY_INPUTS.sql
--
-- Adds two columns to STOICHIOMETRY_INPUTS:
--   TOTAL_N      REAL    – Total Nitrogen (µg/l N) from vw_total_n
--   TOTAL_N_QC   INTEGER – Foreign key to COMPONENT_QC.COMPONENT_QC_ID
--
-- TOTAL_N      is populated where vw_total_n.SOURCE_ROWID = STOICHIOMETRY_INPUTS.SOURCE_ROWID
-- TOTAL_N_QC   is populated by matching vw_total_n.COMPONENTS to COMPONENT_QC.COMPONENTS
-- DATESTAMP    is updated to the current date and time for rows where TOTAL_N is populated
-- =============================================================================

ALTER TABLE STOICHIOMETRY_INPUTS ADD COLUMN TOTAL_N     REAL;
ALTER TABLE STOICHIOMETRY_INPUTS ADD COLUMN TOTAL_N_QC  INTEGER;

-- =============================================================================
-- Populate TOTAL_N, TOTAL_N_QC and DATESTAMP
-- =============================================================================

UPDATE STOICHIOMETRY_INPUTS
SET
    TOTAL_N = (
        SELECT t.TOTAL_NITROGEN_AS_N
        FROM vw_total_n t
        WHERE t.SOURCE_ROWID = STOICHIOMETRY_INPUTS.SOURCE_ROWID
    ),
    TOTAL_N_QC = (
        SELECT cq.COMPONENT_QC_ID
        FROM vw_total_n t
        JOIN COMPONENT_QC cq
            ON cq.COMPONENTS = t.COMPONENTS
        WHERE t.SOURCE_ROWID = STOICHIOMETRY_INPUTS.SOURCE_ROWID
    ),
    DATESTAMP = datetime('now')
WHERE EXISTS (
    SELECT 1
    FROM vw_total_n t
    WHERE t.SOURCE_ROWID = STOICHIOMETRY_INPUTS.SOURCE_ROWID
      AND t.TOTAL_NITROGEN_AS_N IS NOT NULL
);

-- =============================================================================
-- Sanity check
-- =============================================================================

SELECT
    COUNT(*)                AS total_rows,
    COUNT(TOTAL_N)          AS rows_with_TOTAL_N,
    COUNT(TOTAL_N_QC)       AS rows_with_TOTAL_N_QC,
    MIN(TOTAL_N)            AS min_TOTAL_N,
    MAX(TOTAL_N)            AS max_TOTAL_N,
    AVG(TOTAL_N)            AS mean_TOTAL_N
FROM STOICHIOMETRY_INPUTS;
