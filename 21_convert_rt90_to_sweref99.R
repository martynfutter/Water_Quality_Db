# 21_convert_rt90_to_sweref99.R
#
# Reads LOCATIONS from water_quality.db, identifies rows where KOORDINATSYSTEM
# does NOT indicate SWEREF99 (i.e. rows that need reprojection), converts
# coordinates from RT90 2.5 gon V (EPSG:3021) to SWEREF99TM (EPSG:3006),
# and writes the results to a new table RT90_TO_SWEREF99 keyed by LOCATION_ID.
#
# The original LOCATIONS table is never modified.
#
# Required packages:
#   install.packages(c("DBI", "RSQLite", "sf"))
#
# Assumptions:
#   • Coordinates needing conversion are in RT90 2.5 gon V (EPSG:3021).
#     If another RT90 variant is present, update SOURCE_CRS below.
#   • STATIONSKOORDINAT_N_X = northing (Y), STATIONSKOORDINAT_E_Y = easting (X)
#     — column names follow the Swedish convention where N/X = northing.
#
# Truncation fix:
#   RT90 coordinates are always 7-digit integers:
#     Eastings:  1,200,000 – 1,900,000  (leading digit is always 1)
#     Northings: 6,100,000 – 7,700,000  (leading digit is 6 or 7)
#   Values stored with only 6 digits are missing their leading digit and are
#   corrected by multiplying by 10:
#     Truncated easting  < 200,000              → multiply by 10
#     Truncated northing  200,000 – 999,999     → multiply by 10
#   Both coordinate pairs (station and provplats) are checked and fixed.

library(DBI)
library(RSQLite)
library(sf)

# ── Configuration ─────────────────────────────────────────────────────────────
db_path    <- "water_quality.db"
source_crs <- 3021   # RT90 2.5 gon V  — change to e.g. 3022/3023/3024 if needed
target_crs <- 3006   # SWEREF99TM

# ── Helpers: fix truncated 6-digit RT90 coordinates ──────────────────────────
# Eastings  < 200,000              are missing their leading '1' → multiply by 10
# Northings in 200,000 – 999,999  are missing their leading '6' or '7' → multiply by 10
fix_truncated_easting  <- function(x) ifelse(!is.na(x) & x < 200000,           x * 10, x)
fix_truncated_northing <- function(x) ifelse(!is.na(x) & x >= 200000 & x < 1e6, x * 10, x)

# ── Connect ───────────────────────────────────────────────────────────────────
cat("Connecting to:", db_path, "\n")
con <- dbConnect(RSQLite::SQLite(), db_path)

