# ==============================================================================
# scripts/verify_r_calculations.R
# ==============================================================================

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(jsonlite)
})

source("R/data_loader.R")
source("R/persistence.R")
source("R/analytics.R")

d <- load_etf_data("Data.xlsx")
ports <- load_portfolios("saved_portfolios.json", available_etfs = d$available_etfs, ticker_df = d$ticker_df)

calc <- calculate_all_portfolios(ports, d$data_clean, TRUE)
conc <- calculate_concentration_metrics(calc)
metrics <- calculate_portfolio_asset_and_currency_metrics(calc, d$ticker_df, d$corr_matrix, ports)
sec <- calculate_sector_comparison(calc)

cat("--- R CONCENTRATION METRICS ---\n")
print(conc %>% select(portfolio_name, n_eff, hhi, top10_weight, gini_coefficient))

cat("\n--- R SUMMARY METRICS (inkl. Risk/Return) ---\n")
print(metrics$summary_metrics %>% select(portfolio_name, equity_weight_pct, bond_weight_pct, expected_return, expected_vol, sharpe_ratio, equity_weighted_div_yield, equity_weighted_pe, bond_weighted_ytm, bond_weighted_mod_duration, bond_weighted_maturity_years))

cat("\n--- R TOP 5 GICS SECTORS (P1) ---\n")
print(sec %>% arrange(desc(weight_portfolio_1)) %>% head(5) %>% select(gics_sector, weight_portfolio_1, delta_p1_p2))

cat("\n--- R REGION COMPARISON (Aktien-Delta) ---\n")
reg <- calculate_region_comparison(ports, d$ticker_df)
print(reg)

cat("\n--- R TEST SECTOR COMPARISON EXCLUDING REITS ---\n")
test_reit_ports <- list(
  portfolio_1 = list(id = "p1", name = "P1", enabled = TRUE, weights = list("CHSPI.S" = 100)),
  portfolio_2 = list(id = "p2", name = "P2", enabled = TRUE, weights = list("CHSPI.S" = 50, "IWDP.L" = 50)),
  portfolio_3 = list(id = "p3", name = "P3", enabled = FALSE, weights = list())
)
calc_reit <- calculate_all_portfolios(test_reit_ports, d$data_clean, TRUE)
sectors_reit <- calculate_sector_comparison(calc_reit)
print(sectors_reit %>% select(gics_sector, weight_portfolio_1, weight_portfolio_2, delta_p1_p2))

cat("\n--- R TEST 5-ASSET CLASS PORTFOLIO (Aktien, Bonds, Real Estate, Rohstoffe, Cash) ---\n")
test_5asset_ports <- list(
  portfolio_1 = list(
    id = "p1", name = "Balanced 5-Asset", enabled = TRUE,
    weights = list("CHSPI.S" = 35, "CHESG.S" = 25, "LP68082242" = 15, "CMD_BROAD" = 10, "CMD_GOLD" = 5, "CASH_CHF" = 10)
  )
)
calc_5asset <- calculate_all_portfolios(test_5asset_ports, d$data_clean, TRUE)
metrics_5asset <- calculate_portfolio_asset_and_currency_metrics(calc_5asset)
print(metrics_5asset$summary_metrics %>% select(portfolio_name, equity_weight_pct, bond_weight_pct, real_estate_weight_pct, commodity_weight_pct, cash_weight_pct, equity_weighted_div_yield, bond_weighted_ytm, bond_weighted_mod_duration))
print(metrics_5asset$asset_allocation)
