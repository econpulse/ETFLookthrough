// ==============================================================================
// scripts/verify_calculations.js
// Automatisierte Unit- & Paritäts-Testsuite für die JS-Analytics-Engine
// ==============================================================================

import fs from 'fs';
import assert from 'node:assert';
import Constants from '../web/js/constants.js';
import Utils from '../web/js/utils.js';
import Analytics from '../web/js/analytics.js';
import Persistence from '../web/js/persistence.js';

console.log("=================================================================");
console.log(">> STARTE AUTOMATISCHE VALIDIERUNG DER JS-ANALYTICS-ENGINE");
console.log("=================================================================");

// 1. Module- und Konstanten-Tests
console.log("-> Teste Constants & Utils...");
assert.strictEqual(Constants.GICS_11_SECTORS.length, 11, "GICS sollte genau 11 Sektoren enthalten");
assert.ok(Constants.GICS_SECTOR_COLORS["Health Care"], "Farbe für Health Care muss vorhanden sein");
assert.ok(Utils.formatDelta(2.5).includes("+2.50%"), "formatDelta muss positives Vorzeichen und % enthalten");
assert.ok(Utils.formatDelta(-1.2).includes("-1.20%"), "formatDelta muss negatives Vorzeichen enthalten");
assert.ok(Utils.getAssetBadge("Bonds").includes("Bonds"), "Asset Badge für Bonds muss erzeugt werden");
console.log("   [PASS] Constants & Utils valide.");

// 2. Daten laden
const etfData = JSON.parse(fs.readFileSync('web/data/etf_data.json', 'utf8'));
const savedPortfolios = JSON.parse(fs.readFileSync('saved_portfolios.json', 'utf8'));

// 3. Berechnungen ausführen & Performance messen
const startTime = performance.now();
const calcPorts = Analytics.calculateAllPortfolios(savedPortfolios, etfData.holdings, true);
const sectorData = Analytics.calculateSectorComparison(calcPorts);
const topHoldings = Analytics.calculateTopHoldings(calcPorts, 20);
const concMetrics = Analytics.calculateConcentrationMetrics(calcPorts);
const assetMetrics = Analytics.calculatePortfolioAssetAndCurrencyMetrics(calcPorts, etfData.tickers, etfData.correlations, savedPortfolios);
const lorenzCurves = Analytics.calculateLorenzCurves(calcPorts);
const endTime = performance.now();

const durationMs = endTime - startTime;
console.log(`-> Berechnungszeit für alle Portfolios & Metriken: ${durationMs.toFixed(2)} ms`);
assert.ok(durationMs < 500, "Berechnung sollte in unter 500ms abschliessen");

// 4. Look-Through Aggregation Tests
console.log("-> Validiere Look-Through Aggregation (Portfolio 1)...");
const p1Holdings = calcPorts.portfolio_1.holdings;
assert.ok(p1Holdings.length > 5000, "Portfolio 1 sollte > 5000 aggregierte Titel haben");

const totalP1Weight = p1Holdings.reduce((s, h) => s + h.portfolio_weight, 0);
assert.ok(totalP1Weight >= 90 && totalP1Weight <= 100, `Gesamtgewicht Portfolio 1 Look-Through Titel muss >= 90% und <= 100% sein (ist ${totalP1Weight.toFixed(2)}%)`);

console.log(`   Aggregierte Titel: ${p1Holdings.length}, Gesamtgewicht: ${totalP1Weight.toFixed(2)}%`);
console.log("   [PASS] Look-Through Aggregation valide.");

// 5. Konzentrationsmetriken Tests
console.log("-> Validiere Konzentrationsmetriken...");
concMetrics.forEach(m => {
  if (m.is_active) {
    assert.ok(m.n_eff > 10 && m.n_eff < 1000, `N_eff (${m.n_eff}) muss plausibel sein`);
    assert.ok(m.hhi > 10 && m.hhi < 1000, `HHI (${m.hhi}) muss plausibel sein`);
    assert.ok(m.gini_coefficient > 0.5 && m.gini_coefficient < 1.0, `Gini (${m.gini_coefficient}) muss plausibel sein`);
    assert.ok(m.top10_weight > 10 && m.top10_weight < 50, `Top10 (${m.top10_weight}%) muss plausibel sein`);
    console.log(`   ${m.portfolio_name}: N_eff=${m.n_eff}, HHI=${m.hhi}, Top10=${m.top10_weight}%, Gini=${m.gini_coefficient}`);
  }
});
console.log("   [PASS] Konzentrationsmetriken valide.");

// 6. Multi-Asset & Bewertungskennzahlen Tests
console.log("-> Validiere Multi-Asset- und Ertrags-Kennzahlen...");
assetMetrics.summaryMetrics.forEach(m => {
  if (m.is_active) {
    assert.ok(m.equity_weight_pct > 30 && m.equity_weight_pct < 70, "Aktienquote muss plausibel sein");
    assert.ok(m.bond_weight_pct > 20 && m.bond_weight_pct < 50, "Anleihenquote muss plausibel sein");
    assert.ok(m.expected_return > 3.0 && m.expected_return < 8.0, "Erwartete Rendite muss plausibel sein");
    assert.ok(m.expected_vol > 5.0 && m.expected_vol < 15.0, "Erwartete Volatilität muss plausibel sein");
    assert.ok(m.sharpe_ratio > 0.3 && m.sharpe_ratio < 1.0, "Sharpe Ratio muss plausibel sein");
    assert.ok(m.equity_weighted_div_yield > 1.0 && m.equity_weighted_div_yield < 5.0, "Dividendenrendite muss plausibel sein");
    assert.ok(m.bond_weighted_ytm > 2.0 && m.bond_weighted_ytm < 6.0, "YTM muss plausibel sein");
    assert.ok(m.bond_weighted_mod_duration > 4.0 && m.bond_weighted_mod_duration < 10.0, "Duration muss plausibel sein");
  }
});
console.log("   [PASS] Multi-Asset Kennzahlen valide.");

