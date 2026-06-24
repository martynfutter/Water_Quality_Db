# =============================================================================
# map_limiting_factors.R
#
# Produces a 4-panel map of Sweden from vw_locations_limiting_factors:
#
#   Top-left  : % N-limited  (N_COUNT / total × 100)
#   Top-right : Average total phosphorus (AVG_TOTAL_PHOSPHORUS, µg/l P)
#   Bottom-left  : % P-limited
#   Bottom-right : % NP co-limited
#
# Coordinates are in SWEREF99TM (EPSG:3006).
#
# Required packages:
#   install.packages(c("DBI","RSQLite","sf","ggplot2","patchwork",
#                      "scales","rnaturalearth","rnaturalearthdata"))
# =============================================================================

library(DBI)
library(RSQLite)
library(sf)
library(ggplot2)
library(patchwork)
library(scales)
library(rnaturalearth)
library(rnaturalearthdata)

# ── 1. Configuration ──────────────────────────────────────────────────────────
db_path <- "water_quality.db"   # <-- adjust path if needed

# ── 2. Query the view ─────────────────────────────────────────────────────────
con <- dbConnect(RSQLite::SQLite(), db_path)

df <- dbGetQuery(con, "
  SELECT
    LOCATION_ID,
    OVERVAKNINGSSTATION,
    STATIONSKOORDINAT_N_X   AS northing,
    STATIONSKOORDINAT_E_Y   AS easting,
    N_COUNT,
    P_COUNT,
    NP_COUNT,
    AVG_TOTAL_PHOSPHORUS
  FROM vw_locations_limiting_factors
  WHERE STATIONSKOORDINAT_N_X IS NOT NULL
    AND STATIONSKOORDINAT_E_Y IS NOT NULL
")

dbDisconnect(con)

cat("Rows retrieved:", nrow(df), "\n")

# ── 3. Derive proportions ─────────────────────────────────────────────────────
df$TOTAL_COUNT <- df$N_COUNT + df$P_COUNT + df$NP_COUNT

df$PCT_N  <- ifelse(df$TOTAL_COUNT > 0, df$N_COUNT  / df$TOTAL_COUNT * 100, NA)
df$PCT_P  <- ifelse(df$TOTAL_COUNT > 0, df$P_COUNT  / df$TOTAL_COUNT * 100, NA)
df$PCT_NP <- ifelse(df$TOTAL_COUNT > 0, df$NP_COUNT / df$TOTAL_COUNT * 100, NA)

# ── 4. Convert to sf (SWEREF99TM = EPSG:3006) ─────────────────────────────────
pts <- st_as_sf(
  df,
  coords = c("easting", "northing"),
  crs    = 3006
)

# ── 5. Sweden base map ────────────────────────────────────────────────────────
sweden_raw <- ne_countries(scale = "medium", country = "Sweden", returnclass = "sf")
sweden     <- st_transform(sweden_raw, crs = 3006)

# Bounding box in SWEREF99TM (covers mainland Sweden + Gotland)
xlim_sweref <- c(260000, 920000)
ylim_sweref <- c(6140000, 7700000)

# ── 6. Common theme elements ──────────────────────────────────────────────────
base_theme <- theme_void(base_size = 11) +
  theme(
    plot.title      = element_text(size = 11, face = "bold", hjust = 0.5,
                                   margin = margin(b = 4)),
    legend.position = "bottom",
    legend.title    = element_text(size = 8),
    legend.text     = element_text(size = 7),
    legend.key.width  = unit(1.8, "cm"),
    legend.key.height = unit(0.35, "cm"),
    plot.margin     = margin(4, 4, 4, 4)
  )

sweden_layer <- list(
  geom_sf(data = sweden, fill = "grey92", colour = "grey60", linewidth = 0.3),
  coord_sf(xlim = xlim_sweref, ylim = ylim_sweref, expand = FALSE)
)

pt_size  <- 1.8
pt_shape <- 21       # filled circle with border
pt_stroke <- 0.2
pt_colour <- "grey30"

# ── 7. Panel A – % N-limited ──────────────────────────────────────────────────
pA <- ggplot() +
  sweden_layer +
  geom_sf(
    data   = pts,
    aes(fill = PCT_N),
    shape  = pt_shape,
    size   = pt_size,
    stroke = pt_stroke,
    colour = pt_colour
  ) +
  scale_fill_distiller(
    palette  = "YlOrRd",
    direction = 1,
    name     = "% N-limited",
    limits   = c(0, 100),
    breaks   = c(0, 25, 50, 75, 100),
    na.value = "white"
  ) +
  labs(title = "% N-limited") +
  base_theme

# ── 8. Panel B – Average total phosphorus (upper right) ──────────────────────
pB <- ggplot() +
  sweden_layer +
  geom_sf(
    data   = pts,
    aes(fill = AVG_TOTAL_PHOSPHORUS),
    shape  = pt_shape,
    size   = pt_size,
    stroke = pt_stroke,
    colour = pt_colour
  ) +
  scale_fill_distiller(
    palette   = "Blues",
    direction = 1,
    name      = "Avg TP (µg/l P)",
    trans     = "sqrt",           # sqrt transform to handle skew
    breaks    = c(5, 20, 50, 100, 200),
    labels    = label_comma(),
    na.value  = "white"
  ) +
  labs(title = "Average Total Phosphorus") +
  base_theme

# ── 9. Panel C – % P-limited ─────────────────────────────────────────────────
pC <- ggplot() +
  sweden_layer +
  geom_sf(
    data   = pts,
    aes(fill = PCT_P),
    shape  = pt_shape,
    size   = pt_size,
    stroke = pt_stroke,
    colour = pt_colour
  ) +
  scale_fill_distiller(
    palette   = "Greens",
    direction = 1,
    name      = "% P-limited",
    limits    = c(0, 100),
    breaks    = c(0, 25, 50, 75, 100),
    na.value  = "white"
  ) +
  labs(title = "% P-limited") +
  base_theme

# ── 10. Panel D – % NP co-limited ────────────────────────────────────────────
pD <- ggplot() +
  sweden_layer +
  geom_sf(
    data   = pts,
    aes(fill = PCT_NP),
    shape  = pt_shape,
    size   = pt_size,
    stroke = pt_stroke,
    colour = pt_colour
  ) +
  scale_fill_distiller(
    palette   = "Purples",
    direction = 1,
    name      = "% NP co-limited",
    limits    = c(0, 100),
    breaks    = c(0, 25, 50, 75, 100),
    na.value  = "white"
  ) +
  labs(title = "% NP co-limited") +
  base_theme

# ── 11. Compose & save ────────────────────────────────────────────────────────
# Layout: top-left = B (TP), top-right = A (N), bottom-left = C (P), bottom-right = D (NP)
combined <- (pB | pA) / (pC | pD) +
  plot_annotation(
    title    = "Nutrient Limitation and Phosphorus at Swedish Monitoring Stations",
    theme    = theme(plot.title = element_text(size = 13, face = "bold", hjust = 0.5,
                                               margin = margin(b = 6)))
  )

out_path <- "plots/map_limiting_factors.png"
dir.create("plots", showWarnings = FALSE)

ggsave(
  filename = out_path,
  plot     = combined,
  width    = 10,
  height   = 13,
  dpi      = 300,
  bg       = "white"
)

cat("Figure saved to:", out_path, "\n")
