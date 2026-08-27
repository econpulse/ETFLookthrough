# ==============================================================================
# R/data_loader.R
# Modul zum Laden, Validieren und Bereinigen der ETF-Daten aus Data.xlsx
# Unterstützt Multi-Asset (Aktien & Bonds) sowie Kennzahlen & Währungen
# ==============================================================================

library(readxl)
library(dplyr)
library(tidyr)

# Die 11 offiziellen GICS-Sektoren (Global Industry Classification Standard)
GICS_11_SECTORS <- c(
  "Energy",
  "Materials",
  "Industrials",
  "Consumer Discretionary",
  "Consumer Staples",
  "Health Care",
  "Financials",
  "Information Technology",
  "Communication Services",
  "Utilities",
  "Real Estate"
)

# Standardfarben für die 11 GICS-Sektoren
GICS_SECTOR_COLORS <- c(
  "Energy"                 = "#E6550D", # Warmes Orange/Rot
  "Materials"              = "#74C476", # Frischgrün
  "Industrials"            = "#3182BD", # Stahlblau
  "Consumer Discretionary" = "#FD8D3C", # Helles Orange
  "Consumer Staples"       = "#9ECAE1", # Helles Blau
  "Health Care"            = "#E377C2", # Magenta / Rosa
  "Financials"             = "#2B8CBE", # Dunkelcyan
  "Information Technology" = "#6BAED6", # Tech-Blau
  "Communication Services" = "#BCBD22", # Limettengelb
  "Utilities"              = "#17BECF", # Türkis
  "Real Estate"            = "#8C564B"  # Braun / Terrakotta
)

# Standardfarben für Assetklassen
ASSET_TYPE_COLORS <- c(
  "Aktien"      = "#1E40AF", # LUKB Blau
  "Bonds"       = "#0D9488", # Teal / Petrol
  "Real Estate" = "#8C564B"  # Braun / Terrakotta
)

# Währungsfarben für konsistente Visualisierung
CURRENCY_COLORS <- c(
  "CHF" = "#1E40AF", # Schweizer Franken - Tiefblau
  "USD" = "#0D9488", # US-Dollar - Petrol
  "EUR" = "#0284C7", # Euro - Blau
  "GBP" = "#7C3AED", # Britisches Pfund - Violett
  "JPY" = "#E11D48", # Japanischer Yen - Rot
  "CAD" = "#D97706", # Kanadischer Dollar - Bernstein
  "AUD" = "#059669", # Australischer Dollar - Grün
  "CNY" = "#DC2626", # Chinesischer Yuan - Rot
  "INR" = "#EA580C", # Indische Rupie - Orange
  "HKD" = "#DB2777", # Hongkong-Dollar - Pink
  "SGD" = "#4F46E5", # Singapur-Dollar - Indigo
  "KRW" = "#0891B2", # Südkoreanischer Won - Cyan
  "TWD" = "#65A30D", # Taiwan-Dollar - Limette
  "BRL" = "#16A34A", # Brasilianischer Real - Grün
  "ZAR" = "#B45309", # Südafrikanischer Rand - Braun
  "SAR" = "#047857", # Saudi-Riyal - Dunkelgrün
  "MXN" = "#C026D3", # Mexikanischer Peso - Magenta
  "NA"  = "#9CA3AF"  # Nicht zugewiesen / Unbekannt - Grau
)

#' Hilfsfunktion zur strikten Bereinigung von Währungscodes (nur 3-Buchstaben-Codes)
#' Alle anderen Inhalte (insbes. "Access Denied", Fehlermeldungen, Zahlen, NAs) werden zu NA_character_
clean_currency_code <- function(curr) {
  if (is.null(curr)) return(NA_character_)
  curr <- trimws(as.character(curr))
  
  # Standardisiere bekannte Ausnahmen wie GBp -> GBP, ZAc -> ZAR
  curr <- ifelse(curr == "GBp", "GBP", curr)
  curr <- ifelse(curr == "ZAc", "ZAR", curr)
  
  # In Grossbuchstaben konvertieren
  curr <- toupper(curr)
  
  # Strikt nur exakt 3 Buchstaben (A-Z) akzeptieren
  is_valid <- grepl("^[A-Z]{3}$", curr) & !(curr %in% c("NAN", "NIL"))
  
  curr[!is_valid | is.na(curr)] <- NA_character_
  curr
}

