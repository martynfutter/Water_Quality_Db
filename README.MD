# Water Quality Database Pipeline

This repository contains the full pipeline for ingesting, cleaning, and analysing Swedish freshwater monitoring data from `Short.xlsx` into a SQLite database (`water_quality.db`), together with R scripts for visualisation.

---

## Repository structure

```
Water_Quality_Db/
├── 00_create_water_quality_db.R               # Step 0   – Ingest Excel → SQLite RAW_DATA table
├── 00 create_results.sql                      # Step 0b  – Unpivot RAW_DATA → long-format RESULTS table
├── 01 fix_comma_decimals.sql                  # Step 1   – Replace European decimal commas with periods
├── 02 populate_numeric_values.sql             # Step 2   – Cast TEXT_VALUE → NUMERIC_VALUE
├── 03 fix_detection_limits.sql                # Step 3   – Convert <X detection limits → X/2
├── 04 fix_bracketed_values.sql                # Step 4   – Strip brackets from values (e.g. [0.5] → 0.5)
├── 05 delete_placeholder_rows.sql             # Step 5   – Delete dummy/artefact rows
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
├── 45_create_vw_stoichiometry_inputs_deduped.sql  # Step 45 – Deduplicated view of STOICHIOMETRY_INPUTS
├── 50_create_SAMPLES.sql                      # Step 50  – Create curated SAMPLES table
├── 51_create_vw_provdatum_mismatch.sql        # Step 51  – Flag PROVDATUM vs date-component mismatches
├── 60_create_vw_inorganic_ratio.sql           # Step 60  – Create vw_inorganic_ratio (DIN-based N:P)
├── 61_create_vw_total_ratio.sql               # Step 61  – Create vw_total_ratio (Total N-based N:P)
├── 62_create_vw_ratios_precursor.sql          # Step 62  – Union of inorganic and total ratio views
├── 63_create_vw_ratios.sql                    # Step 63  – Add LIMITING_FACTOR classification to ratios
├── 64_create_vw_locations_limiting_factors.sql # Step 64 – Limiting factor summary per location
├── 65_create_wv_nitrogen_summary.sql          # Step 65  – Average nitrogen by location and N_FORM
├── 66_create_nitrogen_crosstab.sql            # Step 66  – Crosstab of nitrogen averages by location
├── 67_create_vw_locations_summary.sql         # Step 67  – Combined location-level summary view
├── 68_create_vw_samples_per_year.sql          # Step 68  – Sample counts per calendar year
├── 69_create_vw_year_limiting_factors.sql     # Step 69  – Limiting factor counts and proportions per year
├── 70_diag_pct_sum.sql                        # Step 70  – Diagnostic: verify proportions sum to 100%
│
├── map_interim_locations.R                    # Visualisation – Map of INTERIM_LOCATIONS sampling sites
├── map_limiting_factors.R                     # Visualisation – 4-panel map of nutrient limitation by location
├── plot_samples_per_year.R                    # Visualisation – Bar chart of sample counts per year
├── plot_year_limiting_factors.R               # Visualisation – Stacked bar charts of limiting factors by year
│
├── .gitignore
└── README.MD
```

> **Note:** `Short.xlsx`, `*.db`, `*.db-journal`, `*.csv`, and `plots/` are listed in `.gitignore` and are not committed to the repository.

---

## Prerequisites

### R packages

