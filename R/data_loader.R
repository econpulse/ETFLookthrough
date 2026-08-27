# ==============================================================================
# R/data_loader.R
# Modul zum Laden, Validieren und Bereinigen der ETF-Daten aus Data.xlsx
# Unterstuetzt Multi-Asset (Aktien, Bonds, Real Estate, Rohstoffe, Cash)
# Zwei-Tabellen-Architektur: Holdings (Spalten 1:5) + Kennzahlen (Spalten 6:15)
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

# Mapping fuer GICS-Sektoren von UPPERCASE / Alias zu Title Case
GICS_SECTOR_MAP <- c(
  "ENERGY"                 = "Energy",
  "MATERIALS"              = "Materials",
  "INDUSTRIALS"            = "Industrials",
  "CONSUMER DISCRETIONARY" = "Consumer Discretionary",
  "CONSUMER STAPLES"       = "Consumer Staples",
  "HEALTH CARE"            = "Health Care",
  "FINANCIALS"             = "Financials",
  "INFORMATION TECHNOLOGY" = "Information Technology",
  "COMMUNICATION SERVICES" = "Communication Services",
  "UTILITIES"              = "Utilities",
  "REAL ESTATE"            = "Real Estate"
)

# Standardfarben fuer die 11 GICS-Sektoren
GICS_SECTOR_COLORS <- c(
  "Energy"                 = "#E6550D", # Warmes Orange/Rot
  "Materials"              = "#74C476", # Frischgruen
  "Industrials"            = "#3182BD", # Stahlblau
  "Consumer Discretionary" = "#FD8D3C", # Helles Orange
  "Consumer Staples"       = "#9ECAE1", # Helles Blau
  "Health Care"            = "#E377C2", # Magenta / Rosa
  "Financials"             = "#2B8CBE", # Dunkelcyan
  "Information Technology" = "#6BAED6", # Tech-Blau
  "Communication Services" = "#BCBD22", # Limettengelb
  "Utilities"              = "#17BECF", # Tuerkis
  "Real Estate"            = "#8C564B"  # Braun / Terrakotta
)

# Standardfarben fuer Assetklassen
ASSET_TYPE_COLORS <- c(
  "Aktien"      = "#1E40AF", # LUKB Blau
  "Bonds"       = "#0D9488", # Teal / Petrol
  "Real Estate" = "#8C564B", # Braun / Terrakotta
  "Rohstoffe"   = "#D97706", # Bernstein / Goldbraun
  "Cash"        = "#16A34A"  # Gruen
)

# Mapping von Refinitiv/Datastream Waehrungskuerzeln zu 3-Buchstaben-ISO-Codes
DATASTREAM_CURRENCY_MAP <- c(
  "SF"      = "CHF",
  "E"       = "EUR",
  "U$"      = "USD",
  "\u00A3"  = "GBP", # Pound Sign
  "Y"       = "JPY",
  "A$"      = "AUD",
  "C$"      = "CAD",
  "K$"      = "HKD",
  "S$"      = "SGD",
  "Z$"      = "NZD",
  "M$"      = "MYR",
  "C"       = "BRL",
  "CE"      = "CLP",
  "CH"      = "CNY",
  "CK"      = "CZK",
  "CP"      = "COP",
  "E\u00A3" = "EGP", # Egyptian Pound
  "ED"      = "AED",
  "HF"      = "HUF",
  "I\u00A3" = "ILS", # Israeli Shekel
  "IR"      = "INR",
  "KD"      = "KWD",
  "KW"      = "KRW",
  "MP"      = "MXN",
  "NK"      = "NOK",
  "PP"      = "PHP",
  "PS"      = "PEN",
  "PZ"      = "PLN",
  "Q"       = "QAR",
  "R"       = "ZAR",
  "RI"      = "IDR",
  "RL"      = "RON",
  "SK"      = "SEK",
  "SR"      = "SAR",
  "TB"      = "THB",
  "TL"      = "TRY",
  "TW"      = "TWD"
)

