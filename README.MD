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
│
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

| Script                           | What it does                                      | QC flag set    |
| -------------------------------- | ------------------------------------------------- | -------------- |
| `01 fix_comma_decimals.sql`      | Replaces European `,` decimal separator with `.`  | `COMMA FIXED`  |
| `02 populate_numeric_values.sql` | Casts clean numeric strings to `NUMERIC_VALUE`    | `VALID NUMBER` |
| `03 fix_detection_limits.sql`    | Parses `<X` → stores `X / 2` as the numeric value | `HALF DETECT`  |
| `04 fix_bracketed_values.sql`    | Strips `[` `]` from values and casts to numeric   | `BRACKETS`     |
| `05 delete_placeholder_rows.sql` | Deletes dummy rows (`XXXX…`, `Column…`)           | — (deleted)    |

**R alternative:** `update_water_quality_db.R` performs the same logic as scripts 01–03 entirely in R using batched `UPDATE` statements via `DBI`, and may be preferable if you want to avoid the `sqlite3` CLI.

---

### Steps 10–12 — Build normalised sample and location tables

```sql
.read "10 create_INTERIM_SAMPLES.sql"
.read "11 create_INTERIM_LOCATIONS.sql"
.read "12 add_INTERIM_LOCATION_ID.sql"
```

| Script                            | What it does                                                                                                                                                                                |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `10 create_INTERIM_SAMPLES.sql`   | Creates **`INTERIM_SAMPLES`** — one row per sampling event; the first 32 metadata columns from `RAW_DATA`, with missing values standardised to `'MISSING'`                                  |
| `11 create_INTERIM_LOCATIONS.sql` | Creates **`INTERIM_LOCATIONS`** — one row per unique combination of the eight location-identifying columns; includes a `LOCATION_ID_TO_USE` column (default `−1`) for manual deduplication  |
| `12 add_INTERIM_LOCATION_ID.sql`  | Adds `INTERIM_LOCATION_ID` to `INTERIM_SAMPLES` by joining on all eight location fields; a verification query confirms no unmatched rows                                                    |

---

### Step 13 — Create SAMPLE_LOCATION_BACKBONE

```sql
.read "13 create_SAMPLE_LOCATION_BACKBONE.sql"
```

Creates **`SAMPLE_LOCATION_BACKBONE`** — a compact three-column cross-reference (`ROWID`, `INTERIM_LOCATION_ID`, `LOCATION_ID_TO_USE`) joining each sampling event to its resolved canonical location. Useful for downstream queries that need to respect the deduplication decisions recorded in `INTERIM_LOCATIONS`.

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

### Step 31 — Create STOICHIOMETRY_NITROGEN table

```sql
.read "31_create_STOICHIOMETRY_NITROGEN.sql"
```

Creates **`STOICHIOMETRY_NITROGEN`** — a wide-format (crosstab) staging table holding individual nitrogen fraction values per sampling event, pivoted from `vw_results_with_lookup` where `ELEMENT = 'NITROGEN'`. Used as the source for the DIN and total nitrogen views in steps 32–33.

| Column                         | Description                        |
| ------------------------------ | ---------------------------------- |
| `SOURCE_ROWID`                 | INTEGER (PK); links to `RAW_DATA`  |
| `DATESTAMP`                    | Date/time the row was populated    |
| `AMMONIUM_AS_N`                | NH4-N (µg/l N)                     |
| `NITRATE_AS_N`                 | NO3-N (µg/l N)                     |
| `NITRITE_AS_N`                 | NO2-N (µg/l N)                     |
| `ORGANIC_NITROGEN_AS_N`        | Org-N (µg/l N)                     |
| `TOTAL_KJELDAHL_NITROGEN_AS_N` | Kjeldahl-N (µg/l N)                |
| `TOTAL_NITROGEN`               | Tot-N (µg/l N)                     |

---

### Step 32 — Create vw_DIN view

```sql
.read "32_create_vw_DIN.sql"
```

Creates the view **`vw_DIN`** — calculates dissolved inorganic nitrogen (DIN) as N for each sampling event by summing available inorganic nitrogen fractions from `STOICHIOMETRY_NITROGEN`. The `COMPONENTS` column records which fractions were used.

| Case | Fractions used                    |
| ---- | --------------------------------- |
| 1    | NH4-N + NO2-N + NO3-N (all three) |
| 2    | NH4-N + NO3-N (NO2-N absent)      |
| 3    | NO3-N only                        |

Rows where `NITRATE_AS_N IS NULL` are excluded (no meaningful DIN can be computed).

---

### Step 33 — Create vw_total_n view

```sql
.read "33_create_vw_total_n.sql"
```

Creates the view **`vw_total_n`** — derives total nitrogen as N per sampling event from `STOICHIOMETRY_NITROGEN`, preferring a directly measured value and falling back through derived estimates.

| Case | Source                                        |
| ---- | --------------------------------------------- |
| 1    | `TOTAL_NITROGEN` directly                     |
| 2    | `TOTAL_KJELDAHL_NITROGEN_AS_N + NITRATE_AS_N` |
| 3    | `ORGANIC_NITROGEN_AS_N + DIN` (from `vw_DIN`) |

---

### Step 34 — Create COMPONENT_QC table

```sql
.read "34_create_COMPONENT_QC.sql"
```

