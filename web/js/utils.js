// ==============================================================================
// web/js/utils.js
// Zentrale Hilfsfunktionen für Formatierung, Badges, Entprellung und HTML-Escaping
// Unterstützt sowohl Browser-Global als auch Node.js (CommonJS)
// ==============================================================================

(function(global) {
  const Constants = (typeof module !== 'undefined' && module.exports)
    ? require('./constants')
    : (global.Constants || {});

  /**
   * Verzögert die Funktionsausführung (Debounce)
   */
  function debounce(func, wait = 200) {
    let timeout;
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout);
        func.apply(this, args);
      };
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
    };
  }

  /**
   * HTML-Sonderzeichen bereinigen (XSS-Schutz)
   */
  function escapeHtml(str) {
    if (str == null) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  /**
   * Formatierung von Zahlen
   */
  function formatNum(val, decimals = 2, suffix = "") {
    if (val == null || isNaN(val) || !isFinite(val)) {
      return '<span class="text-muted">-</span>';
    }
    return `${Number(val).toFixed(decimals)}${suffix}`;
  }

  /**
   * Formatierung von Prozentwerten
   */
  function formatPct(val, decimals = 2) {
    return formatNum(val, decimals, "%");
  }

  /**
   * Formatierung von Delta-Werten mit farbiger Kennzeichnung (+ / -)
   */
  function formatDelta(val, decimals = 2, suffix = "%", isPositiveGood = true) {
    if (val == null || isNaN(val) || !isFinite(val) || Math.abs(val) < 0.001) {
      return `<span class="text-muted">0.00${suffix}</span>`;
    }
    const num = Number(val);
    const sign = num > 0 ? "+" : "";
    let cls = "text-muted";
    if (num > 0) {
      cls = isPositiveGood ? "text-primary fw-semibold" : "text-danger fw-semibold";
    } else {
      cls = isPositiveGood ? "text-danger fw-semibold" : "text-primary fw-semibold";
    }
    return `<span class="${cls}">${sign}${num.toFixed(decimals)}${suffix}</span>`;
  }

  /**
   * Generiert ein farbiges Badge für eine Assetklasse
   */
  function getAssetBadge(assetType) {
    const type = assetType || "Aktien";
    if (type === "Bonds") {
      return '<span class="badge" style="background-color:#E6FFFA;color:#0D9488;border:1px solid #5EEAD4;font-size:0.75rem;">Bonds</span>';
    }
    if (type === "Real Estate") {
      return '<span class="badge" style="background-color:#FDF2F0;color:#8C564B;border:1px solid #F5C6CB;font-size:0.75rem;">Real Estate</span>';
    }
    if (type === "Cash") {
      return '<span class="badge" style="background-color:#F0FDF4;color:#16A34A;border:1px solid #BBF7D0;font-size:0.75rem;">Cash</span>';
    }
    if (type === "Rohstoffe") {
      return '<span class="badge" style="background-color:#FFFBEB;color:#D97706;border:1px solid #FDE68A;font-size:0.75rem;">Rohstoffe</span>';
    }
    return '<span class="badge" style="background-color:#EFF6FF;color:#1E40AF;border:1px solid #BFDBFE;font-size:0.75rem;">Aktien</span>';
  }

  /**
   * Generiert ein farbiges Badge für einen GICS-Sektor
   */
  function getSectorBadge(sector) {
    if (!sector) return '<span class="badge bg-light text-muted border">-</span>';
    const sectorColors = Constants.GICS_SECTOR_COLORS || {};
    const color = sectorColors[sector] || "#64748B";
    return `<span class="badge" style="background-color: ${color}20; color: ${color}; border: 1px solid ${color}40; font-size: 0.75rem;">${escapeHtml(sector)}</span>`;
  }

  /**
   * Generiert ein farbiges Badge für einen Währungscode
   */
  function getCurrencyBadge(curr) {
    if (!curr) return '<span class="badge bg-light text-muted border">-</span>';
    const currColors = Constants.CURRENCY_COLORS || {};
    const color = currColors[curr] || "#64748B";
    return `<span class="badge font-monospace" style="background-color: ${color}1A; color: ${color}; border: 1px solid ${color}40; font-size: 0.75rem; font-weight: 700;">${escapeHtml(curr)}</span>`;
  }

  const Utils = {
    debounce,
    escapeHtml,
    formatNum,
    formatPct,
    formatDelta,
    getAssetBadge,
    getSectorBadge,
    getCurrencyBadge
  };

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = Utils;
  } else {
    global.Utils = Utils;
  }
})(typeof window !== 'undefined' ? window : globalThis);
