# ==============================================================================
# R/analytics.R
# Hochperformantes Modul für Look-Through, Sektormix, Konzentration & Top Holdings
# Unterstützt Multi-Asset (Aktien & Bonds), Währungsallokation und Kennzahlen
# ==============================================================================

library(dplyr)
library(tidyr)

clean_zero <- function(x, tol = 1e-4) ifelse(abs(x) < tol, 0, x)

#' Berechnet den gewichteten harmonischen Mittelwert (Standard nach MSCI / Morningstar für Multiples wie KGV & KBV)
#' Verhindert Verzerrungen durch Ausreisser und extrem kleine Nenner/Buchwerte
#' 
#' @param x Vektor der Kennzahlen (z.B. KGV oder KBV)
#' @param w Vektor der Portfoliogewichte
#' @param min_val Untergrenze (Floor), um Division durch extrem kleine/verzerrte Werte zu verhindern
#' @param max_val Obergrenze (Cap), standardmässig Inf
#' @return Gewichteter harmonischer Mittelwert oder NA_real_
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

#' Berechnet das vollständige Look-Through für ein gegebenes Portfolio (optimiert)
#' 
#' @param etf_weights Benannter Vektor oder Liste der ETF-Gewichte (in Prozent)
#' @param clean_data Aufbereiteter Datensatz aus data_loader.R (data_clean)
#' @param use_normalized_etf_weights Logisch, ob normalisierte ETF-Aktiengewichte (100% Equity) verwendet werden sollen
#' @return Dataframe mit allen Einzeltiteln und deren Portfolio-Gewichten inkl. Asset-Typ & Kennzahlen
calculate_single_portfolio_lookthrough <- function(etf_weights, clean_data, use_normalized_etf_weights = TRUE, filters = NULL) {
  etf_names <- names(etf_weights)
  weights_val <- as.numeric(unlist(etf_weights))
  names(weights_val) <- etf_names
  
  # Nur positive Gewichte berücksichtigen
  weights_val <- weights_val[!is.na(weights_val) & weights_val > 0]
  
  if (length(weights_val) == 0 || sum(weights_val) <= 0) {
    return(tibble(
      holding_ric = character(),
      holding_name = character(),
      asset_type = character(),
      gics_sector = character(),
      currency = character(),
      portfolio_weight = numeric(),
      div_yield = numeric(),
      pb = numeric(),
      pe = numeric(),
      ytm = numeric(),
      mod_duration = numeric(),
      maturity_date = character(),
      maturity_years = numeric(),
      redemption_dates = character(),
      issuer_type = character(),
      msci_mv_usd = numeric(),
      n_etfs = integer(),
      etf_breakdown = character()
    ))
  }
  
  # ETF-Gewichte auf 100% reskalieren, falls Summe != 100%
  total_p_weight <- sum(weights_val)
  weights_val <- (weights_val / total_p_weight) * 100
  
  active_etfs <- names(weights_val)
  
  # Relevante ETF-Holdings filtern
  relevant_holdings <- clean_data %>%
    dplyr::filter(etf_ric %in% active_etfs)
  
  # Filter anwenden (Sektor-Exklusion pro Region & Duration-Bänder)
  if (!is.null(filters)) {
    if (!is.null(filters$equity)) {
      for (reg in names(filters$equity)) {
        ex_secs <- filters$equity[[reg]]
        if (length(ex_secs) > 0) {
          relevant_holdings <- relevant_holdings %>%
            dplyr::filter(!(asset_type == "Aktien" & etf_region == reg & gics_sector %in% ex_secs))
        }
      }
    }
    if (!is.null(filters$bonds)) {
      for (reg in names(filters$bonds)) {
        mat_f <- filters$bonds[[reg]]
        min_m <- mat_f$min
        max_m <- mat_f$max
        if (!is.null(min_m) && !is.na(min_m)) {
          relevant_holdings <- relevant_holdings %>%
            dplyr::filter(!(asset_type == "Bonds" & (etf_region == reg | (etf_ric == "EMB.O" & reg == "EM HC") | (etf_ric == "ELD" & reg == "EM LC")) & !is.na(maturity_years) & maturity_years < min_m))
        }
        if (!is.null(max_m) && !is.na(max_m)) {
          relevant_holdings <- relevant_holdings %>%
            dplyr::filter(!(asset_type == "Bonds" & (etf_region == reg | (etf_ric == "EMB.O" & reg == "EM HC") | (etf_ric == "ELD" & reg == "EM LC")) & !is.na(maturity_years) & maturity_years > max_m))
        }
      }
    }
  }

  if (nrow(relevant_holdings) == 0) {
    return(tibble(
      holding_ric = character(),
      holding_name = character(),
      asset_type = character(),
      gics_sector = character(),
      currency = character(),
      portfolio_weight = numeric(),
      div_yield = numeric(),
      pb = numeric(),
      pe = numeric(),
      ytm = numeric(),
      mod_duration = numeric(),
      maturity_date = character(),
      maturity_years = numeric(),
      redemption_dates = character(),
      issuer_type = character(),
      msci_mv_usd = numeric(),
      n_etfs = integer(),
      etf_breakdown = character()
    ))
  }
  
  # Vektorisierte Berechnung der effektiven Gewichte & Herkunfts-Labels
  p_weights_lookup <- weights_val[relevant_holdings$etf_ric]
  base_w <- if (use_normalized_etf_weights) relevant_holdings$weight_norm else relevant_holdings$weight_raw
  eff_weights <- base_w * (p_weights_lookup / 100)
  
  relevant_holdings$holding_eff_weight <- eff_weights
  relevant_holdings$eff_label <- paste0(
    relevant_holdings$etf_label, " (", sprintf("%.2f%%", eff_weights), ")"
  )
  
  # Schnelle Aggregation auf Einzeltitelebene
  lookthrough_holdings <- relevant_holdings %>%
    dplyr::group_by(holding_ric, holding_name, asset_type, gics_sector, currency) %>%
    dplyr::summarise(
      portfolio_weight = sum(holding_eff_weight, na.rm = TRUE),
      div_yield = if (any(!is.na(div_yield))) weighted.mean(div_yield, holding_eff_weight, na.rm = TRUE) else NA_real_,
      pb = calc_weighted_harmonic(pb, holding_eff_weight, min_val = 0.1),
      pe = calc_weighted_harmonic(pe, holding_eff_weight, min_val = 1.0),
      ytm = if (any(!is.na(ytm))) weighted.mean(ytm, holding_eff_weight, na.rm = TRUE) else NA_real_,
      mod_duration = if (any(!is.na(mod_duration))) weighted.mean(mod_duration, holding_eff_weight, na.rm = TRUE) else NA_real_,
      maturity_date = if (any(!is.na(maturity_date))) maturity_date[which(!is.na(maturity_date))[1]] else NA_character_,
      maturity_years = if (any(!is.na(maturity_years))) weighted.mean(maturity_years, holding_eff_weight, na.rm = TRUE) else NA_real_,
      redemption_dates = if ("redemption_dates" %in% names(relevant_holdings) && any(!is.na(redemption_dates))) redemption_dates[which(!is.na(redemption_dates))[1]] else NA_character_,
      issuer_type = if ("issuer_type" %in% names(relevant_holdings) && any(!is.na(issuer_type))) issuer_type[which(!is.na(issuer_type))[1]] else NA_character_,
      msci_mv_usd = if ("msci_mv_usd" %in% names(relevant_holdings) && any(!is.na(msci_mv_usd))) msci_mv_usd[which(!is.na(msci_mv_usd))[1]] else NA_real_,
      n_etfs = dplyr::n(),
      etf_breakdown = paste(eff_label, collapse = " + "),
      .groups = "drop"
    ) %>%
    dplyr::arrange(desc(portfolio_weight))
  
  lookthrough_holdings
}

