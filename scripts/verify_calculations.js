// ==============================================================================
// scripts/verify_calculations.js
// ==============================================================================

import fs from 'fs';
import Analytics from '../web/js/analytics.js';

const etfData = JSON.parse(fs.readFileSync('web/data/etf_data.json', 'utf8'));
const savedPortfolios = JSON.parse(fs.readFileSync('saved_portfolios.json', 'utf8'));

console.log("=================================================================");
console.log(">> STARTE AUTOMATISCHE VALIDIERUNG DER JS-ANALYTICS-ENGINE");
console.log("=================================================================");

const startTime = performance.now();
const calcPorts = Analytics.calculateAllPortfolios(savedPortfolios, etfData.holdings, true);
const sectorData = Analytics.calculateSectorComparison(calcPorts);
const topHoldings = Analytics.calculateTopHoldings(calcPorts, 20);
const concMetrics = Analytics.calculateConcentrationMetrics(calcPorts);
const assetMetrics = Analytics.calculatePortfolioAssetAndCurrencyMetrics(calcPorts, etfData.tickers, etfData.correlations, savedPortfolios);
const endTime = performance.now();

console.log(`>> Berechnungszeit für alle Portfolios & Metriken: ${(endTime - startTime).toFixed(2)} ms\n`);

console.log("--- PORTFOLIO 1: BASIS-KENNZAHLEN ---");
const p1Holdings = calcPorts.portfolio_1.holdings;
console.log(`Anzahl aggregierter Look-Through Positionen: ${p1Holdings.length}`);
console.log(`Top 5 Positionen (P1):`);
p1Holdings.slice(0, 5).forEach((h, i) => {
  console.log(`  ${i + 1}. ${h.holding_name} (${h.holding_ric}): ${h.portfolio_weight.toFixed(3)}% | Sektor: ${h.gics_sector}`);
});

console.log("\n--- KONZENTRATIONS-KENNZAHLEN ---");
concMetrics.forEach(m => {
  console.log(`${m.portfolio_name}: N_eff = ${m.n_eff}, HHI = ${m.hhi}, Top10 = ${m.top10_weight}%, Gini = ${m.gini_coefficient}`);
});

console.log("\n--- MULTI-ASSET & RENDITEKENNZAHLEN ---");
assetMetrics.summaryMetrics.forEach(m => {
  console.log(`${m.portfolio_name}: Aktien = ${m.equity_weight_pct}%, Bonds = ${m.bond_weight_pct}%, ExpRet = ${m.expected_return}%, ExpVol = ${m.expected_vol}%, Sharpe = ${m.sharpe_ratio}, DivYield = ${m.equity_weighted_div_yield}%, KGV = ${m.equity_weighted_pe}x, YTM = ${m.bond_weighted_ytm}%, Duration = ${m.bond_weighted_mod_duration} J., Restlaufzeit = ${m.bond_weighted_maturity_years} J.`);
});

console.log("\n--- ANLEIHEN (FI) BREAKDOWN NACH REGION & ISSUER TYPE (P1: TAA) ---");
const bondBreakdown = Analytics.calculateBondRegionIssuerBreakdown("portfolio_1", savedPortfolios, etfData.holdings, etfData.tickers);
console.log(`FI Anteil: ${bondBreakdown.totalFiWeight.toFixed(1)}% | Regionen: ${bondBreakdown.matrix.map(r => r.region).join(', ')}`);
console.table(bondBreakdown.matrix);

console.log("\n>> VALIDIERUNG ERFOLGREICH BEENDET.");