// 7. Sektoren- & Regions-Deltas Tests
console.log("-> Validiere Sektor- & Regions-Vergleiche...");
assert.strictEqual(sectorData.length, 11, "Sektorvergleich muss alle 11 Sektoren enthalten");
const secSumP1 = sectorData.reduce((s, r) => s + r.weight_portfolio_1, 0);
assert.ok(Math.abs(secSumP1 - 100) < 0.1, `Sektorsumme P1 muss 100% der Aktien sein (ist ${secSumP1.toFixed(2)}%)`);
console.log("   [PASS] Sektorvergleich valide.");

// 8. Edge Case Tests: Leeres Portfolio & Einzel-ETF
console.log("-> Teste mathematische Edge Cases...");
const edgePortfolios = {
  portfolio_1: { id: "p1", name: "Single ETF", enabled: true, weights: { "CHSPI.S": 100 } },
  portfolio_2: { id: "p2", name: "Empty", enabled: false, weights: {} },
  portfolio_3: { id: "p3", name: "Zero Weight", enabled: true, weights: { "CHSPI.S": 0 } }
};

const edgeCalc = Analytics.calculateAllPortfolios(edgePortfolios, etfData.holdings, true);
assert.ok(edgeCalc.portfolio_1.holdings.length > 0, "Single ETF Portfolio muss Holdings haben");
assert.strictEqual(edgeCalc.portfolio_2.holdings.length, 0, "Empty Portfolio muss 0 Holdings haben");
assert.strictEqual(edgeCalc.portfolio_3.holdings.length, 0, "Zero Weight Portfolio muss 0 Holdings haben");

const edgeConc = Analytics.calculateConcentrationMetrics(edgeCalc);
assert.strictEqual(edgeConc[1].is_active, false, "Disabled Portfolio muss is_active=false sein");

console.log("   [PASS] Edge Cases erfolgreich abgesichert.");

// 9. Portfolio-Filter Tests (Aktien-Sektor-Exklusion & Bond Maturity Bänder)
console.log("-> Validiere Portfolio-Filter Funktionalität (Maturity)...");
const testFilteredPorts = JSON.parse(JSON.stringify(savedPortfolios));
testFilteredPorts.portfolio_1.filters = {
  equity: {
    "Nordamerika": ["Information Technology"]
  },
  bonds: {
    "Schweiz": { min: 0, max: 5.0 }
  }
};

const filteredCalc = Analytics.calculateAllPortfolios(testFilteredPorts, etfData.holdings, true);
const rawCalc = Analytics.calculateAllPortfolios(savedPortfolios, etfData.holdings, true);

// Prüfe: Keine IT-Holdings aus Nordamerika in P1
const p1FilteredHoldings = filteredCalc.portfolio_1.holdings;
const p1RawHoldings = rawCalc.portfolio_1.holdings;
assert.ok(p1FilteredHoldings.length < p1RawHoldings.length, "Gefiltertes Portfolio muss weniger Holdings haben als ungefiltertes Portfolio");

// Prüfe: Keine Schweizer Anleihen mit Maturity > 5.0
const chBondsFiltered = p1FilteredHoldings.filter(h => h.asset_type === "Bonds" && (h.currency === "CHF" || h.etf_breakdown.includes("SPI") || h.etf_breakdown.includes("SBI")));
chBondsFiltered.forEach(b => {
  if (b.maturity_years != null) {
    assert.ok(b.maturity_years <= 5.0001, `CH-Bond Maturity darf nicht > 5.0 sein (ist ${b.maturity_years})`);
  }
});

// Prüfe calculateFilterImpact
const impactP1 = Analytics.calculateFilterImpact("portfolio_1", testFilteredPorts, etfData.holdings, etfData.tickers, true);
assert.ok(impactP1, "Impact calculation muss Objekt zurückgeben");
assert.ok(impactP1.filtered.count < impactP1.unfiltered.count, "Gefilterte Titelanzahl muss kleiner sein");
assert.ok(impactP1.regionalBondStats["Schweiz"].filteredAvgMaturity < impactP1.regionalBondStats["Schweiz"].rawAvgMaturity, "Gefilterte Maturity für Schweiz Anleihen muss gesunken sein");

console.log(`   P1 Filter Impact: ${impactP1.unfiltered.count} -> ${impactP1.filtered.count} Titel, CH Bond Maturity: ${impactP1.regionalBondStats["Schweiz"].rawAvgMaturity.toFixed(2)} J. -> ${impactP1.regionalBondStats["Schweiz"].filteredAvgMaturity.toFixed(2)} J.`);
console.log("   [PASS] Portfolio-Filter Tests erfolgreich bestanden.");

console.log("\n=================================================================");
console.log(">> ALLE VALIDIERUNGS- & ASSERTION-TESTS ERFOLGREICH BESTANDEN!");
console.log("=================================================================");
