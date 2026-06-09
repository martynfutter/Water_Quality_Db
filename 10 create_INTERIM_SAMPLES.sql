-- =============================================================================
-- Create and populate INTERIM_SAMPLES in water_quality.db (SQLite)
-- Source: RAW_DATA table
-- Columns: ROWID through PROVKOMMENTAR (first 32 columns of source data)
-- All columns TEXT except ROWID (INTEGER PRIMARY KEY)
-- Missing text → 'MISSING'  (NULL, empty string, 'na', 'NA' all treated as missing)
-- =============================================================================

DROP TABLE IF EXISTS INTERIM_SAMPLES;

CREATE TABLE INTERIM_SAMPLES (
    ROWID                              INTEGER PRIMARY KEY,
    SOURCE_NAME                        TEXT    NOT NULL DEFAULT 'MISSING',
    OVERVAKNINGSSTATION                TEXT    NOT NULL DEFAULT 'MISSING',
    NATIONELLT_OVERVAKNINGSSTATIONS_ID TEXT    NOT NULL DEFAULT 'MISSING',
    MD_MVM_ID                          TEXT    NOT NULL DEFAULT 'MISSING',
    EU_ID                              TEXT    NOT NULL DEFAULT 'MISSING',
    STATIONSKOORDINAT_N_X              TEXT    NOT NULL DEFAULT 'MISSING',
    STATIONSKOORDINAT_E_Y              TEXT    NOT NULL DEFAULT 'MISSING',
    PROVPLATS                          TEXT    NOT NULL DEFAULT 'MISSING',
    NATIONELLT_PROVPLATS_ID            TEXT    NOT NULL DEFAULT 'MISSING',
    EU_ID_PROVPLATSNIVA                TEXT    NOT NULL DEFAULT 'MISSING',
    PROVPLATSKOORDINAT_N_X             TEXT    NOT NULL DEFAULT 'MISSING',
    PROVPLATSKOORDINAT_E_Y             TEXT    NOT NULL DEFAULT 'MISSING',
    KOORDINATSYSTEM                    TEXT    NOT NULL DEFAULT 'MISSING',
    PROVTAGNINGSMEDIUM                 TEXT    NOT NULL DEFAULT 'MISSING',
    PROGRAM                            TEXT    NOT NULL DEFAULT 'MISSING',
    DELPROGRAM                         TEXT    NOT NULL DEFAULT 'MISSING',
    PROJEKT                            TEXT    NOT NULL DEFAULT 'MISSING',
    LAN                                TEXT    NOT NULL DEFAULT 'MISSING',
    KOMMUN                             TEXT    NOT NULL DEFAULT 'MISSING',
    MS_CD_C2                           TEXT    NOT NULL DEFAULT 'MISSING',
    MS_CD_C3                           TEXT    NOT NULL DEFAULT 'MISSING',
    MS_CD_C4                           TEXT    NOT NULL DEFAULT 'MISSING',
    PROV_ID                            TEXT    NOT NULL DEFAULT 'MISSING',
    PROVDATUM                          TEXT    NOT NULL DEFAULT 'MISSING',
    PROVTAGNINGSAR                     TEXT    NOT NULL DEFAULT 'MISSING',
    PROVTAGNINGSMANAD                  TEXT    NOT NULL DEFAULT 'MISSING',
    PROVTAGNINGSDAG                    TEXT    NOT NULL DEFAULT 'MISSING',
    MIN_PROVDJUP_M                     TEXT    NOT NULL DEFAULT 'MISSING',
    MAX_PROVDJUP_M                     TEXT    NOT NULL DEFAULT 'MISSING',
    UNDERSOKNINGSTYP                   TEXT    NOT NULL DEFAULT 'MISSING',
    PROVKOMMENTAR                      TEXT    NOT NULL DEFAULT 'MISSING'
);

-- =============================================================================
-- Populate from RAW_DATA using exact column names from PRAGMA table_info
-- =============================================================================

INSERT INTO INTERIM_SAMPLES (
    ROWID,
    SOURCE_NAME,
    OVERVAKNINGSSTATION,
    NATIONELLT_OVERVAKNINGSSTATIONS_ID,
    MD_MVM_ID,
    EU_ID,
    STATIONSKOORDINAT_N_X,
    STATIONSKOORDINAT_E_Y,
    PROVPLATS,
    NATIONELLT_PROVPLATS_ID,
    EU_ID_PROVPLATSNIVA,
    PROVPLATSKOORDINAT_N_X,
    PROVPLATSKOORDINAT_E_Y,
    KOORDINATSYSTEM,
    PROVTAGNINGSMEDIUM,
    PROGRAM,
    DELPROGRAM,
    PROJEKT,
    LAN,
    KOMMUN,
    MS_CD_C2,
    MS_CD_C3,
    MS_CD_C4,
    PROV_ID,
    PROVDATUM,
    PROVTAGNINGSAR,
    PROVTAGNINGSMANAD,
    PROVTAGNINGSDAG,
    MIN_PROVDJUP_M,
    MAX_PROVDJUP_M,
    UNDERSOKNINGSTYP,
    PROVKOMMENTAR
)
SELECT
    CAST(RowID AS INTEGER),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("Source.Name"),                      ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("Övervakningsstation"),              ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("Nationellt_övervakningsstations-ID"),''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("MD-MVM_Id"),                        ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("EU_id"),                            ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("Stationskoordinat_N_X"),            ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("Stationskoordinat_E_Y"),            ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("Provplats"),                        ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("Nationellt_provplats-ID"),          ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("EU_ID_provplatsnivå"),              ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("Provplatskoordinat_N_X"),           ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("Provplatskoordinat_E_Y"),           ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("Koordinatsystem"),                  ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("Provtagningsmedium"),               ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("Program"),                          ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("Delprogram"),                       ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("Projekt"),                          ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("Län"),                              ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("Kommun"),                           ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("MS_CD_C2"),                         ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("MS_CD_C3"),                         ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("MS_CD_C4"),                         ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("ProvId"),                           ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("Provdatum"),                        ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("Provtagningsår"),                   ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("Provtagningsmånad"),                ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("Provtagningsdag"),                  ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("Min_provdjup_m"),                   ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("Max_provdjup_m"),                   ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("Undersökningstyp"),                 ''), 'na'), 'NA'), 'MISSING'),
    COALESCE(NULLIF(NULLIF(NULLIF(TRIM("Provkommentar"),                    ''), 'na'), 'NA'), 'MISSING')
FROM RAW_DATA;

-- =============================================================================
-- Quick row-count check
-- =============================================================================
SELECT
    'RAW_DATA'         AS "Table",
    COUNT(*)           AS "Row count"
FROM RAW_DATA

UNION ALL

SELECT
    'INTERIM_SAMPLES',
    COUNT(*)
FROM INTERIM_SAMPLES;