```r
install.packages(c(
  "readxl",                              # reading Excel
  "DBI", "RSQLite",                      # database access
  "ggplot2", "patchwork", "scales",      # plotting
  "tidyr", "dplyr",                      # data reshaping
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

| Script | Action |
| --- | --- |
| `01 fix_comma_decimals.sql` | Replaces European decimal commas with periods in `TEXT_VALUE` |
| `02 populate_numeric_values.sql` | Casts `TEXT_VALUE` to `NUMERIC_VALUE` where the value is a valid number |
| `03 fix_detection_limits.sql` | Converts `<X` detection-limit strings to `X/2` in `NUMERIC_VALUE` |
| `04 fix_bracketed_values.sql` | Strips brackets from values such as `[0.5]`, writing `0.5` |
| `05 delete_placeholder_rows.sql` | Deletes dummy or artefact rows (e.g. `XXXX…`, `Column…`) |

---

### Steps 10–17 — Build INTERIM_SAMPLES and INTERIM_LOCATIONS

```sql
.read "10 create_INTERIM_SAMPLES.sql"
.read "11 create_INTERIM_LOCATIONS.sql"
.read "12 add_INTERIM_LOCATION_ID.sql"
.read "13 create_SAMPLE_LOCATION_BACKBONE.sql"
.read "14 update_depth_from_provkommentar.sql"
.read "15 update_depth_from_undersokningstyp.sql"
.read "16 update_depth_ytvatten.sql"
.read "17 update_depth_botten.sql"
```

Script 10 extracts the first 32 metadata columns from `RAW_DATA` into **`INTERIM_SAMPLES`**, standardising missing values to `'MISSING'`. Script 11 identifies unique sampling locations and writes them to **`INTERIM_LOCATIONS`**. Script 12 links each sample back to its canonical location via `INTERIM_LOCATION_ID`. Scripts 13–17 build a compact sample↔location cross-reference and populate depth information from multiple free-text and coded fields.

---

### Step 18 — Create DATA_SOURCES lookup

```sql
.read "18_create_DATA_SOURCES.sql"
```

Creates and populates **`DATA_SOURCES`** — a lookup table of distinct source dataset names extracted from `INTERIM_SAMPLES`, each assigned a unique integer `DATA_SOURCE_ID`.

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

The R script identifies locations stored in the older RT90 2.5 gon V system (EPSG:3021), corrects any truncated 6-digit coordinates, reprojects to SWEREF99TM (EPSG:3006) using the `sf` package, and writes results to the staging table **`RT90_TO_SWEREF99`**. The SQL script then updates `LOCATIONS` in place with the converted coordinates, setting `KOORDINATSYSTEM = 'SWEREF99TM'` and `QC = 'coordinates from RT90'`.

---

### Step 25 — Create PARAMETER_LOOKUP table

```sql
.read "25 create_NAMES_TO_USE.sql"
```

Creates **`PARAMETER_LOOKUP`** — a lookup table mapping sanitised `PARAMETER_NAME` values in `RESULTS` to standardised English parameter codes, species, element, units, and molar mass.

---

### Step 26 — Create vw_results_with_lookup view

```sql
.read "26 create_RESULTS_view.sql"
```

Creates **`vw_results_with_lookup`** — joins `RESULTS` to `PARAMETER_LOOKUP` on `PARAMETER_NAME` (LEFT JOIN), providing `NAME_TO_USE`, `SPECIES`, `ELEMENT`, `UNITS`, and `ELEMENT_MOLAR_MASS_G` alongside all `RESULTS` columns.

---

### Step 30 — Create STOICHIOMETRY_INPUTS table

```sql
.read "30_create_STOICHIOMETRY_INPUTS.sql"
```

Creates **`STOICHIOMETRY_INPUTS`** — one row per sampling event with a non-NULL `TOTAL_PHOSPHORUS`, drawn from `vw_results_with_lookup`. Nitrogen columns (`DIN`, `TOTAL_N` and their QC flags) are added by later steps.

---

### Step 31 — Create STOICHIOMETRY_NITROGEN table

```sql
.read "31_create_STOICHIOMETRY_NITROGEN.sql"
```

Creates **`STOICHIOMETRY_NITROGEN`** — a wide-format staging table of nitrogen fraction values per sampling event, restricted to `SOURCE_ROWID`s already in `STOICHIOMETRY_INPUTS`.

---

### Steps 32–33 — Create nitrogen views

```sql
.read "32_create_vw_DIN.sql"
.read "33_create_vw_total_n.sql"
```

**`vw_DIN`** computes dissolved inorganic nitrogen (DIN = NH₄ + NO₂ + NO₃ where available) from `STOICHIOMETRY_NITROGEN`. **`vw_total_n`** computes total nitrogen via three fallback cases: direct measurement, Kjeldahl + nitrate, or organic N + DIN.

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

Script 35 adds `DIN` and `DIN_QC` columns; script 36 adds `TOTAL_N` and `TOTAL_N_QC`. Both record which nitrogen fractions were used via `COMPONENT_QC`.

---

### Steps 40–44 — Duplicate detection and flagging

```sql
.read "40_create_vw_source_rowid_stats.sql"
.read "41_create_DUPLICATE_CANDIDATES.sql"
.read "42_create_DUPLICATE_SOURCE_ROWIDS.sql"
.read "43_create_vw_duplicate_samples.sql"
.read "44_update_DUPLICATE_SOURCE_ROWIDS.sql"
```

Script 40 creates **`vw_source_rowid_stats`** — summary statistics per `SOURCE_ROWID` across all measured parameters. Script 41 identifies groups of `SOURCE_ROWID`s sharing identical statistics (**`DUPLICATE_CANDIDATES`**). Script 42 resolves these groups to individual rows (**`DUPLICATE_SOURCE_ROWIDS`**). Script 43 creates **`vw_duplicate_samples`** for inspection. Script 44 flags the smaller `SOURCE_ROWID` in each duplicate pair as `USE_SAMPLE = 'N'`.

---

### Step 45 — Deduplicated stoichiometry view

```sql
.read "45_create_vw_stoichiometry_inputs_deduped.sql"
```

Creates **`vw_stoichiometry_inputs_deduped`** — a deduplicated view of `STOICHIOMETRY_INPUTS` excluding rows flagged `USE_SAMPLE = 'N'`.

---

### Step 50 — Create curated SAMPLES table

```sql
.read "50_create_SAMPLES.sql"
```

Creates the primary curated sample-level table **`SAMPLES`**, combining metadata from `INTERIM_SAMPLES`, deduplication flags from `DUPLICATE_SOURCE_ROWIDS`, and foreign keys to `DATA_SOURCES` and `LOCATIONS`. Key columns include `USE_SAMPLE`, `PROVDATUM`, `PROVTAGNINGSAR`, `PROVTAGNINGSMANAD`, and `PROVTAGNINGSDAG`.

---

### Step 51 — Date consistency check

```sql
.read "51_create_vw_provdatum_mismatch.sql"
```

Creates **`vw_provdatum_mismatch`** — identifies rows in `SAMPLES` where the back-transformed `PROVDATUM` disagrees with the date constructed from `PROVTAGNINGSAR`, `PROVTAGNINGSMANAD`, and `PROVTAGNINGSDAG`.

---

### Steps 60–63 — N:P ratio views

```sql
.read "60_create_vw_inorganic_ratio.sql"
.read "61_create_vw_total_ratio.sql"
.read "62_create_vw_ratios_precursor.sql"
.read "63_create_vw_ratios.sql"
```

Scripts 60 and 61 create **`vw_inorganic_ratio`** and **`vw_total_ratio`** — one row per `SOURCE_ROWID` × THRESHOLDS combination for DIN-based and Total N-based N:P ratios respectively. A `NULLIF` guard prevents division by zero when `TOTAL_PHOSPHORUS = 0`. Script 62 unions these into **`vw_ratios_precursor`**. Script 63 creates **`vw_ratios`**, adding a `LIMITING_FACTOR` column (`'N'`, `'P'`, or `'NP'`) based on whether the ratio falls below, above, or between the threshold bounds. Rows with `NULL` ratios (i.e. `TOTAL_PHOSPHORUS = 0`) are excluded via `WHERE RATIO IS NOT NULL` to prevent misclassification.

---

### Step 64 — Limiting factors by location

```sql
.read "64_create_vw_locations_limiting_factors.sql"
```

Creates **`vw_locations_limiting_factors`** — joins `LOCATIONS` to `vw_ratios` via `SAMPLES` (retained samples only), producing one row per location with counts of each `LIMITING_FACTOR` value (`N_COUNT`, `P_COUNT`, `NP_COUNT`) and `AVG_TOTAL_PHOSPHORUS`.

---

### Step 65 — Average nitrogen by location

```sql
.read "65_create_wv_nitrogen_summary.sql"
```

Creates **`vw_avg_nitrogen_by_location`** — average nitrogen values from `vw_ratios` grouped by `LOCATION_ID` and `N_FORM` (`'INORGANIC'` or `'TOTAL'`), with a count of contributing rows.

---

### Step 66 — Nitrogen crosstab

```sql
.read "66_create_nitrogen_crosstab.sql"
```

Creates a crosstab view of average nitrogen values pivoted by `N_FORM`, giving one row per location with separate columns for inorganic and total nitrogen averages.

---

### Step 67 — Combined location summary

```sql
.read "67_create_vw_locations_summary.sql"
```

Creates **`vw_locations_summary`** — combines location metadata, limiting factor counts and proportions, and average nitrogen and phosphorus into a single wide view for use in maps and exports.

---

### Step 68 — Sample counts per year

```sql
.read "68_create_vw_samples_per_year.sql"
```

Creates **`vw_samples_per_year`** — groups `SAMPLES` by `PROVTAGNINGSAR`, returning `N_SAMPLES_TOTAL` (all samples) and `N_SAMPLES_USE_Y` (retained samples only, `USE_SAMPLE = 'Y'`) per calendar year.

---

### Step 69 — Limiting factors by year

```sql
.read "69_create_vw_year_limiting_factors.sql"
```

Creates **`vw_year_limiting_factors`** — groups retained samples by calendar year, producing `N_COUNT`, `P_COUNT`, `NP_COUNT`, and `TOTAL_COUNT` per year, plus `AVG_TOTAL_PHOSPHORUS`, `AVG_DIN`, and `AVG_TOTAL_N`. Proportions (`PCT_N`, `PCT_P`, `PCT_NP`) are also included but should be treated with caution: because `vw_ratios` produces one row per `SOURCE_ROWID` × `N_FORM` combination, `TOTAL_COUNT` is inflated in years where both INORGANIC and TOTAL nitrogen measurements exist. For plotting, derive proportions in R from `N_COUNT / (N_COUNT + P_COUNT + NP_COUNT)` — see `plot_year_limiting_factors.R`.

---

### Step 70 — Proportion diagnostic

```sql
.read "70_diag_pct_sum.sql"
```

A set of four diagnostic queries to verify that limiting factor proportions sum correctly to 100% for each year. Checks for NULL limiting factors, confirms row counts per N_FORM per year, and identifies years where `N_COUNT + P_COUNT + NP_COUNT ≠ TOTAL_COUNT`.

---

## Visualisations

### Map of interim sampling locations

```r
source("map_interim_locations.R")
# → plots/map_interim_locations.png
```

Reads `INTERIM_LOCATIONS` from the database, reprojects coordinates from SWEREF99TM (EPSG:3006) to WGS84 (EPSG:4326), and plots sites on a base map of Sweden. Station labels are added with `ggrepel` when ≤ 40 locations are present.

---

### 4-panel map of nutrient limitation

```r
source("map_limiting_factors.R")
# → plots/map_limiting_factors.png
```

Reads `vw_locations_limiting_factors` and produces a 4-panel figure in SWEREF99TM:

| Panel | Content |
| --- | --- |
| Top-left | % N-limited (YlOrRd palette) |
| Top-right | Average total phosphorus — sqrt-transformed (Blues) |
| Bottom-left | % P-limited (Greens) |
| Bottom-right | % NP co-limited (Purples) |

Proportions are computed in R from raw counts as `N_COUNT / (N_COUNT + P_COUNT + NP_COUNT) × 100`.

---

### Bar chart of sample counts per year

```r
source("plot_samples_per_year.R")
# → plots/samples_per_year.png
```

Reads `vw_samples_per_year` and plots `N_SAMPLES_USE_Y` (retained samples) as a bar chart by calendar year.

---

### Stacked bar charts of limiting factors by year

```r
source("plot_year_limiting_factors.R")
# → plots/year_limiting_factors.png
```

Reads `vw_year_limiting_factors` and produces a two-panel figure:

- **Panel A** — stacked proportions (% N / NP / P) per year, with proportions derived in R from raw counts to avoid N_FORM denominator inflation.
- **Panel B** — stacked absolute counts per year; bar height equals total classifiable samples.

Colours are consistent across all limiting-factor visualisations: red = N-limited, green = NP co-limited, blue = P-limited.

---

## Database schema

### Tables

#### `RAW_DATA`
Staging table populated directly from `Short.xlsx`. All columns stored as `TEXT`.

#### `RESULTS`
Long-format table; one row per (sample × parameter). Columns: `ID`, `SOURCE_ROWID`, `PARAMETER_NAME`, `TEXT_VALUE`, `NUMERIC_VALUE`, `COMMENTS`, `QC`.

#### `INTERIM_SAMPLES`
One row per sampling event; the first 32 metadata columns from `RAW_DATA` with missing values standardised to `'MISSING'`.

#### `INTERIM_LOCATIONS`
One row per unique sampling location extracted from `INTERIM_SAMPLES`.

#### `DATA_SOURCES`
Lookup table of distinct source dataset names. Columns: `DATA_SOURCE_ID`, `SOURCE_NAME`.

#### `LOCATIONS`
Final deduplicated locations table in SWEREF99TM. Includes `QC` column for annotation.

#### `PARAMETER_LOOKUP`
Maps `PARAMETER_NAME` to standardised codes, species, element, units, and molar mass.

#### `STOICHIOMETRY_INPUTS`
One row per sampling event with a non-NULL `TOTAL_PHOSPHORUS`. Columns include `SOURCE_ROWID`, `TOTAL_PHOSPHORUS`, `DIN`, `DIN_QC`, `TOTAL_N`, `TOTAL_N_QC`.

#### `STOICHIOMETRY_NITROGEN`
Wide-format staging table of nitrogen fraction values per sampling event.

#### `COMPONENT_QC`
Lookup table of nitrogen component combinations used in stoichiometry calculations.

#### `DUPLICATE_CANDIDATES`
Groups of `SOURCE_ROWID`s sharing identical summary statistics across all parameters.

#### `DUPLICATE_SOURCE_ROWIDS`
Individual `SOURCE_ROWID`s within each duplicate group, with `USE_SAMPLE` flag.

#### `SAMPLES`
Primary curated sample table combining metadata, deduplication flags, and foreign keys to `DATA_SOURCES` and `LOCATIONS`.

---

### Views

| View | Description |
| --- | --- |
| `vw_results_with_lookup` | `RESULTS` joined to `PARAMETER_LOOKUP` |
| `vw_DIN` | Computed dissolved inorganic nitrogen per sample |
| `vw_total_n` | Computed total nitrogen per sample |
| `vw_source_rowid_stats` | Summary statistics per `SOURCE_ROWID` (duplicate detection) |
| `vw_duplicate_samples` | Duplicate candidates joined to sample metadata |
| `vw_stoichiometry_inputs_deduped` | Deduplicated `STOICHIOMETRY_INPUTS` |
| `vw_provdatum_mismatch` | Samples where `PROVDATUM` disagrees with date components |
| `vw_inorganic_ratio` | DIN-based N:P ratio per sample × threshold |
| `vw_total_ratio` | Total N-based N:P ratio per sample × threshold |
| `vw_ratios_precursor` | Union of `vw_inorganic_ratio` and `vw_total_ratio` |
| `vw_ratios` | Adds `LIMITING_FACTOR` (`'N'`, `'P'`, `'NP'`) to ratios; excludes NULL ratios |
| `vw_locations_limiting_factors` | Limiting factor counts and avg TP per location |
| `vw_avg_nitrogen_by_location` | Average nitrogen by location and N_FORM |
| `vw_locations_summary` | Combined location-level summary (metadata + nutrients) |
| `vw_samples_per_year` | Sample counts (total and retained) per calendar year |
| `vw_year_limiting_factors` | Limiting factor counts, proportions, and avg nutrients per year |
