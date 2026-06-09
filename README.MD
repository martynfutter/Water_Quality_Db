# Water Quality Database Pipeline

An end-to-end pipeline for ingesting Swedish freshwater monitoring data from Excel, building a normalised SQLite database, quality-controlling measured values, and producing N:P stoichiometry plots.

---

## Repository structure

```
.
├── 00_create_water_quality_db.R      # Step 0 – Read Excel, create SQLite database & RAW_DATA table
├── 00 create_results.sql             # Step 0b – Unpivot RAW_DATA → long-format RESULTS table
├── 01 fix_comma_decimals.sql         # Step 1 – Fix European decimal commas in RESULTS
├── 02 populate_numeric_values.sql    # Step 2 – Cast TEXT_VALUE → NUMERIC_VALUE where valid
├── 03 fix_detection_limits.sql       # Step 3 – Handle below-detection-limit values (<X → X/2)
├── 04 fix_bracketed_values.sql       # Step 4 – Strip brackets from values (e.g. [0.5] → 0.5)
├── 05 delete_placeholder_rows.sql    # Step 5 – Delete dummy/artefact rows (XXXX, Column…)
├── 10 create_INTERIM_SAMPLES.sql     # Step 10 – Create normalised INTERIM_SAMPLES table
├── 11 create_INTERIM_LOCATIONS.sql   # Step 11 – Extract unique sampling locations
├── 12 add_INTERIM_LOCATION_ID.sql    # Step 12 – Link samples back to locations
├── map_interim_locations.R           # Plot sampling locations on a map of Sweden
├── .gitignore
└── README.MD
```

> **Note:** `Short.xlsx`, `*.db`, and `plots/` are listed in `.gitignore` and are not committed to the repository.

---

## Prerequisites

### R packages

```
install.packages(c(
  "readxl",             # reading Excel
  "DBI", "RSQLite",     # database access
  "ggplot2", "patchwork", "scales",  # plotting
  "sf",                 # spatial reprojection (map script)
  "rnaturalearth", "rnaturalearthdata",  # Sweden base map
  "ggrepel"             # non-overlapping map labels
))
```

### SQLite

SQL scripts are written for **SQLite 3**. Run them with the `sqlite3` command-line tool or from within R via `DBI::dbExecute()`.

---

## Pipeline walkthrough

### 1 — Create the database

```
source("00_create_water_quality_db.R")
```

Reads `Short.xlsx` (all columns as text to preserve detection-limit strings such as `<0.5`), sanitises column names, and writes everything to a new SQLite database `water_quality.db` as the table **`RAW_DATA`**.

---

### 2 — Build the long-format RESULTS table

```
-- in sqlite3 or via DBI
.read "00 create_results.sql"
```

Unpivots the 52 measurement columns of `RAW_DATA` into a long-format **`RESULTS`** table with columns:

| Column           | Description                            |
| ---------------- | -------------------------------------- |
| `ID`             | Auto-increment primary key             |
| `SOURCE_ROWID`   | Row in `RAW_DATA` this came from       |
| `PARAMETER_NAME` | Sanitised column/parameter name        |
| `TEXT_VALUE`     | Raw cell value as stored               |
| `NUMERIC_VALUE`  | Parsed numeric value (populated later) |
| `COMMENTS`       | Audit notes (populated later)          |
| `QC`             | Quality-control flag (populated later) |


Empty cells, `NA`, and `NAN` tokens are excluded at this stage.

---

### 3 — Quality-control the values (SQL route)

Run scripts **01 → 05** in order. Each script targets only rows where `QC IS NULL`, so they are safe to re-run and are order-independent within their scope.

| Script                           | What it does                                      | QC flag set    |
| -------------------------------- | ------------------------------------------------- | -------------- |
| `01 fix_comma_decimals.sql`      | Replaces European `,` decimal separator with `.`  | `COMMA FIXED`  |
| `02 populate_numeric_values.sql` | Casts clean numeric strings to `NUMERIC_VALUE`    | `VALID NUMBER` |
| `03 fix_detection_limits.sql`    | Parses `<X` → stores `X / 2` as the numeric value | `HALF DETECT`  |
| `04 fix_bracketed_values.sql`    | Strips `[` `]` from values and casts to numeric   | `BRACKETS`     |
| `05 delete_placeholder_rows.sql` | Deletes dummy rows (`XXXX…`, `Column…`)           | — (deleted)    |


**R alternative:** `update_water_quality_db.R` performs the same logic as scripts 01–03 entirely in R using batched `UPDATE` statements via `DBI`, and may be preferable if you want to avoid the `sqlite3` CLI.

---

### 4 — Build normalised sample and location tables

```
.read "10 create_INTERIM_SAMPLES.sql"
.read "11 create_INTERIM_LOCATIONS.sql"
.read "12 add_INTERIM_LOCATION_ID.sql"
```