#' Berechnet die Look-Through-Ergebnisse für alle aktiven Portfolios
#' 
#' @param portfolios_list Liste mit Konfigurationen für portfolio_1, portfolio_2, portfolio_3
#' @param clean_data Aufbereiteter Datensatz
#' @param use_normalized_etf_weights Logisch, ob 100% Look-Through Skalierung genutzt wird
#' @return Liste mit Dataframes pro Portfolio und kombinierten Tabellen
calculate_all_portfolios <- function(portfolios_list, clean_data, use_normalized_etf_weights = TRUE) {
  results <- list()
  
  for (p_key in c("portfolio_1", "portfolio_2", "portfolio_3")) {
    p_conf <- portfolios_list[[p_key]]
    if (!is.null(p_conf) && isTRUE(p_conf$enabled)) {
      lt <- calculate_single_portfolio_lookthrough(
        etf_weights = p_conf$weights,
        clean_data = clean_data,
        use_normalized_etf_weights = use_normalized_etf_weights,
        filters = p_conf$filters
      )
      results[[p_key]] <- list(
        id = p_conf$id,
        name = p_conf$name,
        enabled = TRUE,
        filters = p_conf$filters,
        holdings = lt
      )
    } else {
      results[[p_key]] <- list(
        id = if (!is.null(p_conf$id)) p_conf$id else p_key,
        name = if (!is.null(p_conf$name)) p_conf$name else p_key,
        enabled = FALSE,
        holdings = tibble()
      )
    }
  }
  
  results
}

#' Aggregiert den Sektormix für alle 11 GICS Sektoren für jedes Portfolio (strikt auf Aktien gefiltert)
#' 
#' @param calculated_portfolios Ergebnis aus calculate_all_portfolios()
#' @return Dataframe mit allen 11 GICS Sektoren und den Portfolio-Gewichten + Differenzen
calculate_sector_comparison <- function(calculated_portfolios) {
  sector_df <- tibble(gics_sector = GICS_11_SECTORS)
  
  for (p_key in c("portfolio_1", "portfolio_2", "portfolio_3")) {
    p_res <- calculated_portfolios[[p_key]]
    col_name <- paste0("weight_", p_key)
    
    if (isTRUE(p_res$enabled) && nrow(p_res$holdings) > 0) {
      # Ausschliesslich echte Aktien-ETFs (keine Bonds, keine REITs / Real Estate) berücksichtigen
      akten_holdings <- p_res$holdings %>%
        dplyr::filter(asset_type == "Aktien" & !is.na(gics_sector) & gics_sector %in% GICS_11_SECTORS)
      
      if (nrow(akten_holdings) > 0) {
        tot_akten_w <- sum(akten_holdings$portfolio_weight, na.rm = TRUE)
        
        if (tot_akten_w > 0) {
          sec_agg <- akten_holdings %>%
            dplyr::group_by(gics_sector) %>%
            dplyr::summarise(
              p_sec_weight = (sum(portfolio_weight, na.rm = TRUE) / tot_akten_w) * 100,
              .groups = "drop"
            )
          
          sector_df <- sector_df %>%
            dplyr::left_join(sec_agg, by = "gics_sector") %>%
            dplyr::mutate(p_sec_weight = ifelse(is.na(p_sec_weight), 0, p_sec_weight))
          
          names(sector_df)[names(sector_df) == "p_sec_weight"] <- col_name
        } else {
          sector_df[[col_name]] <- 0
        }
      } else {
        sector_df[[col_name]] <- 0
      }
    } else {
      sector_df[[col_name]] <- 0
    }
  }
  
  # Differenzen berechnen (Gleitkomma-Rundungsrauschen < 1e-4 auf exakt 0 bereinigen)
  clean_zero <- function(x, tol = 1e-4) ifelse(abs(x) < tol, 0, x)
  
  sector_df <- sector_df %>%
    dplyr::mutate(
      delta_p1_p2 = clean_zero(weight_portfolio_1 - weight_portfolio_2),
      delta_p1_p3 = clean_zero(weight_portfolio_1 - weight_portfolio_3),
      delta_p2_p3 = clean_zero(weight_portfolio_2 - weight_portfolio_3)
    )
  
  sector_df
}

