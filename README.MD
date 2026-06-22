# Water Quality Database Pipeline

An end-to-end pipeline for ingesting Swedish freshwater monitoring data from Excel, building a normalised SQLite database, quality-controlling measured values, producing N:P stoichiometry plots, and identifying duplicate samples.

---

## Repository structure

```
.
├── 00_create_water_quality_db.R               # Step 0   – Read Excel, create SQLite DB & RAW_DATA table
├── 00 create_results.sql                      # Step 0b  – Unpivot RAW_DATA → long-format RESULTS table
├── 01 fix_comma_decimals.sql                  # Step 1   – Fix European decimal commas in RESULTS
├── 02 populate_numeric_values.sql             # Step 2   – Cast TEXT_VALUE → NUMERIC_VALUE where valid
├── 03 fix_detection_limits.sql                # Step 3   – Handle below-detection-limit values (<X → X/2)
├── 04 fix_bracketed_values.sql                # Step 4   – Strip brackets from values (e.g. [0.5] → 0.5)
├── 05 delete_placeholder_rows.sql             # Step 5   – Delete dummy/artefact rows (XXXX, Column…)
├── 10 create_INTERIM_SAMPLES.sql              # Step 10  – Create normalised INTERIM_SAMPLES table
├── 11 create_INTERIM_LOCATIONS.sql            # Step 11  – Extract unique sampling locations
├── 12 add_INTERIM_LOCATION_ID.sql             # Step 12  – Link samples back to locations
├── 13 create_SAMPLE_LOCATION_BACKBONE.sql     # Step 13  – Compact sample↔location cross-reference
├── 14 update_depth_from_provkommentar.sql     # Step 14  – Extract depth from PROVKOMMENTAR free text
├── 15 update_depth_from_undersokningstyp.sql  # Step 15  – Extract depth from UNDERSOKNINGSTYP
├── 16 update_depth_ytvatten.sql               # Step 16  – Assign default depth for 'ytvatten' samples
├── 17 update_depth_botten.sql                 # Step 17  – Assign default depth for 'botten' samples
├── 18_create_DATA_SOURCES.sql                 # Step 18  – Create DATA_SOURCES lookup table
├── 20 create_LOCATIONS.sql                    # Step 20  – Create final deduplicated LOCATIONS table
├── 21_convert_rt90_to_sweref99.R              # Step 21  – Convert RT90 coordinates to SWEREF99TM
├── 22_update_locations_from_rt90.sql          # Step 22  – Write converted coordinates back to LOCATIONS
├── 25 create_NAMES_TO_USE.sql                 # Step 25  – Create PARAMETER_LOOKUP table
├── 26 create_RESULTS_view.sql                 # Step 26  – Create vw_results_with_lookup view
├── 30_create_STOICHIOMETRY_INPUTS.sql         # Step 30  – Create STOICHIOMETRY_INPUTS table
├── 31_create_STOICHIOMETRY_NITROGEN.sql       # Step 31  – Create STOICHIOMETRY_NITROGEN table
├── 32_create_vw_DIN.sql                       # Step 32  – Create vw_DIN view
├── 33_create_vw_total_n.sql                   # Step 33  – Create vw_total_n view
├── 34_create_COMPONENT_QC.sql                 # Step 34  – Create and populate COMPONENT_QC table
├── 35_add_DIN_to_STOICHIOMETRY_INPUTS.sql     # Step 35  – Add DIN and DIN_QC columns
├── 36_add_TOTAL_N_to_STOICHIOMETRY_INPUTS.sql # Step 36  – Add TOTAL_N and TOTAL_N_QC columns
├── 40_create_vw_source_rowid_stats.sql        # Step 40  – Create summary statistics view per SOURCE_ROWID
├── 41_create_DUPLICATE_CANDIDATES.sql         # Step 41  – Identify groups of potential duplicate samples
├── 42_create_DUPLICATE_SOURCE_ROWIDS.sql      # Step 42  – Resolve duplicate groups to individual SOURCE_ROWIDs
├── 43_create_vw_duplicate_samples.sql         # Step 43  – View joining duplicate candidates to sample metadata
├── 44_update_DUPLICATE_SOURCE_ROWIDS.sql      # Step 44  – Flag smaller SOURCE_ROWID in each pair as discarded
├── 45_create_vw_stoichiometry_inputs_deduped.sql  # Step 45  – Deduplicated view of STOICHIOMETRY_INPUTS
├── 50_create_SAMPLES.sql                      # Step 50  – Create curated SAMPLES table
├── 51_create_vw_provdatum_mismatch.sql        # Step 51  – View flagging PROVDATUM vs date-component mismatches
│
├── map_interim_locations.R                    # Visualisation – Map of INTERIM_LOCATIONS sampling sites
├── .gitignore
└── README.MD
```

> **Note:** `Short.xlsx`, `*.db`, `*.db-journal`, and `plots/` are listed in `.gitignore` and are not committed to the repository.

---

## Prerequisites

### R packages

