# Water Quality Database Pipeline

An end-to-end pipeline for ingesting Swedish freshwater monitoring data from Excel, building a normalised SQLite database, quality-controlling measured values, and producing N:P stoichiometry plots.

---

## Repository structure

```
.
├── 00_create_water_quality_db.R               # Step 0  – Read Excel, create SQLite DB & RAW_DATA table
├── 00 create_results.sql                      # Step 0b – Unpivot RAW_DATA → long-format RESULTS table
├── 01 fix_comma_decimals.sql                  # Step 1  – Fix European decimal commas in RESULTS
├── 02 populate_numeric_values.sql             # Step 2  – Cast TEXT_VALUE → NUMERIC_VALUE where valid
├── 03 fix_detection_limits.sql                # Step 3  – Handle below-detection-limit values (<X → X/2)
├── 04 fix_bracketed_values.sql                # Step 4  – Strip brackets from values (e.g. [0.5] → 0.5)
├── 05 delete_placeholder_rows.sql             # Step 5  – Delete dummy/artefact rows (XXXX, Column…)
├── 10 create_INTERIM_SAMPLES.sql              # Step 10 – Create normalised INTERIM_SAMPLES table
├── 11 create_INTERIM_LOCATIONS.sql            # Step 11 – Extract unique sampling locations
├── 12 add_INTERIM_LOCATION_ID.sql             # Step 12 – Link samples back to locations
├── 13 create_SAMPLE_LOCATION_BACKBONE.sql     # Step 13 – Compact sample↔location cross-reference
├── 14 update_depth_from_provkommentar.sql     # Step 14 – Extract depth from PROVKOMMENTAR free text
├── 15 update_depth_from_undersokningstyp.sql  # Step 15 – Extract depth from UNDERSOKNINGSTYP
├── 16 update_depth_ytvatten.sql               # Step 16 – Assign default depth for 'ytvatten' samples
├── 17 update_depth_botten.sql                 # Step 17 – Assign default depth for 'botten' samples
├── 20 create_LOCATIONS.sql                    # Step 20 – Create final deduplicated LOCATIONS table
├── 21_convert_rt90_to_sweref99.R              # Step 21 – Convert RT90 coordinates to SWEREF99TM
├── 22_update_locations_from_rt90.sql          # Step 22 – Write converted coordinates back to LOCATIONS
├── 25 create_NAMES_TO_USE.sql                 # Step 25 – Create parameter name lookup table
├── 26 create_RESULTS_view.sql                 # Step 26 – Create vw_results_with_lookup view
├── 30_create_STOICHIOMETRY_INPUTS.sql         # Step 30 – Create STOICHIOMETRY_INPUTS table
├── 31_create_STOICHIOMETRY_NITROGEN.sql       # Step 31 – Create STOICHIOMETRY_NITROGEN table
├── 32_create_vw_DIN.sql                       # Step 32 – Create vw_DIN view
├── 33_create_vw_total_n.sql                   # Step 33 – Create vw_total_n view
├── 34_create_COMPONENT_QC.sql                 # Step 34 – Create and populate COMPONENT_QC table
├── 35_add_DIN_to_STOICHIOMETRY_INPUTS.sql     # Step 35 – Add DIN and DIN_QC columns
├── 36_add_TOTAL_N_to_STOICHIOMETRY_INPUTS.sql # Step 36 – Add TOTAL_N and TOTAL_N_QC columns
│
├── map_interim_locations.R                    # Plot sampling locations on a map of Sweden
│
├── .gitignore
└── README.MD
```

> **Note:** `Short.xlsx`, `*.db`, and `plots/` are listed in `.gitignore` and are not committed to the repository.

---

## Prerequisites

### R packages

```r
install.packages(c(
  "readxl",                              # reading Excel
  "DBI", "RSQLite",                      # database access
  "ggplot2", "patchwork", "scales",      # plotting
  "sf",                                  # spatial reprojection (map script)
  "rnaturalearth", "rnaturalearthdata",  # Sweden base map
  "ggrepel"                              # non-overlapping map labels
))
```

