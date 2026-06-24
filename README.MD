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
├── 60_create_vw_inorganic_ratio.sql           # Step 60  – Create vw_inorganic_ratio view (DIN-based N:P)
├── 61_create_vw_total_ratio.sql               # Step 61  – Create vw_total_ratio view (Total N-based N:P)
├── 62_create_vw_ratios_precursor.sql          # Step 62  – Union of inorganic and total ratio views
├── 63_create_vw_ratios.sql                    # Step 63  – Add LIMITING_FACTOR column to ratio view
├── 64_create_vw_locations_limiting_factors.sql # Step 64 – Aggregate limiting factors by location
├── 65_create_wv_nitrogen_summary.sql          # Step 65  – Create vw_avg_nitrogen_by_location view
│
├── update_water_quality_db.R                  # R alternative to SQL steps 1–3 (batch UPDATE via DBI)
├── map_interim_locations.R                    # Visualisation – Map of INTERIM_LOCATIONS sampling sites
├── map_limiting_factors.R                     # Visualisation – 4-panel map of nutrient limitation by location
├── plot_NP_final.R                            # Visualisation – N:P stoichiometry 2×2 panel plot
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

| Script                            | Action                                                                  |
| --------------------------------- | ----------------------------------------------------------------------- |
| `01 fix_comma_decimals.sql`       | Replaces European decimal commas with periods in `TEXT_VALUE`           |
| `02 populate_numeric_values.sql`  | Casts `TEXT_VALUE` to `NUMERIC_VALUE` where the value is a valid number |
| `03 fix_detection_limits.sql`     | Converts `<X` detection-limit strings to `X/2` in `NUMERIC_VALUE`      |
| `04 fix_bracketed_values.sql`     | Strips brackets from values such as `[0.5]`, writing `0.5`             |
| `05 delete_placeholder_rows.sql`  | Deletes dummy or artefact rows (e.g. `XXXX`, `Column…`)                |

**R alternative:** `update_water_quality_db.R` performs the same logic as scripts 01–03 entirely in R using batched `UPDATE` statements via `DBI`.

---

### Steps 10–12 — Build normalised sample and location tables

```sql
.read "10 create_INTERIM_SAMPLES.sql"
.read "11 create_INTERIM_LOCATIONS.sql"
.read "12 add_INTERIM_LOCATION_ID.sql"
```

| Table               | Description                                                                                                                 |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `INTERIM_SAMPLES`   | One row per sampling event; the first 32 metadata columns from `RAW_DATA`, with missing values standardised to `'MISSING'` |
| `INTERIM_LOCATIONS` | One row per unique combination of station/sampling-point coordinates and medium; auto-increment `LOCATION_ID`               |

Script 12 adds `INTERIM_LOCATION_ID` to `INTERIM_SAMPLES` by joining on all eight location fields.

---

### Steps 13–17 — Backbone and depth assignment

```sql
.read "13 create_SAMPLE_LOCATION_BACKBONE.sql"
.read "14 update_depth_from_provkommentar.sql"
.read "15 update_depth_from_undersokningstyp.sql"
.read "16 update_depth_ytvatten.sql"
.read "17 update_depth_botten.sql"
```

Script 13 creates a compact `SAMPLE_LOCATION_BACKBONE` cross-reference. Scripts 14–17 progressively assign `MIN_PROVDJUP_M` and `MAX_PROVDJUP_M` values by parsing free-text fields and applying defaults for surface water (`ytvatten`) and bottom (`botten`) sample types.

---

### Step 18 — Create DATA_SOURCES table

```sql
.read "18_create_DATA_SOURCES.sql"
```

Creates **`DATA_SOURCES`** — a lookup table of distinct source file/dataset names drawn from `INTERIM_SAMPLES`.

---

### Step 20 — Create final LOCATIONS table

```sql
.read "20 create_LOCATIONS.sql"
```

Creates **`LOCATIONS`** from `INTERIM_LOCATIONS`, retaining only the canonical representative of each location group after deduplication. Coordinate columns are cast from `TEXT` to `INTEGER`. A `QC` column is included for future annotation.

