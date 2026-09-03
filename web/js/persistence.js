// ==============================================================================
// web/js/persistence.js
// Verwaltung von Portfolios im Browser (LocalStorage) & JSON Import / Export
// ==============================================================================

(function(global) {
  const STORAGE_KEY = "etf_lookthrough_portfolios_v1";

  function getDefaultPortfolios(availableEtfs = [], tickerList = []) {
    return {
      portfolio_1: {
        id: "p1",
        name: "TAA",
        enabled: true,
        filters: {
          equity: {},
          bonds: {}
        },
        weights: {
          "CHSPI.S": 14,
          "EMUU.L": 5,
          "EWU": 3.5,
          "IQQN.DE": 12,
          "IPAC.K": 4.5,
          "EEM": 5,
          "CHESG.S": 14,
          "LP68486946": 8.5,
          "GBF.A": 8.5,
          "VGOV.L": 1,
          "SLXX.L": 1,
          "EMB.O": 3.5,
          "ELD": 4.5,
          "LP68082242": 4,
          "IWDP.L": 2,
          "CASH_CHF": 2.5,
          "CMD_BROAD": 2,
          "CMD_GOLD": 4.5
        }
      },
      portfolio_2: {
        id: "p2",
        name: "SAA",
        enabled: true,
        filters: {
          equity: {},
          bonds: {}
        },
        weights: {
          "CHSPI.S": 13,
          "EMUU.L": 5,
          "EWU": 3.5,
          "IQQN.DE": 12,
          "IPAC.K": 5.5,
          "EEM": 6,
          "CHESG.S": 14,
          "LP68486946": 7.5,
          "GBF.A": 7.5,
          "VGOV.L": 1.5,
          "SLXX.L": 1.5,
          "EMB.O": 3,
          "ELD": 4,
          "LP68082242": 4,
          "IWDP.L": 2,
          "CASH_CHF": 4,
          "CMD_BROAD": 2,
          "CMD_GOLD": 4
        }
      },
      portfolio_3: {
        id: "p3",
        name: "TAA-Alt",
        enabled: true,
        filters: {
          equity: {},
          bonds: {}
        },
        weights: {
          "CHSPI.S": 13,
          "EMUU.L": 6,
          "EWU": 3.5,
          "IQQN.DE": 12,
          "IPAC.K": 5.5,
          "EEM": 5,
          "CHESG.S": 14,
          "LP68486946": 7.5,
          "GBF.A": 7.5,
          "VGOV.L": 1,
          "SLXX.L": 1,
          "EMB.O": 3.5,
          "ELD": 4.5,
          "LP68082242": 4.5,
          "IWDP.L": 2,
          "CASH_CHF": 2.5,
          "CMD_BROAD": 2,
          "CMD_GOLD": 5
        }
      },
      settings: {
        normalize_holdings: true,
        last_saved: "2026-08-27 10:11:23"
      }
    };
  }

  function loadPortfolios(defaultData = null) {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored) {
        const parsed = JSON.parse(stored);
        if (parsed.portfolio_1 && parsed.portfolio_2 && parsed.portfolio_3) {
          return parsed;
        }
      }
    } catch (e) {
      console.warn("Konnte gespeicherte Portfolios nicht aus LocalStorage laden:", e);
    }

    return defaultData || getDefaultPortfolios();
  }

  function savePortfolios(portfoliosState) {
    try {
      const clone = JSON.parse(JSON.stringify(portfoliosState));
      if (!clone.settings) clone.settings = {};
      clone.settings.last_saved = new Date().toLocaleString("de-CH");
      localStorage.setItem(STORAGE_KEY, JSON.stringify(clone));
      return true;
    } catch (e) {
      console.error("Fehler beim Speichern in LocalStorage:", e);
      return false;
    }
  }

  function exportPortfoliosAsJson(portfoliosState, filename = "saved_portfolios.json") {
    const jsonStr = JSON.stringify(portfoliosState, null, 2);
    const blob = new Blob([jsonStr], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  function importPortfoliosFromJsonFile(file, onSuccess, onError) {
    const reader = new FileReader();
    reader.onload = function(e) {
      try {
        const parsed = JSON.parse(e.target.result);
        if (parsed.portfolio_1 && parsed.portfolio_2 && parsed.portfolio_3) {
          savePortfolios(parsed);
          if (onSuccess) onSuccess(parsed);
        } else {
          throw new Error("Ungültiges Portfolio-JSON-Format.");
        }
      } catch (err) {
        if (onError) onError(err);
      }
    };
    reader.onerror = function() {
      if (onError) onError(new Error("Fehler beim Lesen der Datei."));
    };
    reader.readAsText(file);
  }

  const Persistence = {
    getDefaultPortfolios,
    loadPortfolios,
    savePortfolios,
    exportPortfoliosAsJson,
    importPortfoliosFromJsonFile
  };

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = Persistence;
  } else {
    global.Persistence = Persistence;
  }
})(typeof window !== 'undefined' ? window : globalThis);
