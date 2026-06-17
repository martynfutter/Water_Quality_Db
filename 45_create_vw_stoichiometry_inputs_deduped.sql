-- =============================================================================
-- 45_create_vw_stoichiometry_inputs_deduped.sql
--
-- Creates the view vw_stoichiometry_inputs_deduped from STOICHIOMETRY_INPUTS,
-- excluding any SOURCE_ROWIDs that have been flagged as duplicates to discard
-- (USE_SAMPLE = 'N') in DUPLICATE_SOURCE_ROWIDS.
--
-- This view is intended as the clean, deduplicated input for downstream
-- stoichiometry analysis.
-- =============================================================================

DROP VIEW IF EXISTS vw_stoichiometry_inputs_deduped;

CREATE VIEW vw_stoichiometry_inputs_deduped AS
SELECT
    SI.*
FROM STOICHIOMETRY_INPUTS SI
WHERE SI.SOURCE_ROWID NOT IN (
    SELECT DSR.SOURCE_ROWID
    FROM DUPLICATE_SOURCE_ROWIDS DSR
    WHERE DSR.USE_SAMPLE = 'N'
);

-- =============================================================================
-- Sanity check: compare row counts before and after deduplication
-- =============================================================================
SELECT
    'STOICHIOMETRY_INPUTS'              AS "Table",
    COUNT(*)                            AS "Row count"
FROM STOICHIOMETRY_INPUTS

UNION ALL

SELECT
    'vw_stoichiometry_inputs_deduped',
    COUNT(*)
FROM vw_stoichiometry_inputs_deduped

UNION ALL

SELECT
    'Rows excluded (USE_SAMPLE = N)',
    COUNT(*)
FROM STOICHIOMETRY_INPUTS SI
WHERE SI.SOURCE_ROWID IN (
    SELECT DSR.SOURCE_ROWID
    FROM DUPLICATE_SOURCE_ROWIDS DSR
    WHERE DSR.USE_SAMPLE = 'N'
);