```r
install.packages(c(
  "readxl",                              # reading Excel
  "DBI", "RSQLite",                      # database access
  "ggplot2", "patchwork", "scales",      # plotting
  "sf",                                  # spatial reprojection (map and RT90 scripts)
  "rnaturalearth", "rnaturalearthdata",  # Sweden base map
  "ggrepel"                              # non-overlapping map labels
))
```

### SQLite

SQL scripts are written for **SQLite 3**. Run them with the `sqlite3` command-line tool or from within R via `DBI::dbExecute()`.

---

## Pipeline walkthrough

### Step 0 — Create the database

```r
source("00_create_water_quality_db.R")
```

Reads `Short.xlsx` (all columns as text to preserve detection-limit strings such as `<0.5`), sanitises column names, and writes everything to a new SQLite database `water_quality.db` as the table **`RAW_DATA`**. Column names containing special characters (`()°µ/,+` and spaces) are replaced with underscores and de-duplicated automatically.

---

### Step 0b — Build the long-format RESULTS table

```sql
.read "00 create_results.sql"
```

Unpivots the 52 measurement columns of `RAW_DATA` into a long-format **`RESULTS`** table. Empty cells, `NA`, and `NAN` tokens are excluded. Indexes are created on `SOURCE_ROWID` and `PARAMETER_NAME`.

| Column           | Description                                     |
| ---------------- | ----------------------------------------------- |
| `ID`             | Auto-increment primary key                      |
| `SOURCE_ROWID`   | Row in `RAW_DATA` this came from                |
| `PARAMETER_NAME` | Sanitised column/parameter name                 |
| `TEXT_VALUE`     | Raw cell value as stored                        |
| `NUMERIC_VALUE`  | Parsed numeric value (populated by later steps) |
| `COMMENTS`       | Audit notes (populated by later steps)          |
| `QC`             | Quality-control flag (populated by later steps) |

---

### Steps 1–5 — Quality-control the values

Run scripts **01 → 05** in order. Each targets only rows where `QC IS NULL`, so they are safe to re-run.

| Script                            | Action                                                                 |
| --------------------------------- | ---------------------------------------------------------------------- |
| `01 fix_comma_decimals.sql`       | Replaces European decimal commas with periods in `TEXT_VALUE`          |
| `02 populate_numeric_values.sql`  | Casts `TEXT_VALUE` to `NUMERIC_VALUE` where the value is a valid number |
| `03 fix_detection_limits.sql`     | Converts `<X` detection-limit strings to `X/2` in `NUMERIC_VALUE`     |
| `04 fix_bracketed_values.sql`     | Strips brackets from values such as `[0.5]`, writing `0.5`            |
| `05 delete_placeholder_rows.sql`  | Deletes dummy or artefact rows (e.g. `XXXX`, `Column…`)               |

---

### Step 10 — Create INTERIM_SAMPLES table

```sql
.read "10 create_INTERIM_SAMPLES.sql"
```

Creates **`INTERIM_SAMPLES`** from the first 32 metadata columns of `RAW_DATA`. All columns stored as `TEXT`; missing values (`NULL`, empty string, `'na'`, `'NA'`) standardised to `'MISSING'`.

---

### Step 11 — Create INTERIM_LOCATIONS table

```sql
.read "11 create_INTERIM_LOCATIONS.sql"
```

Creates **`INTERIM_LOCATIONS`** by extracting distinct combinations of location-identifying columns from `INTERIM_SAMPLES`. Each unique location receives an auto-incremented `LOCATION_ID`. `LOCATION_ID_TO_USE` defaults to `−1` pending deduplication.

---

### Step 12 — Link samples back to locations

```sql
.read "12 add_INTERIM_LOCATION_ID.sql"
```

Adds an `INTERIM_LOCATION_ID` column to `INTERIM_SAMPLES` and populates it by joining back to `INTERIM_LOCATIONS` on the location-identifying columns.

---

### Step 13 — Create SAMPLE_LOCATION_BACKBONE table

```sql
.read "13 create_SAMPLE_LOCATION_BACKBONE.sql"
```

Creates **`SAMPLE_LOCATION_BACKBONE`** — a compact cross-reference between each sampling event's `ROWID` and the `LOCATION_ID_TO_USE` from `INTERIM_LOCATIONS`. Useful for downstream queries that need to respect the deduplication decisions recorded in `INTERIM_LOCATIONS`.

---

### Steps 14–17 — Populate missing depth values in INTERIM_SAMPLES

These four scripts fill `MIN_PROVDJUP_M` and `MAX_PROVDJUP_M` where both columns are still `'MISSING'`, working through available text fields in priority order. All are safe to run multiple times.

