-- =============================================================================
-- CREATE VIEW vw_results_with_lookup
--
-- Joins RESULTS to PARAMETER_LOOKUP on PARAMETER_NAME.
-- LEFT JOIN ensures all RESULTS rows are returned even if a PARAMETER_NAME
-- has not yet been populated in PARAMETER_LOOKUP.
-- PARAMETER_NAME appears once (from RESULTS) to avoid duplication.
-- =============================================================================

DROP VIEW IF EXISTS vw_results_with_lookup;

CREATE VIEW vw_results_with_lookup AS
SELECT
    -- All RESULTS columns
    R.ID,
    R.SOURCE_ROWID,
    R.PARAMETER_NAME,
    R.TEXT_VALUE,
    R.NUMERIC_VALUE,
    R.COMMENTS,
    R.QC,

    -- All PARAMETER_LOOKUP columns (excluding join key PARAMETER_NAME)
    PL.NAME_TO_USE,
    PL.SPECIES,
    PL.ELEMENT,
    PL.UNITS,
    PL.ELEMENT_MOLAR_MASS_G

FROM RESULTS R
LEFT JOIN PARAMETER_LOOKUP PL
    ON R.PARAMETER_NAME = PL.PARAMETER_NAME;