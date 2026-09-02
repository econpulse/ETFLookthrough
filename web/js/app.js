// ==============================================================================
// web/js/app.js
// Haupt-Anwendungssteuerung, State Management & Interaktive Reaktivität
// Unterstützt sowohl direkte Dateiausführung (file://) als auch Webserver
// ==============================================================================

(function(global) {
  const Analytics = global.Analytics;
  const Charts = global.Charts;
  const Tables = global.Tables;
  const Persistence = global.Persistence;

  // Globaler Anwendungszustand
  const state = {
    data: null,
    portfolios: null,
    activeSidebarPort: "portfolio_1",
    activeTab: "tab_dashboard",
    selectedDeltaPair: "delta_p1_p2",
    selectedDashAssetDeltaPair: "delta_p1_p2",
    selectedDashRegionDeltaPair: "delta_p1_p2",
    selectedDrilldownSector: "Health Care",
    selectedFullTablePort: "portfolio_1",
    selectedFullTableAssetClass: "all",
    selectedBondBreakdownPort: "portfolio_1",
    fullTableSearch: "",
    singleEquitySectorRegion: "Total",
    singleBondIssuerRegion: "Total",
    singleCurrencyAssetClass: "Total",
    comparePortA: "portfolio_1",
    comparePortB: "portfolio_2",
    saveStatus: "Gespeichert"
  };

  /**
   * Initialisierung beim Laden der Seite
   */
  async function initApp() {
    try {
      // 1. Daten laden (entweder aus window.ETF_DATA via <script> oder per fetch)
      if (global.ETF_DATA) {
        state.data = global.ETF_DATA;
      } else {
        const res = await fetch('data/etf_data.json');
        if (!res.ok) throw new Error(`HTTP ${res.status} beim Laden von etf_data.json`);
        state.data = await res.json();
      }

      // 2. Portfolios laden (aus window.SAVED_PORTFOLIOS, fetch oder localStorage)
      let defaultPorts = global.SAVED_PORTFOLIOS || null;
      if (!defaultPorts) {
        try {
          const portRes = await fetch('data/saved_portfolios.json');
          if (portRes.ok) defaultPorts = await portRes.json();
        } catch (_) {}
      }

      state.portfolios = Persistence.loadPortfolios(defaultPorts || Persistence.getDefaultPortfolios(
        state.data.tickers.map(t => t.ric),
        state.data.tickers
      ));

      setupEventHandlers();
      populateSectorDrilldownSelect();
      updateApp();

      console.log(">> ETF Look-Through Dashboard erfolgreich initialisiert (Zero-Dependency)!");
    } catch (err) {
      console.error("Fehler beim Starten der App:", err);
      const errElem = document.getElementById('app-loading-error');
      if (errElem) {
        errElem.classList.remove('d-none');
        errElem.innerText = "Fehler beim Laden der Daten: " + err.message;
      }
    }
  }

  /**
   * Neuberechnung & UI-Update
   */
  function updateApp() {
    if (!state.data || !state.portfolios) return;

    const normalizeHoldings = state.portfolios.settings?.normalize_holdings ?? true;

    // 1. Alle Berechnungen durchführen (Dauer: < 3ms)
    const calcPorts = Analytics.calculateAllPortfolios(state.portfolios, state.data.holdings, normalizeHoldings);
    const sectorData = Analytics.calculateSectorComparison(calcPorts);
    const regionData = Analytics.calculateRegionComparison(state.portfolios, state.data.tickers);
    const topHoldings = Analytics.calculateTopHoldings(calcPorts, 20);
    const concMetrics = Analytics.calculateConcentrationMetrics(calcPorts);
    const lorenzData = Analytics.calculateLorenzCurves(calcPorts);
    const assetCurrMetrics = Analytics.calculatePortfolioAssetAndCurrencyMetrics(calcPorts, state.data.tickers, state.data.correlations, state.portfolios);

    // 2. Sidebar rendern
    renderSidebar();

    // 3. Dropdown-Labels synchronisieren
    updateDeltaDropdownLabels();

    // 4. Aktiven Tab aktualisieren
    renderActiveTab({
      calcPorts,
      sectorData,
      regionData,
      topHoldings,
      concMetrics,
      lorenzData,
      assetCurrMetrics
    });
  }

  function updateDeltaDropdownLabels() {
    const p1Name = state.portfolios?.portfolio_1?.name || "P1";
    const p2Name = state.portfolios?.portfolio_2?.name || "P2";
    const p3Name = state.portfolios?.portfolio_3?.name || "P3";

    const updateSelect = (id, currentVal) => {
      const sel = document.getElementById(id);
      if (!sel) return;
      const val = currentVal || sel.value || "delta_p1_p2";
      sel.innerHTML = `
        <option value="delta_p1_p2" ${val === "delta_p1_p2" ? "selected" : ""}>${p1Name} vs. ${p2Name}</option>
        <option value="delta_p1_p3" ${val === "delta_p1_p3" ? "selected" : ""}>${p1Name} vs. ${p3Name}</option>
        <option value="delta_p2_p3" ${val === "delta_p2_p3" ? "selected" : ""}>${p2Name} vs. ${p3Name}</option>
      `;
    };

    updateSelect('select-dash-region-delta-pair', state.selectedDashRegionDeltaPair);
    updateSelect('select-dash-asset-delta-pair', state.selectedDashAssetDeltaPair);
    updateSelect('select-sector-delta-pair', state.selectedDeltaPair);
  }

  /**
   * Rendert die Live-Sidebar
   */
  function renderSidebar() {
    const pKey = state.activeSidebarPort;
    const pConf = state.portfolios[pKey];
    const container = document.getElementById('sidebar-etf-list');
    const sumBadge = document.getElementById('sidebar-sum-badge');
    const statusBadge = document.getElementById('sidebar-save-status');

    if (!pConf || !container) return;

    // Sum Badge
    const weights = pConf.weights || {};
    const sumVal = Object.values(weights).reduce((s, w) => s + (Number(w) || 0), 0);
    const is100 = Math.abs(sumVal - 100) < 0.05;
    sumBadge.className = `badge rounded-pill badge-pill-weight ${is100 ? 'bg-success text-white' : 'bg-warning text-dark'}`;
    sumBadge.innerText = `${sumVal.toFixed(1)}%`;

    statusBadge.innerText = state.saveStatus;

    // Portfolio Name & Checkbox für P2/P3
    const headerDiv = document.getElementById('sidebar-port-header');
    if (headerDiv) {
      let headerHtml = `<div class="d-flex justify-content-between align-items-center mb-2">
        <span class="fw-bold text-dark">${pConf.name}</span>`;
      if (pKey !== "portfolio_1") {
        headerHtml += `
          <div class="form-check form-switch mb-0">
            <input class="form-check-input" type="checkbox" id="sidebar-port-enabled" ${pConf.enabled ? 'checked' : ''}>
            <label class="form-check-label small" for="sidebar-port-enabled">Aktiv</label>
          </div>
        `;
      }
      headerHtml += `</div>`;
      headerDiv.innerHTML = headerHtml;

      if (pKey !== "portfolio_1") {
        document.getElementById('sidebar-port-enabled')?.addEventListener('change', (e) => {
          pConf.enabled = e.target.checked;
          state.saveStatus = "Ungespeichert";
          updateApp();
        });
      }
    }

    // ETF Liste mit Stepper Buttons
    const activeRics = Object.keys(weights);
    if (activeRics.length === 0) {
      container.innerHTML = `<div class="alert alert-light border text-center py-3 text-muted small my-2">Keine ETFs enthalten.</div>`;
    } else {
      let html = '';
      activeRics.forEach(ric => {
        const tickerInfo = state.data.tickers.find(t => t.ric === ric) || { label: ric, asset_type: "Aktien" };
        const isBond = tickerInfo.asset_type === "Bonds";
        const isRE = tickerInfo.asset_type === "Real Estate";
        const wVal = Number(weights[ric]) || 0;

        let badge = `<span class="badge ms-1" style="background-color:#EFF6FF;color:#1E40AF;border:1px solid #BFDBFE;font-size:0.68rem;padding:2px 4px;">Aktien</span>`;
        if (isBond) {
          badge = `<span class="badge ms-1" style="background-color:#E6FFFA;color:#0D9488;border:1px solid #5EEAD4;font-size:0.68rem;padding:2px 4px;">Bonds</span>`;
        } else if (isRE) {
          badge = `<span class="badge ms-1" style="background-color:#FDF2F0;color:#8C564B;border:1px solid #F5C6CB;font-size:0.68rem;padding:2px 4px;">RE</span>`;
        } else if (tickerInfo.asset_type === "Cash") {
          badge = `<span class="badge ms-1" style="background-color:#F0FDF4;color:#16A34A;border:1px solid #BBF7D0;font-size:0.68rem;padding:2px 4px;">Cash</span>`;
        } else if (tickerInfo.asset_type === "Rohstoffe") {
          badge = `<span class="badge ms-1" style="background-color:#FFFBEB;color:#D97706;border:1px solid #FDE68A;font-size:0.68rem;padding:2px 4px;">Rohstoffe</span>`;
        }

        html += `
          <div class="sidebar-etf-row">
            <div class="d-flex justify-content-between align-items-center mb-1">
              <div class="text-truncate me-2" style="max-width: 200px;">
                <span class="fw-semibold text-dark" style="font-size: 0.83rem;">${tickerInfo.label}</span>
                ${badge}
              </div>
              <button class="btn btn-link text-danger p-0 btn-del-etf" data-ric="${ric}" title="Entfernen" style="text-decoration:none; font-size:1.1rem; line-height:1;">×</button>
            </div>
            <div class="d-flex justify-content-between align-items-center">
              <button class="btn btn-outline-primary btn-sm stepper-btn btn-dec-etf" data-ric="${ric}">-</button>
              <span class="badge bg-light text-dark border weight-pill px-3 py-1" style="font-size: 0.88rem;">${wVal.toFixed(1)}%</span>
              <button class="btn btn-outline-primary btn-sm stepper-btn btn-inc-etf" data-ric="${ric}">+</button>
            </div>
          </div>
        `;
      });
      container.innerHTML = html;

      // Stepper Event Listener
      container.querySelectorAll('.btn-dec-etf').forEach(btn => {
        btn.addEventListener('click', () => {
          const ric = btn.getAttribute('data-ric');
          weights[ric] = Math.max(0, Number(((weights[ric] || 0) - 0.5).toFixed(1)));
          state.saveStatus = "Ungespeichert";
          updateApp();
        });
      });

      container.querySelectorAll('.btn-inc-etf').forEach(btn => {
        btn.addEventListener('click', () => {
          const ric = btn.getAttribute('data-ric');
          weights[ric] = Number(((weights[ric] || 0) + 0.5).toFixed(1));
          state.saveStatus = "Ungespeichert";
          updateApp();
        });
      });

      container.querySelectorAll('.btn-del-etf').forEach(btn => {
        btn.addEventListener('click', () => {
          const ric = btn.getAttribute('data-ric');
          delete weights[ric];
          state.saveStatus = "Ungespeichert";
          updateApp();
        });
      });
    }

    // Dropdown für "ETF hinzufügen"
    renderAddEtfDropdown(activeRics);
  }

  function renderAddEtfDropdown(activeRics) {
    const select = document.getElementById('sidebar-select-add-etf');
    if (!select) return;

    const available = state.data.tickers.filter(t => !activeRics.includes(t.ric));
    if (available.length === 0) {
      select.innerHTML = '<option disabled selected>Alle ETFs bereits im Portfolio</option>';
      select.disabled = true;
      document.getElementById('sidebar-btn-add-etf').disabled = true;
    } else {
      select.disabled = false;
      document.getElementById('sidebar-btn-add-etf').disabled = false;
      let html = '<option value="" disabled selected>-- ETF auswählen --</option>';
      available.forEach(t => {
        html += `<option value="${t.ric}">${t.label} (${t.ric}) [${t.asset_type}]</option>`;
      });
      select.innerHTML = html;
    }
  }

  function renderActiveTab(analyticsResults) {
    const { calcPorts, sectorData, regionData, topHoldings, concMetrics, lorenzData, assetCurrMetrics } = analyticsResults;
    const pConf = state.portfolios[state.activeSidebarPort];

    if (state.activeTab === "tab_dashboard") {
      renderDashboardKpis(assetCurrMetrics.summaryMetrics, concMetrics);
      Charts.renderAssetDeltaPlot("plot_dash_asset_delta", assetCurrMetrics.assetClassComparison, state.selectedDashAssetDeltaPair, state.portfolios);
      Charts.renderRegionDeltaPlot("plot_dash_region_delta", regionData, state.selectedDashRegionDeltaPair, state.portfolios);
      Tables.renderDashboardTop10Table("table_dash_top10", topHoldings.combinedTop, state.portfolios);
      Tables.renderMultiAssetSummaryTable("table_dash_multi_asset", assetCurrMetrics.summaryMetrics, state.portfolios);
    } else if (state.activeTab === "tab_dashboard_single") {
      renderSingleDashboardTab(analyticsResults);
    } else if (state.activeTab === "tab_compare") {
      renderCompareTab(analyticsResults);
    } else if (state.activeTab === "tab_allocation") {
      Charts.renderAssetAllocationPlot("plot_asset_allocation", assetCurrMetrics.assetAllocation, state.portfolios);
      Charts.renderOverallCurrencyPlot("plot_overall_currency", assetCurrMetrics.overallCurrencyCompare, state.portfolios);
      Charts.renderSegmentCurrencyPlot("plot_equity_currency", assetCurrMetrics.equityCurrency, state.portfolios, "Aktien");
      Charts.renderSegmentCurrencyPlot("plot_bond_currency", assetCurrMetrics.bondCurrency, state.portfolios, "Bonds");
      Tables.renderCurrencyCompareTable("table_overall_currency_detail", assetCurrMetrics.overallCurrencyCompare);
      Tables.renderEquityCurrencyDetailTable("table_equity_currency_detail", assetCurrMetrics.equityCurrency);
      Tables.renderBondCurrencyDetailTable("table_bond_currency_detail", assetCurrMetrics.bondCurrency);

      // Bond Region & Issuer Type Breakdown
      const bondSel = document.getElementById('select_bond_breakdown_portfolio');
      if (bondSel) {
        let optHtml = '';
        ["portfolio_1", "portfolio_2", "portfolio_3"].forEach(pk => {
          const conf = state.portfolios[pk];
          if (conf && conf.enabled) {
            optHtml += `<option value="${pk}" ${state.selectedBondBreakdownPort === pk ? 'selected' : ''}>${conf.name || pk}</option>`;
          }
        });
        bondSel.innerHTML = optHtml;
        if (!bondSel.querySelector(`option[value="${state.selectedBondBreakdownPort}"]`)) {
          state.selectedBondBreakdownPort = bondSel.value || "portfolio_1";
        }
      }

      const bondBreakdown = Analytics.calculateBondRegionIssuerBreakdown(
        state.selectedBondBreakdownPort,
        state.portfolios,
        state.data.holdings,
        state.data.tickers
      );
      Tables.renderBondRegionIssuerTable("table_bond_region_issuer_breakdown", bondBreakdown);
      
      const badge = document.getElementById('bond_breakdown_fi_total_badge');
      if (badge) {
        badge.innerText = `FI-Anteil am Portfolio: ${(bondBreakdown.totalFiWeight || 0).toFixed(1)}%`;
      }
    } else if (state.activeTab === "tab_sectors") {
      Charts.renderDashboardSectors("plot_sector_pie", sectorData, state.activeSidebarPort, pConf.name);
      Charts.renderSectorBarsPlot("plot_sector_bars", sectorData, state.portfolios);
      Charts.renderSectorDeltaPlot("plot_sector_delta", sectorData, state.selectedDeltaPair, state.portfolios);
      Tables.renderSectorDetailTable("table_sectors_detail", sectorData, state.portfolios);
      Tables.renderSectorDrilldownTable("table_sector_drilldown", calcPorts, state.selectedDrilldownSector);
    } else if (state.activeTab === "tab_holdings") {
      Charts.renderTop20BarsPlot("plot_top20_bars", topHoldings.combinedTop, state.portfolios);
      Tables.renderTop20DetailTable("table_top20_detail", topHoldings.combinedTop);
      const selPortHoldings = calcPorts[state.selectedFullTablePort]?.holdings || [];
      Tables.renderFullLookthroughTable("table_full_lookthrough", selPortHoldings, state.fullTableSearch, state.selectedFullTableAssetClass);
    } else if (state.activeTab === "tab_concentration") {
      Charts.renderLorenzPlot("plot_lorenz", lorenzData, state.portfolios);
      Tables.renderConcentrationFullTable("table_concentration_full", concMetrics);
    } else if (state.activeTab === "tab_config") {
      renderConfigTab();
    } else if (state.activeTab === "tab_universe") {
      Tables.renderUniverseSummaryTable("table_etf_meta_summary", state.data.etf_summary);
    }
  }

  function renderSingleDashboardTab(analyticsResults) {
    const { calcPorts, concMetrics, assetCurrMetrics } = analyticsResults;
    const pKey = state.activeSidebarPort;
    const pConf = state.portfolios[pKey];
    if (!pConf) return;

    // 1. Titel & Badge aktualisieren
    const titleElem = document.getElementById('single-dashboard-port-name');
    if (titleElem) titleElem.innerText = pConf.name || pKey;
    const badgeElem = document.getElementById('single-dashboard-active-badge');
    if (badgeElem) badgeElem.innerText = `Aktiv: ${pConf.name || pKey}`;

    // 2. KPI Infoboxen aktualisieren
    const pSum = assetCurrMetrics.summaryMetrics.find(m => m.portfolio_key === pKey) || {};
    const pConc = concMetrics.find(m => m.portfolio_key === pKey) || {};

    const setVal = (id, text) => {
      const elem = document.getElementById(id);
      if (elem) elem.innerText = text;
    };

    setVal('single-kpi-val-exp-ret', (pSum.is_active && pSum.expected_return != null) ? `${pSum.expected_return.toFixed(2)}%` : '-');
    setVal('single-kpi-val-exp-vol', (pSum.is_active && pSum.expected_vol != null) ? `${pSum.expected_vol.toFixed(2)}%` : '-');
    setVal('single-kpi-val-sharpe', (pSum.is_active && pSum.sharpe_ratio != null) ? `${pSum.sharpe_ratio.toFixed(2)}` : '-');
    setVal('single-kpi-val-equity', pSum.is_active ? `${pSum.equity_weight_pct.toFixed(1)}%` : '-');
    setVal('single-kpi-val-bonds', pSum.is_active ? `${pSum.bond_weight_pct.toFixed(1)}%` : '-');
    setVal('single-kpi-val-re', pSum.is_active ? `${(pSum.real_estate_weight_pct || 0).toFixed(1)}%` : '-');
    setVal('single-kpi-val-cmd', pSum.is_active ? `${(pSum.commodity_weight_pct || 0).toFixed(1)}%` : '-');
    setVal('single-kpi-val-div', (pSum.is_active && pSum.equity_weighted_div_yield) ? `${pSum.equity_weighted_div_yield.toFixed(2)}%` : '-');
    setVal('single-kpi-val-pe', (pSum.is_active && pSum.equity_weighted_pe) ? `${pSum.equity_weighted_pe.toFixed(1)}x` : '-');
    setVal('single-kpi-val-ytm', (pSum.is_active && pSum.bond_weighted_ytm) ? `${pSum.bond_weighted_ytm.toFixed(2)}%` : '-');
    setVal('single-kpi-val-dur', (pSum.is_active && pSum.bond_weighted_mod_duration) ? `${pSum.bond_weighted_mod_duration.toFixed(1)} J.` : '-');
    setVal('single-kpi-val-neff', (pConc.is_active && pConc.n_eff) ? `${pConc.n_eff}` : '-');

    // 3. Pies berechnen
    const singlePies = Analytics.calculateSinglePortfolioPies(
      pKey,
      state.portfolios,
      state.data.holdings,
      state.data.tickers,
      {
        equitySectorRegion: state.singleEquitySectorRegion || "Total",
        bondIssuerRegion: state.singleBondIssuerRegion || "Total",
        currencyAssetClass: state.singleCurrencyAssetClass || "Total"
      }
    );

    if (singlePies) {
      // Dropdown Optionen aktualisieren
      const eqSelect = document.getElementById('select_single_equity_sector_region');
      if (eqSelect) {
        let optHtml = '';
        (singlePies.availableEquityRegions || ["Total"]).forEach(reg => {
          optHtml += `<option value="${reg}" ${state.singleEquitySectorRegion === reg ? 'selected' : ''}>${reg}</option>`;
        });
        eqSelect.innerHTML = optHtml;
      }

      const bondSelect = document.getElementById('select_single_bond_issuer_region');
      if (bondSelect) {
        let optHtml = '';
        (singlePies.availableBondRegions || ["Total"]).forEach(reg => {
          optHtml += `<option value="${reg}" ${state.singleBondIssuerRegion === reg ? 'selected' : ''}>${reg}</option>`;
        });
        bondSelect.innerHTML = optHtml;
      }

      const currSelect = document.getElementById('select_single_currency_asset_class');
      if (currSelect) {
        currSelect.value = state.singleCurrencyAssetClass || "Total";
      }

      // Charts rendern:
      // 1. Assetklassen als eleganter 100%-Allokationsstreifen
      Charts.renderSingleStackedBar("plot_single_asset_classes", singlePies.assetClassesPie, pConf.name);

      // 2. Aktien-Sektoren als grosser horizontaler Rang-Balkenchart (Spalte 1)
      Charts.renderSingleHorizontalBars("plot_single_equity_sectors", singlePies.equitySectorsPie, "%", 150);

      // 3. Aktien-Regionen als horizontale Balken (Spalte 2 oben)
      Charts.renderSingleHorizontalBars("plot_single_equity_regions", singlePies.equityRegionsPie, "%", 110);

      // 4. Währungsmix als kleiner Donut-Pie (Spalte 2 unten)
      Charts.renderSingleDonutPie(
        "plot_single_currencies",
        singlePies.currencyPie,
        pConf.name,
        state.singleCurrencyAssetClass === "Total" ? "Währungsmix" : `${state.singleCurrencyAssetClass}-Währungen`
      );

      // 5. Bond-Regionen als horizontale Balken
      Charts.renderSingleHorizontalBars("plot_single_bond_regions", singlePies.bondRegionsPie, "%", 100);

      // 6. Bond-Issuer-Types als strukturierte horizontale Balken
      Charts.renderSingleHorizontalBars("plot_single_bond_issuers", singlePies.bondIssuerPie, "%", 150);
    }

    // 4. Risikotabelle rendern
    const nHoldings = calcPorts[pKey]?.holdings?.length || 0;
    Tables.renderSinglePortfolioRiskTable("table_single_risk_metrics", pSum, pConc, pConf.name, nHoldings);
  }

  function renderCompareTab(analyticsResults) {
    const { calcPorts, concMetrics, assetCurrMetrics } = analyticsResults;

    // 1. Dropdowns für Portfolio A und B befüllen
    const selA = document.getElementById('select_compare_port_a');
    const selB = document.getElementById('select_compare_port_b');

    const portKeys = ["portfolio_1", "portfolio_2", "portfolio_3"];
    const enabledPorts = portKeys.filter(k => state.portfolios[k] && state.portfolios[k].enabled);

    if (selA && selB) {
      let optHtmlA = '';
      let optHtmlB = '';
      enabledPorts.forEach(pk => {
        const conf = state.portfolios[pk];
        const name = conf.name || pk;
        optHtmlA += `<option value="${pk}" ${state.comparePortA === pk ? 'selected' : ''}>${name}</option>`;
        optHtmlB += `<option value="${pk}" ${state.comparePortB === pk ? 'selected' : ''}>${name}</option>`;
      });

      selA.innerHTML = optHtmlA;
      selB.innerHTML = optHtmlB;

      // Falls aktuelle Auswahl ungültig ist
      if (!enabledPorts.includes(state.comparePortA)) {
        state.comparePortA = enabledPorts[0] || "portfolio_1";
        selA.value = state.comparePortA;
      }
      if (!enabledPorts.includes(state.comparePortB)) {
        state.comparePortB = enabledPorts[1] || enabledPorts[0] || "portfolio_2";
        selB.value = state.comparePortB;
      }
    }

    const confA = state.portfolios[state.comparePortA];
    const confB = state.portfolios[state.comparePortB];
    const nameA = confA?.name || state.comparePortA;
    const nameB = confB?.name || state.comparePortB;

    // 2. Result Badge
    const badge = document.getElementById('compare_result_badge');
    if (badge) {
      badge.innerText = `Δ (${nameA} − ${nameB})`;
    }

    // 3. Paarweise Vergleiche berechnen
    const comp = Analytics.calculatePairwiseComparison(
      state.comparePortA,
      state.comparePortB,
      state.portfolios,
      state.data.holdings,
      state.data.tickers,
      analyticsResults
    );

    if (comp) {
      Charts.renderDivergingDeltaPlot("plot_compare_asset_classes", comp.assetDeltas, nameA, nameB, "%-Pkt.", 110);
      Charts.renderDivergingDeltaPlot("plot_compare_equity_regions", comp.equityRegionDeltas, nameA, nameB, "%-Pkt.", 110);
      Charts.renderDivergingDeltaPlot("plot_compare_equity_sectors", comp.equitySectorDeltas, nameA, nameB, "%-Pkt.", 140);
      Charts.renderDivergingDeltaPlot("plot_compare_currencies", comp.currencyDeltas, nameA, nameB, "%-Pkt.", 70);
      Charts.renderDivergingDeltaPlot("plot_compare_bond_regions", comp.bondRegionDeltas, nameA, nameB, "%-Pkt.", 110);
      Charts.renderDivergingDeltaPlot("plot_compare_bond_issuers", comp.bondIssuerDeltas, nameA, nameB, "%-Pkt.", 140);
      Charts.renderDivergingDeltaPlot("plot_compare_sub_assets", comp.subAssetDeltas, nameA, nameB, "%-Pkt.", 130);
    }

    // 4. Vergleichende Tabelle
    const sumA = assetCurrMetrics.summaryMetrics.find(m => m.portfolio_key === state.comparePortA);
    const sumB = assetCurrMetrics.summaryMetrics.find(m => m.portfolio_key === state.comparePortB);
    const cA = concMetrics.find(m => m.portfolio_key === state.comparePortA);
    const cB = concMetrics.find(m => m.portfolio_key === state.comparePortB);
    const nHoldingsA = calcPorts[state.comparePortA]?.holdings?.length || 0;
    const nHoldingsB = calcPorts[state.comparePortB]?.holdings?.length || 0;

    Tables.renderPortfolioComparisonTables(
      "table_compare_metrics_left",
      "table_compare_metrics_right",
      sumA,
      sumB,
      cA,
      cB,
      nameA,
      nameB,
      nHoldingsA,
      nHoldingsB,
      comp?.currencyDeltas
    );
  }

  function renderDashboardKpis(summaryMetrics, concMetrics) {
    const pKey = state.activeSidebarPort;
    const pSum = summaryMetrics.find(m => m.portfolio_key === pKey) || {};
    const pConc = concMetrics.find(m => m.portfolio_key === pKey) || {};

    const setVal = (id, text) => {
      const elem = document.getElementById(id);
      if (elem) elem.innerText = text;
    };

    setVal('kpi-val-exp-ret', (pSum.is_active && pSum.expected_return != null) ? `${pSum.expected_return.toFixed(2)}%` : '-');
    setVal('kpi-val-exp-vol', (pSum.is_active && pSum.expected_vol != null) ? `${pSum.expected_vol.toFixed(2)}%` : '-');
    setVal('kpi-val-sharpe', (pSum.is_active && pSum.sharpe_ratio != null) ? `${pSum.sharpe_ratio.toFixed(2)}` : '-');
    setVal('kpi-val-equity', pSum.is_active ? `${pSum.equity_weight_pct.toFixed(1)}%` : '-');
    setVal('kpi-val-bonds', pSum.is_active ? `${pSum.bond_weight_pct.toFixed(1)}%` : '-');
    setVal('kpi-val-re', pSum.is_active ? `${(pSum.real_estate_weight_pct || 0).toFixed(1)}%` : '-');
    setVal('kpi-val-cmd', pSum.is_active ? `${(pSum.commodity_weight_pct || 0).toFixed(1)}%` : '-');
    setVal('kpi-val-div', (pSum.is_active && pSum.equity_weighted_div_yield) ? `${pSum.equity_weighted_div_yield.toFixed(2)}%` : '-');
    setVal('kpi-val-pe', (pSum.is_active && pSum.equity_weighted_pe) ? `${pSum.equity_weighted_pe.toFixed(1)}x` : '-');
    setVal('kpi-val-ytm', (pSum.is_active && pSum.bond_weighted_ytm) ? `${pSum.bond_weighted_ytm.toFixed(2)}%` : '-');
    setVal('kpi-val-dur', (pSum.is_active && pSum.bond_weighted_mod_duration) ? `${pSum.bond_weighted_mod_duration.toFixed(1)} J.` : '-');
    setVal('kpi-val-neff', (pConc.is_active && pConc.n_eff) ? `${pConc.n_eff}` : '-');
  }

  let activeDragItem = null;

  function renderConfigTab() {
    const portKeys = ["portfolio_1", "portfolio_2", "portfolio_3"];
    portKeys.forEach(pKey => {
      const pConf = state.portfolios[pKey];
      const nameInput = document.getElementById(`config-name-${pKey}`);
      if (nameInput && document.activeElement !== nameInput) {
        nameInput.value = pConf.name || "";
      }

      const enabledSwitch = document.getElementById(`config-enabled-${pKey}`);
      if (enabledSwitch) {
        enabledSwitch.checked = pConf.enabled !== false;
      }

      const listDiv = document.getElementById(`config-list-${pKey}`);
      if (!listDiv) return;

      const weights = pConf.weights || {};
      const rics = Object.keys(weights);

      if (rics.length === 0) {
        listDiv.innerHTML = '<div class="text-muted small py-2 text-center border rounded bg-light">Keine ETFs</div>';
      } else {
        let html = '<div class="d-flex flex-column gap-2">';
        rics.forEach((ric, idx) => {
          const tInfo = state.data.tickers.find(t => t.ric === ric) || { label: ric, asset_type: "Aktien" };
          let badge = `<span class="badge me-1" style="background-color:#EFF6FF;color:#1E40AF;border:1px solid #BFDBFE;font-size:0.68rem;padding:2px 4px;">Aktien</span>`;
          if (tInfo.asset_type === "Bonds") {
            badge = `<span class="badge me-1" style="background-color:#E6FFFA;color:#0D9488;border:1px solid #5EEAD4;font-size:0.68rem;padding:2px 4px;">Bonds</span>`;
          } else if (tInfo.asset_type === "Real Estate") {
            badge = `<span class="badge me-1" style="background-color:#FDF2F0;color:#8C564B;border:1px solid #F5C6CB;font-size:0.68rem;padding:2px 4px;">Real Estate</span>`;
          } else if (tInfo.asset_type === "Cash") {
            badge = `<span class="badge me-1" style="background-color:#F0FDF4;color:#16A34A;border:1px solid #BBF7D0;font-size:0.68rem;padding:2px 4px;">Cash</span>`;
          } else if (tInfo.asset_type === "Rohstoffe") {
            badge = `<span class="badge me-1" style="background-color:#FFFBEB;color:#D97706;border:1px solid #FDE68A;font-size:0.68rem;padding:2px 4px;">Rohstoffe</span>`;
          }

          html += `
            <div class="d-flex justify-content-between align-items-center bg-light p-2 rounded border config-etf-row" 
                 draggable="true" data-port="${pKey}" data-ric="${ric}" data-index="${idx}">
              <div class="d-flex align-items-center gap-2 text-truncate" style="max-width: 190px;">
                <i class="bi bi-grip-vertical config-drag-handle" title="Ziehen zum Neuanordnen"></i>
                <div class="text-truncate">
                  <div class="fw-semibold text-truncate" style="max-width: 165px;">${badge}<span>${tInfo.label}</span></div>
                  <div class="text-muted small">${ric}</div>
                </div>
              </div>
              <div class="d-flex align-items-center gap-1">
                <input type="number" step="0.5" class="form-control form-control-sm text-end font-monospace config-weight-input" 
                       data-port="${pKey}" data-ric="${ric}" value="${weights[ric]}" style="width: 75px;" draggable="false">
                <button class="btn btn-outline-danger btn-sm config-del-btn" data-port="${pKey}" data-ric="${ric}" draggable="false">×</button>
              </div>
            </div>
          `;
        });
        html += '</div>';
        listDiv.innerHTML = html;

        // Drag and Drop Event Listeners
        const rows = listDiv.querySelectorAll('.config-etf-row');
        rows.forEach(row => {
          row.addEventListener('dragstart', (e) => {
            if (e.target.tagName === 'INPUT' || e.target.tagName === 'BUTTON') {
              e.preventDefault();
              return;
            }
            const ric = row.getAttribute('data-ric');
            const port = row.getAttribute('data-port');
            const index = parseInt(row.getAttribute('data-index'), 10);
            activeDragItem = { port, ric, index };
            row.classList.add('dragging');
            e.dataTransfer.effectAllowed = 'move';
            e.dataTransfer.setData('text/plain', JSON.stringify(activeDragItem));
          });

          row.addEventListener('dragend', () => {
            row.classList.remove('dragging');
            rows.forEach(r => r.classList.remove('drag-over-top', 'drag-over-bottom', 'dragging'));
            activeDragItem = null;
          });

          row.addEventListener('dragover', (e) => {
            if (!activeDragItem || activeDragItem.port !== pKey || activeDragItem.ric === row.getAttribute('data-ric')) {
              return;
            }
            e.preventDefault();
            e.dataTransfer.dropEffect = 'move';

            const rect = row.getBoundingClientRect();
            const isTop = (e.clientY - rect.top) < (rect.height / 2);
            if (isTop) {
              row.classList.add('drag-over-top');
              row.classList.remove('drag-over-bottom');
            } else {
              row.classList.add('drag-over-bottom');
              row.classList.remove('drag-over-top');
            }
          });

          row.addEventListener('dragleave', () => {
            row.classList.remove('drag-over-top', 'drag-over-bottom');
          });

          row.addEventListener('drop', (e) => {
            e.preventDefault();
            row.classList.remove('drag-over-top', 'drag-over-bottom');
            if (!activeDragItem || activeDragItem.port !== pKey) {
              return;
            }

            const targetRic = row.getAttribute('data-ric');
            const sourceRic = activeDragItem.ric;
            if (sourceRic === targetRic) return;

            const rect = row.getBoundingClientRect();
            const isTop = (e.clientY - rect.top) < (rect.height / 2);

            const currentWeights = state.portfolios[pKey].weights || {};
            const currentRics = Object.keys(currentWeights);
            const fromIdx = currentRics.indexOf(sourceRic);
            if (fromIdx === -1) return;

            // Remove source item
            currentRics.splice(fromIdx, 1);

            // Find new insertion index
            let toIdx = currentRics.indexOf(targetRic);
            if (toIdx === -1) return;
            if (!isTop) {
              toIdx += 1;
            }
            currentRics.splice(toIdx, 0, sourceRic);

            // Reconstruct weights in new order
            const newWeights = {};
            currentRics.forEach(r => {
              newWeights[r] = currentWeights[r];
            });

            state.portfolios[pKey].weights = newWeights;
            state.saveStatus = "Ungespeichert";
            if (typeof Persistence !== 'undefined' && Persistence.savePortfolios) {
              Persistence.savePortfolios(state.portfolios);
            }
            updateApp();
          });
        });

        listDiv.querySelectorAll('.config-weight-input').forEach(inp => {
          inp.addEventListener('change', (e) => {
            const ric = inp.getAttribute('data-ric');
            const port = inp.getAttribute('data-port');
            state.portfolios[port].weights[ric] = Math.max(0, Number(e.target.value) || 0);
            state.portfolios[port].enabled = true;
            state.saveStatus = "Ungespeichert";
            if (typeof Persistence !== 'undefined' && Persistence.savePortfolios) {
              Persistence.savePortfolios(state.portfolios);
            }
            updateApp();
          });
        });

        listDiv.querySelectorAll('.config-del-btn').forEach(btn => {
          btn.addEventListener('click', () => {
            const ric = btn.getAttribute('data-ric');
            const port = btn.getAttribute('data-port');
            delete state.portfolios[port].weights[ric];
            state.saveStatus = "Ungespeichert";
            if (typeof Persistence !== 'undefined' && Persistence.savePortfolios) {
              Persistence.savePortfolios(state.portfolios);
            }
            updateApp();
          });
        });
      }
    });
  }

  function setupEventHandlers() {
    // Tab Navigation
    document.querySelectorAll('#mainNav .nav-link').forEach(link => {
      link.addEventListener('click', (e) => {
        e.preventDefault();
        document.querySelectorAll('#mainNav .nav-link').forEach(l => l.classList.remove('active'));
        link.classList.add('active');

        const targetTab = link.getAttribute('data-tab');
        document.querySelectorAll('.tab-content-panel').forEach(p => p.classList.add('d-none'));
        document.getElementById(targetTab)?.classList.remove('d-none');

        state.activeTab = targetTab;
        updateApp();
      });
    });

    // Config Tab Aktiv-Schalter
    document.querySelectorAll('.config-port-enabled').forEach(sw => {
      sw.addEventListener('change', (e) => {
        const pKey = sw.getAttribute('data-port');
        if (state.portfolios[pKey]) {
          state.portfolios[pKey].enabled = e.target.checked;
          state.saveStatus = "Ungespeichert";
          if (typeof Persistence !== 'undefined' && Persistence.savePortfolios) {
            Persistence.savePortfolios(state.portfolios);
          }
          updateApp();
        }
      });
    });

    // Sidebar Portfolio Selector
    document.querySelectorAll('input[name="sidebar_port_choice"]').forEach(radio => {
      radio.addEventListener('change', (e) => {
        state.activeSidebarPort = e.target.value;
        updateApp();
      });
    });

    // Normalisierungs-Toggle
    const normToggle = document.getElementById('toggle-normalize-holdings');
    if (normToggle) {
      normToggle.addEventListener('change', (e) => {
        if (!state.portfolios.settings) state.portfolios.settings = {};
        state.portfolios.settings.normalize_holdings = e.target.checked;
        state.saveStatus = "Ungespeichert";
        updateApp();
      });
    }

    // Sidebar Quick Buttons
    document.getElementById('sidebar-btn-norm')?.addEventListener('click', () => {
      const pConf = state.portfolios[state.activeSidebarPort];
      const w = pConf.weights || {};
      const sumW = Object.values(w).reduce((s, x) => s + (Number(x) || 0), 0);
      if (sumW > 0) {
        for (const ric of Object.keys(w)) {
          w[ric] = Number(((w[ric] / sumW) * 100).toFixed(1));
        }
        state.saveStatus = "Ungespeichert";
        updateApp();
      }
    });

    document.getElementById('sidebar-btn-eq')?.addEventListener('click', () => {
      const pConf = state.portfolios[state.activeSidebarPort];
      const rics = Object.keys(pConf.weights || {});
      if (rics.length > 0) {
        const eqW = Number((100 / rics.length).toFixed(1));
        rics.forEach(r => pConf.weights[r] = eqW);
        state.saveStatus = "Ungespeichert";
        updateApp();
      }
    });

    document.getElementById('sidebar-btn-clear')?.addEventListener('click', () => {
      state.portfolios[state.activeSidebarPort].weights = {};
      state.saveStatus = "Ungespeichert";
      updateApp();
    });

    // Sidebar ETF Hinzufügen
    document.getElementById('sidebar-btn-add-etf')?.addEventListener('click', () => {
      const sel = document.getElementById('sidebar-select-add-etf');
      const ric = sel?.value;
      if (ric) {
        if (!state.portfolios[state.activeSidebarPort].weights) {
          state.portfolios[state.activeSidebarPort].weights = {};
        }
        state.portfolios[state.activeSidebarPort].weights[ric] = 5.0;
        state.saveStatus = "Ungespeichert";
        updateApp();
      }
    });

    // Speichern & Reset (Sidebar & Tab 6)
    const handleSave = () => {
      // Namen aus Inputs synchronisieren
      ["portfolio_1", "portfolio_2", "portfolio_3"].forEach(pKey => {
        const inp = document.getElementById(`config-name-${pKey}`);
        if (inp && inp.value.trim() !== "") {
          state.portfolios[pKey].name = inp.value.trim();
        }
      });
      Persistence.savePortfolios(state.portfolios);
      state.saveStatus = "Gespeichert";
      updateApp();
    };

    document.getElementById('sidebar-btn-save')?.addEventListener('click', handleSave);
    document.getElementById('btn-config-save')?.addEventListener('click', () => {
      handleSave();
      alert("Portfolios und Namen erfolgreich gespeichert!");
    });

    // Live-Update für Portfolio-Namen im Editor
    ["portfolio_1", "portfolio_2", "portfolio_3"].forEach(pKey => {
      const inp = document.getElementById(`config-name-${pKey}`);
      if (inp) {
        inp.addEventListener('input', (e) => {
          state.portfolios[pKey].name = e.target.value;
          state.saveStatus = "Ungespeichert";
          const statusBadge = document.getElementById('sidebar-save-status');
          if (statusBadge) {
            statusBadge.innerText = state.saveStatus;
            statusBadge.className = "badge bg-warning text-dark";
          }
        });
        inp.addEventListener('change', (e) => {
          state.portfolios[pKey].name = e.target.value.trim() || pKey;
          state.saveStatus = "Ungespeichert";
          updateApp();
        });
      }
    });

    document.getElementById('sidebar-btn-reset')?.addEventListener('click', () => {
      if (confirm("Möchten Sie die Portfolios wirklich auf die Standardwerte zurücksetzen?")) {
        state.portfolios = Persistence.getDefaultPortfolios(state.data.tickers.map(t => t.ric), state.data.tickers);
        Persistence.savePortfolios(state.portfolios);
        state.saveStatus = "Gespeichert";
        updateApp();
      }
    });

    document.getElementById('btn-export-json')?.addEventListener('click', () => {
      Persistence.exportPortfoliosAsJson(state.portfolios);
    });

    const importTrigger = document.getElementById('btn-import-json-trigger');
    const importFileInput = document.getElementById('input-import-json-file');

    importTrigger?.addEventListener('click', () => {
      importFileInput?.click();
    });

    importFileInput?.addEventListener('change', (e) => {
      const file = e.target.files?.[0];
      if (file) {
        Persistence.importPortfoliosFromJsonFile(
          file,
          (importedPorts) => {
            state.portfolios = importedPorts;
            state.saveStatus = "Gespeichert (Import)";
            updateApp();
            alert("Portfolios erfolgreich importiert und gespeichert!");
          },
          (err) => {
            alert("Fehler beim Import: " + err.message);
          }
        );
        importFileInput.value = "";
      }
    });

    // Dashboard Assetklassen Delta Dropdown
    document.getElementById('select-dash-asset-delta-pair')?.addEventListener('change', (e) => {
      state.selectedDashAssetDeltaPair = e.target.value;
      updateApp();
    });

    // Dashboard Region Delta Dropdown
    document.getElementById('select-dash-region-delta-pair')?.addEventListener('change', (e) => {
      state.selectedDashRegionDeltaPair = e.target.value;
      updateApp();
    });

    // Bond Region Issuer Breakdown Portfolio Dropdown
    document.getElementById('select_bond_breakdown_portfolio')?.addEventListener('change', (e) => {
      state.selectedBondBreakdownPort = e.target.value;
      updateApp();
    });

    // Sektor Delta Dropdown
    document.getElementById('select-sector-delta-pair')?.addEventListener('change', (e) => {
      state.selectedDeltaPair = e.target.value;
      updateApp();
    });

    // Sektor Drilldown Dropdown
    document.getElementById('select-drilldown-sector')?.addEventListener('change', (e) => {
      state.selectedDrilldownSector = e.target.value;
      updateApp();
    });

    // Full Lookthrough
    document.getElementById('select-full-table-asset-class')?.addEventListener('change', (e) => {
      state.selectedFullTableAssetClass = e.target.value;
      updateApp();
    });

    document.getElementById('select-full-table-port')?.addEventListener('change', (e) => {
      state.selectedFullTablePort = e.target.value;
      updateApp();
    });

    document.getElementById('input-full-table-search')?.addEventListener('input', (e) => {
      state.fullTableSearch = e.target.value;
      updateApp();
    });

    // Single Dashboard Drilldown Dropdowns
    document.getElementById('select_single_equity_sector_region')?.addEventListener('change', (e) => {
      state.singleEquitySectorRegion = e.target.value;
      updateApp();
    });

    document.getElementById('select_single_bond_issuer_region')?.addEventListener('change', (e) => {
      state.singleBondIssuerRegion = e.target.value;
      updateApp();
    });

    document.getElementById('select_single_currency_asset_class')?.addEventListener('change', (e) => {
      state.singleCurrencyAssetClass = e.target.value;
      updateApp();
    });

    // Vergleich Tab Dropdowns
    document.getElementById('select_compare_port_a')?.addEventListener('change', (e) => {
      state.comparePortA = e.target.value;
      updateApp();
    });

    document.getElementById('select_compare_port_b')?.addEventListener('change', (e) => {
      state.comparePortB = e.target.value;
      updateApp();
    });

    document.querySelectorAll('#pills_compare_bonds button[data-bs-toggle="pill"]').forEach(btn => {
      btn.addEventListener('shown.bs.tab', (e) => {
        const targetId = e.target.getAttribute('data-bs-target');
        if (targetId === '#pills-compare-bond-reg') {
          Plotly.Plots.resize('plot_compare_bond_regions');
        } else if (targetId === '#pills-compare-bond-iss') {
          Plotly.Plots.resize('plot_compare_bond_issuers');
        }
      });
    });
  }

  function populateSectorDrilldownSelect() {
    const sel = document.getElementById('select-drilldown-sector');
    if (!sel) return;
    sel.innerHTML = Analytics.GICS_11_SECTORS.map(s => `<option value="${s}" ${s === "Health Care" ? 'selected' : ''}>${s}</option>`).join('');
  }

  document.addEventListener('DOMContentLoaded', initApp);
})(typeof window !== 'undefined' ? window : globalThis);