#' Hilfsfunktion zur Bereinigung von Maturity Dates (Excel-Seriennummern & Strings)
clean_maturity_date <- function(val) {
  if (is.null(val)) return(NA_character_)
  val_str <- trimws(as.character(val))
  is_invalid <- is.na(val_str) | grepl("Unable|invalid|#N/A|NULL|^$", val_str, ignore.case = TRUE)
  
  result <- rep(NA_character_, length(val_str))
  
  # Versuche als Zahl (Excel Date Serial Number)
  num_vals <- suppressWarnings(as.numeric(val_str))
  valid_num <- !is_invalid & !is.na(num_vals) & num_vals > 10000 & num_vals < 100000
  if (any(valid_num)) {
    dates <- as.Date(num_vals[valid_num], origin = "1899-12-30")
    result[valid_num] <- format(dates, "%Y-%m-%d")
  }
  
  # Versuche als Datumstext (YYYY-MM-DD oder DD.MM.YYYY)
  text_candidates <- !is_invalid & is.na(result)
  if (any(text_candidates)) {
    parsed_dates <- suppressWarnings(as.Date(val_str[text_candidates]))
    ok <- !is.na(parsed_dates)
    if (any(ok)) {
      result[text_candidates][ok] <- format(parsed_dates[ok], "%Y-%m-%d")
    }
  }
  
  result
}

#' Berechnet Restlaufzeit in Jahren ausgehend vom aktuellen Datum
calc_maturity_years <- function(mat_dates, ref_date = Sys.Date()) {
  if (is.null(mat_dates)) return(NA_real_)
  d <- suppressWarnings(as.Date(mat_dates))
  years <- as.numeric(difftime(d, ref_date, units = "days")) / 365.25
  ifelse(!is.na(years) & years > 0, round(years, 2), NA_real_)
}

#' Berechnet den gewichteten harmonischen Mittelwert (Standard nach MSCI / Morningstar für Multiples wie KGV & KBV)
#' Verhindert Verzerrungen durch Ausreisser und extrem kleine Nenner/Buchwerte
calc_weighted_harmonic <- function(x, w, min_val = 0.01, max_val = Inf) {
  if (is.null(x) || is.null(w) || length(x) == 0 || length(w) == 0) return(NA_real_)
  valid <- !is.na(x) & x > 0 & is.finite(x) & !is.na(w) & w > 0
  if (!any(valid)) return(NA_real_)
  
  x_v <- pmin(pmax(x[valid], min_val), max_val)
  w_v <- w[valid]
  sum_w <- sum(w_v)
  if (sum_w <= 0) return(NA_real_)
  
  sum_w / sum(w_v / x_v)
}

