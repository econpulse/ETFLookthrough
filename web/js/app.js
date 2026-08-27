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
    const assetCurrMetrics = Analytics.calculatePortfolioAssetAndCurrencyMetrics(calcPorts);

    // 2. Sidebar rendern
    renderSidebar();

    // 3. Aktiven Tab aktualisieren
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
              <button class="btn btn-outline-danger btn-sm p-0 px-1 border-0 fw-bold btn-del-etf" data-ric="${ric}" title="Entfernen">×</button>
            </div>
            <div class="d-flex align-items-center justify-content-between">
              <button class="btn btn-outline-secondary btn-sm stepper-btn btn-dec-etf" data-ric="${ric}">-</button>
              <span class="badge bg-light text-dark border font-monospace fw-bold px-2 py-1" style="font-size: 0.85rem; min-width: 65px; text-align: center;">
                ${wVal.toFixed(1)}%
              </span>
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
      Charts.renderAssetDeltaPlot("plot_dash_asset_delta", assetCurrMetrics.assetClassComparison, state.selectedDashAssetDeltaPair);
      Charts.renderRegionDeltaPlot("plot_dash_region_delta", regionData, state.selectedDashRegionDeltaPair);
      Tables.renderDashboardTop10Table("table_dash_top10", topHoldings.combinedTop, state.portfolios);
      Tables.renderMultiAssetSummaryTable("table_dash_multi_asset", assetCurrMetrics.summaryMetrics, state.portfolios);
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
      Charts.renderSectorDeltaPlot("plot_sector_delta", sectorData, state.selectedDeltaPair);
      Tables.renderSectorDetailTable("table_sectors_detail", sectorData);
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

  function renderDashboardKpis(summaryMetrics, concMetrics) {
    const pKey = state.activeSidebarPort;
    const pSum = summaryMetrics.find(m => m.portfolio_key === pKey) || {};
    const pConc = concMetrics.find(m => m.portfolio_key === pKey) || {};

    const setVal = (id, text) => {
      const elem = document.getElementById(id);
      if (elem) elem.innerText = text;
    };

    setVal('kpi-val-equity', pSum.is_active ? `${pSum.equity_weight_pct.toFixed(1)}%` : '-');
    setVal('kpi-val-bonds', pSum.is_active ? `${pSum.bond_weight_pct.toFixed(1)}%` : '-');
    setVal('kpi-val-re', pSum.is_active ? `${(pSum.real_estate_weight_pct || 0).toFixed(1)}%` : '-');
    setVal('kpi-val-div', (pSum.is_active && pSum.equity_weighted_div_yield) ? `${pSum.equity_weighted_div_yield.toFixed(2)}%` : '-');
    setVal('kpi-val-pe', (pSum.is_active && pSum.equity_weighted_pe) ? `${pSum.equity_weighted_pe.toFixed(1)}x` : '-');
    setVal('kpi-val-ytm', (pSum.is_active && pSum.bond_weighted_ytm) ? `${pSum.bond_weighted_ytm.toFixed(2)}%` : '-');
    setVal('kpi-val-dur', (pSum.is_active && pSum.bond_weighted_mod_duration) ? `${pSum.bond_weighted_mod_duration.toFixed(1)} J.` : '-');
    setVal('kpi-val-neff', (pConc.is_active && pConc.n_eff) ? `${pConc.n_eff}` : '-');
  }

  function renderConfigTab() {
    const portKeys = ["portfolio_1", "portfolio_2", "portfolio_3"];
    portKeys.forEach(pKey => {
      const pConf = state.portfolios[pKey];
      const nameInput = document.getElementById(`config-name-${pKey}`);
      if (nameInput && document.activeElement !== nameInput) {
        nameInput.value = pConf.name || "";
      }

      const listDiv = document.getElementById(`config-list-${pKey}`);
      if (!listDiv) return;

      const weights = pConf.weights || {};
      const rics = Object.keys(weights);

      if (rics.length === 0) {
        listDiv.innerHTML = '<div class="text-muted small py-2 text-center border rounded bg-light">Keine ETFs</div>';
      } else {
        let html = '<div class="d-flex flex-column gap-2">';
        rics.forEach(ric => {
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
            <div class="d-flex justify-content-between align-items-center bg-light p-2 rounded border">
              <div>
                <div class="fw-semibold text-truncate" style="max-width: 170px;">${badge}<span>${tInfo.label}</span></div>
                <div class="text-muted small">${ric}</div>
              </div>
              <div class="d-flex align-items-center gap-1">
                <input type="number" step="0.5" class="form-control form-control-sm text-end font-monospace config-weight-input" 
                       data-port="${pKey}" data-ric="${ric}" value="${weights[ric]}" style="width: 75px;">
                <button class="btn btn-outline-danger btn-sm config-del-btn" data-port="${pKey}" data-ric="${ric}">×</button>
              </div>
            </div>
          `;
        });
        html += '</div>';
        listDiv.innerHTML = html;

        listDiv.querySelectorAll('.config-weight-input').forEach(inp => {
          inp.addEventListener('change', (e) => {
            const ric = inp.getAttribute('data-ric');
            const port = inp.getAttribute('data-port');
            state.portfolios[port].weights[ric] = Math.max(0, Number(e.target.value) || 0);
            state.saveStatus = "Ungespeichert";
            updateApp();
          });
        });

        listDiv.querySelectorAll('.config-del-btn').forEach(btn => {
          btn.addEventListener('click', () => {
            const ric = btn.getAttribute('data-ric');
            const port = btn.getAttribute('data-port');
            delete state.portfolios[port].weights[ric];
            state.saveStatus = "Ungespeichert";
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
  }

  function populateSectorDrilldownSelect() {
    const sel = document.getElementById('select-drilldown-sector');
    if (!sel) return;
    sel.innerHTML = Analytics.GICS_11_SECTORS.map(s => `<option value="${s}" ${s === "Health Care" ? 'selected' : ''}>${s}</option>`).join('');
  }

  document.addEventListener('DOMContentLoaded', initApp);
})(typeof window !== 'undefined' ? window : globalThis);