#' Aggregiert den regionalen Mix für den Aktienanteil der Portfolios (ohne 'Global')
#' 
#' @param portfolios_list Liste der Portfoliokonfigurationen
#' @param ticker_df Stammdaten der Ticker inkl. region und asset_type
#' @return Dataframe mit allen vorkommenden Aktien-Regionen und Gewichten
calculate_region_comparison <- function(portfolios_list, ticker_df) {
  # Nur echte Aktien-ETFs berücksichtigen (ohne Bonds und ohne Real Estate)
  aktien_tickers <- ticker_df %>%
    dplyr::filter(asset_type == "Aktien" & !is.na(region) & region != "" & region != "Global")
  
  unique_regions <- unique(aktien_tickers$region)
  standard_order <- c("Schweiz", "Nordamerika", "Eurozone", "Pazifik", "Schwellenländer", "UK")
  ordered_regions <- c(standard_order[standard_order %in% unique_regions], setdiff(unique_regions, standard_order))
  
  region_df <- tibble(region = ordered_regions)
  
  for (p_key in c("portfolio_1", "portfolio_2", "portfolio_3")) {
    p_conf <- portfolios_list[[p_key]]
    col_name <- paste0("weight_", p_key)
    
    if (!is.null(p_conf) && isTRUE(p_conf$enabled) && !is.null(p_conf$weights) && length(p_conf$weights) > 0) {
      weights_df <- tibble(
        ric = names(p_conf$weights),
        weight = as.numeric(unlist(p_conf$weights))
      ) %>%
        dplyr::filter(!is.na(weight) & weight > 0) %>%
        dplyr::inner_join(aktien_tickers %>% dplyr::select(ric, region), by = "ric")
      
      tot_eq_w <- sum(weights_df$weight, na.rm = TRUE)
      if (tot_eq_w > 0) {
        reg_agg <- weights_df %>%
          dplyr::group_by(region) %>%
          dplyr::summarise(p_reg_w = (sum(weight, na.rm = TRUE) / tot_eq_w) * 100, .groups = "drop")
        
        region_df <- region_df %>%
          dplyr::left_join(reg_agg, by = "region") %>%
          dplyr::mutate(p_reg_w = ifelse(is.na(p_reg_w), 0, p_reg_w))
        names(region_df)[names(region_df) == "p_reg_w"] <- col_name
      } else {
        region_df[[col_name]] <- 0
      }
    } else {
      region_df[[col_name]] <- 0
    }
  }
  
  clean_zero <- function(x, tol = 1e-4) ifelse(abs(x) < tol, 0, x)
  
  region_df <- region_df %>%
    dplyr::mutate(
      delta_p1_p2 = clean_zero(weight_portfolio_1 - weight_portfolio_2),
      delta_p1_p3 = clean_zero(weight_portfolio_1 - weight_portfolio_3),
      delta_p2_p3 = clean_zero(weight_portfolio_2 - weight_portfolio_3)
    )
  
  region_df
}

#' Berechnet die Top N Holdings im vergleichenden Format (strikt auf Aktien & Real Estate gefiltert)
#' 
#' @param calculated_portfolios Ergebnis aus calculate_all_portfolios()
#' @param top_n Anzahl der Top-Holdings (Standard: 20)
#' @return Liste mit Dataframes für Top-20 pro Portfolio sowie vereinigte Top-Tabelle
calculate_top_holdings <- function(calculated_portfolios, top_n = 20) {
  top_per_portfolio <- list()
  top_slices <- list()
  
  for (p_key in c("portfolio_1", "portfolio_2", "portfolio_3")) {
    p_res <- calculated_portfolios[[p_key]]
    if (isTRUE(p_res$enabled) && nrow(p_res$holdings) > 0) {
      akten_h <- p_res$holdings %>% dplyr::filter(asset_type == "Aktien")
      top_p <- head(akten_h, top_n)
      top_per_portfolio[[p_key]] <- top_p
      top_slices[[p_key]] <- top_p
    } else {
      top_per_portfolio[[p_key]] <- tibble()
    }
  }
  
  if (length(top_slices) == 0) {
    return(list(
      top_per_portfolio = top_per_portfolio,
      combined_top = tibble(
        holding_ric = character(),
        holding_name = character(),
        asset_type = character(),
        gics_sector = character(),
        weight_portfolio_1 = numeric(),
        weight_portfolio_2 = numeric(),
        weight_portfolio_3 = numeric(),
        max_weight = numeric()
      )
    ))
  }
  
  meta_lookup <- bind_rows(top_slices) %>%
    dplyr::distinct(holding_ric, holding_name, asset_type, gics_sector)
  
  combined_top_df <- meta_lookup
  
  for (p_key in c("portfolio_1", "portfolio_2", "portfolio_3")) {
    p_res <- calculated_portfolios[[p_key]]
    col_name <- paste0("weight_", p_key)
    
    if (isTRUE(p_res$enabled) && nrow(p_res$holdings) > 0) {
      akten_h <- p_res$holdings %>% dplyr::filter(asset_type == "Aktien")
      combined_top_df <- combined_top_df %>%
        dplyr::left_join(
          akten_h %>% dplyr::select(holding_ric, p_w = portfolio_weight),
          by = "holding_ric"
        ) %>%
        dplyr::mutate(p_w = ifelse(is.na(p_w), 0, p_w))
      names(combined_top_df)[names(combined_top_df) == "p_w"] <- col_name
    } else {
      combined_top_df[[col_name]] <- 0
    }
  }
  
  w1 <- if ("weight_portfolio_1" %in% names(combined_top_df)) combined_top_df$weight_portfolio_1 else 0
  w2 <- if ("weight_portfolio_2" %in% names(combined_top_df)) combined_top_df$weight_portfolio_2 else 0
  w3 <- if ("weight_portfolio_3" %in% names(combined_top_df)) combined_top_df$weight_portfolio_3 else 0
  
  w1[is.na(w1)] <- 0
  w2[is.na(w2)] <- 0
  w3[is.na(w3)] <- 0
  
  combined_top_df$max_weight <- pmax(w1, w2, w3, 0)
  combined_top_df <- combined_top_df %>% dplyr::arrange(desc(max_weight))
  
  list(
    top_per_portfolio = top_per_portfolio,
    combined_top = combined_top_df
  )
}

