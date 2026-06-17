-- =============================================================================
-- 43_create_vw_duplicate_samples.sql
--
-- Creates the view vw_duplicate_samples by joining DUPLICATE_SOURCE_ROWIDS
-- to INTERIM_SAMPLES on SOURCE_ROWID.
--
-- This allows duplicate candidate groups (identified by TUPLE_ID) to be
-- inspected alongside the full sample metadata from INTERIM_SAMPLES, making
-- it straightforward to compare duplicates and decide which to retain
-- (USE_SAMPLE = 'Y') and which to discard (USE_SAMPLE = 'N').
--
-- Columns:
--   All columns from DUPLICATE_SOURCE_ROWIDS (TUPLE_ID, SOURCE_ROWID,
--   N_SOURCE_ROWIDS, USE_SAMPLE, DATESTAMP) followed by all columns from
--   INTERIM_SAMPLES (excluding SOURCE_ROWID to avoid duplication).
--
-- Ordered by TUPLE_ID then SOURCE_ROWID so duplicate groups are shown
-- together.
-- =============================================================================

DROP VIEW IF EXISTS vw_duplicate_samples;

CREATE VIEW vw_duplicate_samples AS
SELECT
    -- Duplicate candidate columns
    DSR.TUPLE_ID,
    DSR.SOURCE_ROWID,
    DSR.N_SOURCE_ROWIDS,
    DSR.USE_SAMPLE,
    DSR.DATESTAMP,

    -- INTERIM_SAMPLES metadata columns (excluding ROWID / SOURCE_ROWID
    -- as it is already carried from DUPLICATE_SOURCE_ROWIDS above)
    IS_.SOURCE_NAME,
    IS_.OVERVAKNINGSSTATION,
    IS_.NATIONELLT_OVERVAKNINGSSTATIONS_ID,
    IS_.MD_MVM_ID,
    IS_.EU_ID,
    IS_.STATIONSKOORDINAT_N_X,
    IS_.STATIONSKOORDINAT_E_Y,
    IS_.PROVPLATS,
    IS_.NATIONELLT_PROVPLATS_ID,
    IS_.EU_ID_PROVPLATSNIVA,
    IS_.PROVPLATSKOORDINAT_N_X,
    IS_.PROVPLATSKOORDINAT_E_Y,
    IS_.KOORDINATSYSTEM,
    IS_.PROVTAGNINGSMEDIUM,
    IS_.PROGRAM,
    IS_.DELPROGRAM,
    IS_.PROJEKT,
    IS_.LAN,
    IS_.KOMMUN,
    IS_.MS_CD_C2,
    IS_.MS_CD_C3,
    IS_.MS_CD_C4,
    IS_.PROV_ID,
    IS_.PROVDATUM,
    IS_.PROVTAGNINGSAR,
    IS_.PROVTAGNINGSMANAD,
    IS_.PROVTAGNINGSDAG,
    IS_.MIN_PROVDJUP_M,
    IS_.MAX_PROVDJUP_M,
    IS_.UNDERSOKNINGSTYP,
    IS_.PROVKOMMENTAR,
    IS_.INTERIM_LOCATION_ID

FROM DUPLICATE_SOURCE_ROWIDS DSR
JOIN INTERIM_SAMPLES IS_
    ON IS_.ROWID = DSR.SOURCE_ROWID
ORDER BY
    DSR.TUPLE_ID,
    DSR.SOURCE_ROWID;

-- =============================================================================
-- Sanity check: row count and preview
-- =============================================================================

SELECT COUNT(*) AS total_rows FROM vw_duplicate_samples;

SELECT *
FROM vw_duplicate_samples
ORDER BY TUPLE_ID, SOURCE_ROWID
LIMIT 20;
