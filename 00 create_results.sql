-- =============================================================================
-- create_results.sql
--
-- Creates the RESULTS table and populates it from RAW_DATA by unpivoting the
-- 52 measurement columns (Siktdjup_m .. GR_mg_l) into long format.
--
-- Column notes:
--   SOURCE_ROWID   INTEGER  – the ROWID of the source row in RAW_DATA
--   PARAMETER_NAME TEXT     – the sanitised column name (= parameter)
--   TEXT_VALUE     TEXT     – the raw cell value as stored in RAW_DATA
--   NUMERIC_VALUE  REAL     – left NULL here; populated later by
--                             update_water_quality_db.R
--   COMMENTS       TEXT     – free-text annotation; left NULL on insert
--   QC             TEXT     – quality-control flag; left NULL on insert
--
-- Rows excluded per parameter:
--   • SQL NULL  (cell was empty / truly missing in Excel)
--   • empty string after trimming whitespace
--   • literal 'NA' or 'NAN' (case-insensitive) – R/Excel not-available tokens
-- =============================================================================

-- ── 1. Create (or recreate) the RESULTS table ─────────────────────────────
DROP TABLE IF EXISTS RESULTS;

CREATE TABLE RESULTS (
    ID             INTEGER PRIMARY KEY AUTOINCREMENT,
    SOURCE_ROWID   INTEGER,
    PARAMETER_NAME TEXT,
    TEXT_VALUE     TEXT,
    NUMERIC_VALUE  REAL,
    COMMENTS       TEXT,
    QC             TEXT
);