| Script                                       | Source of depth                 | Method                                                                                                             | Depth assigned  |
| -------------------------------------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------------ | --------------- |
| `14 update_depth_from_provkommentar.sql`     | `PROVKOMMENTAR` free text       | Locates first digit, extracts up to 10-char numeric window, strips non-numeric suffixes, normalises decimal comma  | Extracted value |
| `15 update_depth_from_undersokningstyp.sql`  | `UNDERSOKNINGSTYP` field        | Same digit-extraction approach as script 14                                                                        | Extracted value |
| `16 update_depth_ytvatten.sql`               | `UNDERSOKNINGSTYP = 'ytvatten'` | Fixed assignment                                                                                                   | `1.0` m         |
| `17 update_depth_botten.sql`                 | `UNDERSOKNINGSTYP = 'botten'`   | Fixed assignment                                                                                                   | `20.0` m        |

Each script appends a note to `PROVKOMMENTAR` recording how the depth was derived, and includes a preview `SELECT` so you can inspect affected rows before the `UPDATE` runs.

---

### Step 18 — Create DATA_SOURCES lookup table

```sql
.read "18_create_DATA_SOURCES.sql"
```

Creates **`DATA_SOURCES`** by extracting distinct `SOURCE_NAME` values from `INTERIM_SAMPLES` and assigning each a unique integer `DATA_SOURCE_ID`. Ordered alphabetically so IDs are stable across re-runs on the same data. Run after scripts 10–17 (`INTERIM_SAMPLES` must exist and be populated). An optional commented-out block at the end of the script adds a `DATA_SOURCE_ID` foreign-key column back to `INTERIM_SAMPLES`.

| Column          | Type                        | Description                          |
| --------------- | --------------------------- | ------------------------------------ |
| `DATA_SOURCE_ID`| INTEGER (PK, AUTOINCREMENT) | System-generated primary key         |
| `SOURCE_NAME`   | TEXT (UNIQUE)               | Original source file/dataset name    |

---

### Step 20 — Create final LOCATIONS table

```sql
.read "20 create_LOCATIONS.sql"
```

Creates **`LOCATIONS`** from `INTERIM_LOCATIONS`, retaining only rows where `LOCATION_ID = LOCATION_ID_TO_USE` (i.e. the canonical representative of each location group after deduplication). Coordinate columns are cast from `TEXT` to `INTEGER`. A `QC` column is included for future annotation.

---

### Steps 21–22 — Convert legacy RT90 coordinates to SWEREF99TM

Some locations in `LOCATIONS` may have coordinates stored in the older **RT90 2.5 gon V** system (EPSG:3021) rather than SWEREF99TM. These two steps identify and reproject those locations.

```r
source("21_convert_rt90_to_sweref99.R")
```
```sql
.read "22_update_locations_from_rt90.sql"
```

**`21_convert_rt90_to_sweref99.R`** reads all rows from `LOCATIONS` where `KOORDINATSYSTEM` does not indicate SWEREF99, then:

1. Detects and fixes **truncated 6-digit coordinates** — RT90 coordinates are always 7 digits, so values with only 6 digits are missing their leading digit and are corrected by multiplying by 10.
2. Reprojects both station and provplats coordinate pairs from RT90 2.5 gon V (EPSG:3021) to SWEREF99TM (EPSG:3006) using the `sf` package.
3. Writes results to a new staging table **`RT90_TO_SWEREF99`** — the original `LOCATIONS` table is not modified at this stage.

**`22_update_locations_from_rt90.sql`** reads from `RT90_TO_SWEREF99` and updates `LOCATIONS` in place for all rows where station coordinates were successfully converted. Sets `KOORDINATSYSTEM = 'SWEREF99TM'` and `QC = 'coordinates from RT90'` on all updated rows.

---

### Step 25 — Create PARAMETER_LOOKUP table

```sql
.read "25 create_NAMES_TO_USE.sql"
```

Creates **`PARAMETER_LOOKUP`** — a lookup table mapping the sanitised `PARAMETER_NAME` values in `RESULTS` to standardised English parameter codes, species, element, units, and molar mass. Populated initially from the distinct `PARAMETER_NAME` values in `RESULTS`; the `NAME_TO_USE` and other columns must then be filled in manually or via a separate update. Used by the view created in step 26.

| Column                 | Description                               |
| ---------------------- | ----------------------------------------- |
| `PARAMETER_NAME`       | Primary key; sanitised name from `RESULTS` |
| `NAME_TO_USE`          | Standardised English parameter code       |
| `SPECIES`              | Chemical species                          |
| `ELEMENT`              | Element (e.g. `NITROGEN`, `PHOSPHORUS`)   |
| `UNITS`                | Units of measurement                      |
| `ELEMENT_MOLAR_MASS_G` | Molar mass of the element (g/mol)         |

---

### Step 26 — Create vw_results_with_lookup view

```sql
.read "26 create_RESULTS_view.sql"
```

Creates the view **`vw_results_with_lookup`** — joins `RESULTS` to `PARAMETER_LOOKUP` on `PARAMETER_NAME` (LEFT JOIN, so all `RESULTS` rows are retained even if not yet mapped). Provides `NAME_TO_USE`, `SPECIES`, `ELEMENT`, `UNITS`, and `ELEMENT_MOLAR_MASS_G` alongside all `RESULTS` columns for convenient querying.

---

### Step 30 — Create STOICHIOMETRY_INPUTS table