Creates and populates **`COMPONENT_QC`** — a lookup table of the distinct `COMPONENTS` strings found across `vw_DIN` and `vw_total_n`. Each unique string receives a system-generated integer primary key (`COMPONENT_QC_ID`) used as a quality-control foreign key in `STOICHIOMETRY_INPUTS`.

| Column            | Type                        | Description                                      |
| ----------------- | --------------------------- | ------------------------------------------------ |
| `COMPONENT_QC_ID` | INTEGER (PK, AUTOINCREMENT) | System-generated primary key                     |
| `COMPONENTS`      | TEXT                        | Description of nitrogen fractions used           |
| `SOURCE_VIEW`     | TEXT                        | `vw_DIN`, `vw_total_n`, or `vw_DIN, vw_total_n` |

---

### Step 35 — Add DIN and DIN_QC to STOICHIOMETRY_INPUTS

```sql
.read "35_add_DIN_to_STOICHIOMETRY_INPUTS.sql"
```

Adds `DIN` (REAL) and `DIN_QC` (INTEGER) columns to `STOICHIOMETRY_INPUTS`, populating them from `vw_DIN` and `COMPONENT_QC` respectively. `DATESTAMP` is updated for all rows where a non-NULL DIN value was found.

---

### Step 36 — Add TOTAL_N and TOTAL_N_QC to STOICHIOMETRY_INPUTS

```sql
.read "36_add_TOTAL_N_to_STOICHIOMETRY_INPUTS.sql"
```

Adds `TOTAL_N` (REAL) and `TOTAL_N_QC` (INTEGER) columns to `STOICHIOMETRY_INPUTS`, populating them from `vw_total_n` and `COMPONENT_QC` respectively. `DATESTAMP` is updated for all rows where a non-NULL total nitrogen value was found.

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

| Column            | Type    | Description                                       |
| ----------------- | ------- | ------------------------------------------------- |
| `TUPLE_ID`        | INTEGER | FK → `DUPLICATE_CANDIDATES.TUPLE_ID`              |
| `SOURCE_ROWID`    | INTEGER | Individual sampling event identifier              |
| `N_SOURCE_ROWIDS` | INTEGER | Number of `SOURCE_ROWID`s in this duplicate group |
| `DATESTAMP`       | TEXT    | Date the query was run                            |

---

### Views

| View                                  | Description                                                                                                                                 |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `vw_results_with_lookup`              | Joins `RESULTS` to `PARAMETER_LOOKUP`, adding `NAME_TO_USE`, `SPECIES`, `ELEMENT`, `UNITS`, and `ELEMENT_MOLAR_MASS_G` to every result row |
| `vw_DIN`                              | Calculates DIN as N per sampling event from `STOICHIOMETRY_NITROGEN`; includes a `COMPONENTS` column describing which fractions were summed  |
| `vw_total_n`                          | Derives total nitrogen as N per sampling event; prefers measured value, falls back to derived estimates; includes `COMPONENTS` column        |
| `vw_source_rowid_stats`               | Aggregates `RESULTS` by `SOURCE_ROWID`, computing N, sum, mean, and population std dev of `NUMERIC_VALUE`                                   |
| `vw_duplicate_samples`                | Joins `DUPLICATE_SOURCE_ROWIDS` to `INTERIM_SAMPLES`, surfacing full metadata for each duplicate candidate group alongside `USE_SAMPLE`     |
| `vw_stoichiometry_inputs_deduped`     | Filtered version of `STOICHIOMETRY_INPUTS` excluding rows where `USE_SAMPLE = 'N'` in `DUPLICATE_SOURCE_ROWIDS`; clean input for analysis  |

---

### Indexes

| Index               | Table     | Column           |
| ------------------- | --------- | ---------------- |
| `idx_results_rowid` | `RESULTS` | `SOURCE_ROWID`   |
| `idx_results_param` | `RESULTS` | `PARAMETER_NAME` |

---

## Parameter name mapping

`PARAMETER_LOOKUP` maps the sanitised Swedish column headers from `RAW_DATA` to standardised English parameter codes and units. A representative sample of entries is shown below.

| Original column header  | `NAME_TO_USE`                  | Units |
| ----------------------- | ------------------------------ | ----- |
| `Tot-P (µg/l P)`        | `TOTAL_PHOSPHORUS`             | µg/l  |
| `Tot-N (µg/l N)`        | `TOTAL_NITROGEN`               | µg/l  |
| `NO2+NO3-N (µg/l N)`    | `NITRATE_AS_N`                 | µg/l  |
| `NH4-N (µg/l N)`        | `AMMONIUM_AS_N`                | µg/l  |
| `NO2-N (µg/l N)`        | `NITRITE_AS_N`                 | µg/l  |
| `Kjeld.-N (µg/l N)`     | `TOTAL_KJELDAHL_NITROGEN_AS_N` | µg/l  |
| `Org-N (µg/l N)`        | `ORGANIC_NITROGEN_AS_N`        | µg/l  |
| `Vattentemperatur (°C)` | `TEMPERATURE`                  | °C    |
| `Siktdjup (m)`          | `SECCHI`                       | m     |
| `pH`                    | `PH`                           | —     |

---

## Data source

The data originate from the **Swedish national freshwater monitoring programme** and are stored using the original Swedish column naming convention used by the data provider. All coordinates are in **SWEREF99TM (EPSG:3006)**, or are converted to that system during the pipeline (steps 21–22 handle legacy RT90 coordinates).