### SQLite

SQL scripts are written for **SQLite 3**. Run them with the `sqlite3` command-line tool or from within R via `DBI::dbExecute()`.

---

## Pipeline walkthrough

### Step 0 — Create the database

```
source("00_create_water_quality_db.R")
```

Reads `Short.xlsx` (all columns as text to preserve detection-limit strings such as `<0.5`), sanitises column names, and writes everything to a new SQLite database `water_quality.db` as the table **`RAW_DATA`**.

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

| Script                           | What it does                                       | QC flag set    |
| -------------------------------- | -------------------------------------------------- | -------------- |
| `01 fix_comma_decimals.sql`      | Replaces European `,` decimal separator with `.`   | `COMMA FIXED`  |
| `02 populate_numeric_values.sql` | Casts clean numeric strings to `NUMERIC_VALUE`     | `VALID NUMBER` |
| `03 fix_detection_limits.sql`    | Parses `<X` → stores `X / 2` as the numeric value  | `HALF DETECT`  |
| `04 fix_bracketed_values.sql`    | Strips `[` `]` from values and casts to numeric    | `BRACKETS`     |
| `05 delete_placeholder_rows.sql` | Deletes dummy rows (`XXXX…`, `Column…`)            | — (deleted)    |

---

### Steps 10–12 — Build normalised sample and location tables

```sql
.read "10 create_INTERIM_SAMPLES.sql"
.read "11 create_INTERIM_LOCATIONS.sql"
.read "12 add_INTERIM_LOCATION_ID.sql"
```

| Script                            | What it does                                                                                                                                                                               |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `10 create_INTERIM_SAMPLES.sql`   | Creates **`INTERIM_SAMPLES`** — one row per sampling event, first 32 metadata columns from `RAW_DATA`, missing values standardised to `'MISSING'`                                          |
| `11 create_INTERIM_LOCATIONS.sql` | Creates **`INTERIM_LOCATIONS`** — one row per unique combination of the eight location-identifying columns; includes a `LOCATION_ID_TO_USE` column (default `−1`) for manual deduplication |
| `12 add_INTERIM_LOCATION_ID.sql`  | Adds `INTERIM_LOCATION_ID` to `INTERIM_SAMPLES` by joining on all eight location fields; a verification query confirms no unmatched rows                                                   |

---

### Step 13 — Create SAMPLE_LOCATION_BACKBONE

```sql
.read "13 create_SAMPLE_LOCATION_BACKBONE.sql"
```

Creates **`SAMPLE_LOCATION_BACKBONE`** — a compact three-column cross-reference (`ROWID`, `INTERIM_LOCATION_ID`, `LOCATION_ID_TO_USE`) joining each sampling event to its resolved canonical location. Useful for downstream queries that need to respect the deduplication decisions recorded in `INTERIM_LOCATIONS`.

---

### Steps 14–17 — Populate missing depth values in INTERIM_SAMPLES

These four scripts fill `MIN_PROVDJUP_M` and `MAX_PROVDJUP_M` where both columns are still `'MISSING'`, working through available text fields in priority order. All are safe to run multiple times.

| Script                                      | Source of depth                 | Method                                                                                                            | Depth assigned  |
| ------------------------------------------- | ------------------------------- | ----------------------------------------------------------------------------------------------------------------- | --------------- |
| `14 update_depth_from_provkommentar.sql`    | `PROVKOMMENTAR` free text       | Locates first digit, extracts up to 10-char numeric window, strips non-numeric suffixes, normalises decimal comma | Extracted value |
| `15 update_depth_from_undersokningstyp.sql` | `UNDERSOKNINGSTYP` field        | Same digit-extraction approach as script 14                                                                       | Extracted value |
| `16 update_depth_ytvatten.sql`              | `UNDERSOKNINGSTYP = 'ytvatten'` | Fixed assignment                                                                                                  | `1.0` m         |
| `17 update_depth_botten.sql`                | `UNDERSOKNINGSTYP = 'botten'`   | Fixed assignment                                                                                                  | `20.0` m        |

