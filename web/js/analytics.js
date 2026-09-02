// ==============================================================================
// web/js/analytics.js
// Hochperformante Look-Through, Sektor-, Konzentrations- und Multi-Asset Engine
// ==============================================================================

(function(global) {
  const GICS_11_SECTORS = [
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
  ];

  const GICS_SECTOR_COLORS = {
    "Energy": "#E6550D",
    "Materials": "#74C476",
    "Industrials": "#3182BD",
    "Consumer Discretionary": "#FD8D3C",
    "Consumer Staples": "#9ECAE1",
    "Health Care": "#E377C2",
    "Financials": "#2B8CBE",
    "Information Technology": "#6BAED6",
    "Communication Services": "#BCBD22",
    "Utilities": "#17BECF",
    "Real Estate": "#8C564B"
  };

  const ASSET_TYPE_COLORS = {
    "Aktien": "#1E40AF",
    "Bonds": "#0D9488",
    "Real Estate": "#8C564B"
  };

  const CURRENCY_COLORS = {
    "CHF": "#1E40AF",
    "USD": "#0D9488",
    "EUR": "#0284C7",
    "GBP": "#7C3AED",
    "JPY": "#E11D48",
    "CAD": "#D97706",
    "AUD": "#059669",
    "CNY": "#DC2626",
    "INR": "#EA580C",
    "HKD": "#DB2777",
    "SGD": "#4F46E5",
    "KRW": "#0891B2",
    "TWD": "#65A30D",
    "BRL": "#16A34A",
    "ZAR": "#B45309",
    "SAR": "#047857",
    "MXN": "#C026D3",
    "NA": "#9CA3AF"
  };

  function calcWeightedMean(values, weights) {
    let sumWeight = 0;
    let sumVal = 0;
    for (let i = 0; i < values.length; i++) {
      const v = values[i];
      const w = weights[i];
      if (v != null && !isNaN(v) && isFinite(v) && w != null && !isNaN(w) && w > 0) {
        sumVal += v * w;
        sumWeight += w;
      }
    }
    return sumWeight > 0 ? sumVal / sumWeight : null;
  }

  function calcWeightedHarmonic(values, weights, minVal = 0.01, maxVal = Infinity) {
    let sumWeight = 0;
    let sumWeightedReciprocal = 0;

    for (let i = 0; i < values.length; i++) {
      const v = values[i];
      const w = weights[i];
      if (v != null && !isNaN(v) && isFinite(v) && v > 0 && w != null && !isNaN(w) && w > 0) {
        const clampedVal = Math.min(Math.max(v, minVal), maxVal);
        sumWeightedReciprocal += w / clampedVal;
        sumWeight += w;
      }
    }

    return (sumWeight > 0 && sumWeightedReciprocal > 0) ? (sumWeight / sumWeightedReciprocal) : null;
  }

  function calculateSinglePortfolioLookthrough(etfWeights, cleanHoldings, useNormalizedWeights = true) {
    const activeEntries = Object.entries(etfWeights || {}).filter(([ric, w]) => w != null && !isNaN(w) && Number(w) > 0);
    
    if (activeEntries.length === 0) return [];

    const totalRawWeight = activeEntries.reduce((sum, [, w]) => sum + Number(w), 0);
    if (totalRawWeight <= 0) return [];

    const normalizedPortWeights = {};
    for (const [ric, w] of activeEntries) {
      normalizedPortWeights[ric] = (Number(w) / totalRawWeight) * 100;
    }

    const aggregatedMap = new Map();

    for (let i = 0; i < cleanHoldings.length; i++) {
      const h = cleanHoldings[i];
      const portWeightForEtf = normalizedPortWeights[h.etf_ric];
      if (portWeightForEtf == null) continue;

      const baseWeight = useNormalizedWeights ? (h.weight_norm ?? h.weight_raw) : h.weight_raw;
      if (baseWeight == null || baseWeight <= 0) continue;

      const effWeight = baseWeight * (portWeightForEtf / 100);
      const holdingKey = `${h.holding_ric}|${h.holding_name}|${h.asset_type}|${h.gics_sector || ''}|${h.currency || ''}`;

      let item = aggregatedMap.get(holdingKey);
      if (!item) {
        item = {
          holding_ric: h.holding_ric,
          holding_name: h.holding_name,
          asset_type: h.asset_type || "Aktien",
          gics_sector: h.gics_sector || null,
          currency: h.currency || "NA",
          portfolio_weight: 0,
          div_yield_vals: [],
          div_yield_weights: [],
          pe_vals: [],
          pe_weights: [],
          pb_vals: [],
          pb_weights: [],
          ytm_vals: [],
          ytm_weights: [],
          mod_dur_vals: [],
          mod_dur_weights: [],
          maturity_dates: [],
          maturity_years_vals: [],
          maturity_years_weights: [],
          redemption_dates: [],
          issuer_types: [],
          msci_mv_usd_vals: [],
          etf_breakdown_parts: []
        };
        aggregatedMap.set(holdingKey, item);
      }

      item.portfolio_weight += effWeight;
      item.etf_breakdown_parts.push(`${h.etf_label || h.etf_ric} (${effWeight.toFixed(2)}%)`);

      if (h.div_yield != null && !isNaN(h.div_yield)) {
        item.div_yield_vals.push(Number(h.div_yield));
        item.div_yield_weights.push(effWeight);
      }
      if (h.pe != null && !isNaN(h.pe) && Number(h.pe) > 0) {
        item.pe_vals.push(Number(h.pe));
        item.pe_weights.push(effWeight);
      }
      if (h.pb != null && !isNaN(h.pb) && Number(h.pb) > 0) {
        item.pb_vals.push(Number(h.pb));
        item.pb_weights.push(effWeight);
      }
      if (h.ytm != null && !isNaN(h.ytm)) {
        item.ytm_vals.push(Number(h.ytm));
        item.ytm_weights.push(effWeight);
      }
      if (h.mod_duration != null && !isNaN(h.mod_duration)) {
        item.mod_dur_vals.push(Number(h.mod_duration));
        item.mod_dur_weights.push(effWeight);
      }
      if (h.maturity_date) {
        item.maturity_dates.push(h.maturity_date);
      }
      if (h.maturity_years != null && !isNaN(h.maturity_years)) {
        item.maturity_years_vals.push(Number(h.maturity_years));
        item.maturity_years_weights.push(effWeight);
      }
      if (h.redemption_dates) {
        item.redemption_dates.push(h.redemption_dates);
      }
      if (h.issuer_type) {
        item.issuer_types.push(h.issuer_type);
      }
      if (h.msci_mv_usd != null && !isNaN(h.msci_mv_usd)) {
        item.msci_mv_usd_vals.push(Number(h.msci_mv_usd));
      }
    }

    const result = [];
    for (const item of aggregatedMap.values()) {
      result.push({
        holding_ric: item.holding_ric,
        holding_name: item.holding_name,
        asset_type: item.asset_type,
        gics_sector: item.gics_sector,
        currency: item.currency,
        portfolio_weight: item.portfolio_weight,
        div_yield: calcWeightedMean(item.div_yield_vals, item.div_yield_weights),
        pe: calcWeightedHarmonic(item.pe_vals, item.pe_weights, 1.0),
        pb: calcWeightedHarmonic(item.pb_vals, item.pb_weights, 0.1),
        ytm: calcWeightedMean(item.ytm_vals, item.ytm_weights),
        mod_duration: calcWeightedMean(item.mod_dur_vals, item.mod_dur_weights),
        maturity_date: item.maturity_dates.length > 0 ? item.maturity_dates[0] : null,
        maturity_years: calcWeightedMean(item.maturity_years_vals, item.maturity_years_weights),
        redemption_dates: item.redemption_dates.length > 0 ? item.redemption_dates[0] : null,
        issuer_type: item.issuer_types.length > 0 ? item.issuer_types[0] : null,
        msci_mv_usd: item.msci_mv_usd_vals.length > 0 ? item.msci_mv_usd_vals[0] : null,
        n_etfs: item.etf_breakdown_parts.length,
        etf_breakdown: item.etf_breakdown_parts.join(" + ")
      });
    }

    result.sort((a, b) => b.portfolio_weight - a.portfolio_weight);
    return result;
  }

  function calculateAllPortfolios(portfoliosConfig, cleanHoldings, useNormalizedWeights = true) {
    const results = {};
    const portKeys = ["portfolio_1", "portfolio_2", "portfolio_3"];

    for (const pKey of portKeys) {
      const pConf = portfoliosConfig[pKey];
      if (pConf && pConf.enabled) {
        const holdings = calculateSinglePortfolioLookthrough(pConf.weights, cleanHoldings, useNormalizedWeights);
        results[pKey] = {
          id: pConf.id || pKey,
          name: pConf.name || pKey,
          enabled: true,
          holdings
        };
      } else {
        results[pKey] = {
          id: pConf?.id || pKey,
          name: pConf?.name || pKey,
          enabled: false,
          holdings: []
        };
      }
    }

    return results;
  }

  const REGIONS_LIST = [
    "Schweiz",
    "Nordamerika",
    "Eurozone",
    "Pazifik",
    "Schwellenländer",
    "UK"
  ];

  const REGION_COLORS = {
    "Schweiz": "#1E40AF",
    "Nordamerika": "#0D9488",
    "Eurozone": "#0284C7",
    "Pazifik": "#D97706",
    "Schwellenländer": "#DC2626",
    "UK": "#7C3AED"
  };

  function calculateSectorComparison(calculatedPortfolios) {
    const portKeys = ["portfolio_1", "portfolio_2", "portfolio_3"];
    const sectorWeightsByPort = {};

    for (const pKey of portKeys) {
      const pRes = calculatedPortfolios[pKey];
      sectorWeightsByPort[pKey] = {};
      for (const sec of GICS_11_SECTORS) {
        sectorWeightsByPort[pKey][sec] = 0;
      }

      if (pRes && pRes.enabled && pRes.holdings.length > 0) {
        // Berücksichtige ausschliesslich echte Aktien-ETFs (keine Bonds, keine Real Estate / REITs)
        const equityHoldings = pRes.holdings.filter(
          h => h.asset_type === "Aktien" && h.gics_sector && GICS_11_SECTORS.includes(h.gics_sector)
        );

        const totalEquityWeight = equityHoldings.reduce((sum, h) => sum + h.portfolio_weight, 0);

        if (totalEquityWeight > 0) {
          for (const h of equityHoldings) {
            sectorWeightsByPort[pKey][h.gics_sector] += (h.portfolio_weight / totalEquityWeight) * 100;
          }
        }
      }
    }

    const cleanZero = (x, tol = 1e-4) => Math.abs(x) < tol ? 0 : x;

    return GICS_11_SECTORS.map(sector => {
      const w1 = sectorWeightsByPort["portfolio_1"][sector] || 0;
      const w2 = sectorWeightsByPort["portfolio_2"][sector] || 0;
      const w3 = sectorWeightsByPort["portfolio_3"][sector] || 0;

      return {
        gics_sector: sector,
        weight_portfolio_1: w1,
        weight_portfolio_2: w2,
        weight_portfolio_3: w3,
        delta_p1_p2: cleanZero(w1 - w2),
        delta_p1_p3: cleanZero(w1 - w3),
        delta_p2_p3: cleanZero(w2 - w3)
      };
    });
  }

  function calculateRegionComparison(portfoliosConfig, tickersData) {
    const portKeys = ["portfolio_1", "portfolio_2", "portfolio_3"];
    const regionWeightsByPort = {};

    const tickerMap = new Map();
    (tickersData || []).forEach(t => {
      tickerMap.set(t.ric, {
        region: t.region,
        asset_type: t.asset_type || "Aktien"
      });
    });

    // Nur tatsächliche Regionen von Aktien-ETFs (ohne "Global")
    const equityRegions = REGIONS_LIST.filter(reg => reg !== "Global");

    for (const pKey of portKeys) {
      const pConf = portfoliosConfig[pKey];
      regionWeightsByPort[pKey] = {};
      for (const reg of equityRegions) {
        regionWeightsByPort[pKey][reg] = 0;
      }

      if (pConf && pConf.enabled && pConf.weights) {
        const weights = pConf.weights;
        let totalEquityWeight = 0;

        for (const [ric, w] of Object.entries(weights)) {
          const val = Number(w) || 0;
          if (val <= 0) continue;
          const meta = tickerMap.get(ric);
          if (meta && meta.asset_type === "Aktien") {
            totalEquityWeight += val;
          }
        }

        if (totalEquityWeight > 0) {
          for (const [ric, w] of Object.entries(weights)) {
            const val = Number(w) || 0;
            if (val <= 0) continue;
            const meta = tickerMap.get(ric);
            if (meta && meta.asset_type === "Aktien" && meta.region && meta.region !== "Global") {
              const reg = meta.region;
              if (regionWeightsByPort[pKey][reg] == null) regionWeightsByPort[pKey][reg] = 0;
              regionWeightsByPort[pKey][reg] += (val / totalEquityWeight) * 100;
            }
          }
        }
      }
    }

    const cleanZero = (x, tol = 1e-4) => Math.abs(x) < tol ? 0 : x;

    return equityRegions.map(region => {
      const w1 = regionWeightsByPort["portfolio_1"][region] || 0;
      const w2 = regionWeightsByPort["portfolio_2"][region] || 0;
      const w3 = regionWeightsByPort["portfolio_3"][region] || 0;

      return {
        region: region,
        weight_portfolio_1: w1,
        weight_portfolio_2: w2,
        weight_portfolio_3: w3,
        delta_p1_p2: cleanZero(w1 - w2),
        delta_p1_p3: cleanZero(w1 - w3),
        delta_p2_p3: cleanZero(w2 - w3)
      };
    });
  }

  function calculateTopHoldings(calculatedPortfolios, topN = 20) {
    const portKeys = ["portfolio_1", "portfolio_2", "portfolio_3"];
    const topPerPortfolio = {};
    const holdingMap = new Map();

    for (const pKey of portKeys) {
      const pRes = calculatedPortfolios[pKey];
      if (pRes && pRes.enabled && pRes.holdings.length > 0) {
        const equity = pRes.holdings.filter(h => h.asset_type === "Aktien");
        const topSlice = equity.slice(0, topN);
        topPerPortfolio[pKey] = topSlice;

        for (const h of topSlice) {
          if (!holdingMap.has(h.holding_ric)) {
            holdingMap.set(h.holding_ric, {
              holding_ric: h.holding_ric,
              holding_name: h.holding_name,
              asset_type: h.asset_type,
              gics_sector: h.gics_sector,
              currency: h.currency,
              weight_portfolio_1: 0,
              weight_portfolio_2: 0,
              weight_portfolio_3: 0
            });
          }
        }
      } else {
        topPerPortfolio[pKey] = [];
      }
    }

    const combinedTop = Array.from(holdingMap.values());
    for (const item of combinedTop) {
      for (const pKey of portKeys) {
        const pRes = calculatedPortfolios[pKey];
        if (pRes && pRes.enabled && pRes.holdings.length > 0) {
          const found = pRes.holdings.find(h => h.holding_ric === item.holding_ric && h.asset_type === "Aktien");
          item[`weight_${pKey}`] = found ? found.portfolio_weight : 0;
        } else {
          item[`weight_${pKey}`] = 0;
        }
      }
      item.max_weight = Math.max(item.weight_portfolio_1, item.weight_portfolio_2, item.weight_portfolio_3, 0);
    }

    combinedTop.sort((a, b) => (b.weight_portfolio_1 || 0) - (a.weight_portfolio_1 || 0) || b.max_weight - a.max_weight);

    return {
      topPerPortfolio,
      combinedTop
    };
  }

  function calculateConcentrationMetrics(calculatedPortfolios) {
    const portKeys = ["portfolio_1", "portfolio_2", "portfolio_3"];
    const metrics = [];

    for (const pKey of portKeys) {
      const pRes = calculatedPortfolios[pKey];
      if (pRes && pRes.enabled && pRes.holdings.length > 0) {
        const equityHoldings = pRes.holdings.filter(h => h.asset_type === "Aktien");
        const totalEquityWeight = equityHoldings.reduce((sum, h) => sum + h.portfolio_weight, 0);

        if (equityHoldings.length > 0 && totalEquityWeight > 0) {
          const weights = equityHoldings.map(h => h.portfolio_weight);
          const wNorm = weights.map(w => (w / totalEquityWeight) * 100);
          const wFrac = wNorm.map(w => w / 100);
          const nTotal = weights.length;

          const hhi = wNorm.reduce((sum, w) => sum + w * w, 0);
          const sumSqFrac = wFrac.reduce((sum, w) => sum + w * w, 0);
          const nEff = sumSqFrac > 0 ? 1 / sumSqFrac : 0;

          const sortedDesc = [...wNorm].sort((a, b) => b - a);
          const top1 = sortedDesc[0] || 0;
          const top5 = sortedDesc.slice(0, 5).reduce((s, x) => s + x, 0);
          const top10 = sortedDesc.slice(0, 10).reduce((s, x) => s + x, 0);
          const top20 = sortedDesc.slice(0, 20).reduce((s, x) => s + x, 0);

          let gini = 1.0;
          if (nTotal > 1) {
            const sortedAsc = [...wNorm].sort((a, b) => a - b);
            let sumIndexed = 0;
            let sumWeights = 0;
            for (let i = 0; i < nTotal; i++) {
              const idx1 = i + 1;
              sumIndexed += idx1 * sortedAsc[i];
              sumWeights += sortedAsc[i];
            }
            gini = (2 * sumIndexed) / (nTotal * sumWeights) - (nTotal + 1) / nTotal;
          }

          const secAggMap = new Map();
          for (const h of equityHoldings) {
            const sec = h.gics_sector || "Other";
            secAggMap.set(sec, (secAggMap.get(sec) || 0) + h.portfolio_weight);
          }
          const secNorm = Array.from(secAggMap.values()).map(v => (v / totalEquityWeight) * 100);
          const sectorHhi = secNorm.reduce((sum, w) => sum + w * w, 0);
          const secFracSq = secNorm.map(w => w / 100).reduce((sum, w) => sum + w * w, 0);
          const sectorNEff = secFracSq > 0 ? 1 / secFracSq : 0;

          metrics.push({
            portfolio_key: pKey,
            portfolio_name: pRes.name,
            is_active: true,
            total_holdings: nTotal,
            n_eff: Number(nEff.toFixed(1)),
            hhi: Number(hhi.toFixed(1)),
            top1_weight: Number(top1.toFixed(2)),
            top5_weight: Number(top5.toFixed(2)),
            top10_weight: Number(top10.toFixed(2)),
            top20_weight: Number(top20.toFixed(2)),
            gini_coefficient: Number(gini.toFixed(3)),
            sector_hhi: Number(sectorHhi.toFixed(1)),
            sector_n_eff: Number(sectorNEff.toFixed(1))
          });
          continue;
        }
      }

      metrics.push({
        portfolio_key: pKey,
        portfolio_name: pRes?.name || pKey,
        is_active: false,
        total_holdings: 0,
        n_eff: 0,
        hhi: 0,
        top1_weight: 0,
        top5_weight: 0,
        top10_weight: 0,
        top20_weight: 0,
        gini_coefficient: 0,
        sector_hhi: 0,
        sector_n_eff: 0
      });
    }

    return metrics;
  }

  function calculateLorenzCurves(calculatedPortfolios) {
    const curves = [];
    const portKeys = ["portfolio_1", "portfolio_2", "portfolio_3"];

    for (const pKey of portKeys) {
      const pRes = calculatedPortfolios[pKey];
      if (pRes && pRes.enabled && pRes.holdings.length > 0) {
        const equity = pRes.holdings.filter(h => h.asset_type === "Aktien");
        if (equity.length > 0) {
          const sortedDesc = equity.map(h => h.portfolio_weight).sort((a, b) => b - a);
          const totalW = sortedDesc.reduce((s, x) => s + x, 0);
          const n = sortedDesc.length;

          let cumSum = 0;
          const ranks = [];
          const pctHoldings = [];
          const cumWeights = [];

          for (let i = 0; i < n; i++) {
            cumSum += sortedDesc[i];
            ranks.push(i + 1);
            pctHoldings.push(((i + 1) / n) * 100);
            cumWeights.push((cumSum / totalW) * 100);
          }

          curves.push({
            portfolio_key: pKey,
            portfolio_name: pRes.name,
            ranks,
            pct_holdings: pctHoldings,
            cum_weight: cumWeights
          });
        }
      }
    }

    return curves;
  }

  function calculatePortfolioRiskReturn(pWeights, tickers, correlations) {
    if (!pWeights || !tickers || tickers.length === 0) {
      return { expected_return: null, expected_vol: null, sharpe_ratio: null };
    }

    const activeEntries = Object.entries(pWeights).filter(([ric, w]) => {
      return w != null && !isNaN(w) && Number(w) > 0 && tickers.some(t => t.ric === ric);
    });
    if (activeEntries.length === 0) {
      return { expected_return: null, expected_vol: null, sharpe_ratio: null };
    }

    const totW = activeEntries.reduce((sum, [, w]) => sum + Number(w), 0);
    if (totW <= 0) {
      return { expected_return: null, expected_vol: null, sharpe_ratio: null };
    }

    const rics = activeEntries.map(([ric]) => ric);
    const weightsNorm = activeEntries.map(([, w]) => Number(w) / totW);

    const retVec = rics.map(r => {
      const t = tickers.find(item => item.ric === r);
      return (t && t.ret != null && !isNaN(t.ret)) ? Number(t.ret) : 0;
    });

    const volVec = rics.map(r => {
      const t = tickers.find(item => item.ric === r);
      return (t && t.vol != null && !isNaN(t.vol)) ? Number(t.vol) : 0;
    });

    // E[R] = sum(w_i * ret_i)
    let expRet = 0;
    for (let i = 0; i < rics.length; i++) {
      expRet += weightsNorm[i] * retVec[i];
    }

    // Variance = w^T * Cov * w where Cov_ij = vol_i * vol_j * corr_ij
    let varP = 0;
    for (let i = 0; i < rics.length; i++) {
      const r_i = rics[i];
      const w_i = weightsNorm[i];
      const vol_i = volVec[i];

      for (let j = 0; j < rics.length; j++) {
        const r_j = rics[j];
        const w_j = weightsNorm[j];
        const vol_j = volVec[j];

        let corr_ij = 0;
        if (i === j) {
          corr_ij = 1.0;
        } else if (correlations && correlations[r_i] && correlations[r_i][r_j] != null) {
          corr_ij = Number(correlations[r_i][r_j]);
        } else if (correlations && correlations[r_j] && correlations[r_j][r_i] != null) {
          corr_ij = Number(correlations[r_j][r_i]);
        }

        const cov_ij = vol_i * vol_j * corr_ij;
        varP += w_i * w_j * cov_ij;
      }
    }

    const expVol = Math.sqrt(Math.max(0, varP));
    const sharpe = (expVol > 0) ? (expRet / expVol) : null;

    return {
      expected_return: Number(expRet.toFixed(2)),
      expected_vol: Number(expVol.toFixed(2)),
      sharpe_ratio: sharpe != null ? Number(sharpe.toFixed(2)) : null
    };
  }

  function calculatePortfolioAssetAndCurrencyMetrics(calculatedPortfolios, tickers = [], correlations = null, rawPortfoliosState = null) {
    const portKeys = ["portfolio_1", "portfolio_2", "portfolio_3"];
    const assetAllocation = [];
    const overallCurrency = [];
    const equityCurrency = [];
    const bondCurrency = [];
    const summaryMetrics = [];

    for (const pKey of portKeys) {
      const pRes = calculatedPortfolios[pKey];
      if (pRes && pRes.enabled && pRes.holdings.length > 0) {
        const hList = pRes.holdings;
        const totalWeight = hList.reduce((sum, h) => sum + h.portfolio_weight, 0);

        const assetMap = new Map();
        for (const h of hList) {
          const type = h.asset_type || "Aktien";
          assetMap.set(type, (assetMap.get(type) || 0) + h.portfolio_weight);
        }
        for (const [type, w] of assetMap.entries()) {
          assetAllocation.push({
            portfolio_key: pKey,
            portfolio_name: pRes.name,
            asset_type: type,
            weight: w,
            pct: (w / totalWeight) * 100
          });
        }

        const ccyMap = new Map();
        for (const h of hList) {
          const ccy = h.currency || "NA";
          ccyMap.set(ccy, (ccyMap.get(ccy) || 0) + h.portfolio_weight);
        }
        for (const [ccy, w] of ccyMap.entries()) {
          overallCurrency.push({
            portfolio_key: pKey,
            portfolio_name: pRes.name,
            currency: ccy,
            weight: w,
            pct: (w / totalWeight) * 100
          });
        }

        const eqList = hList.filter(h => h.asset_type === "Aktien");
        const eqTotalWeight = eqList.reduce((sum, h) => sum + h.portfolio_weight, 0);

        const reList = hList.filter(h => h.asset_type === "Real Estate");
        const reTotalWeight = reList.reduce((sum, h) => sum + h.portfolio_weight, 0);

        const cashList = hList.filter(h => h.asset_type === "Cash");
        const cashTotalWeight = cashList.reduce((sum, h) => sum + h.portfolio_weight, 0);

        const cmdList = hList.filter(h => h.asset_type === "Rohstoffe");
        const cmdTotalWeight = cmdList.reduce((sum, h) => sum + h.portfolio_weight, 0);

        if (eqList.length > 0 && eqTotalWeight > 0) {
          const eqCcyMap = new Map();
          for (const h of eqList) {
            const ccy = h.currency || "NA";
            let item = eqCcyMap.get(ccy);
            if (!item) {
              item = {
                weight: 0,
                div_yield_vals: [],
                div_yield_weights: [],
                pe_vals: [],
                pe_weights: [],
                pb_vals: [],
                pb_weights: [],
                count: 0
              };
              eqCcyMap.set(ccy, item);
            }
            item.weight += h.portfolio_weight;
            item.count++;
            if (h.div_yield != null && !isNaN(h.div_yield)) {
              item.div_yield_vals.push(h.div_yield);
              item.div_yield_weights.push(h.portfolio_weight);
            }
            if (h.pe != null && !isNaN(h.pe) && h.pe > 0) {
              item.pe_vals.push(h.pe);
              item.pe_weights.push(h.portfolio_weight);
            }
            if (h.pb != null && !isNaN(h.pb) && h.pb > 0) {
              item.pb_vals.push(h.pb);
              item.pb_weights.push(h.portfolio_weight);
            }
          }

          for (const [ccy, item] of eqCcyMap.entries()) {
            equityCurrency.push({
              portfolio_key: pKey,
              portfolio_name: pRes.name,
              currency: ccy,
              weight: item.weight,
              pct_of_equity: (item.weight / eqTotalWeight) * 100,
              pct_of_portfolio: (item.weight / totalWeight) * 100,
              weighted_div_yield: calcWeightedMean(item.div_yield_vals, item.div_yield_weights),
              weighted_pe: calcWeightedHarmonic(item.pe_vals, item.pe_weights, 1.0),
              weighted_pb: calcWeightedHarmonic(item.pb_vals, item.pb_weights, 0.1),
              n_positions: item.count
            });
          }
        }

        const bdList = hList.filter(h => h.asset_type === "Bonds");
        const bdTotalWeight = bdList.reduce((sum, h) => sum + h.portfolio_weight, 0);

        if (bdList.length > 0 && bdTotalWeight > 0) {
          const bdCcyMap = new Map();
          for (const h of bdList) {
            const ccy = h.currency || "NA";
            let item = bdCcyMap.get(ccy);
            if (!item) {
              item = {
                weight: 0,
                ytm_vals: [],
                ytm_weights: [],
                mod_dur_vals: [],
                mod_dur_weights: [],
                mat_years_vals: [],
                mat_years_weights: [],
                count: 0
              };
              bdCcyMap.set(ccy, item);
            }
            item.weight += h.portfolio_weight;
            item.count++;
            if (h.ytm != null && !isNaN(h.ytm)) {
              item.ytm_vals.push(h.ytm);
              item.ytm_weights.push(h.portfolio_weight);
            }
            if (h.mod_duration != null && !isNaN(h.mod_duration)) {
              item.mod_dur_vals.push(h.mod_duration);
              item.mod_dur_weights.push(h.portfolio_weight);
            }
            if (h.maturity_years != null && !isNaN(h.maturity_years)) {
              item.mat_years_vals.push(h.maturity_years);
              item.mat_years_weights.push(h.portfolio_weight);
            }
          }

          for (const [ccy, item] of bdCcyMap.entries()) {
            bondCurrency.push({
              portfolio_key: pKey,
              portfolio_name: pRes.name,
              currency: ccy,
              weight: item.weight,
              pct_of_bonds: (item.weight / bdTotalWeight) * 100,
              pct_of_portfolio: (item.weight / totalWeight) * 100,
              weighted_ytm: calcWeightedMean(item.ytm_vals, item.ytm_weights),
              weighted_duration: calcWeightedMean(item.mod_dur_vals, item.mod_dur_weights),
              weighted_maturity_years: calcWeightedMean(item.mat_years_vals, item.mat_years_weights),
              n_positions: item.count
            });
          }
        }

        const allEqDiv = eqList.filter(h => h.div_yield != null);
        const eqWeightedDiv = allEqDiv.length > 0 ? calcWeightedMean(allEqDiv.map(h => h.div_yield), allEqDiv.map(h => h.portfolio_weight)) : null;
        const eqWeightedPe = calcWeightedHarmonic(eqList.map(h => h.pe), eqList.map(h => h.portfolio_weight), 1.0);
        const eqWeightedPb = calcWeightedHarmonic(eqList.map(h => h.pb), eqList.map(h => h.portfolio_weight), 0.1);

        const allBdYtm = bdList.filter(h => h.ytm != null);
        const bdWeightedYtm = allBdYtm.length > 0 ? calcWeightedMean(allBdYtm.map(h => h.ytm), allBdYtm.map(h => h.portfolio_weight)) : null;
        const allBdDur = bdList.filter(h => h.mod_duration != null);
        const bdWeightedDur = allBdDur.length > 0 ? calcWeightedMean(allBdDur.map(h => h.mod_duration), allBdDur.map(h => h.portfolio_weight)) : null;
        const allBdMat = bdList.filter(h => h.maturity_years != null);
        const bdWeightedMat = allBdMat.length > 0 ? calcWeightedMean(allBdMat.map(h => h.maturity_years), allBdMat.map(h => h.portfolio_weight)) : null;

        const rawWeights = rawPortfoliosState?.[pKey]?.weights || pRes.weights || {};
        const rr = calculatePortfolioRiskReturn(rawWeights, tickers, correlations);

        summaryMetrics.push({
          portfolio_key: pKey,
          portfolio_name: pRes.name,
          is_active: true,
          total_weight: Number(totalWeight.toFixed(2)),
          equity_weight_pct: Number(((eqTotalWeight / totalWeight) * 100).toFixed(2)),
          bond_weight_pct: Number(((bdTotalWeight / totalWeight) * 100).toFixed(2)),
          real_estate_weight_pct: Number(((reTotalWeight / totalWeight) * 100).toFixed(2)),
          cash_weight_pct: Number(((cashTotalWeight / totalWeight) * 100).toFixed(2)),
          commodity_weight_pct: Number(((cmdTotalWeight / totalWeight) * 100).toFixed(2)),
          other_weight_pct: Number(Math.max(0, 100 - (eqTotalWeight + bdTotalWeight + reTotalWeight + cashTotalWeight + cmdTotalWeight) / totalWeight * 100).toFixed(2)),
          equity_weighted_div_yield: eqWeightedDiv != null ? Number(eqWeightedDiv.toFixed(2)) : null,
          equity_weighted_pe: eqWeightedPe != null ? Number(eqWeightedPe.toFixed(2)) : null,
          equity_weighted_pb: eqWeightedPb != null ? Number(eqWeightedPb.toFixed(2)) : null,
          bond_weighted_ytm: bdWeightedYtm != null ? Number(bdWeightedYtm.toFixed(2)) : null,
          bond_weighted_mod_duration: bdWeightedDur != null ? Number(bdWeightedDur.toFixed(2)) : null,
          bond_weighted_maturity_years: bdWeightedMat != null ? Number(bdWeightedMat.toFixed(2)) : null,
          expected_return: rr.expected_return,
          expected_vol: rr.expected_vol,
          sharpe_ratio: rr.sharpe_ratio
        });

      } else {
        summaryMetrics.push({
          portfolio_key: pKey,
          portfolio_name: pRes?.name || pKey,
          is_active: false,
          total_weight: 0,
          equity_weight_pct: 0,
          bond_weight_pct: 0,
          real_estate_weight_pct: 0,
          cash_weight_pct: 0,
          commodity_weight_pct: 0,
          other_weight_pct: 0,
          equity_weighted_div_yield: null,
          equity_weighted_pe: null,
          equity_weighted_pb: null,
          bond_weighted_ytm: null,
          bond_weighted_mod_duration: null,
          bond_weighted_maturity_years: null,
          expected_return: null,
          expected_vol: null,
          sharpe_ratio: null
        });
      }
    }

    const allCurrencies = Array.from(new Set([
      ...overallCurrency.map(c => c.currency),
      "CHF", "USD", "EUR"
    ]));

    const overallCurrencyCompare = allCurrencies.map(ccy => {
      const row = { currency: ccy };
      for (const pKey of portKeys) {
        const found = overallCurrency.find(c => c.portfolio_key === pKey && c.currency === ccy);
        row[`weight_${pKey}`] = found ? found.pct : 0;
      }
      return row;
    });

    overallCurrencyCompare.sort((a, b) => b.weight_portfolio_1 - a.weight_portfolio_1);

    const assetClassComparison = calculateAssetClassComparison(summaryMetrics);

    return {
      assetAllocation,
      overallCurrency,
      overallCurrencyCompare,
      equityCurrency,
      bondCurrency,
      summaryMetrics,
      assetClassComparison
    };
  }

  function calculateAssetClassComparison(summaryMetrics) {
    const assetTypes = ["Aktien", "Bonds", "Real Estate", "Rohstoffe", "Cash"];
    const p1 = summaryMetrics.find(m => m.portfolio_key === "portfolio_1") || {};
    const p2 = summaryMetrics.find(m => m.portfolio_key === "portfolio_2") || {};
    const p3 = summaryMetrics.find(m => m.portfolio_key === "portfolio_3") || {};

    const cleanZero = (x, tol = 1e-4) => Math.abs(x) < tol ? 0 : x;

    const getWeight = (p, type) => {
      if (!p.is_active) return 0;
      if (type === "Aktien") return p.equity_weight_pct || 0;
      if (type === "Bonds") return p.bond_weight_pct || 0;
      if (type === "Real Estate") return p.real_estate_weight_pct || 0;
      if (type === "Rohstoffe") return p.commodity_weight_pct || 0;
      if (type === "Cash") return p.cash_weight_pct || 0;
      return 0;
    };

    return assetTypes.map(type => {
      const w1 = getWeight(p1, type);
      const w2 = getWeight(p2, type);
      const w3 = getWeight(p3, type);

      return {
        asset_type: type,
        weight_portfolio_1: w1,
        weight_portfolio_2: w2,
        weight_portfolio_3: w3,
        delta_p1_p2: cleanZero(w1 - w2),
        delta_p1_p3: cleanZero(w1 - w3),
        delta_p2_p3: cleanZero(w2 - w3)
      };
    });
  }

  function calculateBondRegionIssuerBreakdown(portfolioKey, portfoliosConfig, cleanHoldings, tickers) {
    const pConf = (portfoliosConfig || {})[portfolioKey];
    if (!pConf || !pConf.enabled) {
      return {
        matrix: [],
        totalRow: null,
        issuerCols: [],
        totalFiWeight: 0,
        portfolioName: pConf ? pConf.name : portfolioKey,
        isActive: false
      };
    }

    const activeEntries = Object.entries(pConf.weights || {}).filter(([ric, w]) => w != null && !isNaN(w) && Number(w) > 0);
    if (activeEntries.length === 0) {
      return {
        matrix: [],
        totalRow: null,
        issuerCols: [],
        totalFiWeight: 0,
        portfolioName: pConf.name,
        isActive: false
      };
    }

    const totalRawWeight = activeEntries.reduce((sum, [, w]) => sum + Number(w), 0);
    if (totalRawWeight <= 0) {
      return {
        matrix: [],
        totalRow: null,
        issuerCols: [],
        totalFiWeight: 0,
        portfolioName: pConf.name,
        isActive: false
      };
    }

    const normalizedPortWeights = {};
    for (const [ric, w] of activeEntries) {
      normalizedPortWeights[ric] = (Number(w) / totalRawWeight) * 100;
    }

    // Filter bond holdings
    const bondHoldings = [];
    let totalFiWeight = 0;

    for (let i = 0; i < cleanHoldings.length; i++) {
      const h = cleanHoldings[i];
      if (h.asset_type !== "Bonds") continue;

      const portWeightForEtf = normalizedPortWeights[h.etf_ric];
      if (portWeightForEtf == null || portWeightForEtf <= 0) continue;

      const baseWeight = h.weight_norm ?? h.weight_raw ?? 0;
      if (baseWeight <= 0) continue;

      const effWeight = baseWeight * (portWeightForEtf / 100);
      totalFiWeight += effWeight;

      let bondRegion = h.etf_region || "Global";
      if (h.etf_ric === "EMB.O") {
        bondRegion = "EM HC";
      } else if (h.etf_ric === "ELD") {
        bondRegion = "EM LC";
      }

      let issuerType = h.issuer_type;
      if (!issuerType || issuerType === "#N/A" || issuerType === "NULL" || issuerType === "NA") {
        issuerType = "Andere";
      }

      bondHoldings.push({
        effWeight,
        bondRegion,
        issuerType
      });
    }

    if (totalFiWeight <= 0 || bondHoldings.length === 0) {
      return {
        matrix: [],
        totalRow: null,
        issuerCols: [],
        totalFiWeight: 0,
        portfolioName: pConf.name,
        isActive: true
      };
    }

    // Aggregate matrix: region -> issuerType -> fiPct
    const matrixMap = new Map();
    const discoveredIssuers = new Set();

    for (const bh of bondHoldings) {
      const fiPct = (bh.effWeight / totalFiWeight) * 100;
      if (!matrixMap.has(bh.bondRegion)) {
        matrixMap.set(bh.bondRegion, new Map());
      }
      const regMap = matrixMap.get(bh.bondRegion);
      regMap.set(bh.issuerType, (regMap.get(bh.issuerType) || 0) + fiPct);
      discoveredIssuers.add(bh.issuerType);
    }

    const issOrder = ["SOV", "FIN", "CORP", "AGCY", "SUPR", "SSOV", "Andere"];
    const orderedIssCols = [];
    for (const iss of issOrder) {
      if (discoveredIssuers.has(iss)) {
        orderedIssCols.push(iss);
      }
    }
    for (const iss of discoveredIssuers) {
      if (!orderedIssCols.includes(iss)) {
        orderedIssCols.push(iss);
      }
    }

    const regionOrder = ["Schweiz", "Eurozone", "Nordamerika", "UK", "EM HC", "EM LC"];
    const allRegions = Array.from(matrixMap.keys()).sort((a, b) => {
      const idxA = regionOrder.indexOf(a);
      const idxB = regionOrder.indexOf(b);
      return (idxA !== -1 ? idxA : 999) - (idxB !== -1 ? idxB : 999);
    });

    const rows = [];
    const colTotals = {};
    orderedIssCols.forEach(col => { colTotals[col] = 0; });
    let grandTotal = 0;

    for (const reg of allRegions) {
      const regMap = matrixMap.get(reg);
      const row = { region: reg };
      let rowTotal = 0;

      for (const col of orderedIssCols) {
        const val = regMap.get(col) || 0;
        row[col] = val;
        rowTotal += val;
        colTotals[col] += val;
      }
      row.total = rowTotal;
      grandTotal += rowTotal;
      rows.push(row);
    }

    const totalRow = {
      region: "Total",
      ...colTotals,
      total: grandTotal
    };

    return {
      matrix: rows,
      totalRow,
      issuerCols: orderedIssCols,
      totalFiWeight,
      portfolioName: pConf.name,
      isActive: true
    };
  }

  const ISSUER_TYPE_COLORS = {
    "SOV": "#1E40AF",
    "FIN": "#0D9488",
    "CORP": "#D97706",
    "AGCY": "#7C3AED",
    "SUPR": "#059669",
    "SSOV": "#0284C7",
    "Andere": "#94A3B8"
  };

  const ISSUER_TYPE_LABELS = {
    "SOV": "Staatsanleihen (SOV)",
    "FIN": "Finanzsektor (FIN)",
    "CORP": "Unternehmensanleihen (CORP)",
    "AGCY": "Agencies / Behörden (AGCY)",
    "SUPR": "Supranational (SUPR)",
    "SSOV": "Sub-Sovereign (SSOV)",
    "Andere": "Andere"
  };

  /**
   * Berechnet alle Daten für die 6 Donut-Pie-Charts des "Dashboard Single"
   */
  function calculateSinglePortfolioPies(activePortKey, portfoliosConfig, cleanHoldings, tickersData, options = {}) {
    const pConf = portfoliosConfig[activePortKey];
    if (!pConf || !pConf.enabled || !pConf.weights) {
      return null;
    }

    const {
      equitySectorRegion = "Total",
      bondIssuerRegion = "Total",
      currencyAssetClass = "Total"
    } = options;

    const weights = pConf.weights;
    const tickerMap = new Map((tickersData || []).map(t => [t.ric, t]));

    // 1. Normalisierte ETF-Gewichte im Portfolio berechnen
    let totalRawWeight = 0;
    for (const [ric, w] of Object.entries(weights)) {
      const val = Number(w) || 0;
      if (val > 0) totalRawWeight += val;
    }

    const normEtfWeights = {};
    if (totalRawWeight > 0) {
      for (const [ric, w] of Object.entries(weights)) {
        normEtfWeights[ric] = (Number(w) / totalRawWeight) * 100;
      }
    }

    // 2. Assetklassen-Mix
    const assetTotals = {
      "Aktien": 0,
      "Bonds": 0,
      "Real Estate": 0,
      "Rohstoffe": 0,
      "Cash": 0
    };

    for (const [ric, portWeight] of Object.entries(normEtfWeights)) {
      const meta = tickerMap.get(ric);
      const aType = meta?.asset_type || "Aktien";
      if (assetTotals[aType] != null) {
        assetTotals[aType] += portWeight;
      } else {
        assetTotals["Aktien"] += portWeight;
      }
    }

    const assetClassesPie = Object.entries(assetTotals)
      .filter(([_, val]) => val > 0.01)
      .map(([label, val]) => ({
        label,
        value: Number(val.toFixed(2)),
        color: ASSET_TYPE_COLORS[label] || "#64748B"
      }));

    // 3. Look-Through Holdings für Aktien sammeln
    const equityHoldings = [];
    let totalEquityWeight = 0;

    for (let i = 0; i < (cleanHoldings || []).length; i++) {
      const h = cleanHoldings[i];
      if (h.asset_type !== "Aktien") continue;
      const pw = normEtfWeights[h.etf_ric];
      if (!pw || pw <= 0) continue;
      const baseW = h.weight_norm ?? h.weight_raw ?? 0;
      if (baseW <= 0) continue;
      const effW = baseW * (pw / 100);
      totalEquityWeight += effW;
      const tInfo = tickerMap.get(h.etf_ric);
      const region = tInfo?.region || h.etf_region || "Global";

      equityHoldings.push({
        holding_ric: h.holding_ric,
        holding_name: h.holding_name,
        region,
        gics_sector: h.gics_sector,
        currency: h.currency,
        effWeight: effW
      });
    }

    // 4. Aktien-Regionen Pie
    const eqRegionMap = {};
    for (const h of equityHoldings) {
      eqRegionMap[h.region] = (eqRegionMap[h.region] || 0) + h.effWeight;
    }

    const availableEquityRegions = ["Total", ...Object.keys(eqRegionMap).sort()];

    const equityRegionsPie = Object.entries(eqRegionMap)
      .filter(([_, w]) => totalEquityWeight > 0 && (w / totalEquityWeight) * 100 > 0.01)
      .map(([label, w]) => ({
        label,
        value: Number(((w / totalEquityWeight) * 100).toFixed(2)),
        color: REGION_COLORS[label] || "#64748B"
      }))
      .sort((a, b) => b.value - a.value);

    // 5. Aktien-Sektoren Pie (mit Drilldown nach Region)
    let filteredEquityHoldings = equityHoldings;
    if (equitySectorRegion && equitySectorRegion !== "Total") {
      filteredEquityHoldings = equityHoldings.filter(h => h.region === equitySectorRegion);
    }

    const filteredEqWeight = filteredEquityHoldings.reduce((sum, h) => sum + h.effWeight, 0);
    const eqSectorMap = {};
    for (const h of filteredEquityHoldings) {
      if (h.gics_sector) {
        eqSectorMap[h.gics_sector] = (eqSectorMap[h.gics_sector] || 0) + h.effWeight;
      }
    }

    const equitySectorsPie = Object.entries(eqSectorMap)
      .filter(([_, w]) => filteredEqWeight > 0 && (w / filteredEqWeight) * 100 > 0.01)
      .map(([label, w]) => ({
        label,
        value: Number(((w / filteredEqWeight) * 100).toFixed(2)),
        color: GICS_SECTOR_COLORS[label] || "#64748B"
      }))
      .sort((a, b) => b.value - a.value);

    // 6. Bond-Breakdown berechnen
    const bondBreakdown = calculateBondRegionIssuerBreakdown(activePortKey, portfoliosConfig, cleanHoldings, tickersData);
    const availableBondRegions = ["Total"];
    if (bondBreakdown && bondBreakdown.matrix) {
      bondBreakdown.matrix.forEach(r => {
        if (!availableBondRegions.includes(r.region)) availableBondRegions.push(r.region);
      });
    }

    // Bond-Regionen Pie
    const bondRegionsPie = (bondBreakdown?.matrix || [])
      .filter(r => (r.total || 0) > 0.01)
      .map(r => ({
        label: r.region,
        value: Number((r.total || 0).toFixed(2)),
        color: REGION_COLORS[r.region] || (r.region === "EM HC" ? "#DC2626" : r.region === "EM LC" ? "#EA580C" : "#64748B")
      }))
      .sort((a, b) => b.value - a.value);

    // 7. Bond-Sektoren / Issuer-Types Pie (mit Drilldown nach Region)
    let bondIssuerPie = [];
    if (bondBreakdown && bondBreakdown.issuerCols) {
      let targetRow = bondBreakdown.totalRow;
      if (bondIssuerRegion && bondIssuerRegion !== "Total") {
        targetRow = bondBreakdown.matrix.find(r => r.region === bondIssuerRegion);
      }

      if (targetRow) {
        const regionFiTotal = targetRow.total || 1;
        bondIssuerPie = bondBreakdown.issuerCols
          .map(col => {
            const val = Number(targetRow[col]) || 0;
            // Wenn region-spezifisch, auf 100% dieser Region skalieren
            const pct = bondIssuerRegion === "Total" ? val : (val / regionFiTotal) * 100;
            return {
              label: ISSUER_TYPE_LABELS[col] || col,
              rawKey: col,
              value: Number(pct.toFixed(2)),
              color: ISSUER_TYPE_COLORS[col] || "#64748B"
            };
          })
          .filter(d => d.value > 0.01)
          .sort((a, b) => b.value - a.value);
      }
    }

    // 8. Währungsmix Pie (mit Drilldown nach Anlageklasse)
    const currencyWeights = {};
    let currencyTotalWeight = 0;

    for (let i = 0; i < (cleanHoldings || []).length; i++) {
      const h = cleanHoldings[i];
      if (currencyAssetClass === "Aktien" && h.asset_type !== "Aktien") continue;
      if (currencyAssetClass === "Bonds" && h.asset_type !== "Bonds") continue;

      const pw = normEtfWeights[h.etf_ric];
      if (!pw || pw <= 0) continue;
      const baseW = h.weight_norm ?? h.weight_raw ?? 0;
      if (baseW <= 0) continue;
      const effW = baseW * (pw / 100);

      const curr = h.currency || "CHF";
      currencyWeights[curr] = (currencyWeights[curr] || 0) + effW;
      currencyTotalWeight += effW;
    }

    let currencyPie = [];
    if (currencyTotalWeight > 0) {
      const sortedCurrs = Object.entries(currencyWeights)
        .map(([curr, w]) => ({
          currency: curr,
          pct: (w / currencyTotalWeight) * 100
        }))
        .sort((a, b) => b.pct - a.pct);

      const top7 = sortedCurrs.slice(0, 7);
      const rest = sortedCurrs.slice(7);

      top7.forEach(c => {
        currencyPie.push({
          label: c.currency,
          value: Number(c.pct.toFixed(2)),
          color: CURRENCY_COLORS[c.currency] || "#64748B"
        });
      });

      if (rest.length > 0) {
        const restSum = rest.reduce((s, c) => s + c.pct, 0);
        if (restSum > 0.01) {
          currencyPie.push({
            label: "Übrige",
            value: Number(restSum.toFixed(2)),
            color: "#94A3B8"
          });
        }
      }
    }

    return {
      portfolioName: pConf.name,
      portfolioKey: activePortKey,
      assetClassesPie,
      equityRegionsPie,
      equitySectorsPie,
      bondRegionsPie,
      bondIssuerPie,
      currencyPie,
      availableEquityRegions,
      availableBondRegions,
      totalEquityWeight: Number(totalEquityWeight.toFixed(2)),
      totalFiWeight: Number((bondBreakdown?.totalFiWeight || 0).toFixed(2))
    };
  }

  const Analytics = {
    GICS_11_SECTORS,
    GICS_SECTOR_COLORS,
    ASSET_TYPE_COLORS,
    REGIONS_LIST,
    REGION_COLORS,
    CURRENCY_COLORS,
    ISSUER_TYPE_COLORS,
    ISSUER_TYPE_LABELS,
    calcWeightedMean,
    calcWeightedHarmonic,
    calculateSinglePortfolioLookthrough,
    calculateAllPortfolios,
    calculateSectorComparison,
    calculateRegionComparison,
    calculateTopHoldings,
    calculateConcentrationMetrics,
    calculateLorenzCurves,
    calculatePortfolioAssetAndCurrencyMetrics,
    calculateAssetClassComparison,
    calculateBondRegionIssuerBreakdown,
    calculatePortfolioRiskReturn,
    calculateSinglePortfolioPies
  };

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = Analytics;
  } else {
    global.Analytics = Analytics;
  }
})(typeof window !== 'undefined' ? window : globalThis);
