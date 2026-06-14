# Water Quality Database Pipeline

An end-to-end pipeline for ingesting Swedish freshwater monitoring data from Excel, building a normalised SQLite database, quality-controlling measured values, and mapping sampling locations.

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
├── 25 create NAMES_TO_USE.sql                 # Step 25 – Create PARAMETER_LOOKUP from RESULTS
├── 26 create_RESULTS_view.sql                 # Step 26 – Create vw_results_with_lookup view
├── 30_create_STOICHIOMETRY_INPUTS.sql         # Step 30 – Create STOICHIOMETRY_INPUTS base table
├── 31_create_STOICHIOMETRY_NITROGEN.sql       # Step 31 – Create STOICHIOMETRY_NITROGEN wide table
│
├── map_interim_locations.R                    # Plot sampling locations on a map of Sweden
│
├── .gitignore
└── README.MD
```

> **Note:** `*.xlsx`, `*.db`, `*.db_journal`, and `plots/` are listed in `.gitignore` and are not committed to the repository.

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

```r
source("00_create_water_quality_db.R")
```

Reads `Short.xlsx` (all columns as text to preserve detection-limit strings such as `<0.5`), sanitises column names, and writes everything to a new SQLite database `water_quality.db` as the table **`RAW_DATA`**.

---

### Step 0b — Build the long-format RESULTS table

```sql
.read "00 create_results.sql"
```

Unpivots the 52 measurement columns of `RAW_DATA` into a long-format **`RESULTS`** table. Empty cells, `NA`, and `NAN` tokens are excluded. Indexes are created on `SOURCE_ROWID` and `PARAMETER_NAME`.

| Column | Description |
| --- | --- |
| `ID` | Auto-increment primary key |
| `SOURCE_ROWID` | Row in `RAW_DATA` this came from |
| `PARAMETER_NAME` | Sanitised column/parameter name |
| `TEXT_VALUE` | Raw cell value as stored |
| `NUMERIC_VALUE` | Parsed numeric value (populated by later steps) |
| `COMMENTS` | Audit notes (populated by later steps) |
| `QC` | Quality-control flag (populated by later steps) |

---

### Steps 1–5 — Quality-control the values

Run scripts **01 → 05** in order. Each targets only rows where `QC IS NULL`, so they are safe to re-run.

| Script | What it does | QC flag set |
| --- | --- | --- |
| `01 fix_comma_decimals.sql` | Replaces European `,` decimal separator with `.` | `COMMA FIXED` |
| `02 populate_numeric_values.sql` | Casts clean numeric strings to `NUMERIC_VALUE` | `VALID NUMBER` |
| `03 fix_detection_limits.sql` | Parses `<X` → stores `X / 2` as the numeric value | `HALF DETECT` |
| `04 fix_bracketed_values.sql` | Strips `[` `]` from values and casts to numeric | `BRACKETS` |
| `05 delete_placeholder_rows.sql` | Deletes dummy rows (`XXXX…`, `Column…`) | — (deleted) |

---

### Steps 10–12 — Build normalised sample and location tables

```sql
.read "10 create_INTERIM_SAMPLES.sql"
.read "11 create_INTERIM_LOCATIONS.sql"
.read "12 add_INTERIM_LOCATION_ID.sql"
```

| Script | What it does |
| --- | --- |
| `10 create_INTERIM_SAMPLES.sql` | Creates **`INTERIM_SAMPLES`** — one row per sampling event, first 32 metadata columns from `RAW_DATA`, missing values standardised to `'MISSING'` |
| `11 create_INTERIM_LOCATIONS.sql` | Creates **`INTERIM_LOCATIONS`** — one row per unique combination of the eight location-identifying columns; includes a `LOCATION_ID_TO_USE` column (default `−1`) for manual deduplication |
| `12 add_INTERIM_LOCATION_ID.sql` | Adds `INTERIM_LOCATION_ID` to `INTERIM_SAMPLES` by joining on all eight location fields; a verification query confirms no unmatched rows |

---

### Step 13 — Create SAMPLE_LOCATION_BACKBONE

```sql
.read "13 create_SAMPLE_LOCATION_BACKBONE.sql"
```

Creates **`SAMPLE_LOCATION_BACKBONE`** — a compact three-column cross-reference (`ROWID`, `INTERIM_LOCATION_ID`, `LOCATION_ID_TO_USE`) joining each sampling event to its resolved canonical location. Useful for downstream queries that need to respect the deduplication decisions recorded in `INTERIM_LOCATIONS`.

---

### Steps 14–17 — Populate missing depth values in INTERIM_SAMPLES

These four scripts fill `MIN_PROVDJUP_M` and `MAX_PROVDJUP_M` where both columns are still `'MISSING'`, working through available text fields in priority order. All are safe to run multiple times (each only acts where depths remain `'MISSING'`).

| Script | Source of depth | Method | Depth assigned |
| --- | --- | --- | --- |
| `14 update_depth_from_provkommentar.sql` | `PROVKOMMENTAR` free text | Locates first digit, extracts up to 10-char numeric window, strips non-numeric suffixes, normalises decimal comma | Extracted value |
| `15 update_depth_from_undersokningstyp.sql` | `UNDERSOKNINGSTYP` field | Same digit-extraction approach as script 14 | Extracted value |
| `16 update_depth_ytvatten.sql` | `UNDERSOKNINGSTYP = 'ytvatten'` | Fixed assignment | `1.0` m |
| `17 update_depth_botten.sql` | `UNDERSOKNINGSTYP = 'botten'` | Fixed assignment | `20.0` m |

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

```r
source("21_convert_rt90_to_sweref99.R")
```
```sql
.read "22_update_locations_from_rt90.sql"
```

#### `21_convert_rt90_to_sweref99.R`

Reads all rows from `LOCATIONS` where `KOORDINATSYSTEM` does not indicate SWEREF99, then:

1. Detects and fixes **truncated 6-digit coordinates** — RT90 coordinates are always 7 digits, so values with only 6 digits are missing their leading digit and are corrected by multiplying by 10 (eastings < 200,000; northings between 200,000 and 999,999).
2. Reprojects both station and provplats coordinate pairs from RT90 2.5 gon V (EPSG:3021) to SWEREF99TM (EPSG:3006) using the `sf` package.
3. Writes results to a new staging table **`RT90_TO_SWEREF99`** — the original `LOCATIONS` table is not modified at this stage.

The source CRS can be changed at the top of the script if a different RT90 variant is present.

#### `22_update_locations_from_rt90.sql`

Reads from `RT90_TO_SWEREF99` and updates `LOCATIONS` in place for all rows where station coordinates were successfully converted. Provplats coordinates are updated where available. Sets `KOORDINATSYSTEM = 'SWEREF99TM'` and `QC = 'coordinates from RT90'` on all updated rows. Includes a preview `SELECT` and two verification queries (row counts by QC/CRS, and any remaining non-SWEREF rows).

---

### Step 25 — Create PARAMETER_LOOKUP table

```sql
.read "25 create NAMES_TO_USE.sql"
```

Creates **`PARAMETER_LOOKUP`** — one row per distinct `PARAMETER_NAME` found in `RESULTS`, pre-populated from that table. The additional columns (`NAME_TO_USE`, `SPECIES`, `ELEMENT`, `UNITS`, `ELEMENT_MOLAR_MASS_G`) are intended for manual population to map sanitised parameter names to standardised codes, species, and units.

| Column | Type | Default | Description |
| --- | --- | --- | --- |
| `PARAMETER_NAME` | TEXT (PK) | — | Sanitised column name from `RESULTS` |
| `NAME_TO_USE` | TEXT | `'MISSING'` | Standardised parameter code |
| `SPECIES` | TEXT | `'MISSING'` | Chemical species |
| `ELEMENT` | TEXT | `'MISSING'` | Element name (e.g. `'NITROGEN'`, `'PHOSPHORUS'`) |
| `UNITS` | TEXT | `'UG/L'` | Measurement units |
| `ELEMENT_MOLAR_MASS_G` | REAL | `99.9` | Molar mass (g/mol) |

---

### Step 26 — Create results view

```sql
.read "26 create_RESULTS_view.sql"
```

Creates the view **`vw_results_with_lookup`** — a join of `RESULTS` to `PARAMETER_LOOKUP` on `PARAMETER_NAME`. The LEFT JOIN ensures all `RESULTS` rows are returned even where a `PARAMETER_NAME` has not yet been populated in `PARAMETER_LOOKUP`. Used as the source for downstream stoichiometry analysis.

---

### Steps 30–31 — N:P stoichiometry tables

```sql
.read "30_create_STOICHIOMETRY_INPUTS.sql"
.read "31_create_STOICHIOMETRY_NITROGEN.sql"
```

#### `30_create_STOICHIOMETRY_INPUTS.sql`

Creates **`STOICHIOMETRY_INPUTS`** — one row per `SOURCE_ROWID` that has a non-NULL `TOTAL_PHOSPHORUS` value, sourced from `vw_results_with_lookup`. Intended as the base table for N:P analysis, with additional nutrient columns to be joined in subsequent steps.

| Column | Type | Description |
| --- | --- | --- |
| `SOURCE_ROWID` | INTEGER (PK) | Sampling event identifier |
| `DATESTAMP` | TEXT | Datetime the table was populated |
| `TOTAL_PHOSPHORUS` | REAL | Total P value (µg/l) |

#### `31_create_STOICHIOMETRY_NITROGEN.sql`

Creates **`STOICHIOMETRY_NITROGEN`** — a wide-format (crosstab) table of nitrogen fractions for all `SOURCE_ROWID` values present in `STOICHIOMETRY_INPUTS`. Values are pivoted from `vw_results_with_lookup` using conditional aggregation on `NAME_TO_USE` where `ELEMENT = 'NITROGEN'`.

| Column | Type | Description |
| --- | --- | --- |
| `SOURCE_ROWID` | INTEGER (PK) | Sampling event identifier |
| `DATESTAMP` | TEXT | Datetime the table was populated |
| `AMMONIUM_AS_N` | REAL | NH₄-N (µg/l) |
| `NITRATE_AS_N` | REAL | NO₂+NO₃-N (µg/l) |
| `NITRITE_AS_N` | REAL | NO₂-N (µg/l) |
| `ORGANIC_NITROGEN_AS_N` | REAL | Org-N (µg/l) |
| `TOTAL_KJELDAHL_NITROGEN_AS_N` | REAL | Kjeldahl-N (µg/l) |
| `TOTAL_NITROGEN` | REAL | Tot-N (µg/l) |

---

### Visualisations

#### Map of sampling locations

```r
source("map_interim_locations.R")
# → plots/map_interim_locations.png
```

Reads `INTERIM_LOCATIONS` from the database, reprojects coordinates from **SWEREF99TM (EPSG:3006)** to **WGS84**, and plots sites on a base map of Sweden. Station labels are added automatically when ≤ 40 locations are present.

---

## Data source

The data originate from the **Swedish national freshwater monitoring programme** and are stored in the original Swedish column naming convention used by the data provider. All coordinates are in **SWEREF99TM (EPSG:3006)**.

---

## Database schema

### `RAW_DATA`

Staging table populated directly from `Short.xlsx`. All 84 columns stored as `TEXT`.

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

One row per sampling event; 32 metadata columns from `RAW_DATA` with missing values standardised to `'MISSING'`, plus `INTERIM_LOCATION_ID` (INTEGER) added by script 12.

### `INTERIM_LOCATIONS`

One row per unique sampling location.

| Column | Type |
| --- | --- |
| `LOCATION_ID` | INTEGER (PK, AUTOINCREMENT) |
| `LOCATION_ID_TO_USE` | INTEGER (default −1) |
| `OVERVAKNINGSSTATION` | TEXT |
| `STATIONSKOORDINAT_N_X` | TEXT |
| `STATIONSKOORDINAT_E_Y` | TEXT |
| `PROVPLATS` | TEXT |
| `PROVPLATSKOORDINAT_N_X` | TEXT |
| `PROVPLATSKOORDINAT_E_Y` | TEXT |
| `KOORDINATSYSTEM` | TEXT |
| `PROVTAGNINGSMEDIUM` | TEXT |

### `SAMPLE_LOCATION_BACKBONE`

Compact cross-reference between sampling events and their canonical location.

| Column | Type |
| --- | --- |
| `ROWID` | INTEGER (PK) |
| `INTERIM_LOCATION_ID` | INTEGER |
| `LOCATION_ID_TO_USE` | INTEGER |

### `LOCATIONS`

Final deduplicated location table; subset of `INTERIM_LOCATIONS` where `LOCATION_ID = LOCATION_ID_TO_USE`.

| Column | Type |
| --- | --- |
| `LOCATION_ID` | INTEGER (PK) |
| `OVERVAKNINGSSTATION` | TEXT |
| `STATIONSKOORDINAT_N_X` | INTEGER |
| `STATIONSKOORDINAT_E_Y` | INTEGER |
| `PROVPLATS` | TEXT |
| `PROVPLATSKOORDINAT_N_X` | INTEGER |
| `PROVPLATSKOORDINAT_E_Y` | INTEGER |
| `KOORDINATSYSTEM` | TEXT |
| `PROVTAGNINGSMEDIUM` | TEXT |
| `QC` | TEXT |

### `RT90_TO_SWEREF99`

Staging table of reprojected coordinates produced by `21_convert_rt90_to_sweref99.R`.

| Column | Type |
| --- | --- |
| `LOCATION_ID` | INTEGER |
| `ORIGINAL_KOORDINATSYSTEM` | TEXT |
| `ORIGINAL_STATIONSKOORDINAT_N_X` | TEXT |
| `ORIGINAL_STATIONSKOORDINAT_E_Y` | TEXT |
| `ORIGINAL_PROVPLATSKOORDINAT_N_X` | TEXT |
| `ORIGINAL_PROVPLATSKOORDINAT_E_Y` | TEXT |
| `EASTING_TRUNCATION_FIXED` | INTEGER (0/1) |
| `NORTHING_TRUNCATION_FIXED` | INTEGER (0/1) |
| `SWEREF99TM_STATIONSKOORDINAT_N` | REAL |
| `SWEREF99TM_STATIONSKOORDINAT_E` | REAL |
| `SWEREF99TM_PROVPLATSKOORDINAT_N` | REAL |
| `SWEREF99TM_PROVPLATSKOORDINAT_E` | REAL |
| `SOURCE_CRS` | INTEGER |
| `TARGET_CRS` | INTEGER |
| `CONVERSION_DATE` | TEXT |

### `PARAMETER_LOOKUP`

Parameter name mapping table populated by step 25 and manually extended.

| Column | Type |
| --- | --- |
| `PARAMETER_NAME` | TEXT (PK) |
| `NAME_TO_USE` | TEXT |
| `SPECIES` | TEXT |
| `ELEMENT` | TEXT |
| `UNITS` | TEXT |
| `ELEMENT_MOLAR_MASS_G` | REAL |

### `vw_results_with_lookup` (view)

Join of `RESULTS` to `PARAMETER_LOOKUP`. All `RESULTS` columns plus `NAME_TO_USE`, `SPECIES`, `ELEMENT`, `UNITS`, and `ELEMENT_MOLAR_MASS_G` from `PARAMETER_LOOKUP`.

### `STOICHIOMETRY_INPUTS`

Base table for N:P stoichiometry analysis; one row per `SOURCE_ROWID` with a non-NULL Total P value.

| Column | Type |
| --- | --- |
| `SOURCE_ROWID` | INTEGER (PK) |
| `DATESTAMP` | TEXT |
| `TOTAL_PHOSPHORUS` | REAL |

### `STOICHIOMETRY_NITROGEN`

Wide-format nitrogen fractions table; one row per `SOURCE_ROWID` in `STOICHIOMETRY_INPUTS`.

| Column | Type |
| --- | --- |
| `SOURCE_ROWID` | INTEGER (PK) |
| `DATESTAMP` | TEXT |
| `AMMONIUM_AS_N` | REAL |
| `NITRATE_AS_N` | REAL |
| `NITRITE_AS_N` | REAL |
| `ORGANIC_NITROGEN_AS_N` | REAL |
| `TOTAL_KJELDAHL_NITROGEN_AS_N` | REAL |
| `TOTAL_NITROGEN` | REAL |

### Indexes

| Index | Table | Column |
| --- | --- | --- |
| `idx_results_param` | `RESULTS` | `PARAMETER_NAME` |
| `idx_results_rowid` | `RESULTS` | `SOURCE_ROWID` |
