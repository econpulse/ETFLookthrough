// ==============================================================================
// web/js/constants.js
// Zentrale Konstanten für Farben, Sektoren, Assetklassen, Regionen und Themes
// Unterstützt sowohl Browser-Global als auch Node.js (CommonJS)
// ==============================================================================

(function(global) {
  // Die 11 offiziellen GICS-Sektoren (Global Industry Classification Standard)
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

  // Mapping für GICS-Sektoren von UPPERCASE / Alias zu Title Case
  const GICS_SECTOR_MAP = {
    "ENERGY": "Energy",
    "MATERIALS": "Materials",
    "INDUSTRIALS": "Industrials",
    "CONSUMER DISCRETIONARY": "Consumer Discretionary",
    "CONSUMER STAPLES": "Consumer Staples",
    "HEALTH CARE": "Health Care",
    "FINANCIALS": "Financials",
    "INFORMATION TECHNOLOGY": "Information Technology",
    "COMMUNICATION SERVICES": "Communication Services",
    "UTILITIES": "Utilities",
    "REAL ESTATE": "Real Estate"
  };

  // Standardfarben für die 11 GICS-Sektoren
  const GICS_SECTOR_COLORS = {
    "Energy": "#E6550D",                 // Warmes Orange/Rot
    "Materials": "#74C476",              // Frischgrün
    "Industrials": "#3182BD",            // Stahlblau
    "Consumer Discretionary": "#FD8D3C", // Helles Orange
    "Consumer Staples": "#9ECAE1",       // Helles Blau
    "Health Care": "#E377C2",            // Magenta / Rosa
    "Financials": "#2B8CBE",             // Dunkelcyan
    "Information Technology": "#6BAED6", // Tech-Blau
    "Communication Services": "#BCBD22", // Limettengelb
    "Utilities": "#17BECF",              // Türkis
    "Real Estate": "#8C564B"             // Braun / Terrakotta
  };

  // Standardfarben für Assetklassen
  const ASSET_TYPE_COLORS = {
    "Aktien": "#1E40AF",      // LUKB Blau
    "Bonds": "#0D9488",       // Teal / Petrol
    "Real Estate": "#8C564B", // Braun / Terrakotta
    "Rohstoffe": "#D97706",   // Bernstein / Goldgelb
    "Cash": "#16A34A"         // Grün
  };

  // Regionen-Definitionen & Farben
  const REGIONS_LIST = [
    "Schweiz",
    "Nordamerika",
    "Eurozone",
    "Pazifik",
    "Schwellenländer",
    "UK"
  ];

  const EQUITY_REGIONS_LIST = [
    "Schweiz",
    "Eurozone",
    "UK",
    "Nordamerika",
    "Pazifik",
    "Schwellenländer"
  ];

  const BOND_REGIONS_LIST = [
    "Schweiz",
    "Eurozone",
    "Nordamerika",
    "UK",
    "EM HC",
    "EM LC"
  ];

  const REGION_COLORS = {
    "Schweiz": "#1E40AF",
    "Nordamerika": "#0D9488",
    "Eurozone": "#0284C7",
    "Pazifik": "#D97706",
    "Schwellenländer": "#DC2626",
    "UK": "#7C3AED"
  };

  // ISO-Währungsfarben
  const CURRENCY_COLORS = {
    "CHF": "#1E40AF", // Schweizer Franken - Tiefblau
    "USD": "#0D9488", // US-Dollar - Petrol
    "EUR": "#0284C7", // Euro - Blau
    "GBP": "#7C3AED", // Britisches Pfund - Violett
    "JPY": "#E11D48", // Japanischer Yen - Rot
    "CAD": "#D97706", // Kanadischer Dollar - Bernstein
    "AUD": "#059669", // Australischer Dollar - Grün
    "CNY": "#DC2626", // Chinesischer Yuan - Rot
    "INR": "#EA580C", // Indische Rupie - Orange
    "HKD": "#DB2777", // Hongkong-Dollar - Pink
    "SGD": "#4F46E5", // Singapur-Dollar - Indigo
    "KRW": "#0891B2", // Südkoreanischer Won - Cyan
    "TWD": "#65A30D", // Taiwan-Dollar - Limette
    "BRL": "#16A34A", // Brasilianischer Real - Grün
    "ZAR": "#B45309", // Südafrikanischer Rand - Braun
    "SAR": "#047857", // Saudi-Riyal - Dunkelgrün
    "MXN": "#C026D3", // Mexikanischer Peso - Magenta
    "NA":  "#9CA3AF"  // Unbekannt / Nicht zugewiesen - Grau
  };

  // Anleihen-Emittenten (Issuer Types)
  const ISSUER_TYPE_COLORS = {
    "SOV": "#1E40AF",
    "FIN": "#0D9488",
    "CORP": "#0284C7",
    "AGCY": "#D97706",
    "SUPR": "#7C3AED",
    "SSOV": "#E11D48",
    "Andere": "#9CA3AF"
  };

  const ISSUER_TYPE_LABELS = {
    "SOV": "Staatsanleihen (SOV)",
    "FIN": "Finanztitel / Banken (FIN)",
    "CORP": "Unternehmensanleihen (CORP)",
    "AGCY": "Agencies / Behörden (AGCY)",
    "SUPR": "Supranational (SUPR)",
    "SSOV": "Sub-Sovereign (SSOV)",
    "Andere": "Andere Emittenten"
  };

  // Portfolio-Themes (P1, P2, P3)
  const PORTFOLIO_COLORS = {
    "portfolio_1": "#1E40AF", // Corporate LUKB Blau
    "portfolio_2": "#0D9488", // Petrol / Teal
    "portfolio_3": "#E11D48"  // Karminrot / Rose
  };

  const PORTFOLIO_BG_COLORS = {
    "portfolio_1": "#EFF6FF",
    "portfolio_2": "#F0FDFA",
    "portfolio_3": "#FFF1F2"
  };

  // Refinitiv / Datastream Währungskürzel Mapping
  const DATASTREAM_CURRENCY_MAP = {
    "SF": "CHF",
    "E": "EUR",
    "U$": "USD",
    "£": "GBP",
    "Y": "JPY",
    "A$": "AUD",
    "C$": "CAD",
    "K$": "HKD",
    "S$": "SGD",
    "Z$": "NZD",
    "M$": "MYR",
    "C": "BRL",
    "CE": "CLP",
    "CH": "CNY",
    "CK": "CZK",
    "CP": "COP",
    "E£": "EGP",
    "ED": "AED",
    "HF": "HUF",
    "I£": "ILS",
    "IR": "INR",
    "KD": "KWD",
    "KW": "KRW",
    "MP": "MXN",
    "NK": "NOK",
    "PP": "PHP",
    "PS": "PEN",
    "PZ": "PLN",
    "Q": "QAR",
    "R": "ZAR",
    "RI": "IDR",
    "RL": "RON",
    "SK": "SEK",
    "SR": "SAR",
    "TB": "THB",
    "TL": "TRY",
    "TW": "TWD"
  };

  const Constants = {
    GICS_11_SECTORS,
    GICS_SECTOR_MAP,
    GICS_SECTOR_COLORS,
    ASSET_TYPE_COLORS,
    REGIONS_LIST,
    EQUITY_REGIONS_LIST,
    BOND_REGIONS_LIST,
    REGION_COLORS,
    CURRENCY_COLORS,
    ISSUER_TYPE_COLORS,
    ISSUER_TYPE_LABELS,
    PORTFOLIO_COLORS,
    PORTFOLIO_BG_COLORS,
    DATASTREAM_CURRENCY_MAP
  };

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = Constants;
  } else {
    global.Constants = Constants;
  }
})(typeof window !== 'undefined' ? window : globalThis);
