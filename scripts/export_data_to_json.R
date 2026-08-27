# ==============================================================================
# scripts/export_data_to_json.R
# Konvertiert Data.xlsx in strukturierte JSON- und JS-Dateien unter web/data/
# Unterstützt sowohl Webserver (JSON) als auch Direktklick im Browser (JS)
# ==============================================================================

suppressPackageStartupMessages({
  library(jsonlite)
  library(dplyr)
})

source("R/data_loader.R")

cat(">> Lade und bereinige Data.xlsx...\n")
loaded <- load_etf_data("Data.xlsx")

# Zielverzeichnis erstellen
if (!dir.exists("web/data")) {
  dir.create("web/data", recursive = TRUE)
}

# Korrelationsmatrix in geschachtelte Liste konvertieren
corr_list <- list()
if (!is.null(loaded$corr_matrix) && nrow(loaded$corr_matrix) > 0) {
  r_names <- rownames(loaded$corr_matrix)
  c_names <- colnames(loaded$corr_matrix)
  for (i in seq_along(r_names)) {
    row_map <- list()
    for (j in seq_along(c_names)) {
      row_map[[c_names[j]]] <- loaded$corr_matrix[i, j]
    }
    corr_list[[r_names[i]]] <- row_map
  }
}

# Struktur für die Web-App vorbereiten
export_payload <- list(
  metadata = list(
    generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    total_etfs = length(loaded$available_etfs),
    raw_row_count = loaded$raw_row_count,
    clean_row_count = loaded$clean_row_count,
    ignored_row_count = loaded$ignored_row_count,
    gics_sectors = GICS_11_SECTORS
  ),
  tickers = loaded$ticker_df,
  correlations = corr_list,
  etf_summary = loaded$etf_summary,
  holdings = loaded$data_clean
)

# 1. Als JSON schreiben
json_path <- "web/data/etf_data.json"
cat(">> Schreibe JSON nach", json_path, "...\n")
json_text <- toJSON(export_payload, pretty = TRUE, auto_unbox = TRUE, digits = 6, na = "null")
writeLines(json_text, json_path)

# 2. Als JS schreiben (für direkten Doppelklick ohne Server!)
js_path <- "web/data/etf_data.js"
cat(">> Schreibe JS nach", js_path, " (fuer Direktstart via file://)...\n")
writeLines(paste0("window.ETF_DATA = ", json_text, ";"), js_path)

# Standard-Portfolios kopieren & als JS bereitstellen
if (file.exists("saved_portfolios.json")) {
  file.copy("saved_portfolios.json", "web/data/saved_portfolios.json", overwrite = TRUE)
  port_text <- readLines("saved_portfolios.json", warn = FALSE)
  writeLines(paste0("window.SAVED_PORTFOLIOS = ", paste(port_text, collapse = "\n"), ";"), "web/data/saved_portfolios.js")
  cat(">> saved_portfolios.js nach web/data/ geschrieben.\n")
}

cat(">> Export erfolgreich abgeschlossen!\n")