Each script appends a note to `PROVKOMMENTAR` recording how the depth was derived, and includes a preview `SELECT` so you can inspect affected rows before the `UPDATE` runs.

---

### Step 20 — Create final LOCATIONS table

```sql
.read "20 create_LOCATIONS.sql"
```

Creates **`LOCATIONS`** from `INTERIM_LOCATIONS`, retaining only rows where `LOCATION_ID = LOCATION_ID_TO_USE` (i.e. the canonical representative of each location group after deduplication). Coordinate columns are cast from `TEXT` to `INTEGER`. A `QC` column is included for future annotation.

---

### Steps 21–22 — Convert legacy RT90 coordinates to SWEREF99TM

Some locations in `LOCATIONS` may have coordinates stored in the older **RT90 2.5 gon V** system (EPSG:3021) rather than SWEREF99TM. These two scripts identify and reproject those locations.

```
source("21_convert_rt90_to_sweref99.R")
```
```sql
.read "22_update_locations_from_rt90.sql"
```

#### `21_convert_rt90_to_sweref99.R`

Reads all rows from `LOCATIONS` where `KOORDINATSYSTEM` does not indicate SWEREF99, then:

1. Detects and fixes **truncated 6-digit coordinates** — RT90 coordinates are always 7 digits, so values with only 6 digits are missing their leading digit and are corrected by multiplying by 10.
2. Reprojects both station and provplats coordinate pairs from RT90 2.5 gon V (EPSG:3021) to SWEREF99TM (EPSG:3006) using the `sf` package.
3. Writes results to a new staging table **`RT90_TO_SWEREF99`** — the original `LOCATIONS` table is not modified at this stage.

#### `22_update_locations_from_rt90.sql`

Reads from `RT90_TO_SWEREF99` and updates `LOCATIONS` in place for all rows where station coordinates were successfully converted. Sets `KOORDINATSYSTEM = 'SWEREF99TM'` and `QC = 'coordinates from RT90'` on all updated rows.

---

### Step 25 — Create NAMES_TO_USE lookup table

```sql
.read "25 create_NAMES_TO_USE.sql"
```

Creates **`NAMES_TO_USE`** — a lookup table mapping the sanitised `PARAMETER_NAME` values in `RESULTS` to standardised English parameter codes and units. Used by the view created in step 26.

| Column              | Description                              |
| ------------------- | ---------------------------------------- |
| `NAMES_TO_USE_ID`   | Auto-increment primary key               |
| `PARAMETER_NAME`    | Sanitised name as it appears in RESULTS  |
| `STANDARD_NAME`     | Standardised English parameter code      |
| `UNITS`             | Units of measurement                     |

---

### Step 26 — Create vw_results_with_lookup view

```sql
.read "26 create_RESULTS_view.sql"
```

Creates the view **`vw_results_with_lookup`** — joins `RESULTS` to `NAMES_TO_USE` on `PARAMETER_NAME`, providing `STANDARD_NAME` and `UNITS` alongside all `RESULTS` columns for convenient querying without needing to write the join manually each time.

---

### Step 30 — Create STOICHIOMETRY_INPUTS table

```sql
.read "30_create_STOICHIOMETRY_INPUTS.sql"
```

Creates **`STOICHIOMETRY_INPUTS`** — one row per sampling event, drawing metadata from `INTERIM_SAMPLES` and providing columns for the nutrient values needed for N:P stoichiometry calculations. Includes a `DATESTAMP` column that is updated as values are populated in subsequent steps.

| Column                  | Type                        | Description                                      |
| ----------------------- | --------------------------- | ------------------------------------------------ |
| `STOICHIOMETRY_ID`      | INTEGER (PK, AUTOINCREMENT) | System-generated primary key                     |
| `SOURCE_ROWID`          | INTEGER                     | Links to `RAW_DATA` and `RESULTS`                |
| `DATESTAMP`             | TEXT                        | Date/time the row was last updated               |
| `TOTAL_PHOSPHORUS`      | REAL                        | Total phosphorus (µg/l P)                        |
| `TOTAL_PHOSPHORUS_QC`   | INTEGER                     | FK to `COMPONENT_QC.COMPONENT_QC_ID`             |
| `DIN`                   | REAL                        | Dissolved inorganic nitrogen (µg/l N)            |
| `DIN_QC`                | INTEGER                     | FK to `COMPONENT_QC.COMPONENT_QC_ID`             |
| `TOTAL_N`               | REAL                        | Total nitrogen (µg/l N)                          |
| `TOTAL_N_QC`            | INTEGER                     | FK to `COMPONENT_QC.COMPONENT_QC_ID`             |

