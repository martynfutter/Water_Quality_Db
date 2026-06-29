# =============================================================================
# plot_year_limiting_factors.R
#
# Reads vw_year_limiting_factors from water_quality.db and produces a
# two-panel figure:
#
#   Panel A (top)    : Stacked proportions (% N, % P, % NP) by year
#   Panel B (bottom) : Sample counts by limiting factor (bar height = total)
#
# Panel A proportions are derived in R from the raw counts in Panel B,
# dividing each limiting factor count by (N_COUNT + P_COUNT + NP_COUNT).
# This avoids the denominator inflation that occurs in the SQL view when
# both INORGANIC and TOTAL N_FORM rows exist for the same sample, which
# caused proportions not to sum to 100% for some years.
#
# Required packages: DBI, RSQLite, ggplot2, tidyr, dplyr, patchwork, scales
# Install if needed:
#   install.packages(c("DBI", "RSQLite", "ggplot2", "tidyr", "dplyr",
#                      "patchwork", "scales"))
# =============================================================================

library(DBI)
library(RSQLite)
library(ggplot2)
library(tidyr)
library(dplyr)
library(patchwork)
library(scales)

# ── 1. Configuration ──────────────────────────────────────────────────────────
db_path     <- "water_quality.db"   # adjust path if needed
output_dir  <- "plots"
output_file <- file.path(output_dir, "year_limiting_factors.png")

lf_colours <- c(
  "N"  = "#d7191c",
  "P"  = "#2c7bb6",
  "NP" = "#1a9641"
)

# ── 2. Connect and fetch raw counts ───────────────────────────────────────────
cat("Connecting to database:", db_path, "\n")
con <- dbConnect(RSQLite::SQLite(), db_path)

df <- dbGetQuery(con, "
  SELECT
    PROVTAGNINGSAR,
    N_COUNT,
    P_COUNT,
    NP_COUNT,
    TOTAL_COUNT
  FROM vw_year_limiting_factors
  ORDER BY PROVTAGNINGSAR
")

dbDisconnect(con)
cat("Rows fetched:", nrow(df), "\n")

# ── 3. Derive proportions in R from N + P + NP counts only ───────────────────
# This deliberately ignores TOTAL_COUNT from the view, which is inflated in
# years where both INORGANIC and TOTAL N_FORM rows exist for the same sample.
# NAs in count columns (years where a limiting factor has no samples at all)
# are replaced with 0 before summing, otherwise the CLASSIFIABLE total and
# the derived proportions become NA and ggplot silently drops the segment,
# causing bars not to reach 100%.
df <- df |>
  mutate(
    N_COUNT  = coalesce(N_COUNT,  0L),
    P_COUNT  = coalesce(P_COUNT,  0L),
    NP_COUNT = coalesce(NP_COUNT, 0L),
    CLASSIFIABLE = N_COUNT + P_COUNT + NP_COUNT,
    PCT_N  = ifelse(CLASSIFIABLE > 0, N_COUNT  / CLASSIFIABLE * 100, 0),
    PCT_P  = ifelse(CLASSIFIABLE > 0, P_COUNT  / CLASSIFIABLE * 100, 0),
    PCT_NP = ifelse(CLASSIFIABLE > 0, NP_COUNT / CLASSIFIABLE * 100, 0)
  )

# ── 4. Reshape to long format ─────────────────────────────────────────────────
lf_levels <- c("N", "NP", "P")   # stacking order: N at base, P at top

long_counts <- df |>
  pivot_longer(
    cols      = c(N_COUNT, NP_COUNT, P_COUNT),
    names_to  = "LIMITING_FACTOR",
    values_to = "COUNT"
  ) |>
  mutate(
    LIMITING_FACTOR = recode(LIMITING_FACTOR,
                             N_COUNT  = "N",
                             P_COUNT  = "P",
                             NP_COUNT = "NP"),
    LIMITING_FACTOR = factor(LIMITING_FACTOR, levels = lf_levels)
  )

long_pct <- df |>
  pivot_longer(
    cols      = c(PCT_N, PCT_NP, PCT_P),
    names_to  = "LIMITING_FACTOR",
    values_to = "PROPORTION"
  ) |>
  mutate(
    LIMITING_FACTOR = recode(LIMITING_FACTOR,
                             PCT_N  = "N",
                             PCT_P  = "P",
                             PCT_NP = "NP"),
    LIMITING_FACTOR = factor(LIMITING_FACTOR, levels = lf_levels)
  )

# ── 5. Common theme and scales ────────────────────────────────────────────────
base_theme <- theme_bw(base_size = 11) +
  theme(
    plot.title         = element_text(face = "bold", size = 11),
    axis.text.x        = element_text(angle = 45, hjust = 1),
    panel.grid.major.x = element_blank(),
    panel.grid.minor   = element_blank(),
    legend.position    = "bottom",
    legend.title       = element_text(size = 9),
    legend.text        = element_text(size = 9)
  )

x_scale <- scale_x_continuous(
  breaks = seq(min(df$PROVTAGNINGSAR), max(df$PROVTAGNINGSAR), by = 5)
)

lf_fill <- scale_fill_manual(
  values = lf_colours,
  name   = "Limiting factor",
  labels = c("N" = "N-limited", "NP" = "NP co-limited", "P" = "P-limited")
)

# ── 6. Panel A – stacked proportions derived from counts ─────────────────────

# Diagnostic: identify any rows that will cause ggplot warnings
problem_rows <- long_pct |> filter(is.na(PROPORTION) | PROPORTION < 0 | PROPORTION > 100)
if (nrow(problem_rows) > 0) {
  cat("WARNING:", nrow(problem_rows), "problematic rows in long_pct:\n")
  print(problem_rows)
} else {
  cat("All proportion rows look clean.\n")
}

pA <- ggplot(long_pct, aes(x = PROVTAGNINGSAR, y = PROPORTION,
                            fill = LIMITING_FACTOR)) +
  geom_col(width = 0.8, position = "stack") +
  x_scale +
  scale_y_continuous(
    expand = expansion(mult = c(0, 0.02)),
    labels = label_percent(scale = 1),
    oob    = scales::squish          # squish values slightly outside range
  ) +
  lf_fill +
  labs(
    title = "A  Proportion of samples by limiting factor",
    x     = NULL,
    y     = "Proportion (%)"
  ) +
  base_theme

# ── 7. Panel B – raw counts ───────────────────────────────────────────────────
pB <- ggplot(long_counts, aes(x = PROVTAGNINGSAR, y = COUNT,
                               fill = LIMITING_FACTOR)) +
  geom_col(width = 0.8, position = "stack") +
  x_scale +
  scale_y_continuous(
    expand = expansion(mult = c(0, 0.05)),
    labels = label_comma()
  ) +
  lf_fill +
  labs(
    title   = "B  Sample counts by limiting factor  (bar height = total samples)",
    x       = "Year",
    y       = "Number of samples",
    caption = "Proportions in Panel A derived from N_COUNT + P_COUNT + NP_COUNT"
  ) +
  base_theme

# ── 8. Compose & save ─────────────────────────────────────────────────────────
combined <- pA / pB +
  plot_layout(guides = "collect") &
  theme(legend.position = "bottom")

if (!dir.exists(output_dir)) dir.create(output_dir)

ggsave(output_file, plot = combined, width = 11, height = 9, dpi = 150)
cat("Plot saved to:", output_file, "\n")
