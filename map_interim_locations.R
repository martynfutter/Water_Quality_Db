# map_interim_locations.R
#
# Reads INTERIM_LOCATIONS from water_quality.db and plots the sampling
# locations on a map of Sweden.
#
# Coordinates in the database are stored as text and are in SWEREF99TM (EPSG:3006).
# These are converted to numeric then reprojected to WGS84 (EPSG:4326) for mapping.
#
# Required packages:
#   install.packages(c("DBI", "RSQLite", "sf", "ggplot2", "rnaturalearth",
#                      "rnaturalearthdata", "ggrepel"))

library(DBI)
library(RSQLite)
library(sf)
library(ggplot2)
library(rnaturalearth)
library(rnaturalearthdata)

# ── Configuration ─────────────────────────────────────────────────────────────
db_path     <- "water_quality.db"   # adjust path if needed
output_dir  <- "plots"
output_file <- file.path(output_dir, "map_interim_locations.png")

# ── 1. Connect and fetch INTERIM_LOCATIONS ────────────────────────────────────
cat("Connecting to database:", db_path, "\n")
con <- dbConnect(RSQLite::SQLite(), db_path)

locations <- dbGetQuery(con, "
  SELECT
    LOCATION_ID,
    OVERVAKNINGSSTATION,
    STATIONSKOORDINAT_N_X,
    STATIONSKOORDINAT_E_Y,
    PROVPLATS,
    PROVPLATSKOORDINAT_N_X,
    PROVPLATSKOORDINAT_E_Y,
    KOORDINATSYSTEM,
    PROVTAGNINGSMEDIUM
  FROM INTERIM_LOCATIONS
")

dbDisconnect(con)
cat("Rows fetched from INTERIM_LOCATIONS:", nrow(locations), "\n")

# ── 2. Remove dummy rows ──────────────────────────────────────────────────────
locations <- locations[!grepl("^Dummy data$", locations$PROVTAGNINGSMEDIUM, ignore.case = TRUE), ]
cat("Rows after removing Dummy data:", nrow(locations), "\n")

# ── 3. Convert coordinate columns to numeric (stored as text in DB) ───────────
coord_cols <- c("STATIONSKOORDINAT_N_X", "STATIONSKOORDINAT_E_Y",
                "PROVPLATSKOORDINAT_N_X", "PROVPLATSKOORDINAT_E_Y")
locations[coord_cols] <- lapply(locations[coord_cols], function(x) {
  suppressWarnings(as.numeric(x))
})

# ── 4. Choose which coordinate pair to use ────────────────────────────────────
# Prefer station coords; fall back to sampling-point coords if station is
# -999.9 (placeholder) or NA.
locations$easting <- ifelse(
  !is.na(locations$STATIONSKOORDINAT_E_Y) & locations$STATIONSKOORDINAT_E_Y > 0,
  locations$STATIONSKOORDINAT_E_Y,
  locations$PROVPLATSKOORDINAT_E_Y
)
locations$northing <- ifelse(
  !is.na(locations$STATIONSKOORDINAT_N_X) & locations$STATIONSKOORDINAT_N_X > 0,
  locations$STATIONSKOORDINAT_N_X,
  locations$PROVPLATSKOORDINAT_N_X
)

# Drop rows where both coordinate pairs are missing / placeholder / NA
valid <- !is.na(locations$easting)  & locations$easting  > 0 &
         !is.na(locations$northing) & locations$northing > 0

cat("Locations with valid coordinates:", sum(valid), "of", nrow(locations), "\n")
cat("Locations dropped (no valid coords):", sum(!valid), "\n")

locations <- locations[valid, ]

if (nrow(locations) == 0) stop("No rows with valid coordinates — check the database.")

# ── 5. Reproject SWEREF99TM -> WGS84 ─────────────────────────────────────────
pts_sweref <- st_as_sf(
  locations,
  coords = c("easting", "northing"),
  crs    = 3006   # SWEREF99TM
)

pts_wgs84 <- st_transform(pts_sweref, crs = 4326)

# Attach lon/lat back to the data frame for ggplot
coords_wgs <- st_coordinates(pts_wgs84)
locations$lon <- coords_wgs[, 1]
locations$lat <- coords_wgs[, 2]

cat("Coordinate range — Lon:", round(range(locations$lon), 3),
    "  Lat:", round(range(locations$lat), 3), "\n")

# ── 6. Get Sweden base map ────────────────────────────────────────────────────
sweden <- ne_countries(scale = "medium", country = "Sweden", returnclass = "sf")

# ── 7. Build the map ──────────────────────────────────────────────────────────
p_map <- ggplot() +
  # Sweden outline
  geom_sf(data = sweden, fill = "grey92", colour = "grey60", linewidth = 0.4) +
  # Sampling locations
  geom_point(
    data   = locations,
    aes(x  = lon, y = lat),
    colour = "#2166AC",
    size   = 2.5,
    alpha  = 0.80
  ) +
  # Labels for stations (only if <= 40 locations to avoid overplotting)
  {if (nrow(locations) <= 40)
    ggrepel::geom_text_repel(
      data         = locations,
      aes(x = lon, y = lat, label = OVERVAKNINGSSTATION),
      size         = 2.5,
      max.overlaps = 20,
      colour       = "grey20"
    )
  } +
  coord_sf(
    xlim   = c(10, 25),
    ylim   = c(55, 70),
    expand = FALSE
  ) +
  labs(
    title    = "INTERIM_LOCATIONS \u2014 Sampling Sites",
    subtitle = paste0(nrow(locations), " location(s) plotted"),
    x        = "Longitude",
    y        = "Latitude",
    caption  = "Coordinates reprojected from SWEREF99TM (EPSG:3006) to WGS84"
  ) +
  theme_bw(base_size = 11) +
  theme(
    plot.title    = element_text(face = "bold", hjust = 0.5),
    plot.subtitle = element_text(hjust = 0.5, colour = "grey40")
  )

# ── 8. Save output ────────────────────────────────────────────────────────────
if (!dir.exists(output_dir)) dir.create(output_dir)

ggsave(output_file, plot = p_map, width = 7, height = 10, dpi = 300)
cat("Map saved to:", output_file, "\n")

# Also display interactively if running in RStudio
print(p_map)