---

### Step 31 — Create STOICHIOMETRY_NITROGEN table

```sql
.read "31_create_STOICHIOMETRY_NITROGEN.sql"
```

Creates **`STOICHIOMETRY_NITROGEN`** — a staging table holding the individual nitrogen-fraction values (e.g. nitrate, nitrite, ammonium, total nitrogen) extracted from `vw_results_with_lookup` for each sampling event. Used as the source for the DIN and total nitrogen views in steps 32–33.

---

### Step 32 — Create vw_DIN view

```sql
.read "32_create_vw_DIN.sql"
```

Creates the view **`vw_DIN`** — calculates dissolved inorganic nitrogen (DIN) as N for each sampling event by summing the available inorganic nitrogen fractions from `STOICHIOMETRY_NITROGEN`. Includes a `COMPONENTS` column describing which fractions were available and used in the calculation (e.g. `NO3-N + NO2-N + NH4-N`).

| Column         | Description                                          |
| -------------- | ---------------------------------------------------- |
| `SOURCE_ROWID` | Links to `RAW_DATA`                                  |
| `DIN_AS_N`     | Calculated DIN value (µg/l N)                        |
| `COMPONENTS`   | Description of nitrogen fractions used in calculation |

---

### Step 33 — Create vw_total_n view

```sql
.read "33_create_vw_total_n.sql"
```

Creates the view **`vw_total_n`** — derives total nitrogen as N for each sampling event from `STOICHIOMETRY_NITROGEN`, preferring a directly measured total nitrogen value where available, and falling back to DIN (from `vw_DIN`) where it is not. Includes a `COMPONENTS` column describing the source of the value.

| Column              | Description                                        |
| ------------------- | -------------------------------------------------- |
| `SOURCE_ROWID`      | Links to `RAW_DATA`                                |
| `TOTAL_NITROGEN_AS_N` | Total nitrogen value (µg/l N)                    |
| `COMPONENTS`        | Description of the source used for the calculation |

---

### Step 34 — Create COMPONENT_QC table

```sql
.read "34_create_COMPONENT_QC.sql"
```

Creates and populates **`COMPONENT_QC`** — a lookup table of the distinct `COMPONENTS` strings found across `vw_DIN` and `vw_total_n`. Each unique string receives a system-generated integer primary key (`COMPONENT_QC_ID`) which is used as a quality-control foreign key in `STOICHIOMETRY_INPUTS`. A `SOURCE_VIEW` column records which view(s) the components string originated from.

| Column             | Type                        | Description                                          |
| ------------------ | --------------------------- | ---------------------------------------------------- |
| `COMPONENT_QC_ID`  | INTEGER (PK, AUTOINCREMENT) | System-generated primary key                         |
| `COMPONENTS`       | TEXT                        | Description of nitrogen fractions used               |
| `SOURCE_VIEW`      | TEXT                        | `vw_DIN`, `vw_total_n`, or `vw_DIN, vw_total_n`     |

---

### Step 35 — Add DIN and DIN_QC to STOICHIOMETRY_INPUTS

```sql
.read "35_add_DIN_to_STOICHIOMETRY_INPUTS.sql"
```

Adds two columns to `STOICHIOMETRY_INPUTS` and populates them from `vw_DIN` and `COMPONENT_QC`:

- **`DIN`** (REAL) — populated with `vw_DIN.DIN_AS_N` where `vw_DIN.SOURCE_ROWID = STOICHIOMETRY_INPUTS.SOURCE_ROWID`
- **`DIN_QC`** (INTEGER) — populated with `COMPONENT_QC.COMPONENT_QC_ID` where `COMPONENT_QC.COMPONENTS = vw_DIN.COMPONENTS`