#' Berechnet quantitative Konzentrations- und Diversifikationsmasse für den Aktienteil
#' 
#' @param calculated_portfolios Ergebnis aus calculate_all_portfolios()
#' @return Dataframe mit allen Kennzahlen je Portfolio
calculate_concentration_metrics <- function(calculated_portfolios) {
  metrics_list <- list()
  
  for (p_key in c("portfolio_1", "portfolio_2", "portfolio_3")) {
    p_res <- calculated_portfolios[[p_key]]
    
    if (isTRUE(p_res$enabled) && nrow(p_res$holdings) > 0) {
      akten_h <- p_res$holdings %>% dplyr::filter(asset_type == "Aktien")
      
      if (nrow(akten_h) > 0) {
        weights <- akten_h$portfolio_weight
        w_norm <- weights / sum(weights) * 100
        w_frac <- w_norm / 100
        
        n_total <- length(weights)
        
        # Herfindahl-Hirschman Index (0 bis 10.000)
        hhi <- sum(w_norm^2)
        
        # Effektive Anzahl Holdings (N_eff = 1 / sum(w_i^2))
        n_eff <- 1 / sum(w_frac^2)
        
        sorted_w <- sort(w_norm, decreasing = TRUE)
        top1_w <- if (n_total >= 1) sorted_w[1] else 0
        top5_w <- sum(head(sorted_w, 5))
        top10_w <- sum(head(sorted_w, 10))
        top20_w <- sum(head(sorted_w, 20))
        
        gini <- if (n_total > 1) {
          sw <- sort(w_norm)
          2 * sum((1:n_total) * sw) / (n_total * sum(sw)) - (n_total + 1) / n_total
        } else {
          1.0
        }
        
        sec_agg <- akten_h %>%
          dplyr::group_by(gics_sector) %>%
          dplyr::summarise(s_w = sum(portfolio_weight), .groups = "drop")
        s_norm <- sec_agg$s_w / sum(sec_agg$s_w) * 100
        sector_hhi <- sum(s_norm^2)
        sector_n_eff <- 1 / sum((s_norm/100)^2)
        
        metrics_list[[p_key]] <- tibble(
          portfolio_key = p_key,
          portfolio_name = p_res$name,
          is_active = TRUE,
          total_holdings = n_total,
          n_eff = round(n_eff, 1),
          hhi = round(hhi, 1),
          top1_weight = round(top1_w, 2),
          top5_weight = round(top5_w, 2),
          top10_weight = round(top10_w, 2),
          top20_weight = round(top20_w, 2),
          gini_coefficient = round(gini, 3),
          sector_hhi = round(sector_hhi, 1),
          sector_n_eff = round(sector_n_eff, 1)
        )
      } else {
        metrics_list[[p_key]] <- tibble(
          portfolio_key = p_key,
          portfolio_name = p_res$name,
          is_active = FALSE,
          total_holdings = 0,
          n_eff = 0,
          hhi = 0,
          top1_weight = 0,
          top5_weight = 0,
          top10_weight = 0,
          top20_weight = 0,
          gini_coefficient = 0,
          sector_hhi = 0,
          sector_n_eff = 0
        )
      }
    } else {
      metrics_list[[p_key]] <- tibble(
        portfolio_key = p_key,
        portfolio_name = p_res$name,
        is_active = FALSE,
        total_holdings = 0,
        n_eff = 0,
        hhi = 0,
        top1_weight = 0,
        top5_weight = 0,
        top10_weight = 0,
        top20_weight = 0,
        gini_coefficient = 0,
        sector_hhi = 0,
        sector_n_eff = 0
      )
    }
  }
  
  bind_rows(metrics_list)
}

#' Berechnet die Datenpunkte für die kumulative Lorenz-Kurve der Konzentration (Aktien)
#' 
#' @param calculated_portfolios Ergebnis aus calculate_all_portfolios()
#' @return Long-Format Dataframe für Plotly
calculate_lorenz_curves <- function(calculated_portfolios) {
  curves_list <- list()
  
  for (p_key in c("portfolio_1", "portfolio_2", "portfolio_3")) {
    p_res <- calculated_portfolios[[p_key]]
    
    if (isTRUE(p_res$enabled) && nrow(p_res$holdings) > 0) {
      akten_h <- p_res$holdings %>% dplyr::filter(asset_type == "Aktien")
      if (nrow(akten_h) > 0) {
        weights <- sort(akten_h$portfolio_weight, decreasing = TRUE)
        cum_weights <- cumsum(weights) / sum(weights) * 100
        n <- length(weights)
        
        curves_list[[p_key]] <- tibble(
          portfolio_key = p_key,
          portfolio_name = p_res$name,
          rank = 1:n,
          pct_holdings = (1:n) / n * 100,
          cum_weight = cum_weights
        )
      }
    }
  }
  
  bind_rows(curves_list)
}

