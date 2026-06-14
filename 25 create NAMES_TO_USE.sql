-- =============================================================================
-- Create PARAMETER_LOOKUP from distinct PARAMETER_NAME values in RESULTS
-- =============================================================================

DROP TABLE IF EXISTS PARAMETER_LOOKUP;

CREATE TABLE PARAMETER_LOOKUP (
    PARAMETER_NAME        TEXT    PRIMARY KEY,
    NAME_TO_USE           TEXT    NOT NULL DEFAULT 'MISSING',
    SPECIES               TEXT    NOT NULL DEFAULT 'MISSING',
    ELEMENT               TEXT    NOT NULL DEFAULT 'MISSING',
    UNITS                 TEXT    NOT NULL DEFAULT 'UG/L',
    ELEMENT_MOLAR_MASS_G  REAL    NOT NULL DEFAULT 99.9
);

INSERT INTO PARAMETER_LOOKUP (PARAMETER_NAME)
SELECT DISTINCT PARAMETER_NAME
FROM RESULTS
ORDER BY PARAMETER_NAME;

-- =============================================================================
-- Sanity check
-- =============================================================================
SELECT * FROM PARAMETER_LOOKUP ORDER BY PARAMETER_NAME;