`DATESTAMP` is updated to the time the query was run for all rows where a non-NULL `DIN` value was found. Rows with no match in `vw_DIN` are left unchanged.

---

### Step 36 — Add TOTAL_N and TOTAL_N_QC to STOICHIOMETRY_INPUTS

```sql
.read "36_add_TOTAL_N_to_STOICHIOMETRY_INPUTS.sql"
```

Adds two columns to `STOICHIOMETRY_INPUTS` and populates them from `vw_total_n` and `COMPONENT_QC`:

- **`TOTAL_N`** (REAL) — populated with `vw_total_n.TOTAL_NITROGEN_AS_N` where `vw_total_n.SOURCE_ROWID = STOICHIOMETRY_INPUTS.SOURCE_ROWID`
- **`TOTAL_N_QC`** (INTEGER) — populated with `COMPONENT_QC.COMPONENT_QC_ID` where `COMPONENT_QC.COMPONENTS = vw_total_n.COMPONENTS`

`DATESTAMP` is updated to the time the query was run for all rows where a non-NULL `TOTAL_N` value was found. Rows with no match in `vw_total_n` are left unchanged.

---

## Visualisations

### Map of sampling locations

```
source("map_interim_locations.R")
# → plots/map_interim_locations.png
```

Reads `INTERIM_LOCATIONS` from the database, reprojects coordinates from **SWEREF99TM (EPSG:3006)** to **WGS84**, and plots sites on a base map of Sweden. Station labels are added automatically when ≤ 40 locations are present.

---

## Parameter name mapping

`names_to_use.csv` maps original Swedish column headers to standardised English parameter codes and units. Useful reference when querying `RESULTS` by `PARAMETER_NAME`.

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

---

## Database schema

### `RAW_DATA`

Staging table populated directly from `Short.xlsx`. All 84 columns stored as `TEXT`.

---

### `RESULTS`

Long-format table unpivoted from `RAW_DATA`.

| Column           | Type                        |
| ---------------- | --------------------------- |
| `ID`             | INTEGER (PK, AUTOINCREMENT) |
| `SOURCE_ROWID`   | INTEGER                     |
| `PARAMETER_NAME` | TEXT                        |
| `TEXT_VALUE`     | TEXT                        |
| `NUMERIC_VALUE`  | REAL                        |
| `COMMENTS`       | TEXT                        |
| `QC`             | TEXT                        |

---

### `INTERIM_SAMPLES`

One row per sampling event; 32 metadata columns from `RAW_DATA` with missing values standardised to `'MISSING'`, plus `INTERIM_LOCATION_ID` (INTEGER) added by script 12.

---

### `INTERIM_LOCATIONS`

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

### `SAMPLE_LOCATION_BACKBONE`

Compact cross-reference between sampling events and their canonical location.

| Column                | Type         |
| --------------------- | ------------ |
| `ROWID`               | INTEGER (PK) |
| `INTERIM_LOCATION_ID` | INTEGER      |
| `LOCATION_ID_TO_USE`  | INTEGER      |

---

### `LOCATIONS`

Final deduplicated location table; subset of `INTERIM_LOCATIONS` where `LOCATION_ID = LOCATION_ID_TO_USE`.

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

### `RT90_TO_SWEREF99`

Staging table of reprojected coordinates produced by `21_convert_rt90_to_sweref99.R`.