#' Berechnet Expected Return, Expected Volatility und Sharpe Ratio fuer ein Portfolio
#' 
#' @param p_weights Benannter Vektor der ETF-Gewichte (z.B. c("CHSPI.S" = 14, "CHESG.S" = 14, ...))
#' @param ticker_df Ticker Metadaten mit Spalten 'ric', 'ret', 'vol'
#' @param corr_matrix Quadratische Korrelationsmatrix mit RICs als Zeilen- und Spaltennamen
#' @return Liste mit expected_return, expected_vol, sharpe_ratio
calculate_portfolio_risk_return <- function(p_weights, ticker_df, corr_matrix = NULL) {
  p_weights <- p_weights[!is.na(p_weights) & p_weights > 0]
  if (length(p_weights) == 0 || sum(p_weights) <= 0 || is.null(ticker_df) || nrow(ticker_df) == 0) {
    return(list(expected_return = NA_real_, expected_vol = NA_real_, sharpe_ratio = NA_real_))
  }
  
  # Nur valide Ticker berücksichtigen
  valid_mask <- names(p_weights) %in% ticker_df$ric
  p_weights <- p_weights[valid_mask]
  if (length(p_weights) == 0 || sum(p_weights) <= 0) {
    return(list(expected_return = NA_real_, expected_vol = NA_real_, sharpe_ratio = NA_real_))
  }
  
  tot_w <- sum(p_weights)
  w_norm <- p_weights / tot_w
  rics <- names(w_norm)
  
  ret_vec <- sapply(rics, function(r) {
    idx <- which(ticker_df$ric == r)
    if (length(idx) > 0 && !is.na(ticker_df$ret[idx[1]])) ticker_df$ret[idx[1]] else 0
  })
  
  vol_vec <- sapply(rics, function(r) {
    idx <- which(ticker_df$ric == r)
    if (length(idx) > 0 && !is.na(ticker_df$vol[idx[1]])) ticker_df$vol[idx[1]] else 0
  })
  
  exp_ret <- sum(w_norm * ret_vec)
  
  # Submatrix aus Korrelationen
  sub_corr <- matrix(0, nrow = length(rics), ncol = length(rics), dimnames = list(rics, rics))
  diag(sub_corr) <- 1.0
  
  if (!is.null(corr_matrix) && nrow(corr_matrix) > 0) {
    for (i in seq_along(rics)) {
      r_i <- rics[i]
      for (j in seq_along(rics)) {
        r_j <- rics[j]
        if (r_i %in% rownames(corr_matrix) && r_j %in% colnames(corr_matrix)) {
          sub_corr[i, j] <- corr_matrix[r_i, r_j]
        } else if (i == j) {
          sub_corr[i, j] <- 1.0
        }
      }
    }
  }
  
  cov_mat <- outer(vol_vec, vol_vec, "*") * sub_corr
  var_p <- as.numeric(t(w_norm) %*% cov_mat %*% w_norm)
  exp_vol <- sqrt(max(0, var_p))
  
  sharpe <- if (!is.na(exp_vol) && exp_vol > 0) exp_ret / exp_vol else NA_real_
  
  list(
    expected_return = exp_ret,
    expected_vol = exp_vol,
    sharpe_ratio = sharpe
  )
}