```sql
.read "30_create_STOICHIOMETRY_INPUTS.sql"
```

Creates **`STOICHIOMETRY_INPUTS`** — one row per sampling event that has a non-NULL `TOTAL_PHOSPHORUS` value, drawn from `vw_results_with_lookup`. Additional nutrient columns (`DIN`, `TOTAL_N` and their QC flags) are added by later steps (35–36).

---

### Step 31 — Create STOICHIOMETRY_NITROGEN table

```sql
.read "31_create_STOICHIOMETRY_NITROGEN.sql"
```

Creates **`STOICHIOMETRY_NITROGEN`** — a wide-format staging table of nitrogen fraction values per sampling event, restricted to `SOURCE_ROWID`s already present in `STOICHIOMETRY_INPUTS`.

---

### Steps 32–33 — Create nitrogen views

```sql
.read "32_create_vw_DIN.sql"
.read "33_create_vw_total_n.sql"
```

Creates two views that compute dissolved inorganic nitrogen (DIN) and total nitrogen from the components held in `STOICHIOMETRY_NITROGEN`.

---

### Step 34 — Create COMPONENT_QC table

```sql
.read "34_create_COMPONENT_QC.sql"
```

Creates and populates **`COMPONENT_QC`** — a lookup table recording the distinct combinations of nitrogen fractions used when deriving DIN or total nitrogen, together with the source view name.

---

### Steps 35–36 — Add nitrogen columns to STOICHIOMETRY_INPUTS

```sql
.read "35_add_DIN_to_STOICHIOMETRY_INPUTS.sql"
.read "36_add_TOTAL_N_to_STOICHIOMETRY_INPUTS.sql"
```

Script 35 adds `DIN` and `DIN_QC` columns; script 36 adds `TOTAL_N` and `TOTAL_N_QC` columns. Both join through `COMPONENT_QC` to record which nitrogen fractions were used for each row. `DATESTAMP` is updated for all rows where a non-NULL value was found.

---

### Step 40 — Create vw_source_rowid_stats view

```sql
.read "40_create_vw_source_rowid_stats.sql"
```

Creates the view **`vw_source_rowid_stats`** — aggregates `RESULTS` by `SOURCE_ROWID`, computing summary statistics over `NUMERIC_VALUE` across all parameters for each sampling event. Only rows where `NUMERIC_VALUE IS NOT NULL` contribute to the aggregates. This is the first step in identifying duplicate samples; `SOURCE_ROWID`s with identical statistics are candidates for further inspection.

---

### Step 41 — Create DUPLICATE_CANDIDATES table

```sql
.read "41_create_DUPLICATE_CANDIDATES.sql"
```

Creates **`DUPLICATE_CANDIDATES`** by grouping `vw_source_rowid_stats` on its aggregate columns. Each group whose `N_SOURCE_ROWIDS > 1` is a potential duplicate set.

| Column                | Type                        | Description                                                   |
| --------------------- | --------------------------- | ------------------------------------------------------------- |
| `TUPLE_ID`            | INTEGER (PK, AUTOINCREMENT) | System-generated primary key identifying each duplicate group |
| `N_PARAMETERS`        | INTEGER                     | Count of parameters with a non-NULL `NUMERIC_VALUE`           |
| `SUM_NUMERIC_VALUE`   | REAL                        | Sum of `NUMERIC_VALUE` across all parameters                  |
| `AVG_NUMERIC_VALUE`   | REAL                        | Mean of `NUMERIC_VALUE` across all parameters                 |
| `STDEV_NUMERIC_VALUE` | REAL                        | Population standard deviation of `NUMERIC_VALUE`              |
| `N_SOURCE_ROWIDS`     | INTEGER                     | Count of `SOURCE_ROWID`s sharing these statistics             |

---

### Step 42 — Create DUPLICATE_SOURCE_ROWIDS table

```sql
.read "42_create_DUPLICATE_SOURCE_ROWIDS.sql"
```

Creates **`DUPLICATE_SOURCE_ROWIDS`** — resolves each duplicate candidate group to its individual member `SOURCE_ROWID`s. Defaults `USE_SAMPLE = 'Y'` for all rows; this flag is updated by script 44 to mark which duplicates should be discarded.

| Column            | Type    | Description                                                              |
| ----------------- | ------- | ------------------------------------------------------------------------ |
| `TUPLE_ID`        | INTEGER | FK → `DUPLICATE_CANDIDATES.TUPLE_ID`                                     |
| `SOURCE_ROWID`    | INTEGER | Individual sampling event identifier                                     |
| `N_SOURCE_ROWIDS` | INTEGER | Number of `SOURCE_ROWID`s in this duplicate group                        |
| `USE_SAMPLE`      | TEXT    | `'Y'` = retain, `'N'` = discard; defaults to `'Y'` on insert            |
| `DATESTAMP`       | TEXT    | Date the row was created or last updated                                 |

---

### Step 43 — Create vw_duplicate_samples view

```sql
.read "43_create_vw_duplicate_samples.sql"
```