# Waehrungsfarben fuer konsistente Visualisierung
CURRENCY_COLORS <- c(
  "CHF" = "#1E40AF", # Schweizer Franken - Tiefblau
  "USD" = "#0D9488", # US-Dollar - Petrol
  "EUR" = "#0284C7", # Euro - Blau
  "GBP" = "#7C3AED", # Britisches Pfund - Violett
  "JPY" = "#E11D48", # Japanischer Yen - Rot
  "CAD" = "#D97706", # Kanadischer Dollar - Bernstein
  "AUD" = "#059669", # Australischer Dollar - Gruen
  "CNY" = "#DC2626", # Chinesischer Yuan - Rot
  "INR" = "#EA580C", # Indische Rupie - Orange
  "HKD" = "#DB2777", # Hongkong-Dollar - Pink
  "SGD" = "#4F46E5", # Singapur-Dollar - Indigo
  "KRW" = "#0891B2", # Suedkoreanischer Won - Cyan
  "TWD" = "#65A30D", # Taiwan-Dollar - Limette
  "BRL" = "#16A34A", # Brasilianischer Real - Gruen
  "ZAR" = "#B45309", # Suedafrikanischer Rand - Braun
  "SAR" = "#047857", # Saudi-Riyal - Dunkelgruen
  "MXN" = "#C026D3", # Mexikanischer Peso - Magenta
  "NA"  = "#9CA3AF"  # Nicht zugewiesen / Unbekannt - Grau
)

#' Hilfsfunktion zur Bereinigung von Waehrungscodes (Datastream -> 3-Buchstaben-ISO)
clean_currency_code <- function(curr) {
  if (is.null(curr)) return(NA_character_)
  curr <- trimws(as.character(curr))
  
  # 1. Pruefe Datastream-Mapping
  mapped <- DATASTREAM_CURRENCY_MAP[curr]
  res <- ifelse(!is.na(mapped), mapped, curr)
  
  # 2. Bekannte Spezialfaelle
  res <- ifelse(res == "GBp", "GBP", res)
  res <- ifelse(res == "ZAc", "ZAR", res)
  res <- toupper(res)
  
  # 3. Strikt nur 3 Buchstaben (A-Z)
  is_valid <- grepl("^[A-Z]{3}$", res) & !(res %in% c("NAN", "NIL", "N/A", "#N/A", "NULL", "NONE"))
  res[!is_valid | is.na(res)] <- NA_character_
  res
}

#' Hilfsfunktion zur Bereinigung von Sektornamen (aus Spalte 5 "GICS Sector Name")
clean_sector_name <- function(sec) {
  if (is.null(sec)) return(NA_character_)
  sec_clean <- trimws(as.character(sec))
  is_invalid <- is.na(sec_clean) | sec_clean %in% c("#N/A", "NULL", "", "NA") | grepl("invalid|unable|collect", sec_clean, ignore.case = TRUE)
  
  res <- rep(NA_character_, length(sec_clean))
  for (i in which(!is_invalid)) {
    s <- sec_clean[i]
    if (s %in% GICS_11_SECTORS) {
      res[i] <- s
    } else {
      s_upper <- toupper(s)
      if (s_upper %in% names(GICS_SECTOR_MAP)) {
        res[i] <- GICS_SECTOR_MAP[s_upper]
      } else {
        # Fallback to Title Case
        res[i] <- tools::toTitleCase(tolower(s))
      }
    }
  }
  res
}

#' Hilfsfunktion zur Bereinigung von Redemption Dates (Format: ddmmyyyy -> YYYY-MM-DD)
parse_ddmmyyyy <- function(val_str) {
  if (is.null(val_str)) return(NA_character_)
  val_str <- trimws(as.character(val_str))
  is_invalid <- is.na(val_str) | val_str %in% c("#N/A", "NULL", "", "NA") | grepl("invalid|unable", val_str, ignore.case = TRUE)
  
  res <- rep(NA_character_, length(val_str))
  
  for (i in which(!is_invalid)) {
    s <- val_str[i]
    n <- nchar(s)
    parsed <- NA_character_
    
    # 8-stellig (oder laenger mit Option/Call-Suffix): DDMMYYYY
    if (n >= 8) {
      y <- substr(s, 5, 8)
      if (grepl("^(19|20|21)\\d{2}$", y)) {
        d <- substr(s, 1, 2)
        m <- substr(s, 3, 4)
        cand <- paste0(y, "-", m, "-", d)
        dt <- suppressWarnings(as.Date(cand, format = "%Y-%m-%d"))
        if (!is.na(dt)) parsed <- format(dt, "%Y-%m-%d")
      }
    }
    
    # 7-stellig (oder 9-stellig): DMMYYYY (einstelliger Tag)
    if (is.na(parsed) && n >= 7) {
      y <- substr(s, 4, 7)
      if (grepl("^(19|20|21)\\d{2}$", y)) {
        d <- paste0("0", substr(s, 1, 1))
        m <- substr(s, 2, 3)
        cand <- paste0(y, "-", m, "-", d)
        dt <- suppressWarnings(as.Date(cand, format = "%Y-%m-%d"))
        if (!is.na(dt)) parsed <- format(dt, "%Y-%m-%d")
      }
    }
    
    # Fallback: Excel Date Serial Number
    if (is.na(parsed)) {
      num_v <- suppressWarnings(as.numeric(s))
      if (!is.na(num_v) && num_v > 10000 && num_v < 100000) {
        dt <- suppressWarnings(as.Date(num_v, origin = "1899-12-30"))
        if (!is.na(dt)) parsed <- format(dt, "%Y-%m-%d")
      }
    }
    
    res[i] <- parsed
  }
  res
}