| Table               | Description                                                                                                                |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `INTERIM_SAMPLES`   | One row per sampling event; the first 32 metadata columns from `RAW_DATA`, with missing values standardised to `'MISSING'` |
| `INTERIM_LOCATIONS` | One row per unique combination of station/sampling-point coordinates and medium; auto-increment `LOCATION_ID`              |


Script 12 adds `INTERIM_LOCATION_ID` to `INTERIM_SAMPLES` by joining on all eight location fields.

---

### 5 — Visualisations

#### Map of sampling locations

```
source("map_interim_locations.R")
# → plots/map_interim_locations.png
```

Reads `INTERIM_LOCATIONS` from the database, reprojects coordinates from **SWEREF99TM (EPSG:3006)** to **WGS84**, and plots sites on a base map of Sweden. Station labels are added automatically when ≤ 40 locations are present.

#### N:P stoichiometry plot

```
source("plot_NP_final.R")
# → plots/NP_final_2x2.png
```

Reads `short_NP_STOICHIOMETRY.csv` and classifies each observation by nutrient limitation status based on DIN and Total P concentrations (both µg/l). The output is a 2 × 2 panel figure: scatter plot (log₁₀ axes), DIN distribution, Total P distribution, and a legend panel.

---

## Parameter name mapping

`names_to_use.csv` maps the original Swedish column headers to standardised English parameter codes and units. Useful reference when querying `RESULTS` by `PARAMETER_NAME`.

Example entries:

| Original name           | Standardised name | Units |
| ----------------------- | ----------------- | ----- |
| `Tot-P (µg/l P)`        | `TOTP-P`          | µg/l  |
| `Tot-N (µg/l N)`        | `TOTN-N`          | µg/l  |
| `NO2+NO3-N (µg/l N)`    | `NO3-N`           | µg/l  |
| `Vattentemperatur (°C)` | `TEMPERATURE`     | °C    |
| `Siktdjup (m)`          | `SECCHI`          | m     |
| `pH`                    | `PH`              | —     |

---

## Data source

The data originate from the **Swedish national freshwater monitoring programme** and are stored in the original Swedish column naming convention used by the data provider. All coordinates are in **SWEREF99TM (EPSG:3006)**.

## About

code to create and populate a water quality database

---

## Database schema

The database contains 5 tables and 2 indexes.

### `RAW_DATA`

Staging table populated directly from `Short.xlsx`. All columns stored as `TEXT`.

| Column | Type |
| --- | --- |
| `RowID` | TEXT |
| `Source.Name` | TEXT |
| `Övervakningsstation` | TEXT |
| `Nationellt_övervakningsstations-ID` | TEXT |
| `MD-MVM_Id` | TEXT |
| `EU_id` | TEXT |
| `Stationskoordinat_N_X` | TEXT |
| `Stationskoordinat_E_Y` | TEXT |
| `Provplats` | TEXT |
| `Nationellt_provplats-ID` | TEXT |
| `EU_ID_provplatsnivå` | TEXT |
| `Provplatskoordinat_N_X` | TEXT |
| `Provplatskoordinat_E_Y` | TEXT |
| `Koordinatsystem` | TEXT |
| `Provtagningsmedium` | TEXT |
| `Program` | TEXT |
| `Delprogram` | TEXT |
| `Projekt` | TEXT |
| `Län` | TEXT |
| `Kommun` | TEXT |
| `MS_CD_C2` | TEXT |
| `MS_CD_C3` | TEXT |
| `MS_CD_C4` | TEXT |
| `ProvId` | TEXT |
| `Provdatum` | TEXT |
| `Provtagningsår` | TEXT |
| `Provtagningsmånad` | TEXT |
| `Provtagningsdag` | TEXT |
| `Min_provdjup_m` | TEXT |
| `Max_provdjup_m` | TEXT |
| `Undersökningstyp` | TEXT |
| `Provkommentar` | TEXT |
| `Siktdjup_m` | TEXT |
| `Vattentemperatur_C` | TEXT |
| `Syrgashalt_mg_l_O2` | TEXT |
| `Syrgasmättnad_%` | TEXT |
| `pH` | TEXT |
| `Alk._mekv_l` | TEXT |
| `Alk_Acid_mekv_l` | TEXT |
| `Kond_20_S_cm` | TEXT |
| `Kond_25_mS_m` | TEXT |
| `Ca_mg_l` | TEXT |
| `Ca_Mg_mekv_l` | TEXT |
| `Cl_mg_l` | TEXT |
| `F_mg_l` | TEXT |
| `K_mg_l` | TEXT |
| `Mg_mg_l` | TEXT |
| `Na_mg_l` | TEXT |
| `SO4_mg_l` | TEXT |
| `SO4_mg_l_S` | TEXT |
| `SO4_IC_mg_l_S` | TEXT |
| `SO4_Mack._mekv_l` | TEXT |
| `Kjeld.-N_g_l_N` | TEXT |
| `Org-N_g_l_N` | TEXT |
| `NH4-N_g_l_N` | TEXT |
| `NO2-N_g_l_N` | TEXT |
| `NO2_NO3-N_g_l_N` | TEXT |
| `NO3-N_g_l_N` | TEXT |
| `Tot-N_g_l_N` | TEXT |
| `Tot-N_ps_g_l_N` | TEXT |
| `PO4-P_g_l_P` | TEXT |
| `Tot-P_g_l_P` | TEXT |
| `Abs_F_420_5cm` | TEXT |
| `Abs_OF_420_5cm` | TEXT |
| `Färgtal_mg_Pt_l` | TEXT |
| `Slamhalt_mg_l` | TEXT |
| `Turb_FNU_FNU` | TEXT |
| `BOD7_mg_l_O2` | TEXT |
| `CODMn_mg_l_O2` | TEXT |
| `KMnO4_mg_l` | TEXT |
| `TOC_mg_l_C` | TEXT |
| `Kfyll_g_l` | TEXT |
| `Al_s_g_l` | TEXT |
| `Cd_g_l` | TEXT |
| `Cr_g_l` | TEXT |
| `Cu_g_l` | TEXT |
| `Fe_g_l` | TEXT |
| `Mn_g_l` | TEXT |
| `Ni_g_l` | TEXT |
| `Pb_g_l` | TEXT |
| `Si_mg_l` | TEXT |
| `Zn_g_l` | TEXT |
| `GF_mg_l` | TEXT |
| `GR_mg_l` | TEXT |