Creates the view **`vw_duplicate_samples`** — joins `DUPLICATE_SOURCE_ROWIDS` to `INTERIM_SAMPLES` on `SOURCE_ROWID`, surfacing the full sample metadata alongside each duplicate candidate's `TUPLE_ID` and `USE_SAMPLE` flag. Ordered by `TUPLE_ID` then `SOURCE_ROWID` so all members of each duplicate group appear together. Intended as the primary inspection tool for deciding which duplicates to retain (`USE_SAMPLE = 'Y'`) and which to discard (`USE_SAMPLE = 'N'`).

---

### Step 44 — Flag duplicates for removal in DUPLICATE_SOURCE_ROWIDS

```sql
.read "44_update_DUPLICATE_SOURCE_ROWIDS.sql"
```

For each `TUPLE_ID` where `N_SOURCE_ROWIDS = 2`, sets `USE_SAMPLE = 'N'` on the **smaller** (earlier) `SOURCE_ROWID`, leaving the larger (later) one with `USE_SAMPLE = 'Y'`. Groups with more than two members are left unchanged for manual review. Includes a preview `SELECT` before the `UPDATE` and verification queries after.

---

### Step 45 — Create vw_stoichiometry_inputs_deduped view

```sql
.read "45_create_vw_stoichiometry_inputs_deduped.sql"
```

Creates the view **`vw_stoichiometry_inputs_deduped`** — a clean, deduplicated version of `STOICHIOMETRY_INPUTS` that excludes any `SOURCE_ROWID` flagged as `USE_SAMPLE = 'N'` in `DUPLICATE_SOURCE_ROWIDS`. Intended as the primary input for all downstream stoichiometry analysis and plotting.

---

### Step 50 — Create SAMPLES table

```sql
.read "50_create_SAMPLES.sql"
```

Creates and populates **`SAMPLES`** — the primary curated sample-level table, drawing together:

- Sample metadata from `INTERIM_SAMPLES` (dates, depths, identifiers)
- `USE_SAMPLE` flag from `DUPLICATE_SOURCE_ROWIDS` (`'Y'` = keep, `'N'` = discard); samples with no entry in `DUPLICATE_SOURCE_ROWIDS` are not duplicates and default to `'Y'`
- `DATA_SOURCE_ID` — FK to `DATA_SOURCES`, resolved by matching `INTERIM_SAMPLES.SOURCE_NAME → DATA_SOURCES.SOURCE_NAME`
- `LOCATION_ID` — FK to `INTERIM_LOCATIONS`, resolved by matching `INTERIM_SAMPLES.INTERIM_LOCATION_ID → INTERIM_LOCATIONS.LOCATION_ID`

Type conversions applied on insert: `PROVDATUM` is back-transformed from the Excel Windows serial number to an ISO date string (`YYYY-MM-DD`) using the epoch `1899-12-30`; year/month/day components are cast to `INTEGER`; depth columns are cast to `REAL`. `'MISSING'` and non-numeric values become `NULL`.

| Column             | Type    | Description                                            |
| ------------------ | ------- | ------------------------------------------------------ |
| `ROWID`            | INTEGER (PK) | Matches `INTERIM_SAMPLES.ROWID`                   |
| `USE_SAMPLE`       | TEXT    | `'Y'` = retain, `'N'` = discard                       |
| `DATA_SOURCE_ID`   | INTEGER | FK → `DATA_SOURCES`                                   |
| `LOCATION_ID`      | INTEGER | FK → `INTERIM_LOCATIONS`                              |
| `PROV_ID`          | TEXT    | Sample identifier                                      |
| `PROVDATUM`        | TEXT    | ISO date string (YYYY-MM-DD) converted from Excel serial |
| `PROVTAGNINGSAR`   | INTEGER | Sampling year                                          |
| `PROVTAGNINGSMANAD`| INTEGER | Sampling month                                         |
| `PROVTAGNINGSDAG`  | INTEGER | Sampling day                                           |
| `MIN_PROVDJUP_M`   | REAL    | Minimum sampling depth (m)                             |
| `MAX_PROVDJUP_M`   | REAL    | Maximum sampling depth (m)                             |
| `UNDERSOKNINGSTYP` | TEXT    | Investigation type                                     |
| `PROVKOMMENTAR`    | TEXT    | Sample comment                                         |
| `DATESTAMP`        | TEXT    | Date this script was run                               |

---

### Step 51 — Create vw_provdatum_mismatch view

```sql
.read "51_create_vw_provdatum_mismatch.sql"
```

Creates the view **`vw_provdatum_mismatch`** — identifies rows in `SAMPLES` where `PROVDATUM` (back-transformed from the Excel serial) does not match the date constructed from the three integer components `PROVTAGNINGSAR`, `PROVTAGNINGSMANAD`, `PROVTAGNINGSDAG`. Only rows where all five values are non-NULL are included; rows with any NULL value are excluded as a separate data-quality concern. Useful for catching edge cases where the Excel serial and the individual date columns are inconsistent.