-- ── 2. Populate from RAW_DATA (unpivot via UNION ALL) ─────────────────────
INSERT INTO RESULTS (SOURCE_ROWID, PARAMETER_NAME, TEXT_VALUE, NUMERIC_VALUE, COMMENTS, QC)
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Siktdjup_m'              AS PARAMETER_NAME,
        TRIM("Siktdjup_m")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Siktdjup_m" IS NOT NULL
      AND TRIM("Siktdjup_m") != ''
      AND UPPER(TRIM("Siktdjup_m")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Vattentemperatur_C'              AS PARAMETER_NAME,
        TRIM("Vattentemperatur_C")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Vattentemperatur_C" IS NOT NULL
      AND TRIM("Vattentemperatur_C") != ''
      AND UPPER(TRIM("Vattentemperatur_C")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Syrgashalt_mg_l_O2'              AS PARAMETER_NAME,
        TRIM("Syrgashalt_mg_l_O2")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Syrgashalt_mg_l_O2" IS NOT NULL
      AND TRIM("Syrgashalt_mg_l_O2") != ''
      AND UPPER(TRIM("Syrgashalt_mg_l_O2")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Syrgasmättnad_%'              AS PARAMETER_NAME,
        TRIM("Syrgasmättnad_%")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Syrgasmättnad_%" IS NOT NULL
      AND TRIM("Syrgasmättnad_%") != ''
      AND UPPER(TRIM("Syrgasmättnad_%")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'pH'              AS PARAMETER_NAME,
        TRIM("pH")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "pH" IS NOT NULL
      AND TRIM("pH") != ''
      AND UPPER(TRIM("pH")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Alk._mekv_l'              AS PARAMETER_NAME,
        TRIM("Alk._mekv_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Alk._mekv_l" IS NOT NULL
      AND TRIM("Alk._mekv_l") != ''
      AND UPPER(TRIM("Alk._mekv_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Alk_Acid_mekv_l'              AS PARAMETER_NAME,
        TRIM("Alk_Acid_mekv_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Alk_Acid_mekv_l" IS NOT NULL
      AND TRIM("Alk_Acid_mekv_l") != ''
      AND UPPER(TRIM("Alk_Acid_mekv_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Kond_20_S_cm'              AS PARAMETER_NAME,
        TRIM("Kond_20_S_cm")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Kond_20_S_cm" IS NOT NULL
      AND TRIM("Kond_20_S_cm") != ''
      AND UPPER(TRIM("Kond_20_S_cm")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Kond_25_mS_m'              AS PARAMETER_NAME,
        TRIM("Kond_25_mS_m")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Kond_25_mS_m" IS NOT NULL
      AND TRIM("Kond_25_mS_m") != ''
      AND UPPER(TRIM("Kond_25_mS_m")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Ca_mg_l'              AS PARAMETER_NAME,
        TRIM("Ca_mg_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Ca_mg_l" IS NOT NULL
      AND TRIM("Ca_mg_l") != ''
      AND UPPER(TRIM("Ca_mg_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Ca_Mg_mekv_l'              AS PARAMETER_NAME,
        TRIM("Ca_Mg_mekv_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Ca_Mg_mekv_l" IS NOT NULL
      AND TRIM("Ca_Mg_mekv_l") != ''
      AND UPPER(TRIM("Ca_Mg_mekv_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Cl_mg_l'              AS PARAMETER_NAME,
        TRIM("Cl_mg_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Cl_mg_l" IS NOT NULL
      AND TRIM("Cl_mg_l") != ''
      AND UPPER(TRIM("Cl_mg_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'F_mg_l'              AS PARAMETER_NAME,
        TRIM("F_mg_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "F_mg_l" IS NOT NULL
      AND TRIM("F_mg_l") != ''
      AND UPPER(TRIM("F_mg_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'K_mg_l'              AS PARAMETER_NAME,
        TRIM("K_mg_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "K_mg_l" IS NOT NULL
      AND TRIM("K_mg_l") != ''
      AND UPPER(TRIM("K_mg_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Mg_mg_l'              AS PARAMETER_NAME,
        TRIM("Mg_mg_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Mg_mg_l" IS NOT NULL
      AND TRIM("Mg_mg_l") != ''
      AND UPPER(TRIM("Mg_mg_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Na_mg_l'              AS PARAMETER_NAME,
        TRIM("Na_mg_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Na_mg_l" IS NOT NULL
      AND TRIM("Na_mg_l") != ''
      AND UPPER(TRIM("Na_mg_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'SO4_mg_l'              AS PARAMETER_NAME,
        TRIM("SO4_mg_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "SO4_mg_l" IS NOT NULL
      AND TRIM("SO4_mg_l") != ''
      AND UPPER(TRIM("SO4_mg_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'SO4_mg_l_S'              AS PARAMETER_NAME,
        TRIM("SO4_mg_l_S")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "SO4_mg_l_S" IS NOT NULL
      AND TRIM("SO4_mg_l_S") != ''
      AND UPPER(TRIM("SO4_mg_l_S")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'SO4_IC_mg_l_S'              AS PARAMETER_NAME,
        TRIM("SO4_IC_mg_l_S")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "SO4_IC_mg_l_S" IS NOT NULL
      AND TRIM("SO4_IC_mg_l_S") != ''
      AND UPPER(TRIM("SO4_IC_mg_l_S")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'SO4_Mack._mekv_l'              AS PARAMETER_NAME,
        TRIM("SO4_Mack._mekv_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "SO4_Mack._mekv_l" IS NOT NULL
      AND TRIM("SO4_Mack._mekv_l") != ''
      AND UPPER(TRIM("SO4_Mack._mekv_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Kjeld.-N_g_l_N'              AS PARAMETER_NAME,
        TRIM("Kjeld.-N_g_l_N")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Kjeld.-N_g_l_N" IS NOT NULL
      AND TRIM("Kjeld.-N_g_l_N") != ''
      AND UPPER(TRIM("Kjeld.-N_g_l_N")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Org-N_g_l_N'              AS PARAMETER_NAME,
        TRIM("Org-N_g_l_N")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Org-N_g_l_N" IS NOT NULL
      AND TRIM("Org-N_g_l_N") != ''
      AND UPPER(TRIM("Org-N_g_l_N")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'NH4-N_g_l_N'              AS PARAMETER_NAME,
        TRIM("NH4-N_g_l_N")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "NH4-N_g_l_N" IS NOT NULL
      AND TRIM("NH4-N_g_l_N") != ''
      AND UPPER(TRIM("NH4-N_g_l_N")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'NO2-N_g_l_N'              AS PARAMETER_NAME,
        TRIM("NO2-N_g_l_N")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "NO2-N_g_l_N" IS NOT NULL
      AND TRIM("NO2-N_g_l_N") != ''
      AND UPPER(TRIM("NO2-N_g_l_N")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'NO2_NO3-N_g_l_N'              AS PARAMETER_NAME,
        TRIM("NO2_NO3-N_g_l_N")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "NO2_NO3-N_g_l_N" IS NOT NULL
      AND TRIM("NO2_NO3-N_g_l_N") != ''
      AND UPPER(TRIM("NO2_NO3-N_g_l_N")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'NO3-N_g_l_N'              AS PARAMETER_NAME,
        TRIM("NO3-N_g_l_N")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "NO3-N_g_l_N" IS NOT NULL
      AND TRIM("NO3-N_g_l_N") != ''
      AND UPPER(TRIM("NO3-N_g_l_N")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Tot-N_g_l_N'              AS PARAMETER_NAME,
        TRIM("Tot-N_g_l_N")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Tot-N_g_l_N" IS NOT NULL
      AND TRIM("Tot-N_g_l_N") != ''
      AND UPPER(TRIM("Tot-N_g_l_N")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Tot-N_ps_g_l_N'              AS PARAMETER_NAME,
        TRIM("Tot-N_ps_g_l_N")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Tot-N_ps_g_l_N" IS NOT NULL
      AND TRIM("Tot-N_ps_g_l_N") != ''
      AND UPPER(TRIM("Tot-N_ps_g_l_N")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'PO4-P_g_l_P'              AS PARAMETER_NAME,
        TRIM("PO4-P_g_l_P")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "PO4-P_g_l_P" IS NOT NULL
      AND TRIM("PO4-P_g_l_P") != ''
      AND UPPER(TRIM("PO4-P_g_l_P")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Tot-P_g_l_P'              AS PARAMETER_NAME,
        TRIM("Tot-P_g_l_P")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Tot-P_g_l_P" IS NOT NULL
      AND TRIM("Tot-P_g_l_P") != ''
      AND UPPER(TRIM("Tot-P_g_l_P")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Abs_F_420_5cm'              AS PARAMETER_NAME,
        TRIM("Abs_F_420_5cm")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Abs_F_420_5cm" IS NOT NULL
      AND TRIM("Abs_F_420_5cm") != ''
      AND UPPER(TRIM("Abs_F_420_5cm")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Abs_OF_420_5cm'              AS PARAMETER_NAME,
        TRIM("Abs_OF_420_5cm")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Abs_OF_420_5cm" IS NOT NULL
      AND TRIM("Abs_OF_420_5cm") != ''
      AND UPPER(TRIM("Abs_OF_420_5cm")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Färgtal_mg_Pt_l'              AS PARAMETER_NAME,
        TRIM("Färgtal_mg_Pt_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Färgtal_mg_Pt_l" IS NOT NULL
      AND TRIM("Färgtal_mg_Pt_l") != ''
      AND UPPER(TRIM("Färgtal_mg_Pt_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Slamhalt_mg_l'              AS PARAMETER_NAME,
        TRIM("Slamhalt_mg_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Slamhalt_mg_l" IS NOT NULL
      AND TRIM("Slamhalt_mg_l") != ''
      AND UPPER(TRIM("Slamhalt_mg_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Turb_FNU_FNU'              AS PARAMETER_NAME,
        TRIM("Turb_FNU_FNU")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Turb_FNU_FNU" IS NOT NULL
      AND TRIM("Turb_FNU_FNU") != ''
      AND UPPER(TRIM("Turb_FNU_FNU")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'BOD7_mg_l_O2'              AS PARAMETER_NAME,
        TRIM("BOD7_mg_l_O2")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "BOD7_mg_l_O2" IS NOT NULL
      AND TRIM("BOD7_mg_l_O2") != ''
      AND UPPER(TRIM("BOD7_mg_l_O2")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'CODMn_mg_l_O2'              AS PARAMETER_NAME,
        TRIM("CODMn_mg_l_O2")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "CODMn_mg_l_O2" IS NOT NULL
      AND TRIM("CODMn_mg_l_O2") != ''
      AND UPPER(TRIM("CODMn_mg_l_O2")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'KMnO4_mg_l'              AS PARAMETER_NAME,
        TRIM("KMnO4_mg_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "KMnO4_mg_l" IS NOT NULL
      AND TRIM("KMnO4_mg_l") != ''
      AND UPPER(TRIM("KMnO4_mg_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'TOC_mg_l_C'              AS PARAMETER_NAME,
        TRIM("TOC_mg_l_C")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "TOC_mg_l_C" IS NOT NULL
      AND TRIM("TOC_mg_l_C") != ''
      AND UPPER(TRIM("TOC_mg_l_C")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Kfyll_g_l'              AS PARAMETER_NAME,
        TRIM("Kfyll_g_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Kfyll_g_l" IS NOT NULL
      AND TRIM("Kfyll_g_l") != ''
      AND UPPER(TRIM("Kfyll_g_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Al_s_g_l'              AS PARAMETER_NAME,
        TRIM("Al_s_g_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Al_s_g_l" IS NOT NULL
      AND TRIM("Al_s_g_l") != ''
      AND UPPER(TRIM("Al_s_g_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Cd_g_l'              AS PARAMETER_NAME,
        TRIM("Cd_g_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Cd_g_l" IS NOT NULL
      AND TRIM("Cd_g_l") != ''
      AND UPPER(TRIM("Cd_g_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Cr_g_l'              AS PARAMETER_NAME,
        TRIM("Cr_g_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Cr_g_l" IS NOT NULL
      AND TRIM("Cr_g_l") != ''
      AND UPPER(TRIM("Cr_g_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Cu_g_l'              AS PARAMETER_NAME,
        TRIM("Cu_g_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Cu_g_l" IS NOT NULL
      AND TRIM("Cu_g_l") != ''
      AND UPPER(TRIM("Cu_g_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Fe_g_l'              AS PARAMETER_NAME,
        TRIM("Fe_g_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Fe_g_l" IS NOT NULL
      AND TRIM("Fe_g_l") != ''
      AND UPPER(TRIM("Fe_g_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Mn_g_l'              AS PARAMETER_NAME,
        TRIM("Mn_g_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Mn_g_l" IS NOT NULL
      AND TRIM("Mn_g_l") != ''
      AND UPPER(TRIM("Mn_g_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Ni_g_l'              AS PARAMETER_NAME,
        TRIM("Ni_g_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Ni_g_l" IS NOT NULL
      AND TRIM("Ni_g_l") != ''
      AND UPPER(TRIM("Ni_g_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Pb_g_l'              AS PARAMETER_NAME,
        TRIM("Pb_g_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Pb_g_l" IS NOT NULL
      AND TRIM("Pb_g_l") != ''
      AND UPPER(TRIM("Pb_g_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Si_mg_l'              AS PARAMETER_NAME,
        TRIM("Si_mg_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Si_mg_l" IS NOT NULL
      AND TRIM("Si_mg_l") != ''
      AND UPPER(TRIM("Si_mg_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'Zn_g_l'              AS PARAMETER_NAME,
        TRIM("Zn_g_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "Zn_g_l" IS NOT NULL
      AND TRIM("Zn_g_l") != ''
      AND UPPER(TRIM("Zn_g_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'GF_mg_l'              AS PARAMETER_NAME,
        TRIM("GF_mg_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "GF_mg_l" IS NOT NULL
      AND TRIM("GF_mg_l") != ''
      AND UPPER(TRIM("GF_mg_l")) NOT IN ('NA', 'NAN')
    UNION ALL
    SELECT
        CAST(ROWID AS INTEGER) AS SOURCE_ROWID,
        'GR_mg_l'              AS PARAMETER_NAME,
        TRIM("GR_mg_l")              AS TEXT_VALUE,
        NULL                   AS NUMERIC_VALUE,
        NULL                   AS COMMENTS,
        NULL                   AS QC
    FROM RAW_DATA
    WHERE "GR_mg_l" IS NOT NULL
      AND TRIM("GR_mg_l") != ''
      AND UPPER(TRIM("GR_mg_l")) NOT IN ('NA', 'NAN');

-- ── 3. Optional: index on SOURCE_ROWID and PARAMETER_NAME ────────────────
CREATE INDEX IF NOT EXISTS idx_results_rowid    ON RESULTS (SOURCE_ROWID);
CREATE INDEX IF NOT EXISTS idx_results_param    ON RESULTS (PARAMETER_NAME);

-- ── 4. Quick sanity check ─────────────────────────────────────────────────
SELECT
    PARAMETER_NAME,
    COUNT(*)        AS n_rows,
    SUM(CASE WHEN TEXT_VALUE LIKE '<%' THEN 1 ELSE 0 END) AS n_below_detect
FROM RESULTS
GROUP BY PARAMETER_NAME
ORDER BY PARAMETER_NAME;
