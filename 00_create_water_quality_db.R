# create_water_quality_db.R
#
# Reads Short.xlsx and creates a SQLite database (water_quality.db) with
# one table (RAW_DATA) mirroring the spreadsheet's column structure.
#
# Required packages: readxl, DBI, RSQLite
# Install if needed:
#   install.packages(c("readxl", "DBI", "RSQLite"))

library(readxl)
library(DBI)
library(RSQLite)

# ── Configuration ─────────────────────────────────────────────────────────────
xlsx_path <- ".xlsx"   # path to your Excel file
db_path   <- "water_quality.db"
table_name <- "RAW_DATA"

# ── Read Excel ────────────────────────────────────────────────────────────────
cat("Reading", xlsx_path, "...\n")
df <- read_excel(xlsx_path, sheet = 1, col_types = "text")  # read all as text
                                                             # to preserve values like "<0.5"
cat(sprintf("  %d rows x %d columns read.\n", nrow(df), ncol(df)))

# ── Sanitise column names for SQLite ─────────────────────────────────────────
# SQLite accepts almost any name when quoted, but we'll keep them readable.
# Strategy: replace characters that are awkward in SQL with underscores,
#           collapse runs of underscores, strip leading/trailing underscores.
sanitise <- function(x) {
  x <- iconv(x, to = "UTF-8")           # ensure UTF-8
  x <- gsub("[()°µ/,+]", "_", x)        # replace common special chars
  x <- gsub("[[:space:]]+", "_", x)     # spaces → underscore
  x <- gsub("_+", "_", x)               # collapse runs
  x <- gsub("^_|_$", "", x)             # strip leading/trailing
  x
}

original_names  <- colnames(df)
sanitised_names <- sanitise(original_names)

# Guard against duplicates after sanitising
sanitised_names <- make.unique(sanitised_names, sep = "_")

colnames(df) <- sanitised_names

cat("Column name mapping (original → SQLite):\n")
for (i in seq_along(original_names)) {
  cat(sprintf("  %-45s → %s\n", original_names[i], sanitised_names[i]))
}

# ── Connect / create database ─────────────────────────────────────────────────
if (file.exists(db_path)) {
  cat("\nDatabase", db_path, "already exists — it will be overwritten.\n")
  file.remove(db_path)
}

con <- dbConnect(RSQLite::SQLite(), db_path)
cat("Connected to", db_path, "\n")

# ── Write table ───────────────────────────────────────────────────────────────
# All columns are TEXT (we read everything as text above to preserve
# detection-limit strings such as "<0.5").  Numeric conversion can be
# done later via the update_water_quality_db.R workflow.
dbWriteTable(con, table_name, df, overwrite = TRUE)

cat(sprintf("\nTable '%s' created with %d rows and %d columns.\n",
            table_name, nrow(df), ncol(df)))

# ── Verify ────────────────────────────────────────────────────────────────────
info <- dbGetQuery(con, sprintf("PRAGMA table_info('%s')", table_name))
cat("\nSQLite column list:\n")
print(info[, c("cid", "name", "type")])

row_count <- dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM '%s'", table_name))
cat(sprintf("\nRow count in table: %d\n", row_count$n))

# ── Close ─────────────────────────────────────────────────────────────────────
dbDisconnect(con)
cat("Done. Database written to:", db_path, "\n")