#' Berechnet Restlaufzeit in Jahren ausgehend vom aktuellen Datum
calc_maturity_years <- function(mat_dates, ref_date = Sys.Date()) {
  if (is.null(mat_dates)) return(NA_real_)
  d <- suppressWarnings(as.Date(mat_dates))
  years <- as.numeric(difftime(d, ref_date, units = "days")) / 365.25
  ifelse(!is.na(years) & years > 0, round(years, 2), NA_real_)
}

#' Berechnet den gewichteten harmonischen Mittelwert (MSCI / Morningstar Standard)
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

#' Extrahiert Tabelle 1 (Holdings, Spalten 1:5) und Tabelle 2 (Attribute, Spalten 6:15) aus einem Sheet
extract_two_tables <- function(file_path, sheet_name) {
  raw <- read_excel(file_path, sheet = sheet_name, col_names = FALSE)
  hdr_idx <- which(raw[[2]] == "Holding RIC" | raw[[1]] == "Holding RIC")[1]
  if (is.na(hdr_idx) || nrow(raw) <= hdr_idx) return(list(t1 = tibble(), t2 = tibble()))
  
  data_rows <- raw[(hdr_idx + 1):nrow(raw), , drop = FALSE]
  
  # Tabelle 1: Holdings (Spalten 1:5)
  t1 <- data_rows[, 1:min(5, ncol(data_rows)), drop = FALSE]
  c1_names <- c("etf_ric", "holding_ric", "holding_name", "weight_raw", "gics_sector_raw")
  colnames(t1) <- c1_names[1:ncol(t1)]
  t1 <- t1 %>%
    mutate(
      etf_ric = trimws(as.character(etf_ric)),
      holding_ric = trimws(as.character(holding_ric)),
      holding_name = trimws(as.character(holding_name)),
      weight_raw = suppressWarnings(as.numeric(weight_raw)),
      gics_sector_raw = if ("gics_sector_raw" %in% names(.)) trimws(as.character(gics_sector_raw)) else NA_character_
    ) %>%
    filter(!is.na(etf_ric) & etf_ric != "" & !is.na(holding_ric) & holding_ric != "")
  
  # Tabelle 2: Instrument-Attribute (Spalten 6:15)
  if (ncol(data_rows) >= 6) {
    t2 <- data_rows[, 6:min(15, ncol(data_rows)), drop = FALSE]
    c2_names <- c("type_ric", "sector_nxt_dy_legacy", "div_yield", "pb", "pe", "ytm", "mod_duration", "raw_redemption_dates", "raw_currency", "issuer_type")
    colnames(t2) <- c2_names[1:ncol(t2)]
    
    t2 <- t2 %>%
      mutate(
        type_ric = trimws(as.character(type_ric)),
        # sector_nxt_dy_legacy auskommentiert/ignoriert zu Gunsten von gics_sector_raw in Spalte 5
        div_yield = if ("div_yield" %in% names(.)) suppressWarnings(as.numeric(div_yield)) else NA_real_,
        pb = if ("pb" %in% names(.)) suppressWarnings(as.numeric(pb)) else NA_real_,
        pe = if ("pe" %in% names(.)) suppressWarnings(as.numeric(pe)) else NA_real_,
        ytm = if ("ytm" %in% names(.)) suppressWarnings(as.numeric(ytm)) else NA_real_,
        mod_duration = if ("mod_duration" %in% names(.)) suppressWarnings(as.numeric(mod_duration)) else NA_real_,
        raw_redemption_dates = if ("raw_redemption_dates" %in% names(.)) trimws(as.character(raw_redemption_dates)) else NA_character_,
        raw_currency = if ("raw_currency" %in% names(.)) trimws(as.character(raw_currency)) else NA_character_,
        issuer_type = if ("issuer_type" %in% names(.)) trimws(as.character(issuer_type)) else NA_character_
      ) %>%
      filter(!is.na(type_ric) & type_ric != "")
  } else {
    t2 <- tibble()
  }
  
  list(t1 = t1, t2 = t2)
}

