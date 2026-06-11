# Water Quality Database Pipeline

An end-to-end pipeline for ingesting Swedish freshwater monitoring data from Excel, building a normalised SQLite database, quality-controlling measured values, and mapping sampling locations.

---

## Repository structure

```
.
├── 00_create_water_quality_db.R           # Step 0  – Read Excel, create SQLite DB & RAW_DATA table
├── 00 create_results.sql                  # Step 0b – Unpivot RAW_DATA → long-format RESULTS table
├── 01 fix_comma_decimals.sql              # Step 1  – Fix European decimal commas in RESULTS
├── 02 populate_numeric_values.sql         # Step 2  – Cast TEXT_VALUE → NUMERIC_VALUE where valid
├── 03 fix_detection_limits.sql            # Step 3  – Handle below-detection-limit values (<X → X/2)
├── 04 fix_bracketed_values.sql            # Step 4  – Strip brackets from values (e.g. [0.5] → 0.5)
├── 05 delete_placeholder_rows.sql         # Step 5  – Delete dummy/artefact rows (XXXX, Column…)
├── 10 create_INTERIM_SAMPLES.sql          # Step 10 – Create normalised INTERIM_SAMPLES table
├── 11 create_INTERIM_LOCATIONS.sql        # Step 11 – Extract unique sampling locations
├── 12 add_INTERIM_LOCATION_ID.sql         # Step 12 – Link samples back to locations
├── 13 create_SAMPLE_LOCATION_BACKBONE.sql # Step 13 – Compact sample↔location cross-reference
├── 14 update_depth_from_provkommentar.sql # Step 14 – Extract depth from PROVKOMMENTAR free text
├── 15 update_depth_from_undersokningstyp.sql # Step 15 – Extract depth from UNDERSOKNINGSTYP
├── 16 update_depth_ytvatten.sql           # Step 16 – Assign default depth for 'ytvatten' samples
├── 17 update_depth_botten.sql             # Step 17 – Assign default depth for 'botten' samples
├── 20 create_LOCATIONS.sql                # Step 20 – Create final deduplicated LOCATIONS table
│
├── map_interim_locations.R                # Plot sampling locations on a map of Sweden
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

### Steps 1–5 — Quality-control the values (SQL route)

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

### Visualisations

#### Map of sampling locations

```r
source("map_interim_locations.R")
# → plots/map_interim_locations.png
```

Reads `INTERIM_LOCATIONS` from the database, reprojects coordinates from **SWEREF99TM (EPSG:3006)** to **WGS84**, and plots sites on a base map of Sweden. Station labels are added automatically when ≤ 40 locations are present.

---

## Parameter name mapping

`names_to_use.csv` maps original Swedish column headers to standardised English parameter codes and units. Useful reference when querying `RESULTS` by `PARAMETER_NAME`.

| Original name | Standardised name | Units |
| --- | --- | --- |
| `Tot-P (µg/l P)` | `TOTP-P` | µg/l |
| `Tot-N (µg/l N)` | `TOTN-N` | µg/l |
| `NO2+NO3-N (µg/l N)` | `NO3-N` | µg/l |
| `Vattentemperatur (°C)` | `TEMPERATURE` | °C |
| `Siktdjup (m)` | `SECCHI` | m |
| `pH` | `PH` | — |

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

### Indexes

| Index | Table | Column |
| --- | --- | --- |
| `idx_results_param` | `RESULTS` | `PARAMETER_NAME` |
| `idx_results_rowid` | `RESULTS` | `SOURCE_ROWID` |
