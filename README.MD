# Water Quality Database Pipeline

An end-to-end pipeline for ingesting Swedish freshwater monitoring data from Excel, building a normalised SQLite database, quality-controlling measured values, and producing N:P stoichiometry plots.

---

## Repository structure

```
.
├── Short.xlsx                        # Source data (Excel, all columns read as text)
├── Water_quality_rawdata_short.csv   # Short CSV extract of raw data (reference)
├── columns.csv                       # List of measurement column names
├── rowid.csv                         # Row-ID / header reference file
├── names_to_use.csv                  # Mapping: original Swedish names → standard names + units
├── short_NP_STOICHIOMETRY.csv        # Pre-computed N:P stoichiometry output (sample)
│
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
│
├── update_water_quality_db.R         # R alternative to SQL steps 1–3 (batch UPDATE via DBI)
├── map_interim_locations.R           # Plot sampling locations on a map of Sweden
├── plot_NP_final.R                   # Produce N:P stoichiometry 2×2 plot
│
├── .gitignore
└── README.md
```

> **Note:** `Short.xlsx`, `*.db`, and `plots/` are listed in `.gitignore` and are not committed to the repository.

---

## Prerequisites

### R packages

```r
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

```r
source("00_create_water_quality_db.R")
```

Reads `Short.xlsx` (all columns as text to preserve detection-limit strings such as `<0.5`), sanitises column names, and writes everything to a new SQLite database `water_quality.db` as the table **`RAW_DATA`**.

---

### 2 — Build the long-format RESULTS table

```sql
-- in sqlite3 or via DBI
.read "00 create_results.sql"
```

Unpivots the 52 measurement columns of `RAW_DATA` into a long-format **`RESULTS`** table with columns:

| Column | Description |
|---|---|
| `ID` | Auto-increment primary key |
| `SOURCE_ROWID` | Row in `RAW_DATA` this came from |
| `PARAMETER_NAME` | Sanitised column/parameter name |
| `TEXT_VALUE` | Raw cell value as stored |
| `NUMERIC_VALUE` | Parsed numeric value (populated later) |
| `COMMENTS` | Audit notes (populated later) |
| `QC` | Quality-control flag (populated later) |

Empty cells, `NA`, and `NAN` tokens are excluded at this stage.

---

### 3 — Quality-control the values (SQL route)

Run scripts **01 → 05** in order. Each script targets only rows where `QC IS NULL`, so they are safe to re-run and are order-independent within their scope.

| Script | What it does | QC flag set |
|---|---|---|
| `01 fix_comma_decimals.sql` | Replaces European `,` decimal separator with `.` | `COMMA FIXED` |
| `02 populate_numeric_values.sql` | Casts clean numeric strings to `NUMERIC_VALUE` | `VALID NUMBER` |
| `03 fix_detection_limits.sql` | Parses `<X` → stores `X / 2` as the numeric value | `HALF DETECT` |
| `04 fix_bracketed_values.sql` | Strips `[` `]` from values and casts to numeric | `BRACKETS` |
| `05 delete_placeholder_rows.sql` | Deletes dummy rows (`XXXX…`, `Column…`) | — (deleted) |

**R alternative:** `update_water_quality_db.R` performs the same logic as scripts 01–03 entirely in R using batched `UPDATE` statements via `DBI`, and may be preferable if you want to avoid the `sqlite3` CLI.

---

### 4 — Build normalised sample and location tables

```sql
.read "10 create_INTERIM_SAMPLES.sql"
.read "11 create_INTERIM_LOCATIONS.sql"
.read "12 add_INTERIM_LOCATION_ID.sql"
```

| Table | Description |
|---|---|
| `INTERIM_SAMPLES` | One row per sampling event; the first 32 metadata columns from `RAW_DATA`, with missing values standardised to `'MISSING'` |
| `INTERIM_LOCATIONS` | One row per unique combination of station/sampling-point coordinates and medium; auto-increment `LOCATION_ID` |

Script 12 adds `INTERIM_LOCATION_ID` to `INTERIM_SAMPLES` by joining on all eight location fields.

---

### 5 — Visualisations

#### Map of sampling locations

```r
source("map_interim_locations.R")
# → plots/map_interim_locations.png
```

Reads `INTERIM_LOCATIONS` from the database, reprojects coordinates from **SWEREF99TM (EPSG:3006)** to **WGS84**, and plots sites on a base map of Sweden. Station labels are added automatically when ≤ 40 locations are present.

#### N:P stoichiometry plot

```r
source("plot_NP_final.R")
# → plots/NP_final_2x2.png
```

Reads `short_NP_STOICHIOMETRY.csv` and classifies each observation by nutrient limitation status based on DIN and Total P concentrations (both µg/l). The output is a 2 × 2 panel figure: scatter plot (log₁₀ axes), DIN distribution, Total P distribution, and a legend panel.

---

## Parameter name mapping

`names_to_use.csv` maps the original Swedish column headers to standardised English parameter codes and units. Useful reference when querying `RESULTS` by `PARAMETER_NAME`.

Example entries:

| Original name | Standardised name | Units |
|---|---|---|
| `Tot-P (µg/l P)` | `TOTP-P` | µg/l |
| `Tot-N (µg/l N)` | `TOTN-N` | µg/l |
| `NO2+NO3-N (µg/l N)` | `NO3-N` | µg/l |
| `Vattentemperatur (°C)` | `TEMPERATURE` | °C |
| `Siktdjup (m)` | `SECCHI` | m |
| `pH` | `PH` | — |

---

## Data source

The data originate from the **Swedish national freshwater monitoring programme** and are stored in the original Swedish column naming convention used by the data provider. All coordinates are in **SWEREF99TM (EPSG:3006)**.