#' Laedt und bereinigt die ETF-Daten aus Data.xlsx (Multi-Asset faehig)
#' 
#' @param file_path Pfad zur Excel-Datei (Standard: "Data.xlsx")
#' @return Eine Liste mit 'ticker_df', 'data_clean', 'etf_summary', 'raw_row_count', 'clean_row_count', etc.
load_etf_data <- function(file_path = "Data.xlsx") {
  if (!file.exists(file_path)) {
    stop(paste("Datei nicht gefunden:", file_path))
  }
  
  # 1. Metadaten aus Sheet 'ticker' laden
  ticker_raw <- read_excel(file_path, sheet = "ticker")
  
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
  
  # 2. Tabellen aus 'data' und 'Manuell' extrahieren
  sheets_available <- excel_sheets(file_path)
  data_tables <- extract_two_tables(file_path, "data")
  
  t1_list <- list(data_tables$t1)
  t2_list <- list(data_tables$t2)
  
  if ("Manuell" %in% sheets_available) {
    man_tables <- extract_two_tables(file_path, "Manuell")
    t1_list <- append(t1_list, list(man_tables$t1))
    t2_list <- append(t2_list, list(man_tables$t2))
  }
  
  t1_combined <- bind_rows(t1_list)
  t2_combined <- bind_rows(t2_list) %>% distinct(type_ric, .keep_all = TRUE)
  
  raw_row_count <- nrow(t1_combined)
  
  # 3. Verknuepfung: Tabelle 1 (Holding RIC) <-> Tabelle 2 (Type)
  joined_data <- t1_combined %>%
    left_join(t2_combined, by = c("holding_ric" = "type_ric")) %>%
    left_join(
      ticker_df %>% select(ric, etf_label = label, etf_region = region, asset_type),
      by = c("etf_ric" = "ric")
    ) %>%
    mutate(
      asset_type = ifelse(is.na(asset_type), "Aktien", asset_type),
      etf_label = ifelse(is.na(etf_label), etf_ric, etf_label),
      currency = clean_currency_code(raw_currency),
      gics_sector = clean_sector_name(gics_sector_raw),
      redemption_dates = ifelse(raw_redemption_dates %in% c("#N/A", "NULL", "", "NA"), NA_character_, raw_redemption_dates),
      maturity_date = parse_ddmmyyyy(raw_redemption_dates),
      maturity_years = calc_maturity_years(maturity_date),
      issuer_type = ifelse(issuer_type %in% c("#N/A", "NULL", "", "NA"), NA_character_, issuer_type),
      mod_duration = suppressWarnings(as.numeric(mod_duration))
    )
  
  # 4. Differenzierte Bereinigung nach Assetklasse
  clean_akten <- joined_data %>%
    filter(
      asset_type == "Aktien",
      !is.na(holding_ric) & holding_ric != "" & holding_ric != "NULL",
      !grepl("invalid|Unable|CASH|FEES|OTHER ASSETS|OTHER LIAB|FOREX", holding_name, ignore.case = TRUE),
      !is.na(weight_raw) & weight_raw > 0
    ) %>%
    mutate(
      ytm = NA_real_,
      mod_duration = NA_real_,
      maturity_date = NA_character_,
      maturity_years = NA_real_
    )
  
  clean_bonds <- joined_data %>%
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
  
  clean_real_estate <- joined_data %>%
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
  
  clean_cash <- joined_data %>%
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
  
  clean_rohstoffe <- joined_data %>%
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
      currency = ifelse(is.na(currency) | currency == "", ifelse(holding_ric == "CMD_GOLD", "CHF", "USD"), currency)
    )
  
  # 5. Gesamtdatensatz zusammenfuehren
  data_clean <- bind_rows(clean_akten, clean_bonds, clean_real_estate, clean_cash, clean_rohstoffe) %>%
    select(
      etf_ric, etf_label, etf_region, asset_type,
      holding_ric, holding_name, gics_sector,
      weight_raw, div_yield, pb, pe, ytm, mod_duration, maturity_date, maturity_years, currency,
      redemption_dates, issuer_type
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