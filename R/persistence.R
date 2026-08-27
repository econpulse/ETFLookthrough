# ==============================================================================
# R/persistence.R
# Modul zur permanenten Speicherung und dynamischen Verwaltung von bis zu 3 Portfolios
# ==============================================================================

library(jsonlite)

DEFAULT_CONFIG_FILE <- "saved_portfolios.json"

#' Erzeugt Standardkonfigurationen für bis zu 3 Portfolios gemäss Spezifikation
#' 
#' @param available_etfs Vektor der verfügbaren ETF-RICs
#' @param ticker_df Optionales Ticker-Dataframe für bessere Labels und Reihenfolge
#' @return Liste mit 3 Portfolios
get_default_portfolios <- function(available_etfs = NULL, ticker_df = NULL) {
  # Robustheit: available_etfs extrahieren falls Liste übergeben wurde
  if (is.list(available_etfs) && "available_etfs" %in% names(available_etfs)) {
    available_etfs <- available_etfs$available_etfs
  }
  available_etfs <- as.character(unlist(available_etfs))
  available_etfs <- available_etfs[!is.na(available_etfs) & available_etfs != ""]
  
  # Bevorzuge die Reihenfolge aus ticker_df falls vorhanden
  if (!is.null(ticker_df) && "ric" %in% names(ticker_df)) {
    ordered_rics <- as.character(ticker_df$ric)
    ordered_rics <- ordered_rics[ordered_rics %in% available_etfs]
    # Restliche anfügen
    remaining <- setdiff(available_etfs, ordered_rics)
    etf_list <- c(ordered_rics, remaining)
  } else {
    etf_list <- available_etfs
  }
  
  n_etfs <- length(etf_list)
  
  # ETF Labels ermitteln
  get_label <- function(ric) {
    if (!is.null(ticker_df) && "ric" %in% names(ticker_df) && "label" %in% names(ticker_df)) {
      match_row <- ticker_df[ticker_df$ric == ric, ]
      if (nrow(match_row) > 0) return(as.character(match_row$label[1]))
    }
    as.character(ric)
  }
  
  # ----------------------------------------------------------------------------
  # PORTFOLIO 1: Bis zu 6 ETFs mit Gewichten 13, 5, 3.5, 12, 5, 6.5
  # ----------------------------------------------------------------------------
  p1_target_weights <- c(13, 5, 3.5, 12, 5, 6.5)
  p1_n <- min(n_etfs, 6)
  w1_list <- list()
  if (p1_n > 0) {
    for (i in 1:p1_n) {
      ric <- etf_list[i]
      w1_list[[ric]] <- p1_target_weights[i]
    }
  }
  
  # ----------------------------------------------------------------------------
  # PORTFOLIO 2: Bis zu 6 ETFs gleichgewichtet (Summe 100%)
  # ----------------------------------------------------------------------------
  p2_n <- min(n_etfs, 6)
  w2_list <- list()
  if (p2_n > 0) {
    eq_w <- round(100 / p2_n, 2)
    for (i in 1:p2_n) {
      ric <- etf_list[i]
      w2_list[[ric]] <- eq_w
    }
    # Rundungsdifferenz auf ersten ETF anpassen
    sum_w2 <- sum(unlist(w2_list))
    if (sum_w2 != 100 && p2_n > 0) {
      w2_list[[etf_list[1]]] <- round(w2_list[[etf_list[1]]] + (100 - sum_w2), 2)
    }
  }
  
  # ----------------------------------------------------------------------------
  # PORTFOLIO 3: Initial LEER (keine ETFs)
  # ----------------------------------------------------------------------------
  w3_list <- list()
  
  list(
    portfolio_1 = list(
      id = "p1",
      name = "Portfolio 1 (Muster)",
      enabled = TRUE,
      weights = w1_list
    ),
    portfolio_2 = list(
      id = "p2",
      name = "Portfolio 2 (Gleichgewicht)",
      enabled = TRUE,
      weights = w2_list
    ),
    portfolio_3 = list(
      id = "p3",
      name = "Portfolio 3 (Leer)",
      enabled = TRUE,
      weights = w3_list
    ),
    settings = list(
      normalize_holdings = TRUE,
      last_saved = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    )
  )
}