| Column             | Description                                                    |
| ------------------ | -------------------------------------------------------------- |
| `ROWID`            | FK → `SAMPLES.ROWID`                                           |
| `PROVDATUM`        | Date as back-transformed from Excel serial                     |
| `PROVTAGNINGSAR`   | Year component                                                 |
| `PROVTAGNINGSMANAD`| Month component                                                |
| `PROVTAGNINGSDAG`  | Day component                                                  |
| `CONSTRUCTED_DATE` | Date built from components: `PRINTF('%04d-%02d-%02d', …)`      |

---

### Visualisations

#### Map of sampling locations

```r
source("map_interim_locations.R")
# → plots/map_interim_locations.png
```

Reads `INTERIM_LOCATIONS` from the database, reprojects coordinates from **SWEREF99TM (EPSG:3006)** to **WGS84 (EPSG:4326)**, and plots sites on a base map of Sweden using `ggplot2` + `rnaturalearth`. Station labels are added automatically with `ggrepel` when ≤ 40 locations are present.

#### N:P stoichiometry plot

```r
source("plot_NP_final.R")
# → plots/NP_final_2x2.png
```

Reads `STOICHIOMETRY_INPUTS` from the database and produces a 2 × 2 `patchwork` panel: a log₁₀ DIN vs Total P scatter plot with nutrient-limitation classification, a DIN distribution, a Total P distribution, and a legend panel.

---

## Database schema

### Tables

#### `RAW_DATA`

Staging table populated directly from `Short.xlsx`. All 84 columns stored as `TEXT`. One row per original spreadsheet row.

---

#### `RESULTS`

Long-format table unpivoted from `RAW_DATA`; one row per (sample × parameter) combination.

| Column           | Type                        |
| ---------------- | --------------------------- |
| `ID`             | INTEGER (PK, AUTOINCREMENT) |
| `SOURCE_ROWID`   | INTEGER                     |
| `PARAMETER_NAME` | TEXT                        |
| `TEXT_VALUE`     | TEXT                        |
| `NUMERIC_VALUE`  | REAL                        |
| `COMMENTS`       | TEXT                        |
| `QC`             | TEXT                        |

Indexes: `idx_results_rowid` on `SOURCE_ROWID`, `idx_results_param` on `PARAMETER_NAME`.

---

#### `INTERIM_SAMPLES`

One row per sampling event; the first 32 metadata columns from `RAW_DATA` with missing values standardised to `'MISSING'`, plus `INTERIM_LOCATION_ID` (INTEGER, added by script 12). Key columns include `ROWID`, `OVERVAKNINGSSTATION`, `PROVPLATS`, `PROVTAGNINGSMEDIUM`, `PROVDATUM`, `MIN_PROVDJUP_M`, `MAX_PROVDJUP_M`, `UNDERSOKNINGSTYP`, and `PROVKOMMENTAR`.

---

#### `INTERIM_LOCATIONS`

One row per unique sampling location.

| Column                   | Type                        |
| ------------------------ | --------------------------- |
| `LOCATION_ID`            | INTEGER (PK, AUTOINCREMENT) |
| `LOCATION_ID_TO_USE`     | INTEGER (default −1)        |
| `OVERVAKNINGSSTATION`    | TEXT                        |
| `STATIONSKOORDINAT_N_X`  | TEXT                        |
| `STATIONSKOORDINAT_E_Y`  | TEXT                        |
| `PROVPLATS`              | TEXT                        |
| `PROVPLATSKOORDINAT_N_X` | TEXT                        |
| `PROVPLATSKOORDINAT_E_Y` | TEXT                        |
| `KOORDINATSYSTEM`        | TEXT                        |
| `PROVTAGNINGSMEDIUM`     | TEXT                        |

---

#### `SAMPLE_LOCATION_BACKBONE`

Compact cross-reference between sampling events and their canonical location.

| Column                | Type         |
| --------------------- | ------------ |
| `ROWID`               | INTEGER (PK) |
| `INTERIM_LOCATION_ID` | INTEGER      |
| `LOCATION_ID_TO_USE`  | INTEGER      |

---

#### `DATA_SOURCES`

Lookup table of distinct data source names.

| Column          | Type                        |
| --------------- | --------------------------- |
| `DATA_SOURCE_ID`| INTEGER (PK, AUTOINCREMENT) |
| `SOURCE_NAME`   | TEXT (UNIQUE NOT NULL)      |

---

#### `LOCATIONS`

Final deduplicated location table; subset of `INTERIM_LOCATIONS` where `LOCATION_ID = LOCATION_ID_TO_USE`. Coordinate columns cast to `INTEGER`.

| Column                   | Type         |
| ------------------------ | ------------ |
| `LOCATION_ID`            | INTEGER (PK) |
| `OVERVAKNINGSSTATION`    | TEXT         |
| `STATIONSKOORDINAT_N_X`  | INTEGER      |
| `STATIONSKOORDINAT_E_Y`  | INTEGER      |
| `PROVPLATS`              | TEXT         |
| `PROVPLATSKOORDINAT_N_X` | INTEGER      |
| `PROVPLATSKOORDINAT_E_Y` | INTEGER      |
| `KOORDINATSYSTEM`        | TEXT         |
| `PROVTAGNINGSMEDIUM`     | TEXT         |
| `QC`                     | TEXT         |

