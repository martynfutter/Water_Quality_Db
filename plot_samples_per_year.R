# plot_samples_per_year.R
#
# Reads vw_samples_per_year from water_quality.db and produces a bar chart
# of samples per calendar year.
#
# Required packages: DBI, RSQLite, ggplot2
# Install if needed:
#   install.packages(c("DBI", "RSQLite", "ggplot2"))

library(DBI)
library(RSQLite)
library(ggplot2)

# ── Configuration ─────────────────────────────────────────────────────────────
db_path     <- "water_quality.db"   # adjust path if needed
output_dir  <- "plots"
output_file <- file.path(output_dir, "samples_per_year.png")

# ── Connect and fetch ─────────────────────────────────────────────────────────
cat("Connecting to database:", db_path, "\n")
con <- dbConnect(RSQLite::SQLite(), db_path)

df <- dbGetQuery(con, "SELECT * FROM vw_samples_per_year ORDER BY PROVTAGNINGSAR")

dbDisconnect(con)
cat("Rows fetched:", nrow(df), "\n")

# ── Plot ───────────────────────────────────────────────────────────────────────
p <- ggplot(df, aes(x = PROVTAGNINGSAR, y = N_SAMPLES_USE_Y)) +
  geom_col(fill = "#2c7bb6", width = 0.7) +
  scale_x_continuous(breaks = seq(min(df$PROVTAGNINGSAR),
                                   max(df$PROVTAGNINGSAR), by = 5)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
  labs(
    title    = "Number of samples per calendar year",
    subtitle = "Retained samples only (USE_SAMPLE = 'Y')",
    x        = "Year",
    y        = "Number of samples"
  ) +
  theme_bw() +
  theme(
    plot.title    = element_text(face = "bold", size = 13),
    plot.subtitle = element_text(size = 10, colour = "grey40"),
    axis.text.x   = element_text(angle = 45, hjust = 1),
    panel.grid.major.x = element_blank(),
    panel.grid.minor   = element_blank()
  )

# ── Save ───────────────────────────────────────────────────────────────────────
if (!dir.exists(output_dir)) dir.create(output_dir)

ggsave(output_file, plot = p, width = 10, height = 6, dpi = 150)
cat("Plot saved to:", output_file, "\n")