### `RESULTS`

Long-format table unpivoted from `RAW_DATA`.

| Column | Type |
| --- | --- |
| `ID` | INTEGER (PK, AUTOINCREMENT) |
| `SOURCE_ROWID` | INTEGER |
| `PARAMETER_NAME` | TEXT |
| `TEXT_VALUE` | TEXT |
| `NUMERIC_VALUE` | REAL |
| `COMMENTS` | TEXT |
| `QC` | TEXT |

### `INTERIM_SAMPLES`

One row per sampling event; metadata columns from `RAW_DATA` with missing values standardised to `'MISSING'`.

| Column | Type |
| --- | --- |
| `ROWID` | INTEGER (PK) |
| `SOURCE_NAME` | TEXT |
| `OVERVAKNINGSSTATION` | TEXT |
| `NATIONELLT_OVERVAKNINGSSTATIONS_ID` | TEXT |
| `MD_MVM_ID` | TEXT |
| `EU_ID` | TEXT |
| `STATIONSKOORDINAT_N_X` | TEXT |
| `STATIONSKOORDINAT_E_Y` | TEXT |
| `PROVPLATS` | TEXT |
| `NATIONELLT_PROVPLATS_ID` | TEXT |
| `EU_ID_PROVPLATSNIVA` | TEXT |
| `PROVPLATSKOORDINAT_N_X` | TEXT |
| `PROVPLATSKOORDINAT_E_Y` | TEXT |
| `KOORDINATSYSTEM` | TEXT |
| `PROVTAGNINGSMEDIUM` | TEXT |
| `PROGRAM` | TEXT |
| `DELPROGRAM` | TEXT |
| `PROJEKT` | TEXT |
| `LAN` | TEXT |
| `KOMMUN` | TEXT |
| `MS_CD_C2` | TEXT |
| `MS_CD_C3` | TEXT |
| `MS_CD_C4` | TEXT |
| `PROV_ID` | TEXT |
| `PROVDATUM` | TEXT |
| `PROVTAGNINGSAR` | TEXT |
| `PROVTAGNINGSMANAD` | TEXT |
| `PROVTAGNINGSDAG` | TEXT |
| `MIN_PROVDJUP_M` | TEXT |
| `MAX_PROVDJUP_M` | TEXT |
| `UNDERSOKNINGSTYP` | TEXT |
| `PROVKOMMENTAR` | TEXT |
| `INTERIM_LOCATION_ID` | INTEGER |

### `INTERIM_LOCATIONS`

One row per unique sampling location.

| Column | Type |
| --- | --- |
| `LOCATION_ID` | INTEGER (PK, AUTOINCREMENT) |
| `LOCATION_ID_TO_USE` | INTEGER (default -1) |
| `OVERVAKNINGSSTATION` | TEXT |
| `STATIONSKOORDINAT_N_X` | TEXT |
| `STATIONSKOORDINAT_E_Y` | TEXT |
| `PROVPLATS` | TEXT |
| `PROVPLATSKOORDINAT_N_X` | TEXT |
| `PROVPLATSKOORDINAT_E_Y` | TEXT |
| `KOORDINATSYSTEM` | TEXT |
| `PROVTAGNINGSMEDIUM` | TEXT |

### `sqlite_sequence`

Internal SQLite table tracking auto-increment counters.

### Indexes

| Index | Table | Column |
| --- | --- | --- |
| `idx_results_param` | `RESULTS` | `PARAMETER_NAME` |
| `idx_results_rowid` | `RESULTS` | `SOURCE_ROWID` |