---

### Steps 21–22 — Convert legacy RT90 coordinates to SWEREF99TM

```r
source("21_convert_rt90_to_sweref99.R")
```
```sql
.read "22_update_locations_from_rt90.sql"
```

The R script identifies rows in `LOCATIONS` where `KOORDINATSYSTEM` does not indicate SWEREF99, corrects truncated 6-digit coordinates, and reprojects from RT90 2.5 gon V (EPSG:3021) to SWEREF99TM (EPSG:3006) via the `sf` package. Results are written to a staging table **`RT90_TO_SWEREF99`**. Script 22 then updates `LOCATIONS` in place and sets `QC = 'coordinates from RT90'`.

---

### Step 25 — Create PARAMETER_LOOKUP table

```sql
.read "25 create_NAMES_TO_USE.sql"
```

Creates **`PARAMETER_LOOKUP`** — maps sanitised `PARAMETER_NAME` values from `RESULTS` to standardised English parameter codes, species, element, units, and molar mass.

---

### Step 26 — Create vw_results_with_lookup view

```sql
.read "26 create_RESULTS_view.sql"
```

Creates the view **`vw_results_with_lookup`** — a LEFT JOIN of `RESULTS` to `PARAMETER_LOOKUP`, providing `NAME_TO_USE`, `SPECIES`, `ELEMENT`, `UNITS`, and `ELEMENT_MOLAR_MASS_G` alongside all `RESULTS` columns.

---

### Step 30 — Create STOICHIOMETRY_INPUTS table

```sql
.read "30_create_STOICHIOMETRY_INPUTS.sql"
```

Creates **`STOICHIOMETRY_INPUTS`** — one row per sampling event that has a non-NULL `TOTAL_PHOSPHORUS` value. Additional nitrogen columns (`DIN`, `TOTAL_N` and their QC flags) are added by steps 35–36.

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

Creates **`vw_DIN`** and **`vw_total_n`** — views that compute dissolved inorganic nitrogen (DIN) and total nitrogen from the components held in `STOICHIOMETRY_NITROGEN`.

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

Script 35 adds `DIN` and `DIN_QC` columns; script 36 adds `TOTAL_N` and `TOTAL_N_QC` columns. Both join through `COMPONENT_QC` to record which nitrogen fractions were used for each row.

---

### Step 40 — Create vw_source_rowid_stats view

```sql
.read "40_create_vw_source_rowid_stats.sql"
```

Creates the view **`vw_source_rowid_stats`** — aggregates `RESULTS` by `SOURCE_ROWID`, computing summary statistics over `NUMERIC_VALUE` across all parameters for each sampling event. The basis for duplicate detection.

---

### Step 41 — Create DUPLICATE_CANDIDATES table

```sql
.read "41_create_DUPLICATE_CANDIDATES.sql"
```

Creates **`DUPLICATE_CANDIDATES`** by grouping `vw_source_rowid_stats` on its aggregate columns. Groups with `N_SOURCE_ROWIDS > 1` are potential duplicate sets.

---

### Step 42 — Create DUPLICATE_SOURCE_ROWIDS table

```sql
.read "42_create_DUPLICATE_SOURCE_ROWIDS.sql"
```

Creates **`DUPLICATE_SOURCE_ROWIDS`** — resolves each duplicate candidate group to its individual member `SOURCE_ROWID`s. Defaults `USE_SAMPLE = 'Y'` for all rows; updated by script 44.

---

### Step 43 — Create vw_duplicate_samples view

```sql
.read "43_create_vw_duplicate_samples.sql"
```

Creates the view **`vw_duplicate_samples`** — joins `DUPLICATE_CANDIDATES` to sample metadata for inspection of potential duplicates.

---

### Step 44 — Update DUPLICATE_SOURCE_ROWIDS

```sql
.read "44_update_DUPLICATE_SOURCE_ROWIDS.sql"
```