#' Berechnet die Assetklassen- und Währungsallokation sowie Kennzahlen für alle Portfolios
#' Inklusive YTM und Modified Duration nach Währung für Anleihen
#' 
#' @param calculated_portfolios Ergebnis aus calculate_all_portfolios()
#' @param ticker_df Ticker Metadaten mit ret und vol
#' @param corr_matrix Korrelationsmatrix
#' @param raw_portfolios Liste der urspruenglichen Portfolio-Konfigurationen
#' @return Liste mit Dataframes für Asset Allocation, Gesamt-Währungen, Aktien-Währungen, Bond-Währungen (inkl. YTM & Duration)
calculate_portfolio_asset_and_currency_metrics <- function(calculated_portfolios, ticker_df = NULL, corr_matrix = NULL, raw_portfolios = NULL) {
  asset_alloc_list <- list()
  overall_curr_list <- list()
  equity_curr_list <- list()
  bond_curr_list <- list()
  summary_metrics_list <- list()
  
  for (p_key in c("portfolio_1", "portfolio_2", "portfolio_3")) {
    p_res <- calculated_portfolios[[p_key]]
    
    if (isTRUE(p_res$enabled) && nrow(p_res$holdings) > 0) {
      h <- p_res$holdings %>%
        dplyr::mutate(currency_code = ifelse(is.na(currency) | currency == "", "NA", currency))
      
      tot_w <- sum(h$portfolio_weight, na.rm = TRUE)
      
      # 1. Asset Type Allocation
      aa <- h %>%
        dplyr::group_by(asset_type) %>%
        dplyr::summarise(weight = sum(portfolio_weight, na.rm = TRUE), .groups = "drop") %>%
        dplyr::mutate(
          pct = (weight / tot_w) * 100,
          portfolio_key = p_key,
          portfolio_name = p_res$name
        )
      asset_alloc_list[[p_key]] <- aa
      
      # 2. Overall Currency Breakdown
      oc <- h %>%
        dplyr::group_by(currency = currency_code) %>%
        dplyr::summarise(weight = sum(portfolio_weight, na.rm = TRUE), .groups = "drop") %>%
        dplyr::mutate(
          pct = (weight / tot_w) * 100,
          portfolio_key = p_key,
          portfolio_name = p_res$name
        ) %>%
        dplyr::arrange(desc(weight))
      overall_curr_list[[p_key]] <- oc
      
      # 3. Equity Portion
      eq_h <- h %>% dplyr::filter(asset_type == "Aktien")
      eq_w <- sum(eq_h$portfolio_weight, na.rm = TRUE)
      
      if (nrow(eq_h) > 0 && eq_w > 0) {
        ec <- eq_h %>%
          dplyr::group_by(currency = currency_code) %>%
          dplyr::summarise(
            weight = sum(portfolio_weight, na.rm = TRUE),
            weighted_div_yield = if (any(!is.na(div_yield))) weighted.mean(div_yield, portfolio_weight, na.rm = TRUE) else NA_real_,
            weighted_pe = calc_weighted_harmonic(pe, portfolio_weight, min_val = 1.0),
            weighted_pb = calc_weighted_harmonic(pb, portfolio_weight, min_val = 0.1),
            n_positions = dplyr::n(),
            .groups = "drop"
          ) %>%
          dplyr::mutate(
            pct_of_equity = (weight / eq_w) * 100,
            pct_of_portfolio = (weight / tot_w) * 100,
            portfolio_key = p_key,
            portfolio_name = p_res$name
          ) %>%
          dplyr::arrange(desc(weight))
        equity_curr_list[[p_key]] <- ec
        
        valid_div <- eq_h %>% dplyr::filter(!is.na(div_yield))
        weighted_div <- if (nrow(valid_div) > 0) {
          weighted.mean(valid_div$div_yield, valid_div$portfolio_weight, na.rm = TRUE)
        } else {
          NA_real_
        }
        
        weighted_pe <- calc_weighted_harmonic(eq_h$pe, eq_h$portfolio_weight, min_val = 1.0)
        weighted_pb <- calc_weighted_harmonic(eq_h$pb, eq_h$portfolio_weight, min_val = 0.1)
      } else {
        equity_curr_list[[p_key]] <- tibble()
        weighted_div <- NA_real_
        weighted_pe <- NA_real_
        weighted_pb <- NA_real_
      }
      
      # 4. Bond Portion (inklusive YTM, Modified Duration & Maturity nach Währung!)
      bd_h <- h %>% dplyr::filter(asset_type == "Bonds")
      bd_w <- sum(bd_h$portfolio_weight, na.rm = TRUE)
      
      if (nrow(bd_h) > 0 && bd_w > 0) {
        bc <- bd_h %>%
          dplyr::group_by(currency = currency_code) %>%
          dplyr::summarise(
            weight = sum(portfolio_weight, na.rm = TRUE),
            weighted_ytm = if (any(!is.na(ytm))) weighted.mean(ytm, portfolio_weight, na.rm = TRUE) else NA_real_,
            weighted_duration = if (any(!is.na(mod_duration))) weighted.mean(mod_duration, portfolio_weight, na.rm = TRUE) else NA_real_,
            weighted_maturity_years = if (any(!is.na(maturity_years))) weighted.mean(maturity_years, portfolio_weight, na.rm = TRUE) else NA_real_,
            n_positions = dplyr::n(),
            .groups = "drop"
          ) %>%
          dplyr::mutate(
            pct_of_bonds = (weight / bd_w) * 100,
            pct_of_portfolio = (weight / tot_w) * 100,
            portfolio_key = p_key,
            portfolio_name = p_res$name
          ) %>%
          dplyr::arrange(desc(weight))
        bond_curr_list[[p_key]] <- bc
        
        valid_ytm <- bd_h %>% dplyr::filter(!is.na(ytm))
        weighted_ytm <- if (nrow(valid_ytm) > 0) {
          weighted.mean(valid_ytm$ytm, valid_ytm$portfolio_weight, na.rm = TRUE)
        } else {
          NA_real_
        }
        
        valid_dur <- bd_h %>% dplyr::filter(!is.na(mod_duration))
        weighted_dur <- if (nrow(valid_dur) > 0) {
          weighted.mean(valid_dur$mod_duration, valid_dur$portfolio_weight, na.rm = TRUE)
        } else {
          NA_real_
        }

        valid_mat <- bd_h %>% dplyr::filter(!is.na(maturity_years))
        weighted_mat <- if (nrow(valid_mat) > 0) {
          weighted.mean(valid_mat$maturity_years, valid_mat$portfolio_weight, na.rm = TRUE)
        } else {
          NA_real_
        }
      } else {
        bond_curr_list[[p_key]] <- tibble()
        weighted_ytm <- NA_real_
        weighted_dur <- NA_real_
        weighted_mat <- NA_real_
      }
      
      re_h <- h %>% dplyr::filter(asset_type == "Real Estate")
      re_w <- sum(re_h$portfolio_weight, na.rm = TRUE)

      cash_h <- h %>% dplyr::filter(asset_type == "Cash")
      cash_w <- sum(cash_h$portfolio_weight, na.rm = TRUE)

      cmd_h <- h %>% dplyr::filter(asset_type == "Rohstoffe")
      cmd_w <- sum(cmd_h$portfolio_weight, na.rm = TRUE)
      
      # Risk/Return Metriken berechnen
      p_weights_raw <- if (!is.null(raw_portfolios) && !is.null(raw_portfolios[[p_key]]$weights)) {
        unlist(raw_portfolios[[p_key]]$weights)
      } else if (!is.null(p_res$weights)) {
        unlist(p_res$weights)
      } else {
        numeric()
      }
      
      rr <- calculate_portfolio_risk_return(p_weights_raw, ticker_df, corr_matrix)

      summary_metrics_list[[p_key]] <- tibble(
        portfolio_key = p_key,
        portfolio_name = p_res$name,
        is_active = TRUE,
        total_weight = round(tot_w, 2),
        equity_weight_pct = round((eq_w / tot_w) * 100, 2),
        bond_weight_pct = round((bd_w / tot_w) * 100, 2),
        real_estate_weight_pct = round((re_w / tot_w) * 100, 2),
        cash_weight_pct = round((cash_w / tot_w) * 100, 2),
        commodity_weight_pct = round((cmd_w / tot_w) * 100, 2),
        other_weight_pct = round(max(0, 100 - (eq_w + bd_w + re_w + cash_w + cmd_w) / tot_w * 100), 2),
        equity_weighted_div_yield = if (!is.na(weighted_div)) round(weighted_div, 2) else NA_real_,
        equity_weighted_pe = if (!is.na(weighted_pe)) round(weighted_pe, 2) else NA_real_,
        equity_weighted_pb = if (!is.na(weighted_pb)) round(weighted_pb, 2) else NA_real_,
        bond_weighted_ytm = if (!is.na(weighted_ytm)) round(weighted_ytm, 2) else NA_real_,
        bond_weighted_mod_duration = if (!is.na(weighted_dur)) round(weighted_dur, 2) else NA_real_,
        bond_weighted_maturity_years = if (!is.na(weighted_mat)) round(weighted_mat, 2) else NA_real_,
        expected_return = if (!is.na(rr$expected_return)) round(rr$expected_return, 2) else NA_real_,
        expected_vol = if (!is.na(rr$expected_vol)) round(rr$expected_vol, 2) else NA_real_,
        sharpe_ratio = if (!is.na(rr$sharpe_ratio)) round(rr$sharpe_ratio, 2) else NA_real_
      )
    } else {
      summary_metrics_list[[p_key]] <- tibble(
        portfolio_key = p_key,
        portfolio_name = p_res$name,
        is_active = FALSE,
        total_weight = 0,
        equity_weight_pct = 0,
        bond_weight_pct = 0,
        real_estate_weight_pct = 0,
        cash_weight_pct = 0,
        commodity_weight_pct = 0,
        other_weight_pct = 0,
        equity_weighted_div_yield = NA_real_,
        equity_weighted_pe = NA_real_,
        equity_weighted_pb = NA_real_,
        bond_weighted_ytm = NA_real_,
        bond_weighted_mod_duration = NA_real_,
        bond_weighted_maturity_years = NA_real_,
        expected_return = NA_real_,
        expected_vol = NA_real_,
        sharpe_ratio = NA_real_
      )
    }
  }
  
  all_curr_names <- unique(c(
    unlist(lapply(overall_curr_list, function(x) if (nrow(x) > 0) x$currency else character())),
    "CHF", "USD", "EUR"
  ))
  
  curr_compare_df <- tibble(currency = all_curr_names)
  for (p_key in c("portfolio_1", "portfolio_2", "portfolio_3")) {
    col_name <- paste0("weight_", p_key)
    p_curr <- overall_curr_list[[p_key]]
    if (!is.null(p_curr) && nrow(p_curr) > 0) {
      curr_compare_df <- curr_compare_df %>%
        dplyr::left_join(p_curr %>% dplyr::select(currency, p_pct = pct), by = "currency") %>%
        dplyr::mutate(p_pct = ifelse(is.na(p_pct), 0, p_pct))
      names(curr_compare_df)[names(curr_compare_df) == "p_pct"] <- col_name
    } else {
      curr_compare_df[[col_name]] <- 0
    }
  }
  
  curr_compare_df <- curr_compare_df %>%
    dplyr::arrange(desc(weight_portfolio_1))

  summary_df <- bind_rows(summary_metrics_list)
  asset_class_comp <- calculate_asset_class_comparison(summary_df)
  
  list(
    asset_allocation = bind_rows(asset_alloc_list),
    overall_currency = bind_rows(overall_curr_list),
    overall_currency_compare = curr_compare_df,
    equity_currency = bind_rows(equity_curr_list),
    bond_currency = bind_rows(bond_curr_list),
    summary_metrics = summary_df,
    asset_class_comparison = asset_class_comp
  )
}