tryCatch({

  # ── 1. Fetch rows that need conversion ──────────────────────────────────────
  locs <- dbGetQuery(con, "
    SELECT
      LOCATION_ID,
      KOORDINATSYSTEM,
      STATIONSKOORDINAT_N_X,
      STATIONSKOORDINAT_E_Y,
      PROVPLATSKOORDINAT_N_X,
      PROVPLATSKOORDINAT_E_Y
    FROM LOCATIONS
    WHERE UPPER(KOORDINATSYSTEM) NOT LIKE '%SWEREF%'
  ")

  cat("Rows to convert (non-SWEREF KOORDINATSYSTEM):", nrow(locs), "\n")

  if (nrow(locs) == 0) {
    cat("Nothing to convert — exiting.\n")
    dbDisconnect(con)
    return(invisible(NULL))
  }

  # ── 2. Convert columns to numeric ───────────────────────────────────────────
  locs$stn_n <- suppressWarnings(as.numeric(locs$STATIONSKOORDINAT_N_X))
  locs$stn_e <- suppressWarnings(as.numeric(locs$STATIONSKOORDINAT_E_Y))
  locs$prv_n <- suppressWarnings(as.numeric(locs$PROVPLATSKOORDINAT_N_X))
  locs$prv_e <- suppressWarnings(as.numeric(locs$PROVPLATSKOORDINAT_E_Y))

  # ── 3. Fix truncated 6-digit coordinates ────────────────────────────────────
  n_fixed_stn_e <- sum(!is.na(locs$stn_e) & locs$stn_e < 200000)
  n_fixed_prv_e <- sum(!is.na(locs$prv_e) & locs$prv_e < 200000)
  n_fixed_stn_n <- sum(!is.na(locs$stn_n) & locs$stn_n >= 200000 & locs$stn_n < 1e6)
  n_fixed_prv_n <- sum(!is.na(locs$prv_n) & locs$prv_n >= 200000 & locs$prv_n < 1e6)

  if (n_fixed_stn_e > 0) cat("Station easting  truncation fix applied to", n_fixed_stn_e, "row(s).\n")
  if (n_fixed_prv_e > 0) cat("Provplats easting  truncation fix applied to", n_fixed_prv_e, "row(s).\n")
  if (n_fixed_stn_n > 0) cat("Station northing truncation fix applied to", n_fixed_stn_n, "row(s).\n")
  if (n_fixed_prv_n > 0) cat("Provplats northing truncation fix applied to", n_fixed_prv_n, "row(s).\n")

  locs$stn_e <- fix_truncated_easting(locs$stn_e)
  locs$prv_e <- fix_truncated_easting(locs$prv_e)
  locs$stn_n <- fix_truncated_northing(locs$stn_n)
  locs$prv_n <- fix_truncated_northing(locs$prv_n)

  # ── 4. Reproject station coordinates ────────────────────────────────────────
  valid_stn <- !is.na(locs$stn_e) & !is.na(locs$stn_n) &
               locs$stn_e > 0     & locs$stn_n > 0

  stn_sweref_n <- rep(NA_real_, nrow(locs))
  stn_sweref_e <- rep(NA_real_, nrow(locs))

  if (any(valid_stn)) {
    pts_stn <- st_as_sf(
      locs[valid_stn, ],
      coords = c("stn_e", "stn_n"),
      crs    = source_crs
    )
    pts_stn_t <- st_transform(pts_stn, crs = target_crs)
    xy <- st_coordinates(pts_stn_t)
    stn_sweref_e[valid_stn] <- xy[, "X"]
    stn_sweref_n[valid_stn] <- xy[, "Y"]
    cat("Station coordinates converted:", sum(valid_stn), "row(s).\n")
  }

  # ── 5. Reproject provplats coordinates ──────────────────────────────────────
  valid_prv <- !is.na(locs$prv_e) & !is.na(locs$prv_n) &
               locs$prv_e > 0     & locs$prv_n > 0

  prv_sweref_n <- rep(NA_real_, nrow(locs))
  prv_sweref_e <- rep(NA_real_, nrow(locs))

  if (any(valid_prv)) {
    pts_prv <- st_as_sf(
      locs[valid_prv, ],
      coords = c("prv_e", "prv_n"),
      crs    = source_crs
    )
    pts_prv_t <- st_transform(pts_prv, crs = target_crs)
    xy2 <- st_coordinates(pts_prv_t)
    prv_sweref_e[valid_prv] <- xy2[, "X"]
    prv_sweref_n[valid_prv] <- xy2[, "Y"]
    cat("Provplats coordinates converted:", sum(valid_prv), "row(s).\n")
  }

  # ── 6. Assemble output data frame ────────────────────────────────────────────
  out <- data.frame(
    LOCATION_ID                    = locs$LOCATION_ID,
    ORIGINAL_KOORDINATSYSTEM       = locs$KOORDINATSYSTEM,
    ORIGINAL_STATIONSKOORDINAT_N_X = locs$STATIONSKOORDINAT_N_X,
    ORIGINAL_STATIONSKOORDINAT_E_Y = locs$STATIONSKOORDINAT_E_Y,
    ORIGINAL_PROVPLATSKOORDINAT_N_X = locs$PROVPLATSKOORDINAT_N_X,
    ORIGINAL_PROVPLATSKOORDINAT_E_Y = locs$PROVPLATSKOORDINAT_E_Y,
    EASTING_TRUNCATION_FIXED        = as.integer(!is.na(locs$stn_e) & locs$stn_e < 200000 |
                                                  !is.na(locs$prv_e) & locs$prv_e < 200000),
    NORTHING_TRUNCATION_FIXED       = as.integer(!is.na(locs$stn_n) & locs$stn_n >= 200000 & locs$stn_n < 1e6 |
                                                  !is.na(locs$prv_n) & locs$prv_n >= 200000 & locs$prv_n < 1e6),
    SWEREF99TM_STATIONSKOORDINAT_N = round(stn_sweref_n),
    SWEREF99TM_STATIONSKOORDINAT_E = round(stn_sweref_e),
    SWEREF99TM_PROVPLATSKOORDINAT_N = round(prv_sweref_n),
    SWEREF99TM_PROVPLATSKOORDINAT_E = round(prv_sweref_e),
    SOURCE_CRS                     = source_crs,
    TARGET_CRS                     = target_crs,
    CONVERSION_DATE                = format(Sys.Date(), "%Y-%m-%d"),
    stringsAsFactors               = FALSE
  )

  # ── 7. Write to database ─────────────────────────────────────────────────────
  dbExecute(con, "DROP TABLE IF EXISTS RT90_TO_SWEREF99")

  dbWriteTable(con, "RT90_TO_SWEREF99", out, overwrite = TRUE)

  cat("\nTable RT90_TO_SWEREF99 written with", nrow(out), "row(s).\n")

  # ── 8. Verification query ────────────────────────────────────────────────────
  check <- dbGetQuery(con, "
    SELECT
      COUNT(*)                                          AS total_rows,
      COUNT(SWEREF99TM_STATIONSKOORDINAT_N)             AS stn_converted,
      COUNT(SWEREF99TM_PROVPLATSKOORDINAT_N)            AS prv_converted,
      SUM(EASTING_TRUNCATION_FIXED)                     AS easting_truncation_fixes,
      SUM(NORTHING_TRUNCATION_FIXED)                    AS northing_truncation_fixes
    FROM RT90_TO_SWEREF99
  ")
  cat("\nSummary of RT90_TO_SWEREF99:\n")
  print(check)

  # Preview first few rows
  preview <- dbGetQuery(con, "
    SELECT
      LOCATION_ID,
      ORIGINAL_KOORDINATSYSTEM,
      SWEREF99TM_STATIONSKOORDINAT_N,
      SWEREF99TM_STATIONSKOORDINAT_E,
      EASTING_TRUNCATION_FIXED,
      NORTHING_TRUNCATION_FIXED
    FROM RT90_TO_SWEREF99
    ORDER BY LOCATION_ID
    LIMIT 10
  ")
  cat("\nFirst rows of RT90_TO_SWEREF99:\n")
  print(preview)

}, error = function(e) {
  cat("Error — no changes written.\n")
  stop(e)
}, finally = {
  dbDisconnect(con)
  cat("\nDatabase connection closed.\n")
})