Flags the smaller `SOURCE_ROWID` in each duplicate pair as discarded (`USE_SAMPLE = 'N'`), retaining the larger (most recent) row.

---

### Step 45 — Create vw_stoichiometry_inputs_deduped view

```sql
.read "45_create_vw_stoichiometry_inputs_deduped.sql"
```

Creates the view **`vw_stoichiometry_inputs_deduped`** — a deduplicated view of `STOICHIOMETRY_INPUTS` excluding rows flagged as duplicates by step 44.

---

### Step 50 — Create SAMPLES table

```sql
.read "50_create_SAMPLES.sql"
```

Creates the curated **`SAMPLES`** table — a clean, typed version of `INTERIM_SAMPLES` with `USE_SAMPLE`, `DATA_SOURCE_ID`, `LOCATION_ID`, and properly converted date/depth columns. `'MISSING'` and non-numeric values become `NULL`.

---

### Step 51 — Create vw_provdatum_mismatch view

```sql
.read "51_create_vw_provdatum_mismatch.sql"
```

Creates the view **`vw_provdatum_mismatch`** — identifies rows in `SAMPLES` where `PROVDATUM` (back-transformed from the Excel serial) does not match the date constructed from `PROVTAGNINGSAR`, `PROVTAGNINGSMANAD`, `PROVTAGNINGSDAG`. Useful for catching edge cases where the Excel serial and the individual date columns are inconsistent.

---

### Step 60 — Create vw_inorganic_ratio view

```sql
.read "60_create_vw_inorganic_ratio.sql"
```

Creates the view **`vw_inorganic_ratio`** — joins `STOICHIOMETRY_INPUTS` to `THRESHOLDS` (where `N_FORM = 'INORGANIC'`) and returns one row per `SOURCE_ROWID` / threshold combination where `DIN` is not NULL, computing `DIN / TOTAL_PHOSPHORUS` as `RATIO`.

---

### Step 61 — Create vw_total_ratio view

```sql
.read "61_create_vw_total_ratio.sql"
```

Creates the view **`vw_total_ratio`** — as above but using `TOTAL_N` and joining to `THRESHOLDS` where `N_FORM = 'TOTAL'`.

---

### Step 62 — Create vw_ratios_precursor view

```sql
.read "62_create_vw_ratios_precursor.sql"
```

Creates the view **`vw_ratios_precursor`** — a `UNION ALL` of `vw_inorganic_ratio` and `vw_total_ratio`, combining both nitrogen forms into a single view.

---

### Step 63 — Create vw_ratios view

```sql
.read "63_create_vw_ratios.sql"
```

Creates the view **`vw_ratios`** — extends `vw_ratios_precursor` with a `LIMITING_FACTOR` column derived from comparing `RATIO` against the N and P thresholds from `THRESHOLDS`:

| Condition       | `LIMITING_FACTOR` |
| --------------- | ----------------- |
| `RATIO < N`     | `'N'` (nitrogen limiting) |
| `RATIO > P`     | `'P'` (phosphorus limiting) |
| otherwise       | `'NP'` (co-limitation) |

---

### Step 64 — Create vw_locations_limiting_factors view

```sql
.read "64_create_vw_locations_limiting_factors.sql"
```

Creates the view **`vw_locations_limiting_factors`** — aggregates `vw_ratios` by `LOCATION_ID` and `N_FORM`, counting the number of N-, P-, and NP-limited observations per location and computing average total phosphorus. Used by `map_limiting_factors.R`.

---

### Step 65 — Create vw_avg_nitrogen_by_location view

```sql
.read "65_create_wv_nitrogen_summary.sql"
```

Creates the view **`vw_avg_nitrogen_by_location`** — aggregates `vw_ratios` by `LOCATION_ID` and `N_FORM`, returning average nitrogen concentration and sample count per location. Joins to `SAMPLES` and filters to `USE_SAMPLE = 'Y'`.

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

#### Map of nutrient limitation by location

```r
source("map_limiting_factors.R")
# → plots/map_limiting_factors.png
```