#' Lädt und bereinigt die ETF-Daten aus Data.xlsx (Multi-Asset fähig: Aktien, Bonds, Real Estate)
#' 
#' @param file_path Pfad zur Excel-Datei (Standard: "Data.xlsx")
#' @return Eine Liste mit 'ticker_df', 'data_clean', 'etf_summary', 'raw_row_count', 'clean_row_count', etc.
load_etf_data <- function(file_path = "Data.xlsx") {
  if (!file.exists(file_path)) {
    stop(paste("Datei nicht gefunden:", file_path))
  }
  
  # 1. Metadaten aus Sheet 'ticker' laden
  ticker_raw <- read_excel(file_path, sheet = "ticker")
  
  # Bereinige Ticker-Spalten inkl. asset_type (auch weiter unten liegende Ticker erfassen)
  ticker_df <- ticker_raw %>%
    rename_with(tolower) %>%
    filter(!is.na(ric) & trimws(as.character(ric)) != "") %>%
    mutate(
      ric = trimws(as.character(ric)),
      label = if ("label" %in% names(.)) trimws(as.character(label)) else ric,
      region = if ("region" %in% names(.)) trimws(as.character(region)) else "Global",
      factor = if ("factor" %in% names(.)) trimws(as.character(factor)) else "Standard",
      sector = if ("sector" %in% names(.)) trimws(as.character(sector)) else "All",
      asset_type = if ("asset_type" %in% names(.)) {
        ifelse(is.na(asset_type) | trimws(as.character(asset_type)) == "", "Aktien", trimws(as.character(asset_type)))
      } else {
        "Aktien"
      }
    )
  
  # 2. Holdings aus Sheet 'data' und optional 'Manuell' laden
  sheets_available <- excel_sheets(file_path)
  data_raw <- read_excel(file_path, sheet = "data", skip = 1)
  
  standardize_cols <- function(df) {
    if (ncol(df) >= 1) colnames(df)[1] <- "etf_ric"
    if (ncol(df) >= 2) colnames(df)[2] <- "raw_holding_ric"
    if (ncol(df) >= 3) colnames(df)[3] <- "raw_holding_name"
    if (ncol(df) >= 4) colnames(df)[4] <- "raw_weight"
    if (ncol(df) >= 5) colnames(df)[5] <- "raw_sector"
    if (ncol(df) >= 6) colnames(df)[6] <- "raw_div_yield"
    if (ncol(df) >= 7) colnames(df)[7] <- "raw_pb"
    if (ncol(df) >= 8) colnames(df)[8] <- "raw_pe"
    if (ncol(df) >= 9) colnames(df)[9] <- "raw_ytm"
    if (ncol(df) >= 10) colnames(df)[10] <- "raw_mod_duration"
    if (ncol(df) >= 11) colnames(df)[11] <- "raw_maturity_date"
    if (ncol(df) >= 12) colnames(df)[12] <- "raw_ccy"
    if (ncol(df) >= 13) colnames(df)[13] <- "raw_currency_code"
    df
  }
  
  data_raw <- standardize_cols(data_raw)
  
  if ("Manuell" %in% sheets_available) {
    manuell_raw <- read_excel(file_path, sheet = "Manuell")
    manuell_raw <- standardize_cols(manuell_raw)
    data_raw <- bind_rows(data_raw, manuell_raw)
  }
  
  raw_row_count <- nrow(data_raw)
  
  # 3. Zweistufige Währungsbereinigung:
  # Wenn Ccy (Spalte 12) nicht valide ist (z.B. "Access Denied"), Fallback auf Currency Code (Spalte 13)
  ccy1 <- if ("raw_ccy" %in% names(data_raw)) clean_currency_code(data_raw$raw_ccy) else rep(NA_character_, nrow(data_raw))
  ccy2 <- if ("raw_currency_code" %in% names(data_raw)) clean_currency_code(data_raw$raw_currency_code) else rep(NA_character_, nrow(data_raw))
  currency_combined <- ifelse(!is.na(ccy1), ccy1, ccy2)
  
  # 4. Vorbereiten und Verknüpfen mit Metadaten
  data_prep <- data_raw %>%
    mutate(
      etf_ric = trimws(as.character(etf_ric)),
      holding_ric = trimws(as.character(raw_holding_ric)),
      holding_name = trimws(as.character(raw_holding_name)),
      raw_sector = if ("raw_sector" %in% names(.)) trimws(as.character(raw_sector)) else NA_character_,
      weight_raw = suppressWarnings(as.numeric(raw_weight)),
      div_yield = if ("raw_div_yield" %in% names(.)) suppressWarnings(as.numeric(raw_div_yield)) else NA_real_,
      pb = if ("raw_pb" %in% names(.)) suppressWarnings(as.numeric(raw_pb)) else NA_real_,
      pe = if ("raw_pe" %in% names(.)) suppressWarnings(as.numeric(raw_pe)) else NA_real_,
      ytm = if ("raw_ytm" %in% names(.)) suppressWarnings(as.numeric(raw_ytm)) else NA_real_,
      mod_duration = if ("raw_mod_duration" %in% names(.)) suppressWarnings(as.numeric(raw_mod_duration)) else NA_real_,
      maturity_date = if ("raw_maturity_date" %in% names(.)) clean_maturity_date(raw_maturity_date) else NA_character_,
      currency = currency_combined
    ) %>%
    mutate(
      maturity_years = calc_maturity_years(maturity_date)
    ) %>%
    left_join(
      ticker_df %>% select(ric, etf_label = label, etf_region = region, asset_type),
      by = c("etf_ric" = "ric")
    ) %>%
    mutate(
      asset_type = ifelse(is.na(asset_type), "Aktien", asset_type),
      etf_label = ifelse(is.na(etf_label), etf_ric, etf_label)
    )
  
  # 5. Differenzierte Bereinigung nach Assetklasse
  clean_akten <- data_prep %>%
    filter(
      asset_type == "Aktien",
      !is.na(holding_ric) & holding_ric != "" & holding_ric != "NULL",
      !is.na(raw_sector) & raw_sector %in% GICS_11_SECTORS,
      !is.na(weight_raw) & weight_raw > 0
    ) %>%
    mutate(
      gics_sector = raw_sector,
      ytm = NA_real_,
      mod_duration = NA_real_,
      maturity_date = NA_character_,
      maturity_years = NA_real_
    )
  
  clean_bonds <- data_prep %>%
    filter(
      asset_type == "Bonds",
      !is.na(holding_ric) & holding_ric != "" & holding_ric != "NULL",
      !grepl("invalid|Unable|CASH|FEES|OTHER ASSETS|OTHER LIAB", holding_name, ignore.case = TRUE),
      !is.na(weight_raw) & weight_raw > 0
    ) %>%
    mutate(
      gics_sector = NA_character_,
      div_yield = NA_real_,
      pe = NA_real_,
      pb = NA_real_
    )
  
  clean_real_estate <- data_prep %>%
    filter(
      asset_type == "Real Estate",
      !is.na(holding_ric) & holding_ric != "" & holding_ric != "NULL",
      !grepl("invalid|Unable|CASH|FEES|OTHER ASSETS|OTHER LIAB|FOREX", holding_name, ignore.case = TRUE),
      !is.na(weight_raw) & weight_raw > 0
    ) %>%
    mutate(
      gics_sector = "Real Estate",
      currency = ifelse(is.na(currency) & (grepl("\\.S$", holding_ric) | etf_ric == "LP68082242"), "CHF", currency),
      ytm = NA_real_,
      mod_duration = NA_real_,
      maturity_date = NA_character_,
      maturity_years = NA_real_
    )

  clean_cash <- data_prep %>%
    filter(
      asset_type == "Cash",
      !is.na(holding_ric) & holding_ric != "" & holding_ric != "NULL",
      !is.na(weight_raw) & weight_raw > 0
    ) %>%
    mutate(
      gics_sector = NA_character_,
      div_yield = NA_real_,
      pe = NA_real_,
      pb = NA_real_,
      ytm = NA_real_,
      mod_duration = NA_real_,
      maturity_date = NA_character_,
      maturity_years = NA_real_,
      currency = ifelse(is.na(currency) | currency == "", "CHF", currency)
    )

  clean_rohstoffe <- data_prep %>%
    filter(
      asset_type == "Rohstoffe",
      !is.na(holding_ric) & holding_ric != "" & holding_ric != "NULL",
      !is.na(weight_raw) & weight_raw > 0
    ) %>%
    mutate(
      gics_sector = NA_character_,
      div_yield = NA_real_,
      pe = NA_real_,
      pb = NA_real_,
      ytm = NA_real_,
      mod_duration = NA_real_,
      maturity_date = NA_character_,
      maturity_years = NA_real_,
      currency = ifelse(is.na(currency) | currency == "", "USD", currency)
    )
  
  # Kombinierter bereinigter Datensatz
  data_clean <- bind_rows(clean_akten, clean_bonds, clean_real_estate, clean_cash, clean_rohstoffe) %>%
    select(
      etf_ric, etf_label, etf_region, asset_type,
      holding_ric, holding_name, gics_sector,
      weight_raw, div_yield, pb, pe, ytm, mod_duration, maturity_date, maturity_years, currency
    )
  
  # Normalisierte Gewichte berechnen (auf 100% innerhalb jedes ETF skaliert)
  data_clean <- data_clean %>%
    group_by(etf_ric) %>%
    mutate(
      etf_total_raw_weight = sum(weight_raw, na.rm = TRUE),
      weight_norm = (weight_raw / sum(weight_raw, na.rm = TRUE)) * 100
    ) %>%
    ungroup()
  
  # Zusammenfassung pro ETF
  etf_summary <- data_clean %>%
    group_by(etf_ric, etf_label, asset_type, etf_region) %>%
    summarise(
      n_holdings = n(),
      raw_weight_sum = sum(weight_raw, na.rm = TRUE),
      n_sectors = n_distinct(gics_sector, na.rm = TRUE),
      avg_div_yield = if (any(!is.na(div_yield))) weighted.mean(div_yield, weight_raw, na.rm = TRUE) else NA_real_,
      avg_pe = calc_weighted_harmonic(pe, weight_raw, min_val = 1.0),
      avg_pb = calc_weighted_harmonic(pb, weight_raw, min_val = 0.1),
      avg_ytm = if (any(!is.na(ytm))) weighted.mean(ytm, weight_raw, na.rm = TRUE) else NA_real_,
      avg_mod_duration = if (any(!is.na(mod_duration))) weighted.mean(mod_duration, weight_raw, na.rm = TRUE) else NA_real_,
      avg_maturity_years = if (any(!is.na(maturity_years))) weighted.mean(maturity_years, weight_raw, na.rm = TRUE) else NA_real_,
      top_holding = holding_name[which.max(weight_raw)],
      top_holding_weight = max(weight_raw),
      .groups = "drop"
    )
  
  ignored_row_count <- raw_row_count - nrow(data_clean)
  
  list(
    ticker_df = ticker_df,
    data_clean = data_clean,
    etf_summary = etf_summary,
    raw_row_count = raw_row_count,
    clean_row_count = nrow(data_clean),
    ignored_row_count = ignored_row_count,
    available_etfs = unique(data_clean$etf_ric)
  )
}