---

#### `RT90_TO_SWEREF99`

Staging table of reprojected coordinates produced by `21_convert_rt90_to_sweref99.R`. The original `LOCATIONS` table is not modified until script 22 is run.

| Column                             | Type          |
| ---------------------------------- | ------------- |
| `LOCATION_ID`                      | INTEGER       |
| `ORIGINAL_KOORDINATSYSTEM`         | TEXT          |
| `ORIGINAL_STATIONSKOORDINAT_N_X`   | TEXT          |
| `ORIGINAL_STATIONSKOORDINAT_E_Y`   | TEXT          |
| `ORIGINAL_PROVPLATSKOORDINAT_N_X`  | TEXT          |
| `ORIGINAL_PROVPLATSKOORDINAT_E_Y`  | TEXT          |
| `EASTING_TRUNCATION_FIXED`         | INTEGER (0/1) |
| `NORTHING_TRUNCATION_FIXED`        | INTEGER (0/1) |
| `SWEREF99TM_STATIONSKOORDINAT_N`   | REAL          |
| `SWEREF99TM_STATIONSKOORDINAT_E`   | REAL          |
| `SWEREF99TM_PROVPLATSKOORDINAT_N`  | REAL          |
| `SWEREF99TM_PROVPLATSKOORDINAT_E`  | REAL          |
| `SOURCE_CRS`                       | INTEGER       |
| `TARGET_CRS`                       | INTEGER       |
| `CONVERSION_DATE`                  | TEXT          |

---

#### `PARAMETER_LOOKUP`

Parameter name lookup table linking `RESULTS.PARAMETER_NAME` to standardised codes and units.

| Column                 | Type      |
| ---------------------- | --------- |
| `PARAMETER_NAME`       | TEXT (PK) |
| `NAME_TO_USE`          | TEXT      |
| `SPECIES`              | TEXT      |
| `ELEMENT`              | TEXT      |
| `UNITS`                | TEXT      |
| `ELEMENT_MOLAR_MASS_G` | REAL      |

---

#### `STOICHIOMETRY_NITROGEN`

Wide-format staging table of nitrogen fraction values per sampling event, restricted to `SOURCE_ROWID`s present in `STOICHIOMETRY_INPUTS`.

| Column                         | Type         |
| ------------------------------ | ------------ |
| `SOURCE_ROWID`                 | INTEGER (PK) |
| `DATESTAMP`                    | TEXT         |
| `AMMONIUM_AS_N`                | REAL         |
| `NITRATE_AS_N`                 | REAL         |
| `NITRITE_AS_N`                 | REAL         |
| `ORGANIC_NITROGEN_AS_N`        | REAL         |
| `TOTAL_KJELDAHL_NITROGEN_AS_N` | REAL         |
| `TOTAL_NITROGEN`               | REAL         |

---

#### `STOICHIOMETRY_INPUTS`

One row per sampling event with a measured Total P; the central table for N:P stoichiometry analysis.

| Column             | Type         | Description                              |
| ------------------ | ------------ | ---------------------------------------- |
| `SOURCE_ROWID`     | INTEGER (PK) | Links to `RAW_DATA` and `RESULTS`        |
| `DATESTAMP`        | TEXT         | Date/time the row was last updated       |
| `TOTAL_PHOSPHORUS` | REAL         | Total phosphorus (µg/l P)                |
| `DIN`              | REAL         | Dissolved inorganic nitrogen (µg/l N)    |
| `DIN_QC`           | INTEGER      | FK → `COMPONENT_QC.COMPONENT_QC_ID`      |
| `TOTAL_N`          | REAL         | Total nitrogen (µg/l N)                  |
| `TOTAL_N_QC`       | INTEGER      | FK → `COMPONENT_QC.COMPONENT_QC_ID`      |

---

#### `COMPONENT_QC`

Lookup table of distinct nitrogen component combinations used in stoichiometry calculations.

| Column            | Type                        | Description                                      |
| ----------------- | --------------------------- | ------------------------------------------------ |
| `COMPONENT_QC_ID` | INTEGER (PK, AUTOINCREMENT) | System-generated primary key                     |
| `COMPONENTS`      | TEXT                        | Description of nitrogen fractions used           |
| `SOURCE_VIEW`     | TEXT                        | `vw_DIN`, `vw_total_n`, or `vw_DIN, vw_total_n` |

---

#### `DUPLICATE_CANDIDATES`

Groups of `SOURCE_ROWID`s that share identical summary statistics across all measured parameters, indicating potential duplicate samples.