Reads `vw_locations_limiting_factors` from the database and produces a 4-panel map of Sweden showing: % N-limited, average total phosphorus, % P-limited, and % NP co-limited, with filled-circle symbols at each monitoring station.

---

## Database schema

### Tables

#### `RAW_DATA`
Staging table populated directly from `Short.xlsx`. All 84 columns stored as `TEXT`. One row per original spreadsheet row.

#### `RESULTS`
Long-format table; one row per (sample × parameter) combination. Columns: `ID`, `SOURCE_ROWID`, `PARAMETER_NAME`, `TEXT_VALUE`, `NUMERIC_VALUE`, `COMMENTS`, `QC`.

#### `INTERIM_SAMPLES`
One row per sampling event; first 32 metadata columns from `RAW_DATA` with missing values as `'MISSING'`, plus `INTERIM_LOCATION_ID`.

#### `INTERIM_LOCATIONS`
One row per unique sampling location (station + coordinates + medium).

#### `DATA_SOURCES`
Lookup of distinct source dataset names.

#### `LOCATIONS`
Final deduplicated locations table; coordinates as `INTEGER` (SWEREF99TM).

#### `RT90_TO_SWEREF99`
Staging table for RT90 → SWEREF99TM coordinate conversions.

#### `PARAMETER_LOOKUP`
Maps sanitised `PARAMETER_NAME` values to standardised codes, units, and molar masses.

#### `STOICHIOMETRY_INPUTS`
One row per sampling event with non-NULL total phosphorus; includes `DIN`, `DIN_QC`, `TOTAL_N`, `TOTAL_N_QC` columns added by steps 35–36.

#### `STOICHIOMETRY_NITROGEN`
Wide-format staging table of nitrogen fraction values per sampling event.

#### `COMPONENT_QC`
Lookup of nitrogen fraction combinations used when deriving DIN or total nitrogen.

#### `DUPLICATE_CANDIDATES`
Groups of `SOURCE_ROWID`s sharing identical aggregate statistics — potential duplicate sampling events.

#### `DUPLICATE_SOURCE_ROWIDS`
Individual `SOURCE_ROWID` members of each duplicate group with `USE_SAMPLE` flag.

#### `SAMPLES`
Curated, typed sampling events table with `USE_SAMPLE`, `DATA_SOURCE_ID`, `LOCATION_ID`, and converted date/depth columns.

### Views

| View                                  | Description                                                         |
| ------------------------------------- | ------------------------------------------------------------------- |
| `vw_results_with_lookup`              | `RESULTS` joined to `PARAMETER_LOOKUP`                             |
| `vw_DIN`                              | Dissolved inorganic nitrogen computed from `STOICHIOMETRY_NITROGEN` |
| `vw_total_n`                          | Total nitrogen computed from `STOICHIOMETRY_NITROGEN`               |
| `vw_source_rowid_stats`               | Aggregate statistics per `SOURCE_ROWID` for duplicate detection     |
| `vw_duplicate_samples`                | Duplicate candidates joined to sample metadata                      |
| `vw_stoichiometry_inputs_deduped`     | `STOICHIOMETRY_INPUTS` with duplicates excluded                     |
| `vw_provdatum_mismatch`               | `SAMPLES` rows where date components disagree                       |
| `vw_inorganic_ratio`                  | DIN-based N:P ratios per threshold source                           |
| `vw_total_ratio`                      | Total-N-based N:P ratios per threshold source                       |
| `vw_ratios_precursor`                 | Union of `vw_inorganic_ratio` and `vw_total_ratio`                  |
| `vw_ratios`                           | N:P ratios with `LIMITING_FACTOR` classification                    |
| `vw_locations_limiting_factors`       | Limiting factor counts and average TP per location                  |
| `vw_avg_nitrogen_by_location`         | Average nitrogen concentration per location and N form              |

---

## Data source

The data originate from the **Swedish national freshwater monitoring programme** and are stored using the original Swedish column naming convention used by the data provider. All coordinates are in **SWEREF99TM (EPSG:3006)**.