| Column                            | Type          |
| --------------------------------- | ------------- |
| `LOCATION_ID`                     | INTEGER       |
| `ORIGINAL_KOORDINATSYSTEM`        | TEXT          |
| `ORIGINAL_STATIONSKOORDINAT_N_X`  | TEXT          |
| `ORIGINAL_STATIONSKOORDINAT_E_Y`  | TEXT          |
| `ORIGINAL_PROVPLATSKOORDINAT_N_X` | TEXT          |
| `ORIGINAL_PROVPLATSKOORDINAT_E_Y` | TEXT          |
| `EASTING_TRUNCATION_FIXED`        | INTEGER (0/1) |
| `NORTHING_TRUNCATION_FIXED`       | INTEGER (0/1) |
| `SWEREF99TM_STATIONSKOORDINAT_N`  | REAL          |
| `SWEREF99TM_STATIONSKOORDINAT_E`  | REAL          |
| `SWEREF99TM_PROVPLATSKOORDINAT_N` | REAL          |
| `SWEREF99TM_PROVPLATSKOORDINAT_E` | REAL          |
| `SOURCE_CRS`                      | INTEGER       |
| `TARGET_CRS`                      | INTEGER       |
| `CONVERSION_DATE`                 | TEXT          |

---

### `NAMES_TO_USE`

Parameter name lookup table linking `RESULTS.PARAMETER_NAME` to standardised codes and units.

| Column            | Type                        |
| ----------------- | --------------------------- |
| `NAMES_TO_USE_ID` | INTEGER (PK, AUTOINCREMENT) |
| `PARAMETER_NAME`  | TEXT                        |
| `STANDARD_NAME`   | TEXT                        |
| `UNITS`           | TEXT                        |

---

### `STOICHIOMETRY_NITROGEN`

Staging table of individual nitrogen fraction values per sampling event, used as the source for `vw_DIN` and `vw_total_n`.

---

### `STOICHIOMETRY_INPUTS`

One row per sampling event; holds nutrient values for N:P stoichiometry calculations.

| Column                | Type                        | Description                              |
| --------------------- | --------------------------- | ---------------------------------------- |
| `STOICHIOMETRY_ID`    | INTEGER (PK, AUTOINCREMENT) | System-generated primary key             |
| `SOURCE_ROWID`        | INTEGER                     | Links to `RAW_DATA` and `RESULTS`        |
| `DATESTAMP`           | TEXT                        | Date/time the row was last updated       |
| `TOTAL_PHOSPHORUS`    | REAL                        | Total phosphorus (µg/l P)                |
| `TOTAL_PHOSPHORUS_QC` | INTEGER                     | FK to `COMPONENT_QC.COMPONENT_QC_ID`    |
| `DIN`                 | REAL                        | Dissolved inorganic nitrogen (µg/l N)    |
| `DIN_QC`              | INTEGER                     | FK to `COMPONENT_QC.COMPONENT_QC_ID`    |
| `TOTAL_N`             | REAL                        | Total nitrogen (µg/l N)                  |
| `TOTAL_N_QC`          | INTEGER                     | FK to `COMPONENT_QC.COMPONENT_QC_ID`    |

---

### `COMPONENT_QC`

Lookup table of distinct nitrogen component combinations used in stoichiometry calculations.

| Column            | Type                        | Description                                      |
| ----------------- | --------------------------- | ------------------------------------------------ |
| `COMPONENT_QC_ID` | INTEGER (PK, AUTOINCREMENT) | System-generated primary key                     |
| `COMPONENTS`      | TEXT                        | Description of nitrogen fractions used           |
| `SOURCE_VIEW`     | TEXT                        | `vw_DIN`, `vw_total_n`, or `vw_DIN, vw_total_n` |

---

### Views

| View                     | Description                                                                                          |
| ------------------------ | ---------------------------------------------------------------------------------------------------- |
| `vw_results_with_lookup` | Joins `RESULTS` to `NAMES_TO_USE`, adding `STANDARD_NAME` and `UNITS` to each row                   |
| `vw_DIN`                 | Calculates DIN as N per sampling event from `STOICHIOMETRY_NITROGEN`; includes `COMPONENTS` column  |
| `vw_total_n`             | Derives total nitrogen as N per sampling event; prefers measured value, falls back to DIN            |

---

### Indexes

| Index               | Table     | Column           |
| ------------------- | --------- | ---------------- |
| `idx_results_param` | `RESULTS` | `PARAMETER_NAME` |
| `idx_results_rowid` | `RESULTS` | `SOURCE_ROWID`   |
