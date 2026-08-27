// ==============================================================================
// web/js/charts.js
// Plotly.js Visualisierungen für Sektoren, Allokation, Währungen & Top Holdings
// ==============================================================================

(function(global) {
  const PORTFOLIO_COLORS = {
    "portfolio_1": "#1E40AF", // LUKB Corporate Navy
    "portfolio_2": "#0D9488", // Teal / Petrol
    "portfolio_3": "#E11D48"  // Rose / Coral
  };

  const DEFAULT_PLOT_LAYOUT = {
    font: { family: "Inter, -apple-system, sans-serif", size: 12 },
    margin: { t: 30, r: 20, l: 60, b: 40 },
    paper_bgcolor: "transparent",
    plot_bgcolor: "transparent",
    hovermode: "closest",
    hoverlabel: { bgcolor: "#1E293B", font: { color: "#FFFFFF", size: 12 } }
  };

  function renderDashboardSectors(elementId, sectorData, activePortKey = "portfolio_1", portName = "Portfolio 1") {
    const elem = document.getElementById(elementId);
    if (!elem || typeof Plotly === 'undefined') return;

    const sectorColors = global.Analytics?.GICS_SECTOR_COLORS || {};
    const colKey = `weight_${activePortKey}`;
    const nonZero = sectorData.filter(d => (d[colKey] || 0) > 0.05);

    if (nonZero.length === 0) {
      Plotly.newPlot(elem, [], {
        ...DEFAULT_PLOT_LAYOUT,
        annotations: [{ text: "Keine Aktiensektoren verfügbar", showarrow: false, font: { size: 14, color: "#64748B" } }]
      }, { responsive: true, displayModeBar: false });
      return;
    }

    const trace = {
      labels: nonZero.map(d => d.gics_sector),
      values: nonZero.map(d => d[colKey]),
      type: "pie",
      hole: 0.5,
      marker: {
        colors: nonZero.map(d => sectorColors[d.gics_sector] || "#94A3B8")
      },
      textinfo: "label+percent",
      textposition: "inside",
      hoverinfo: "label+value+percent",
      hovertemplate: "<b>%{label}</b><br>Gewicht: %{value:.2f}%<br>Anteil am Aktienteil: %{percent}<extra></extra>"
    };

    const layout = {
      ...DEFAULT_PLOT_LAYOUT,
      showlegend: false,
      margin: { t: 20, r: 20, l: 20, b: 20 },
      annotations: [
        {
          text: `<b>${portName}</b><br><span style="font-size:11px;color:#64748B;">Aktiensektoren</span>`,
          showarrow: false,
          font: { size: 13, color: "#1E293B" }
        }
      ]
    };

    Plotly.react(elem, [trace], layout, { responsive: true, displayModeBar: false });
  }

  function renderAssetAllocationPlot(elementId, assetData, portfoliosState) {
    const elem = document.getElementById(elementId);
    if (!elem || typeof Plotly === 'undefined') return;

    const traces = [];
    const portKeys = ["portfolio_1", "portfolio_2", "portfolio_3"];
    const assetTypes = ["Aktien", "Bonds", "Real Estate", "Rohstoffe", "Cash"];
    const assetColors = {
      "Aktien": "#1E40AF",
      "Bonds": "#0D9488",
      "Real Estate": "#8C564B",
      "Rohstoffe": "#D97706",
      "Cash": "#16A34A"
    };

    for (const aType of assetTypes) {
      const xVals = [];
      const yVals = [];

      for (const pKey of portKeys) {
        const pConf = portfoliosState[pKey];
        if (pConf && pConf.enabled) {
          xVals.push(pConf.name || pKey);
          const match = assetData.find(d => d.portfolio_key === pKey && d.asset_type === aType);
          yVals.push(match ? match.pct : 0);
        }
      }

      if (xVals.length > 0 && yVals.some(v => v > 0)) {
        traces.push({
          x: xVals,
          y: yVals,
          name: aType,
          type: "bar",
          marker: { color: assetColors[aType] || "#64748B" },
          hovertemplate: `<b>%{x}</b><br>${aType}: %{y:.2f}%<extra></extra>`
        });
      }
    }

    const layout = {
      ...DEFAULT_PLOT_LAYOUT,
      barmode: "stack",
      yaxis: { title: "Anteil (%)", range: [0, 105], gridcolor: "#E2E8F0" },
      xaxis: { gridcolor: "#E2E8F0" },
      legend: { orientation: "h", y: -0.2 }
    };

    Plotly.react(elem, traces, layout, { responsive: true, displayModeBar: false });
  }

  function renderOverallCurrencyPlot(elementId, currCompareData, portfoliosState) {
    const elem = document.getElementById(elementId);
    if (!elem || typeof Plotly === 'undefined') return;

    const topCurrencies = currCompareData.slice(0, 8);
    const traces = [];
    const portKeys = ["portfolio_1", "portfolio_2", "portfolio_3"];

    for (const pKey of portKeys) {
      const pConf = portfoliosState[pKey];
      if (pConf && pConf.enabled) {
        traces.push({
          x: topCurrencies.map(c => c.currency),
          y: topCurrencies.map(c => c[`weight_${pKey}`] || 0),
          name: pConf.name || pKey,
          type: "bar",
          marker: { color: PORTFOLIO_COLORS[pKey] },
          hovertemplate: `<b>%{x}</b> (%{fullData.name})<br>Gewicht: %{y:.2f}%<extra></extra>`
        });
      }
    }

    const layout = {
      ...DEFAULT_PLOT_LAYOUT,
      barmode: "group",
      yaxis: { title: "Währungsanteil (%)", gridcolor: "#E2E8F0" },
      xaxis: { title: "Währung" },
      legend: { orientation: "h", y: -0.25 }
    };

    Plotly.react(elem, traces, layout, { responsive: true, displayModeBar: false });
  }

  function renderSegmentCurrencyPlot(elementId, segmentCurrData, portfoliosState, segmentName = "Aktien") {
    const elem = document.getElementById(elementId);
    if (!elem || typeof Plotly === 'undefined') return;

    const traces = [];
    const portKeys = ["portfolio_1", "portfolio_2", "portfolio_3"];

    for (const pKey of portKeys) {
      const pConf = portfoliosState[pKey];
      if (pConf && pConf.enabled) {
        const pData = segmentCurrData.filter(d => d.portfolio_key === pKey);
        if (pData.length > 0) {
          traces.push({
            x: pData.map(d => d.currency),
            y: pData.map(d => d.pct_of_equity ?? d.pct_of_bonds ?? 0),
            name: pConf.name || pKey,
            type: "bar",
            marker: { color: PORTFOLIO_COLORS[pKey] },
            hovertemplate: `<b>%{x}</b> (%{fullData.name})<br>Anteil im Segment: %{y:.2f}%<extra></extra>`
          });
        }
      }
    }

    const layout = {
      ...DEFAULT_PLOT_LAYOUT,
      barmode: "group",
      yaxis: { title: `Anteil an ${segmentName} (%)`, gridcolor: "#E2E8F0" },
      legend: { orientation: "h", y: -0.25 }
    };

    Plotly.react(elem, traces, layout, { responsive: true, displayModeBar: false });
  }

  function renderSectorBarsPlot(elementId, sectorData, portfoliosState) {
    const elem = document.getElementById(elementId);
    if (!elem || typeof Plotly === 'undefined') return;

    const traces = [];
    const portKeys = ["portfolio_1", "portfolio_2", "portfolio_3"];

    for (const pKey of portKeys) {
      const pConf = portfoliosState[pKey];
      if (pConf && pConf.enabled) {
        traces.push({
          y: sectorData.map(d => d.gics_sector),
          x: sectorData.map(d => d[`weight_${pKey}`] || 0),
          name: pConf.name || pKey,
          type: "bar",
          orientation: "h",
          marker: { color: PORTFOLIO_COLORS[pKey] },
          hovertemplate: `<b>%{y}</b> (%{fullData.name})<br>Gewicht: %{x:.2f}%<extra></extra>`
        });
      }
    }

    const layout = {
      ...DEFAULT_PLOT_LAYOUT,
      barmode: "group",
      margin: { t: 20, r: 20, l: 150, b: 40 },
      xaxis: { title: "Sektorgewicht im Aktienteil (%)", gridcolor: "#E2E8F0" },
      yaxis: { autorange: "reversed" },
      legend: { orientation: "h", y: -0.2 }
    };

    Plotly.react(elem, traces, layout, { responsive: true, displayModeBar: false });
  }

  function renderSectorDeltaPlot(elementId, sectorData, deltaPair = "delta_p1_p2") {
    const elem = document.getElementById(elementId);
    if (!elem || typeof Plotly === 'undefined') return;

    const yVals = sectorData.map(d => d.gics_sector);
    const xVals = sectorData.map(d => d[deltaPair] || 0);
    const colors = xVals.map(v => v >= 0 ? "#1E40AF" : "#E11D48");

    const trace = {
      y: yVals,
      x: xVals,
      type: "bar",
      orientation: "h",
      marker: { color: colors },
      hovertemplate: `<b>%{y}</b><br>Delta: %{x:+.2f}%<extra></extra>`
    };

    const layout = {
      ...DEFAULT_PLOT_LAYOUT,
      margin: { t: 20, r: 20, l: 150, b: 40 },
      xaxis: { title: `Übergewicht / Untergewicht (%)`, zerolinecolor: "#475569", gridcolor: "#E2E8F0" },
      yaxis: { autorange: "reversed" },
      shapes: [{
        type: "line",
        x0: 0, x1: 0,
        y0: -0.5, y1: yVals.length - 0.5,
        line: { color: "#334155", width: 1.5 }
      }]
    };

    Plotly.react(elem, [trace], layout, { responsive: true, displayModeBar: false });
  }

  function renderRegionDeltaPlot(elementId, regionData, deltaPair = "delta_p1_p2") {
    const elem = document.getElementById(elementId);
    if (!elem || typeof Plotly === 'undefined') return;

    let colA = "weight_portfolio_1";
    let colB = "weight_portfolio_2";
    if (deltaPair === "delta_p1_p3") {
      colA = "weight_portfolio_1";
      colB = "weight_portfolio_3";
    } else if (deltaPair === "delta_p2_p3") {
      colA = "weight_portfolio_2";
      colB = "weight_portfolio_3";
    }

    // Nur Regionen herausfiltern, die tatsächlich in mindestens einem der beiden verglichenen Portfolios vorkommen
    const activeRegionData = regionData.filter(d => 
      ((d[colA] || 0) > 0.001 || (d[colB] || 0) > 0.001) && d.region !== "Global"
    );

    if (activeRegionData.length === 0) {
      Plotly.newPlot(elem, [], {
        ...DEFAULT_PLOT_LAYOUT,
        annotations: [{ text: "Keine Aktienregionen im ausgewählten Vergleich", showarrow: false, font: { size: 13, color: "#64748B" } }]
      }, { responsive: true, displayModeBar: false });
      return;
    }

    const yVals = activeRegionData.map(d => d.region);
    const xVals = activeRegionData.map(d => d[deltaPair] || 0);
    const colors = xVals.map(v => v >= 0 ? "#1E40AF" : "#E11D48");

    const trace = {
      y: yVals,
      x: xVals,
      type: "bar",
      orientation: "h",
      marker: { color: colors },
      hovertemplate: `<b>%{y}</b><br>Delta: %{x:+.2f}%<extra></extra>`
    };

    const layout = {
      ...DEFAULT_PLOT_LAYOUT,
      margin: { t: 20, r: 20, l: 130, b: 40 },
      xaxis: { title: `Übergewicht / Untergewicht (%)`, zerolinecolor: "#475569", gridcolor: "#E2E8F0" },
      yaxis: { autorange: "reversed" },
      shapes: [{
        type: "line",
        x0: 0, x1: 0,
        y0: -0.5, y1: yVals.length - 0.5,
        line: { color: "#334155", width: 1.5 }
      }]
    };

    Plotly.react(elem, [trace], layout, { responsive: true, displayModeBar: false });
  }

  function renderAssetDeltaPlot(elementId, assetCompareData, deltaPair = "delta_p1_p2") {
    const elem = document.getElementById(elementId);
    if (!elem || typeof Plotly === 'undefined' || !Array.isArray(assetCompareData)) return;

    let colA = "weight_portfolio_1";
    let colB = "weight_portfolio_2";
    if (deltaPair === "delta_p1_p3") {
      colA = "weight_portfolio_1";
      colB = "weight_portfolio_3";
    } else if (deltaPair === "delta_p2_p3") {
      colA = "weight_portfolio_2";
      colB = "weight_portfolio_3";
    }

    const activeAssets = assetCompareData.filter(d => 
      ((d[colA] || 0) > 0.001 || (d[colB] || 0) > 0.001)
    );

    if (activeAssets.length === 0) {
      Plotly.newPlot(elem, [], {
        ...DEFAULT_PLOT_LAYOUT,
        annotations: [{ text: "Keine Assetklassen im ausgewählten Vergleich", showarrow: false, font: { size: 13, color: "#64748B" } }]
      }, { responsive: true, displayModeBar: false });
      return;
    }

    const yVals = activeAssets.map(d => d.asset_type);
    const xVals = activeAssets.map(d => d[deltaPair] || 0);
    const colors = xVals.map(v => v >= 0 ? "#1E40AF" : "#E11D48");

    const trace = {
      y: yVals,
      x: xVals,
      type: "bar",
      orientation: "h",
      marker: { color: colors },
      hovertemplate: `<b>%{y}</b><br>Delta: %{x:+.2f}%-Pkt.<extra></extra>`
    };

    const layout = {
      ...DEFAULT_PLOT_LAYOUT,
      margin: { t: 20, r: 20, l: 110, b: 40 },
      xaxis: { title: `Übergewicht / Untergewicht (%-Punkte)`, zerolinecolor: "#475569", gridcolor: "#E2E8F0" },
      yaxis: { autorange: "reversed" },
      shapes: [{
        type: "line",
        x0: 0, x1: 0,
        y0: -0.5, y1: yVals.length - 0.5,
        line: { color: "#334155", width: 1.5 }
      }]
    };

    Plotly.react(elem, [trace], layout, { responsive: true, displayModeBar: false });
  }

  function renderTop20BarsPlot(elementId, combinedTop, portfoliosState) {
    const elem = document.getElementById(elementId);
    if (!elem || typeof Plotly === 'undefined') return;

    const topSlice = combinedTop.slice(0, 20).reverse();
    const traces = [];
    const portKeys = ["portfolio_1", "portfolio_2", "portfolio_3"];

    for (const pKey of portKeys) {
      const pConf = portfoliosState[pKey];
      if (pConf && pConf.enabled) {
        traces.push({
          y: topSlice.map(d => d.holding_name || d.holding_ric),
          x: topSlice.map(d => d[`weight_${pKey}`] || 0),
          name: pConf.name || pKey,
          type: "bar",
          orientation: "h",
          marker: { color: PORTFOLIO_COLORS[pKey] },
          hovertemplate: `<b>%{y}</b> (%{fullData.name})<br>Portfolio-Gewicht: %{x:.2f}%<extra></extra>`
        });
      }
    }

    const layout = {
      ...DEFAULT_PLOT_LAYOUT,
      barmode: "group",
      margin: { t: 20, r: 20, l: 200, b: 40 },
      xaxis: { title: "Look-Through Gewicht (%)", gridcolor: "#E2E8F0" },
      legend: { orientation: "h", y: -0.15 }
    };

    Plotly.react(elem, traces, layout, { responsive: true, displayModeBar: false });
  }

  function renderLorenzPlot(elementId, lorenzData, portfoliosState) {
    const elem = document.getElementById(elementId);
    if (!elem || typeof Plotly === 'undefined') return;

    const traces = [];

    traces.push({
      x: [0, 100],
      y: [0, 100],
      name: "Gleichverteilung (Referenz)",
      type: "scatter",
      mode: "lines",
      line: { dash: "dash", color: "#94A3B8", width: 1.5 },
      hoverinfo: "skip"
    });

    const portKeys = ["portfolio_1", "portfolio_2", "portfolio_3"];
    for (const pKey of portKeys) {
      const pConf = portfoliosState[pKey];
      if (pConf && pConf.enabled) {
        const pCurve = lorenzData.find(c => c.portfolio_key === pKey);
        if (pCurve && pCurve.pct_holdings.length > 0) {
          traces.push({
            x: [0, ...pCurve.pct_holdings],
            y: [0, ...pCurve.cum_weight],
            name: pConf.name || pKey,
            type: "scatter",
            mode: "lines",
            line: { color: PORTFOLIO_COLORS[pKey], width: 2.5 },
            hovertemplate: `<b>%{fullData.name}</b><br>Top %{x:.1f}% der Titel konzentrieren %{y:.1f}% des Aktiengewichts<extra></extra>`
          });
        }
      }
    }

    const layout = {
      ...DEFAULT_PLOT_LAYOUT,
      xaxis: { title: "Kumulierter Anteil der Titel (%)", range: [0, 100], gridcolor: "#E2E8F0" },
      yaxis: { title: "Kumuliertes Aktiengewicht (%)", range: [0, 105], gridcolor: "#E2E8F0" },
      legend: { orientation: "h", y: -0.2 }
    };

    Plotly.react(elem, traces, layout, { responsive: true, displayModeBar: false });
  }

  const Charts = {
    renderDashboardSectors,
    renderAssetAllocationPlot,
    renderAssetDeltaPlot,
    renderOverallCurrencyPlot,
    renderSegmentCurrencyPlot,
    renderSectorBarsPlot,
    renderSectorDeltaPlot,
    renderRegionDeltaPlot,
    renderTop20BarsPlot,
    renderLorenzPlot
  };

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = Charts;
  } else {
    global.Charts = Charts;
  }
})(typeof window !== 'undefined' ? window : globalThis);