#' Berechnet die Assetklassen-Divergenzen (Delta) zwischen Portfolios
#' 
#' @param summary_metrics Zusammenfassungstabelle aus calculate_portfolio_asset_and_currency_metrics()
#' @return Dataframe mit den 5 Assetklassen und Delta-Spalten
calculate_asset_class_comparison <- function(summary_metrics) {
  asset_types <- c("Aktien", "Bonds", "Real Estate", "Rohstoffe", "Cash")
  
  p1 <- summary_metrics %>% dplyr::filter(portfolio_key == "portfolio_1")
  p2 <- summary_metrics %>% dplyr::filter(portfolio_key == "portfolio_2")
  p3 <- summary_metrics %>% dplyr::filter(portfolio_key == "portfolio_3")
  
  get_w <- function(p, type) {
    if (nrow(p) == 0 || !isTRUE(p$is_active)) return(0)
    if (type == "Aktien") return(if (is.null(p$equity_weight_pct) || is.na(p$equity_weight_pct)) 0 else p$equity_weight_pct)
    if (type == "Bonds") return(if (is.null(p$bond_weight_pct) || is.na(p$bond_weight_pct)) 0 else p$bond_weight_pct)
    if (type == "Real Estate") return(if (is.null(p$real_estate_weight_pct) || is.na(p$real_estate_weight_pct)) 0 else p$real_estate_weight_pct)
    if (type == "Rohstoffe") return(if (is.null(p$commodity_weight_pct) || is.na(p$commodity_weight_pct)) 0 else p$commodity_weight_pct)
    if (type == "Cash") return(if (is.null(p$cash_weight_pct) || is.na(p$cash_weight_pct)) 0 else p$cash_weight_pct)
    0
  }
  
  rows <- lapply(asset_types, function(type) {
    w1 <- get_w(p1, type)
    w2 <- get_w(p2, type)
    w3 <- get_w(p3, type)
    
    tibble(
      asset_type = type,
      weight_portfolio_1 = w1,
      weight_portfolio_2 = w2,
      weight_portfolio_3 = w3,
      delta_p1_p2 = clean_zero(w1 - w2),
      delta_p1_p3 = clean_zero(w1 - w3),
      delta_p2_p3 = clean_zero(w2 - w3)
    )
  })
  
  bind_rows(rows)
}