| Column                | Type                        | Description                                                   |
| --------------------- | --------------------------- | ------------------------------------------------------------- |
| `TUPLE_ID`            | INTEGER (PK, AUTOINCREMENT) | System-generated primary key identifying each duplicate group |
| `N_PARAMETERS`        | INTEGER                     | Count of parameters with a non-NULL `NUMERIC_VALUE`           |
| `SUM_NUMERIC_VALUE`   | REAL                        | Sum of `NUMERIC_VALUE` across all parameters                  |
| `AVG_NUMERIC_VALUE`   | REAL                        | Mean of `NUMERIC_VALUE` across all parameters                 |
| `STDEV_NUMERIC_VALUE` | REAL                        | Population standard deviation of `NUMERIC_VALUE`              |
| `N_SOURCE_ROWIDS`     | INTEGER                     | Count of `SOURCE_ROWID`s sharing these statistics             |

---

#### `DUPLICATE_SOURCE_ROWIDS`

Individual `SOURCE_ROWID`s belonging to each duplicate candidate group.

| Column            | Type    | Description                                                              |
| ----------------- | ------- | ------------------------------------------------------------------------ |
| `TUPLE_ID`        | INTEGER | FK → `DUPLICATE_CANDIDATES.TUPLE_ID`                                     |
| `SOURCE_ROWID`    | INTEGER | Individual sampling event identifier                                     |
| `N_SOURCE_ROWIDS` | INTEGER | Number of `SOURCE_ROWID`s in this duplicate group                        |
| `USE_SAMPLE`      | TEXT    | `'Y'` = retain, `'N'` = discard; defaults to `'Y'` on insert            |
| `DATESTAMP`       | TEXT    | Date the row was created or last updated                                 |

---

#### `SAMPLES`

Primary curated sample-level table combining metadata, deduplication flags, and foreign keys to `DATA_SOURCES` and `LOCATIONS`.

| Column             | Type         | Description                                            |
| ------------------ | ------------ | ------------------------------------------------------ |
| `ROWID`            | INTEGER (PK) | Matches `INTERIM_SAMPLES.ROWID`                        |
| `USE_SAMPLE`       | TEXT         | `'Y'` = retain, `'N'` = discard                        |
| `DATA_SOURCE_ID`   | INTEGER      | FK → `DATA_SOURCES`                                    |
| `LOCATION_ID`      | INTEGER      | FK → `INTERIM_LOCATIONS`                               |
| `PROV_ID`          | TEXT         | Sample identifier                                      |
| `PROVDATUM`        | TEXT         | ISO date (YYYY-MM-DD) converted from Excel serial      |
| `PROVTAGNINGSAR`   | INTEGER      | Sampling year                                          |
| `PROVTAGNINGSMANAD`| INTEGER      | Sampling month                                         |
| `PROVTAGNINGSDAG`  | INTEGER      | Sampling day                                           |
| `MIN_PROVDJUP_M`   | REAL         | Minimum sampling depth (m)                             |
| `MAX_PROVDJUP_M`   | REAL         | Maximum sampling depth (m)                             |
| `UNDERSOKNINGSTYP` | TEXT         | Investigation type                                     |
| `PROVKOMMENTAR`    | TEXT         | Sample comment                                         |
| `DATESTAMP`        | TEXT         | Date this script was run                               |

---

### Views

#### `vw_results_with_lookup`

Joins `RESULTS` to `PARAMETER_LOOKUP` on `PARAMETER_NAME` (LEFT JOIN). Provides standardised parameter codes and units alongside raw result values.

---

#### `vw_DIN`

Computes dissolved inorganic nitrogen from components in `STOICHIOMETRY_NITROGEN`.

---

#### `vw_total_n`

Computes total nitrogen from components in `STOICHIOMETRY_NITROGEN`.

---

#### `vw_source_rowid_stats`

Aggregates `RESULTS` by `SOURCE_ROWID`; the basis for duplicate detection.

---

#### `vw_duplicate_samples`

Joins `DUPLICATE_SOURCE_ROWIDS` to `INTERIM_SAMPLES`; primary inspection tool for duplicate review.

---

#### `vw_stoichiometry_inputs_deduped`

Deduplicated version of `STOICHIOMETRY_INPUTS`; excludes rows flagged `USE_SAMPLE = 'N'`.

---

#### `vw_provdatum_mismatch`

Identifies rows in `SAMPLES` where the back-transformed `PROVDATUM` disagrees with the date constructed from `PROVTAGNINGSAR`, `PROVTAGNINGSMANAD`, and `PROVTAGNINGSDAG`. Rows with any NULL in the five compared fields are excluded.

| Column             | Description                                                    |
| ------------------ | -------------------------------------------------------------- |
| `ROWID`            | FK → `SAMPLES.ROWID`                                           |
| `PROVDATUM`        | Date as back-transformed from Excel serial                     |
| `PROVTAGNINGSAR`   | Year component                                                 |
| `PROVTAGNINGSMANAD`| Month component                                                |
| `PROVTAGNINGSDAG`  | Day component                                                  |
| `CONSTRUCTED_DATE` | Date built from components: `PRINTF('%04d-%02d-%02d', …)`      |
