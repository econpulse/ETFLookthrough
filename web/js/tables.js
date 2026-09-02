// ==============================================================================
// web/js/tables.js
// Tabellen-Renderer für Top Holdings, Sektoren, Allokation & Konzentration
// ==============================================================================

(function(global) {
  function formatNum(val, decimals = 2, suffix = "") {
    if (val == null || isNaN(val)) return '<span class="text-muted">-</span>';
    return `${Number(val).toFixed(decimals)}${suffix}`;
  }

  function formatDelta(val) {
    if (val == null || isNaN(val) || Math.abs(val) < 0.001) {
      return '<span class="text-muted">0.00%</span>';
    }
    const cls = val > 0 ? "text-primary fw-semibold" : "text-danger fw-semibold";
    const sign = val > 0 ? "+" : "";
    return `<span class="${cls}">${sign}${val.toFixed(2)}%</span>`;
  }

  function getAssetBadge(assetType) {
    if (assetType === "Bonds") {
      return '<span class="badge" style="background-color:#E6FFFA;color:#0D9488;border:1px solid #5EEAD4;font-size:0.75rem;">Bonds</span>';
    }
    if (assetType === "Real Estate") {
      return '<span class="badge" style="background-color:#FDF2F0;color:#8C564B;border:1px solid #F5C6CB;font-size:0.75rem;">Real Estate</span>';
    }
    if (assetType === "Cash") {
      return '<span class="badge" style="background-color:#F0FDF4;color:#16A34A;border:1px solid #BBF7D0;font-size:0.75rem;">Cash</span>';
    }
    if (assetType === "Rohstoffe") {
      return '<span class="badge" style="background-color:#FFFBEB;color:#D97706;border:1px solid #FDE68A;font-size:0.75rem;">Rohstoffe</span>';
    }
    return '<span class="badge" style="background-color:#EFF6FF;color:#1E40AF;border:1px solid #BFDBFE;font-size:0.75rem;">Aktien</span>';
  }

  function getSectorBadge(sector) {
    if (!sector) return '<span class="badge bg-light text-muted border">-</span>';
    const sectorColors = global.Analytics?.GICS_SECTOR_COLORS || {};
    const color = sectorColors[sector] || "#64748B";
    return `<span class="badge" style="background-color: ${color}20; color: ${color}; border: 1px solid ${color}40; font-size: 0.75rem;">${sector}</span>`;
  }

  function renderDashboardTop10Table(elementId, combinedTop, portfoliosState) {
    const elem = document.getElementById(elementId);
    if (!elem) return;

    const top10 = combinedTop.slice(0, 10);
    if (top10.length === 0) {
      elem.innerHTML = '<div class="text-center text-muted py-3 small">Keine Daten verfügbar</div>';
      return;
    }

    let html = `
      <div class="table-responsive" style="max-height: 360px;">
        <table class="table table-sm table-hover align-middle mb-0" style="font-size: 0.82rem;">
          <thead class="table-light sticky-top">
            <tr>
              <th style="width: 30px;">#</th>
              <th>Titel</th>
              <th>Asset</th>
              <th>Sektor</th>
              <th class="text-end">P1</th>
              <th class="text-end">P2</th>
              <th class="text-end">P3</th>
            </tr>
          </thead>
          <tbody>
    `;

    top10.forEach((h, i) => {
      html += `
        <tr>
          <td class="text-muted small">${i + 1}</td>
          <td>
            <div class="fw-semibold text-truncate" style="max-width: 140px;" title="${h.holding_name}">${h.holding_name || h.holding_ric}</div>
            <div class="text-muted" style="font-size: 0.72rem;">${h.holding_ric}</div>
          </td>
          <td>${getAssetBadge(h.asset_type)}</td>
          <td>${getSectorBadge(h.gics_sector)}</td>
          <td class="text-end font-monospace">${h.weight_portfolio_1 > 0 ? h.weight_portfolio_1.toFixed(2) + '%' : '-'}</td>
          <td class="text-end font-monospace">${h.weight_portfolio_2 > 0 ? h.weight_portfolio_2.toFixed(2) + '%' : '-'}</td>
          <td class="text-end font-monospace">${h.weight_portfolio_3 > 0 ? h.weight_portfolio_3.toFixed(2) + '%' : '-'}</td>
        </tr>
      `;
    });

    html += '</tbody></table></div>';
    elem.innerHTML = html;
  }

  function renderMultiAssetSummaryTable(elementId, summaryMetrics, portfoliosState) {
    const elem = document.getElementById(elementId);
    if (!elem) return;

    const activeMetrics = summaryMetrics.filter(m => m.is_active);
    if (activeMetrics.length === 0) {
      elem.innerHTML = '<div class="text-muted p-3 text-center">Keine aktiven Portfolios.</div>';
      return;
    }

    const rowsDef = [
      { section: "Asset-Allokation", isHeader: true },
      { label: "Aktien (%)", key: "equity_weight_pct", format: v => formatNum(v, 1, "%"), badgeClass: "bg-primary-subtle text-primary border" },
      { label: "Anleihen / Bonds (%)", key: "bond_weight_pct", format: v => formatNum(v, 1, "%"), badgeStyle: "background-color:#E6FFFA;color:#0D9488;border:1px solid #5EEAD4;" },
      { label: "Real Estate (%)", key: "real_estate_weight_pct", format: v => formatNum(v, 1, "%"), badgeStyle: "background-color:#FDF2F0;color:#8C564B;border:1px solid #F5C6CB;" },
      { label: "Rohstoffe (%)", key: "commodity_weight_pct", format: v => formatNum(v, 1, "%"), badgeStyle: "background-color:#FFFBEB;color:#D97706;border:1px solid #FDE68A;" },
      { label: "Cash (%)", key: "cash_weight_pct", format: v => formatNum(v, 1, "%"), badgeStyle: "background-color:#F0FDF4;color:#16A34A;border:1px solid #BBF7D0;" },

      { section: "Risk & Return", isHeader: true },
      { label: "Erw. Rendite (p.a.)", key: "expected_return", format: v => formatNum(v, 2, "%"), cellClass: "fw-bold text-primary bg-primary-subtle font-monospace" },
      { label: "Erw. Volatilität (p.a.)", key: "expected_vol", format: v => formatNum(v, 2, "%"), cellClass: "fw-bold text-dark bg-light font-monospace" },
      { label: "Sharpe Ratio", key: "sharpe_ratio", format: v => v != null ? v.toFixed(2) : "-", cellClass: "fw-bold text-success bg-light font-monospace" },

      { section: "Aktien-Kennzahlen", isHeader: true },
      { label: "Dividendenrendite", key: "equity_weighted_div_yield", format: v => formatNum(v, 2, "%"), fontMono: true },
      { label: "KGV (Harmonisch)", key: "equity_weighted_pe", format: v => formatNum(v, 1, "x"), fontMono: true },
      { label: "KBV (Harmonisch)", key: "equity_weighted_pb", format: v => formatNum(v, 1, "x"), fontMono: true },

      { section: "Anleihen-Kennzahlen", isHeader: true },
      { label: "Yield to Maturity (YTM)", key: "bond_weighted_ytm", format: v => formatNum(v, 2, "%"), fontMono: true },
      { label: "Mod. Duration", key: "bond_weighted_mod_duration", format: v => formatNum(v, 1, " J."), fontMono: true },
      { label: "Restlaufzeit", key: "bond_weighted_maturity_years", format: v => formatNum(v, 1, " J."), fontMono: true }
    ];

    let html = `
      <div class="table-responsive">
        <table class="table table-sm table-hover table-bordered align-middle mb-0" style="font-size: 0.85rem;">
          <thead class="table-light">
            <tr>
              <th style="width: 35%;" class="ps-3">Kennzahl</th>
    `;

    for (const m of activeMetrics) {
      html += `<th class="text-end pe-3" style="width: ${65 / activeMetrics.length}%;">${m.portfolio_name}</th>`;
    }

    html += `
            </tr>
          </thead>
          <tbody>
    `;

    for (const r of rowsDef) {
      if (r.isHeader) {
        html += `
          <tr class="table-secondary bg-light">
            <td colspan="${activeMetrics.length + 1}" class="fw-bold text-uppercase py-1 ps-3 text-secondary" style="font-size: 0.74rem; letter-spacing: 0.5px;">
              ${r.section}
            </td>
          </tr>
        `;
        continue;
      }

      html += `<tr><td class="ps-3 fw-semibold text-dark">${r.label}</td>`;

      for (const m of activeMetrics) {
        const val = m[r.key];
        const formatted = r.format(val);
        
        let cellContent = formatted;
        if (r.badgeClass) {
          cellContent = `<span class="badge ${r.badgeClass}">${formatted}</span>`;
        } else if (r.badgeStyle) {
          cellContent = `<span class="badge" style="${r.badgeStyle}">${formatted}</span>`;
        }

        const extraClass = r.cellClass ? r.cellClass : (r.fontMono ? 'font-monospace' : '');
        html += `<td class="text-end pe-3 ${extraClass}">${cellContent}</td>`;
      }

      html += `</tr>`;
    }

    html += '</tbody></table></div>';
    elem.innerHTML = html;
  }

  function renderCurrencyCompareTable(elementId, currCompareData) {
    const elem = document.getElementById(elementId);
    if (!elem) return;

    let html = `
      <div class="table-responsive" style="max-height: 380px;">
        <table class="table table-sm table-hover align-middle mb-0" style="font-size: 0.83rem;">
          <thead class="table-light sticky-top">
            <tr>
              <th>Währung</th>
              <th class="text-end">Portfolio 1</th>
              <th class="text-end">Portfolio 2</th>
              <th class="text-end">Portfolio 3</th>
            </tr>
          </thead>
          <tbody>
    `;

    currCompareData.forEach(c => {
      const isAny = (c.weight_portfolio_1 > 0 || c.weight_portfolio_2 > 0 || c.weight_portfolio_3 > 0);
      if (!isAny) return;

      html += `
        <tr>
          <td class="fw-bold"><span class="badge bg-light text-dark border px-2">${c.currency}</span></td>
          <td class="text-end font-monospace">${c.weight_portfolio_1 > 0 ? c.weight_portfolio_1.toFixed(2) + '%' : '-'}</td>
          <td class="text-end font-monospace">${c.weight_portfolio_2 > 0 ? c.weight_portfolio_2.toFixed(2) + '%' : '-'}</td>
          <td class="text-end font-monospace">${c.weight_portfolio_3 > 0 ? c.weight_portfolio_3.toFixed(2) + '%' : '-'}</td>
        </tr>
      `;
    });

    html += '</tbody></table></div>';
    elem.innerHTML = html;
  }

  function renderEquityCurrencyDetailTable(elementId, equityCurrencyData) {
    const elem = document.getElementById(elementId);
    if (!elem) return;

    if (equityCurrencyData.length === 0) {
      elem.innerHTML = '<div class="text-center text-muted py-3 small">Keine Daten verfügbar</div>';
      return;
    }

    let html = `
      <div class="table-responsive" style="max-height: 380px;">
        <table class="table table-sm table-hover align-middle mb-0" style="font-size: 0.82rem;">
          <thead class="table-light sticky-top">
            <tr>
              <th>Portfolio</th>
              <th>Währung</th>
              <th class="text-end">Anteil am Aktienteil</th>
              <th class="text-end">Div. Rendite</th>
              <th class="text-end">KGV</th>
              <th class="text-end">KBV</th>
              <th class="text-end">Titel</th>
            </tr>
          </thead>
          <tbody>
    `;

    equityCurrencyData.forEach(r => {
      html += `
        <tr>
          <td class="fw-semibold">${r.portfolio_name}</td>
          <td><span class="badge bg-light text-dark border px-2">${r.currency}</span></td>
          <td class="text-end font-monospace fw-bold">${r.pct_of_equity.toFixed(2)}%</td>
          <td class="text-end font-monospace">${formatNum(r.weighted_div_yield, 2, "%")}</td>
          <td class="text-end font-monospace">${formatNum(r.weighted_pe, 1, "x")}</td>
          <td class="text-end font-monospace">${formatNum(r.weighted_pb, 1, "x")}</td>
          <td class="text-end text-muted">${r.n_positions}</td>
        </tr>
      `;
    });

    html += '</tbody></table></div>';
    elem.innerHTML = html;
  }

  function renderBondCurrencyDetailTable(elementId, bondCurrencyData) {
    const elem = document.getElementById(elementId);
    if (!elem) return;

    if (bondCurrencyData.length === 0) {
      elem.innerHTML = '<div class="text-center text-muted py-3 small">Keine Anleihen-Daten im Portfolio enthalten</div>';
      return;
    }

    let html = `
      <div class="table-responsive" style="max-height: 380px;">
        <table class="table table-sm table-hover align-middle mb-0" style="font-size: 0.82rem;">
          <thead class="table-light sticky-top">
            <tr>
              <th>Portfolio</th>
              <th>Währung</th>
              <th class="text-end">Anteil am Bondteil</th>
              <th class="text-end">Yield to Maturity</th>
              <th class="text-end">Mod. Duration</th>
              <th class="text-end">Restlaufzeit</th>
              <th class="text-end">Positionen</th>
            </tr>
          </thead>
          <tbody>
    `;

    bondCurrencyData.forEach(r => {
      html += `
        <tr>
          <td class="fw-semibold">${r.portfolio_name}</td>
          <td><span class="badge bg-light text-dark border px-2">${r.currency}</span></td>
          <td class="text-end font-monospace fw-bold">${r.pct_of_bonds.toFixed(2)}%</td>
          <td class="text-end font-monospace">${formatNum(r.weighted_ytm, 2, "%")}</td>
          <td class="text-end font-monospace">${formatNum(r.weighted_duration, 1, " J.")}</td>
          <td class="text-end font-monospace">${formatNum(r.weighted_maturity_years, 1, " J.")}</td>
          <td class="text-end text-muted">${r.n_positions}</td>
        </tr>
      `;
    });

    html += '</tbody></table></div>';
    elem.innerHTML = html;
  }

  function renderSectorDetailTable(elementId, sectorData) {
    const elem = document.getElementById(elementId);
    if (!elem) return;

    let html = `
      <div class="table-responsive">
        <table class="table table-sm table-hover align-middle mb-0 text-center" style="font-size: 0.83rem;">
          <thead class="table-light">
            <tr>
              <th class="text-start">GICS Sektor</th>
              <th>Portfolio 1 (%)</th>
              <th>Portfolio 2 (%)</th>
              <th>Portfolio 3 (%)</th>
              <th>Delta P1 vs P2</th>
              <th>Delta P1 vs P3</th>
            </tr>
          </thead>
          <tbody>
    `;

    sectorData.forEach(s => {
      html += `
        <tr>
          <td class="text-start">${getSectorBadge(s.gics_sector)}</td>
          <td class="font-monospace">${s.weight_portfolio_1 > 0 ? s.weight_portfolio_1.toFixed(2) + '%' : '0.00%'}</td>
          <td class="font-monospace">${s.weight_portfolio_2 > 0 ? s.weight_portfolio_2.toFixed(2) + '%' : '0.00%'}</td>
          <td class="font-monospace">${s.weight_portfolio_3 > 0 ? s.weight_portfolio_3.toFixed(2) + '%' : '0.00%'}</td>
          <td class="font-monospace">${formatDelta(s.delta_p1_p2)}</td>
          <td class="font-monospace">${formatDelta(s.delta_p1_p3)}</td>
        </tr>
      `;
    });

    html += '</tbody></table></div>';
    elem.innerHTML = html;
  }

  function renderSectorDrilldownTable(elementId, calculatedPortfolios, sectorName) {
    const elem = document.getElementById(elementId);
    if (!elem) return;

    const portKeys = ["portfolio_1", "portfolio_2", "portfolio_3"];
    const map = new Map();

    for (const pKey of portKeys) {
      const pRes = calculatedPortfolios[pKey];
      if (pRes && pRes.enabled && pRes.holdings.length > 0) {
        const match = pRes.holdings.filter(h => h.asset_type === "Aktien" && h.gics_sector === sectorName);
        for (const h of match) {
          if (!map.has(h.holding_ric)) {
            map.set(h.holding_ric, {
              ric: h.holding_ric,
              name: h.holding_name,
              currency: h.currency,
              p1: 0, p2: 0, p3: 0,
              div_yield: h.div_yield,
              pe: h.pe,
              pb: h.pb
            });
          }
          map.get(h.holding_ric)[pKey === "portfolio_1" ? "p1" : pKey === "portfolio_2" ? "p2" : "p3"] = h.portfolio_weight;
        }
      }
    }

    const list = Array.from(map.values()).sort((a, b) => Math.max(b.p1, b.p2, b.p3) - Math.max(a.p1, a.p2, a.p3));

    if (list.length === 0) {
      elem.innerHTML = `<div class="text-center text-muted py-3 small">Keine Titel im Sektor <b>${sectorName}</b> vorhanden</div>`;
      return;
    }

    let html = `
      <div class="table-responsive" style="max-height: 380px;">
        <table class="table table-sm table-hover align-middle mb-0" style="font-size: 0.82rem;">
          <thead class="table-light sticky-top">
            <tr>
              <th>Titel</th>
              <th>Währung</th>
              <th class="text-end">P1 (%)</th>
              <th class="text-end">P2 (%)</th>
              <th class="text-end">P3 (%)</th>
              <th class="text-end">Div. Rendite</th>
              <th class="text-end">KGV</th>
              <th class="text-end">KBV</th>
            </tr>
          </thead>
          <tbody>
    `;

    list.forEach(item => {
      html += `
        <tr>
          <td>
            <div class="fw-semibold text-truncate" style="max-width: 180px;" title="${item.name}">${item.name}</div>
            <div class="text-muted" style="font-size: 0.7rem;">${item.ric}</div>
          </td>
          <td><span class="badge bg-light text-dark border">${item.currency}</span></td>
          <td class="text-end font-monospace">${item.p1 > 0 ? item.p1.toFixed(2) + '%' : '-'}</td>
          <td class="text-end font-monospace">${item.p2 > 0 ? item.p2.toFixed(2) + '%' : '-'}</td>
          <td class="text-end font-monospace">${item.p3 > 0 ? item.p3.toFixed(2) + '%' : '-'}</td>
          <td class="text-end font-monospace">${formatNum(item.div_yield, 2, "%")}</td>
          <td class="text-end font-monospace">${formatNum(item.pe, 1, "x")}</td>
          <td class="text-end font-monospace">${formatNum(item.pb, 1, "x")}</td>
        </tr>
      `;
    });

    html += '</tbody></table></div>';
    elem.innerHTML = html;
  }

  let top20SortState = { column: 'weight_portfolio_1', order: 'desc' };

  function renderTop20DetailTable(elementId, combinedTop) {
    const elem = document.getElementById(elementId);
    if (!elem || !Array.isArray(combinedTop)) return;

    function getSortedData() {
      const col = top20SortState.column;
      const order = top20SortState.order;
      const data = [...combinedTop];
      data.sort((a, b) => {
        let valA = a[col];
        let valB = b[col];
        if (typeof valA === 'string') {
          valA = valA.toLowerCase();
          valB = (valB || '').toLowerCase();
          return order === 'asc' ? valA.localeCompare(valB) : valB.localeCompare(valA);
        }
        valA = Number(valA) || 0;
        valB = Number(valB) || 0;
        return order === 'asc' ? valA - valB : valB - valA;
      });
      return data.slice(0, 20);
    }

    function render() {
      const top20 = getSortedData();
      const col = top20SortState.column;
      const order = top20SortState.order;

      const getHeader = (key, label, align = "") => {
        const isCurrent = col === key;
        const icon = isCurrent ? (order === 'asc' ? ' ▲' : ' ▼') : ' <span class="text-muted opacity-25" style="font-size:0.75rem;">⇅</span>';
        const activeClass = isCurrent ? 'text-primary fw-bold bg-primary-subtle' : '';
        return `<th class="${align} ${activeClass}" style="cursor: pointer; user-select: none;" data-sort-key="${key}" title="Klicken zum Sortieren nach ${label}">${label}${icon}</th>`;
      };

      let html = `
        <div class="table-responsive" style="max-height: 520px;">
          <table class="table table-sm table-hover align-middle mb-0" style="font-size: 0.82rem;">
            <thead class="table-light sticky-top">
              <tr>
                <th style="width: 30px;">#</th>
                ${getHeader('holding_name', 'Titel')}
                ${getHeader('gics_sector', 'Sektor')}
                ${getHeader('weight_portfolio_1', 'P1 (%)', 'text-end')}
                ${getHeader('weight_portfolio_2', 'P2 (%)', 'text-end')}
                ${getHeader('weight_portfolio_3', 'P3 (%)', 'text-end')}
              </tr>
            </thead>
            <tbody>
      `;

      top20.forEach((h, i) => {
        html += `
          <tr>
            <td class="text-muted small">${i + 1}</td>
            <td>
              <div class="fw-semibold text-truncate" style="max-width: 170px;" title="${h.holding_name}">${h.holding_name || h.holding_ric}</div>
              <div class="text-muted" style="font-size: 0.72rem;">${h.holding_ric}</div>
            </td>
            <td>${getSectorBadge(h.gics_sector)}</td>
            <td class="text-end font-monospace ${col === 'weight_portfolio_1' ? 'fw-bold text-primary bg-primary-subtle' : ''}">${h.weight_portfolio_1 > 0 ? h.weight_portfolio_1.toFixed(2) + '%' : '-'}</td>
            <td class="text-end font-monospace ${col === 'weight_portfolio_2' ? 'fw-bold text-teal bg-light' : ''}">${h.weight_portfolio_2 > 0 ? h.weight_portfolio_2.toFixed(2) + '%' : '-'}</td>
            <td class="text-end font-monospace ${col === 'weight_portfolio_3' ? 'fw-bold text-danger bg-light' : ''}">${h.weight_portfolio_3 > 0 ? h.weight_portfolio_3.toFixed(2) + '%' : '-'}</td>
          </tr>
        `;
      });

      html += '</tbody></table></div>';
      elem.innerHTML = html;

      elem.querySelectorAll('th[data-sort-key]').forEach(th => {
        th.addEventListener('click', () => {
          const key = th.getAttribute('data-sort-key');
          if (top20SortState.column === key) {
            top20SortState.order = top20SortState.order === 'desc' ? 'asc' : 'desc';
          } else {
            top20SortState.column = key;
            top20SortState.order = 'desc';
          }
          render();
        });
      });
    }

    render();
  }

  function renderFullLookthroughTable(elementId, holdings, searchTerm = "", assetFilter = "all") {
    const elem = document.getElementById(elementId);
    if (!elem) return;

    let filtered = holdings || [];
    if (assetFilter && assetFilter !== "all") {
      filtered = filtered.filter(h => h.asset_type === assetFilter);
    }
    if (searchTerm) {
      const s = searchTerm.toLowerCase();
      filtered = filtered.filter(h => 
        (h.holding_name && h.holding_name.toLowerCase().includes(s)) ||
        (h.holding_ric && h.holding_ric.toLowerCase().includes(s)) ||
        (h.gics_sector && h.gics_sector.toLowerCase().includes(s)) ||
        (h.currency && h.currency.toLowerCase().includes(s)) ||
        (h.maturity_date && h.maturity_date.toLowerCase().includes(s))
      );
    }

    let html = `
      <div class="table-responsive" style="max-height: 480px;">
        <table class="table table-sm table-hover align-middle mb-0" style="font-size: 0.82rem;">
          <thead class="table-light sticky-top">
            <tr>
              <th style="width: 35px;">#</th>
              <th>Titel & Ticker</th>
              <th>Asset</th>
              <th>Sektor</th>
              <th>Währung</th>
              <th class="text-end">Look-Through Gewicht</th>
              <th class="text-end">Div. Rendite</th>
              <th class="text-end">KGV / YTM</th>
              <th class="text-end">KBV / Duration</th>
              <th class="text-center">Fälligkeit</th>
              <th>Herkunfts-ETFs</th>
            </tr>
          </thead>
          <tbody>
    `;

    if (filtered.length === 0) {
      html += `<tr><td colspan="11" class="text-center py-3 text-muted">Keine Positionen gefunden</td></tr>`;
    } else {
      filtered.slice(0, 150).forEach((h, i) => {
        const isBond = h.asset_type === "Bonds";

        html += `
          <tr>
            <td class="text-muted small">${i + 1}</td>
            <td>
              <div class="fw-semibold text-truncate" style="max-width: 190px;" title="${h.holding_name}">${h.holding_name || h.holding_ric}</div>
              <div class="text-muted" style="font-size: 0.72rem;">${h.holding_ric}</div>
            </td>
            <td>${getAssetBadge(h.asset_type)}</td>
            <td>${getSectorBadge(h.gics_sector)}</td>
            <td><span class="badge bg-light text-dark border">${h.currency}</span></td>
            <td class="text-end font-monospace fw-bold">${h.portfolio_weight.toFixed(3)}%</td>
            <td class="text-end font-monospace">${formatNum(h.div_yield, 2, "%")}</td>
            <td class="text-end font-monospace">${isBond ? formatNum(h.ytm, 2, "%") : formatNum(h.pe, 1, "x")}</td>
            <td class="text-end font-monospace">${isBond ? formatNum(h.mod_duration, 1, " J.") : formatNum(h.pb, 1, "x")}</td>
            <td class="text-center font-monospace small">${isBond && h.maturity_date ? `<span class="badge bg-light text-secondary border">${h.maturity_date}</span>` : '<span class="text-muted">-</span>'}</td>
            <td><div class="text-muted small text-truncate" style="max-width: 220px;" title="${h.etf_breakdown}">${h.etf_breakdown}</div></td>
          </tr>
        `;
      });
    }

    html += '</tbody></table></div>';
    if (filtered.length > 150) {
      html += `<div class="text-muted small p-2 text-center border-top bg-light">Zeige 150 von ${filtered.length} Positionen (Suchfeld zur Filterung nutzen)</div>`;
    }
    elem.innerHTML = html;
  }

  function renderConcentrationFullTable(elementId, metrics) {
    const elem = document.getElementById(elementId);
    if (!elem) return;

    let html = `
      <div class="table-responsive">
        <table class="table table-sm table-bordered align-middle mb-0 text-center" style="font-size: 0.84rem;">
          <thead class="table-light">
            <tr>
              <th class="text-start">Kennzahl (Aktienteil)</th>
              <th>Portfolio 1</th>
              <th>Portfolio 2</th>
              <th>Portfolio 3</th>
            </tr>
          </thead>
          <tbody>
    `;

    const rows = [
      { label: "Anzahl Aktientitel", key: "total_holdings", format: v => v },
      { label: "Effektive Titelanzahl (N_eff)", key: "n_eff", format: v => `<b>${v}</b>` },
      { label: "Herfindahl-Index (HHI)", key: "hhi", format: v => v },
      { label: "Top 1 Aktie (%)", key: "top1_weight", format: v => `${v}%` },
      { label: "Top 5 Aktien (%)", key: "top5_weight", format: v => `${v}%` },
      { label: "Top 10 Aktien (%)", key: "top10_weight", format: v => `<b>${v}%</b>` },
      { label: "Top 20 Aktien (%)", key: "top20_weight", format: v => `${v}%` },
      { label: "Gini-Koeffizient", key: "gini_coefficient", format: v => v },
      { label: "Sektor HHI", key: "sector_hhi", format: v => v },
      { label: "Sektor N_eff", key: "sector_n_eff", format: v => v }
    ];

    const p1 = metrics.find(m => m.portfolio_key === "portfolio_1") || {};
    const p2 = metrics.find(m => m.portfolio_key === "portfolio_2") || {};
    const p3 = metrics.find(m => m.portfolio_key === "portfolio_3") || {};

    rows.forEach(r => {
      html += `
        <tr>
          <td class="text-start fw-semibold">${r.label}</td>
          <td class="font-monospace">${p1.is_active ? r.format(p1[r.key]) : '-'}</td>
          <td class="font-monospace">${p2.is_active ? r.format(p2[r.key]) : '-'}</td>
          <td class="font-monospace">${p3.is_active ? r.format(p3[r.key]) : '-'}</td>
        </tr>
      `;
    });

    html += '</tbody></table></div>';
    elem.innerHTML = html;
  }

  function renderUniverseSummaryTable(elementId, etfSummaryList) {
    const elem = document.getElementById(elementId);
    if (!elem) return;

    let html = `
      <div class="table-responsive">
        <table class="table table-sm table-hover align-middle mb-0" style="font-size: 0.84rem;">
          <thead class="table-light">
            <tr>
              <th>RIC</th>
              <th>Name / Label</th>
              <th>Assetklasse</th>
              <th>Region</th>
              <th class="text-end">Holdings</th>
              <th class="text-end">Div. Rendite</th>
              <th class="text-end">KGV / YTM</th>
              <th class="text-end">KBV / Duration</th>
              <th class="text-end">Restlaufzeit</th>
              <th>Grösste Position</th>
            </tr>
          </thead>
          <tbody>
    `;

    etfSummaryList.forEach(e => {
      const isBond = e.asset_type === "Bonds";

      html += `
        <tr>
          <td class="fw-bold font-monospace">${e.etf_ric}</td>
          <td class="fw-semibold">${e.etf_label}</td>
          <td>${getAssetBadge(e.asset_type)}</td>
          <td>${e.etf_region || 'Global'}</td>
          <td class="text-end font-monospace">${e.n_holdings}</td>
          <td class="text-end font-monospace">${formatNum(e.avg_div_yield, 2, "%")}</td>
          <td class="text-end font-monospace">${isBond ? formatNum(e.avg_ytm, 2, "%") : formatNum(e.avg_pe, 1, "x")}</td>
          <td class="text-end font-monospace">${isBond ? formatNum(e.avg_mod_duration, 1, " J.") : formatNum(e.avg_pb, 1, "x")}</td>
          <td class="text-end font-monospace">${isBond ? formatNum(e.avg_maturity_years, 1, " J.") : '-'}</td>
          <td class="small text-truncate" style="max-width: 180px;" title="${e.top_holding}">${e.top_holding} (${e.top_holding_weight?.toFixed(1)}%)</td>
        </tr>
      `;
    });

    html += '</tbody></table></div>';
    elem.innerHTML = html;
  }

  const ISSUER_TYPE_LABELS = {
    "SOV": "Sovereigns (SOV)",
    "FIN": "Financials (FIN)",
    "CORP": "Corporates (CORP)",
    "AGCY": "Agencies (AGCY)",
    "SUPR": "Supranationals (SUPR)",
    "SSOV": "Sub-Sovereigns (SSOV)",
    "Andere": "Andere / Sonstige"
  };

  function renderBondRegionIssuerTable(elementId, breakdownData) {
    const elem = document.getElementById(elementId);
    if (!elem) return;

    if (!breakdownData || !breakdownData.isActive || !breakdownData.matrix || breakdownData.matrix.length === 0) {
      elem.innerHTML = `
        <div class="p-4 text-center text-muted">
          <i class="bi bi-info-circle me-1"></i> Keine Fixed-Income (Bond) Positionen im ausgewählten Portfolio enthalten.
        </div>
      `;
      return;
    }

    const { matrix, totalRow, issuerCols } = breakdownData;

    let html = `
      <div class="table-responsive">
        <table class="table table-sm table-hover align-middle mb-0" style="font-size: 0.85rem;">
          <thead class="table-light">
            <tr>
              <th class="ps-3" style="min-width: 140px;">Region</th>
    `;

    issuerCols.forEach(col => {
      const fullLabel = ISSUER_TYPE_LABELS[col] || col;
      html += `<th class="text-end" title="${fullLabel}" style="min-width: 85px;">${col}</th>`;
    });

    html += `
              <th class="text-end pe-3 fw-bold bg-light" style="min-width: 95px;">Total (%)</th>
            </tr>
          </thead>
          <tbody>
    `;

    matrix.forEach(row => {
      html += `
        <tr>
          <td class="ps-3 fw-semibold">
            <span class="d-inline-block rounded-circle me-1" style="width:8px;height:8px;background-color:#0D9488;"></span>
            ${row.region}
          </td>
      `;

      issuerCols.forEach(col => {
        const val = row[col] || 0;
        if (val > 0) {
          html += `<td class="text-end font-monospace">${val.toFixed(2)}%</td>`;
        } else {
          html += `<td class="text-end font-monospace text-muted opacity-50">-</td>`;
        }
      });

      html += `<td class="text-end pe-3 font-monospace fw-bold bg-light">${(row.total || 0).toFixed(2)}%</td>`;
      html += `</tr>`;
    });

    if (totalRow) {
      html += `
        <tr class="table-secondary fw-bold border-top border-2" style="border-top-color: #CBD5E1 !important;">
          <td class="ps-3 fw-bold">Total</td>
      `;

      issuerCols.forEach(col => {
        const val = totalRow[col] || 0;
        html += `<td class="text-end font-monospace fw-bold">${val.toFixed(2)}%</td>`;
      });

      html += `<td class="text-end pe-3 font-monospace fw-bold text-teal" style="color: #0D9488;">${(totalRow.total || 100).toFixed(2)}%</td>`;
      html += `</tr>`;
    }

    html += '</tbody></table></div>';
    elem.innerHTML = html;
  }

  /**
   * Rendert die Gesamtportfolio-Risikotabelle im "Dashboard Single"
   */
  function renderSinglePortfolioRiskTable(elementId, pSum, pConc, pName, nHoldings) {
    const elem = document.getElementById(elementId);
    if (!elem) return;

    if (!pSum || !pSum.is_active) {
      elem.innerHTML = '<div class="text-center text-muted py-3 small">Portfolio ist inaktiv oder enthält keine Daten.</div>';
      return;
    }

    const html = `
      <div class="row g-3 p-3">
        <!-- Spalte 1: Risiko & Ertrag -->
        <div class="col-md-6 col-lg-3">
          <div class="border rounded p-2 bg-light h-100">
            <div class="fw-bold text-primary small border-bottom pb-1 mb-2 d-flex align-items-center gap-1">
              <i class="bi bi-graph-up-arrow"></i> Ertrag & Volatilität
            </div>
            <div class="d-flex justify-content-between py-1 border-bottom small">
              <span class="text-muted">Erwartete Rendite (p.a.)</span>
              <span class="fw-bold font-monospace text-primary">${formatNum(pSum.expected_return, 2, "%")}</span>
            </div>
            <div class="d-flex justify-content-between py-1 border-bottom small">
              <span class="text-muted">Erwartete Vola (p.a.)</span>
              <span class="fw-bold font-monospace text-dark">${formatNum(pSum.expected_vol, 2, "%")}</span>
            </div>
            <div class="d-flex justify-content-between py-1 small">
              <span class="text-muted">Sharpe Ratio (rf = 0)</span>
              <span class="fw-bold font-monospace text-success">${formatNum(pSum.sharpe_ratio, 2, "")}</span>
            </div>
          </div>
        </div>

        <!-- Spalte 2: Konzentration & Diversifikation -->
        <div class="col-md-6 col-lg-3">
          <div class="border rounded p-2 bg-light h-100">
            <div class="fw-bold text-secondary small border-bottom pb-1 mb-2 d-flex align-items-center gap-1">
              <i class="bi bi-pie-chart"></i> Diversifikation & Titel
            </div>
            <div class="d-flex justify-content-between py-1 border-bottom small">
              <span class="text-muted">Effektive Titel (N_eff)</span>
              <span class="fw-bold font-monospace text-dark">${formatNum(pConc?.n_eff, 1, "")}</span>
            </div>
            <div class="d-flex justify-content-between py-1 border-bottom small">
              <span class="text-muted">Herfindahl-Index (HHI)</span>
              <span class="fw-bold font-monospace text-dark">${formatNum(pConc?.hhi, 1, "")}</span>
            </div>
            <div class="d-flex justify-content-between py-1 border-bottom small">
              <span class="text-muted">Gini-Koeffizient</span>
              <span class="fw-bold font-monospace text-dark">${formatNum(pConc?.gini_coefficient, 3, "")}</span>
            </div>
            <div class="d-flex justify-content-between py-1 border-bottom small">
              <span class="text-muted">Top 10 Konzentration</span>
              <span class="fw-bold font-monospace text-dark">${formatNum(pConc?.top10_weight, 2, "%")}</span>
            </div>
            <div class="d-flex justify-content-between py-1 small">
              <span class="text-muted">Look-Through Positionen</span>
              <span class="fw-bold font-monospace text-dark">${nHoldings ? nHoldings.toLocaleString('de-CH') : "-"}</span>
            </div>
          </div>
        </div>

        <!-- Spalte 3: Aktienbewertung -->
        <div class="col-md-6 col-lg-3">
          <div class="border rounded p-2 bg-light h-100">
            <div class="fw-bold text-primary small border-bottom pb-1 mb-2 d-flex align-items-center gap-1">
              <i class="bi bi-currency-dollar"></i> Aktien-Bewertung
            </div>
            <div class="d-flex justify-content-between py-1 border-bottom small">
              <span class="text-muted">Aktienanteil am Portfolio</span>
              <span class="fw-bold font-monospace text-primary">${formatNum(pSum.equity_weight_pct, 2, "%")}</span>
            </div>
            <div class="d-flex justify-content-between py-1 border-bottom small">
              <span class="text-muted">Dividendenrendite (gew.)</span>
              <span class="fw-bold font-monospace text-dark">${formatNum(pSum.equity_weighted_div_yield, 2, "%")}</span>
            </div>
            <div class="d-flex justify-content-between py-1 border-bottom small">
              <span class="text-muted">KGV (harmonisch gew.)</span>
              <span class="fw-bold font-monospace text-dark">${formatNum(pSum.equity_weighted_pe, 1, "x")}</span>
            </div>
            <div class="d-flex justify-content-between py-1 small">
              <span class="text-muted">KBV (harmonisch gew.)</span>
              <span class="fw-bold font-monospace text-dark">${formatNum(pSum.equity_weighted_pb, 2, "x")}</span>
            </div>
          </div>
        </div>

        <!-- Spalte 4: Zins & Anleihen -->
        <div class="col-md-6 col-lg-3">
          <div class="border rounded p-2 bg-light h-100">
            <div class="fw-bold small border-bottom pb-1 mb-2 d-flex align-items-center gap-1" style="color: #0D9488;">
              <i class="bi bi-shield-check"></i> Anleihen & Zinsrisiko
            </div>
            <div class="d-flex justify-content-between py-1 border-bottom small">
              <span class="text-muted">Bondanteil am Portfolio</span>
              <span class="fw-bold font-monospace" style="color: #0D9488;">${formatNum(pSum.bond_weight_pct, 2, "%")}</span>
            </div>
            <div class="d-flex justify-content-between py-1 border-bottom small">
              <span class="text-muted">Yield to Maturity (YTM)</span>
              <span class="fw-bold font-monospace text-dark">${formatNum(pSum.bond_weighted_ytm, 2, "%")}</span>
            </div>
            <div class="d-flex justify-content-between py-1 border-bottom small">
              <span class="text-muted">Modified Duration</span>
              <span class="fw-bold font-monospace text-dark">${formatNum(pSum.bond_weighted_mod_duration, 2, " J.")}</span>
            </div>
            <div class="d-flex justify-content-between py-1 small">
              <span class="text-muted">Durchschnittl. Restlaufzeit</span>
              <span class="fw-bold font-monospace text-dark">${formatNum(pSum.bond_weighted_maturity_years, 2, " J.")}</span>
            </div>
          </div>
        </div>
      </div>
    `;

    elem.innerHTML = html;
  }

  /**
   * Rendert die vergleichende Portfolio-Kennzahlen-Tabelle (Portfolio A vs Portfolio B vs Delta)
   */
  function renderPortfolioComparisonTable(elementId, summaryA, summaryB, concA, concB, nameA, nameB, nHoldingsA, nHoldingsB) {
    const elem = document.getElementById(elementId);
    if (!elem) return;

    const formatVal = (val, dec = 2, unit = "") => {
      if (val == null || isNaN(val)) return "-";
      return `${val.toFixed(dec)}${unit}`;
    };

    const makeRow = (label, valA, valB, dec = 2, unit = "", invertColor = false) => {
      const numA = Number(valA);
      const numB = Number(valB);
      const hasA = valA != null && !isNaN(numA);
      const hasB = valB != null && !isNaN(numB);

      let deltaStr = "-";
      let badgeClass = "text-muted";

      if (hasA && hasB) {
        const delta = numA - numB;
        const sign = delta > 0 ? "+" : "";
        deltaStr = `${sign}${delta.toFixed(dec)}${unit}`;

        if (Math.abs(delta) > 0.001) {
          const isPositiveGood = !invertColor;
          if (delta > 0) {
            badgeClass = isPositiveGood ? "text-primary fw-bold" : "text-danger fw-bold";
          } else {
            badgeClass = isPositiveGood ? "text-danger fw-bold" : "text-primary fw-bold";
          }
        }
      }

      return `
        <tr>
          <td class="ps-3 text-dark">${label}</td>
          <td class="text-end font-monospace">${hasA ? formatVal(numA, dec, unit) : "-"}</td>
          <td class="text-end font-monospace">${hasB ? formatVal(numB, dec, unit) : "-"}</td>
          <td class="text-end pe-3 font-monospace ${badgeClass}">${deltaStr}</td>
        </tr>
      `;
    };

    const makeHeader = (title, icon, colorClass = "text-primary") => `
      <tr class="table-light">
        <th colspan="4" class="ps-3 py-2 ${colorClass} fw-bold small">
          <i class="bi ${icon} me-1"></i> ${title}
        </th>
      </tr>
    `;

    let html = `
      <div class="table-responsive">
        <table class="table table-hover table-sm align-middle mb-0" style="font-size: 0.85rem;">
          <thead class="table-light border-bottom">
            <tr>
              <th class="ps-3" style="width: 40%;">Kennzahl / Segment</th>
              <th class="text-end" style="width: 20%;">${nameA || "Portfolio A"}</th>
              <th class="text-end" style="width: 20%;">${nameB || "Portfolio B"}</th>
              <th class="text-end pe-3" style="width: 20%;">Differenz (Δ = A − B)</th>
            </tr>
          </thead>
          <tbody>
    `;

    // 1. Ertrag & Risiko
    html += makeHeader("Ertrag & Risiko (p.a.)", "bi-graph-up-arrow", "text-primary");
    html += makeRow("Erwartete Rendite", summaryA?.expected_return, summaryB?.expected_return, 2, "%");
    html += makeRow("Erwartete Volatilität", summaryA?.expected_vol, summaryB?.expected_vol, 2, "%", true);
    html += makeRow("Sharpe Ratio (rf = 0)", summaryA?.sharpe_ratio, summaryB?.sharpe_ratio, 2, "");

    // 2. Diversifikation & Konzentration
    html += makeHeader("Diversifikation & Konzentration", "bi-pie-chart", "text-secondary");
    html += makeRow("Effektive Titelanzahl (N_eff)", concA?.n_eff, concB?.n_eff, 1, "");
    html += makeRow("Herfindahl-Index (HHI)", concA?.hhi, concB?.hhi, 1, "", true);
    html += makeRow("Gini-Koeffizient", concA?.gini_coefficient, concB?.gini_coefficient, 3, "", true);
    html += makeRow("Top 10 Konzentration", concA?.top10_weight, concB?.top10_weight, 2, "%", true);
    html += makeRow("Look-Through Positionen", nHoldingsA, nHoldingsB, 0, "");

    // 3. Aktien-Bewertung
    html += makeHeader("Aktien-Bewertungskennzahlen (Look-Through)", "bi-currency-dollar", "text-primary");
    html += makeRow("Aktienanteil am Portfolio", summaryA?.equity_weight_pct, summaryB?.equity_weight_pct, 2, "%");
    html += makeRow("Dividendenrendite (gew.)", summaryA?.equity_weighted_div_yield, summaryB?.equity_weighted_div_yield, 2, "%");
    html += makeRow("KGV (harmonisch gew.)", summaryA?.equity_weighted_pe, summaryB?.equity_weighted_pe, 1, "x");
    html += makeRow("KBV (harmonisch gew.)", summaryA?.equity_weighted_pb, summaryB?.equity_weighted_pb, 2, "x");

    // 4. Anleihen & Zinsrisiko
    html += makeHeader("Anleihen & Zinsrisikokennzahlen", "bi-shield-check", "text-teal");
    html += makeRow("Anleihenanteil am Portfolio", summaryA?.bond_weight_pct, summaryB?.bond_weight_pct, 2, "%");
    html += makeRow("Yield to Maturity (YTM)", summaryA?.bond_weighted_ytm, summaryB?.bond_weighted_ytm, 2, "%");
    html += makeRow("Modified Duration", summaryA?.bond_weighted_mod_duration, summaryB?.bond_weighted_mod_duration, 2, " J.");
    html += makeRow("Durchschnittl. Restlaufzeit", summaryA?.bond_weighted_maturity_years, summaryB?.bond_weighted_maturity_years, 2, " J.");

    // 5. Asset-Allokation
    html += makeHeader("Asset-Allokation (Portfolioanteile)", "bi-layers", "text-dark");
    html += makeRow("Aktien", summaryA?.equity_weight_pct, summaryB?.equity_weight_pct, 2, "%");
    html += makeRow("Anleihen", summaryA?.bond_weight_pct, summaryB?.bond_weight_pct, 2, "%");
    html += makeRow("Real Estate", summaryA?.real_estate_weight_pct, summaryB?.real_estate_weight_pct, 2, "%");
    html += makeRow("Rohstoffe", summaryA?.commodity_weight_pct, summaryB?.commodity_weight_pct, 2, "%");
    html += makeRow("Cash", summaryA?.cash_weight_pct, summaryB?.cash_weight_pct, 2, "%");

    html += `</tbody></table></div>`;
    elem.innerHTML = html;
  }

  const Tables = {
    renderDashboardTop10Table,
    renderMultiAssetSummaryTable,
    renderCurrencyCompareTable,
    renderEquityCurrencyDetailTable,
    renderBondCurrencyDetailTable,
    renderSectorDetailTable,
    renderSectorDrilldownTable,
    renderTop20DetailTable,
    renderFullLookthroughTable,
    renderConcentrationFullTable,
    renderUniverseSummaryTable,
    renderBondRegionIssuerTable,
    renderSinglePortfolioRiskTable,
    renderPortfolioComparisonTable
  };

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = Tables;
  } else {
    global.Tables = Tables;
  }
})(typeof window !== 'undefined' ? window : globalThis);