#' Berechnet den Fixed-Income-Breakdown nach Region und Issuer-Type fuer ein ausgewaehltes Portfolio
#' 
#' @param portfolio_key Schluessel des Portfolios (z.B. "portfolio_1")
#' @param portfolios_list Liste mit Portfolio-Konfigurationen
#' @param clean_data Bereinigter Datensatz aus load_etf_data()
#' @param ticker_df Ticker-Metadaten
#' @return Eine Liste mit Matrix-Dataframe, Spaltennamen, Gesamtsumme FI-Gewicht und Portfolio-Name
calculate_bond_region_issuer_breakdown <- function(portfolio_key, portfolios_list, clean_data, ticker_df) {
  p_conf <- portfolios_list[[portfolio_key]]
  if (is.null(p_conf) || !isTRUE(p_conf$enabled)) {
    return(list(
      matrix_df = tibble(),
      issuer_cols = character(),
      total_fi_weight = 0,
      portfolio_name = if (!is.null(p_conf$name)) p_conf$name else portfolio_key,
      is_active = FALSE
    ))
  }
  
  p_weights <- unlist(p_conf$weights)
  p_weights <- p_weights[!is.na(p_weights) & p_weights > 0]
  if (length(p_weights) == 0 || sum(p_weights) <= 0) {
    return(list(
      matrix_df = tibble(),
      issuer_cols = character(),
      total_fi_weight = 0,
      portfolio_name = p_conf$name,
      is_active = FALSE
    ))
  }
  
  tot_pw <- sum(p_weights)
  p_norm <- (p_weights / tot_pw) * 100
  active_etfs <- names(p_norm)
  
  # Filtere nur Bond-Positionen
  bd_holdings <- clean_data %>%
    dplyr::filter(asset_type == "Bonds" & etf_ric %in% active_etfs & !is.na(weight_norm) & weight_norm > 0) %>%
    dplyr::mutate(
      port_weight_for_etf = p_norm[etf_ric],
      eff_weight = weight_norm * (port_weight_for_etf / 100),
      bond_region = dplyr::case_when(
        etf_ric == "EMB.O" ~ "EM HC",
        etf_ric == "ELD" ~ "EM LC",
        TRUE ~ etf_region
      ),
      issuer_type_clean = dplyr::case_when(
        is.na(issuer_type) | issuer_type %in% c("#N/A", "NULL", "", "NA") ~ "Andere",
        TRUE ~ issuer_type
      )
    )
  
  tot_fi_weight <- sum(bd_holdings$eff_weight, na.rm = TRUE)
  if (tot_fi_weight <= 0) {
    return(list(
      matrix_df = tibble(),
      issuer_cols = character(),
      total_fi_weight = 0,
      portfolio_name = p_conf$name,
      is_active = TRUE
    ))
  }
  
  # Prozentual auf FI-Segment skalieren
  bd_holdings <- bd_holdings %>%
    dplyr::mutate(fi_pct = (eff_weight / tot_fi_weight) * 100)
  
  # 2D Matrix aggregieren
  mat <- bd_holdings %>%
    dplyr::group_by(bond_region, issuer_type_clean) %>%
    dplyr::summarise(pct = sum(fi_pct, na.rm = TRUE), .groups = "drop") %>%
    tidyr::pivot_wider(names_from = issuer_type_clean, values_from = pct, values_fill = 0)
  
  # Spalten nach Standard sortieren
  iss_cols <- setdiff(names(mat), "bond_region")
  iss_order <- c("SOV", "FIN", "CORP", "AGCY", "SUPR", "SSOV", "Andere")
  ordered_iss_cols <- c(intersect(iss_order, iss_cols), setdiff(iss_cols, iss_order))
  ordered_cols <- c("bond_region", ordered_iss_cols)
  mat <- mat[, ordered_cols]
  
  # Regionen sortieren: Schweiz, Eurozone, Nordamerika, UK, EM HC, EM LC
  region_order <- c("Schweiz", "Eurozone", "Nordamerika", "UK", "EM HC", "EM LC")
  mat$order_idx <- match(mat$bond_region, region_order)
  mat$order_idx[is.na(mat$order_idx)] <- 999
  mat <- mat %>% dplyr::arrange(order_idx) %>% dplyr::select(-order_idx)
  
  # Zeilensumme (Total pro Region)
  mat$Total <- rowSums(mat[, ordered_iss_cols, drop = FALSE])
  
  # Spaltensummen (Total-Zeile)
  sum_row <- as.list(colSums(mat[, c(ordered_iss_cols, "Total"), drop = FALSE]))
  sum_row$bond_region <- "Total"
  mat_with_total <- dplyr::bind_rows(mat, dplyr::as_tibble(sum_row))
  
  list(
    matrix_df = mat_with_total,
    issuer_cols = ordered_iss_cols,
    total_fi_weight = tot_fi_weight,
    portfolio_name = p_conf$name,
    is_active = TRUE
  )
}