#' Lädt die Portfolios aus einer JSON-Datei oder initialisiert Standardwerte
#' 
#' @param config_file Pfad zur JSON-Datei
#' @param available_etfs Vektor der aktuell im Datensatz vorhandenen ETF-RICs
#' @param ticker_df Optionales Ticker-Dataframe
#' @return Liste mit Portfoliokonfigurationen
load_portfolios <- function(config_file = DEFAULT_CONFIG_FILE, available_etfs = NULL, ticker_df = NULL) {
  if (is.list(available_etfs) && "available_etfs" %in% names(available_etfs)) {
    available_etfs <- available_etfs$available_etfs
  }
  available_etfs <- as.character(unlist(available_etfs))
  available_etfs <- available_etfs[!is.na(available_etfs) & available_etfs != ""]
  
  defaults <- get_default_portfolios(available_etfs, ticker_df)
  
  if (!file.exists(config_file)) {
    save_portfolios(defaults, config_file)
    return(defaults)
  }
  
  tryCatch({
    saved <- fromJSON(config_file, simplifyVector = FALSE)
    
    # Sicherstellen, dass alle 3 Portfolios existieren
    for (p_key in c("portfolio_1", "portfolio_2", "portfolio_3")) {
      if (is.null(saved[[p_key]])) {
        saved[[p_key]] <- defaults[[p_key]]
      } else {
        # Filtere Gewichte auf die tatsächlich in Data.xlsx verfügbaren ETFs
        raw_w <- saved[[p_key]]$weights
        clean_w <- list()
        if (!is.null(raw_w) && is.list(raw_w) && length(raw_w) > 0) {
          for (k in names(raw_w)) {
            # Nur ETFs behalten, die auch in available_etfs sind (falls available_etfs angegeben)
            if (is.null(available_etfs) || k %in% available_etfs) {
              val <- as.numeric(raw_w[[k]])
              clean_w[[k]] <- if (!is.na(val)) val else 0
            }
          }
        }
        saved[[p_key]]$weights <- clean_w
      }
    }
    
    if (is.null(saved$settings)) {
      saved$settings <- defaults$settings
    }
    
    saved
  }, error = function(e) {
    warning(paste("Fehler beim Laden von", config_file, ":", e$message, "- Verwende Defaults."))
    defaults
  })
}

#' Speichert die Portfolios in einer JSON-Datei
#' 
#' @param portfolios_list Liste der Portfoliokonfigurationen
#' @param config_file Pfad zur JSON-Datei
#' @return TRUE bei Erfolg, FALSE bei Fehler
save_portfolios <- function(portfolios_list, config_file = DEFAULT_CONFIG_FILE) {
  tryCatch({
    # Sicherstellen, dass Gewichte als benannte Listen serialisiert werden
    for (p_key in c("portfolio_1", "portfolio_2", "portfolio_3")) {
      if (!is.null(portfolios_list[[p_key]]) && !is.null(portfolios_list[[p_key]]$weights)) {
        w_raw <- portfolios_list[[p_key]]$weights
        w_clean <- list()
        for (k in names(w_raw)) {
          if (is.character(k) && nchar(k) > 0) {
            val <- as.numeric(w_raw[[k]])
            w_clean[[k]] <- if (!is.na(val)) val else 0
          }
        }
        portfolios_list[[p_key]]$weights <- w_clean
      }
    }
    
    if (is.null(portfolios_list$settings)) {
      portfolios_list$settings <- list()
    }
    portfolios_list$settings$last_saved <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    
    json_data <- toJSON(portfolios_list, pretty = TRUE, auto_unbox = TRUE)
    writeLines(json_data, con = config_file)
    TRUE
  }, error = function(e) {
    warning(paste("Fehler beim Speichern von", config_file, ":", e$message))
    FALSE
  })
}
