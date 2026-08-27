# ETF Look-Through Dashboard

Ein hochperformantes, professionelles Portfolio Look-Through Dashboard für Multi-Asset-Portfolios (Aktien, Anleihen/Bonds, Real Estate, Rohstoffe, Cash).

Das Projekt bietet zwei parallele, feature-identische Implementierungen:
1. **Zero-Dependency WebApp (`web/index.html`):** Läuft blitzschnell (0 ms Latenz) direkt im Browser (auch offline via `file://` ohne Webserver).
2. **R-Shiny Dashboard (`app.R`):** Enterprise R-Shiny App mit modularer Architektur (`bslib`, `plotly`, `reactable`).

---

## ?? Hauptfunktionen

- **Multi-Asset Allokation & Kennzahlen:**
  - Aggregation über 5 Assetklassen: **Aktien**, **Bonds**, **Real Estate**, **Rohstoffe**, **Cash**.
  - Renditekennzahlen: Gewichtete Dividendenrendite, KGV (P/E), KBV (P/B), Yield to Maturity (YTM), Modified Duration, Restlaufzeit (Maturity).
- **Assetklassen- & Regionen-Divergenzen:**
  - Interaktive Delta-Balkencharts ($\Delta$ in Prozentpunkten) für Vergleiche zwischen Portfolios (`P1 vs. P2`, `P1 vs. P3`, `P2 vs. P3`).
- **GICS Sektor-Mix (11 Sektoren):**
  - Donut-/Pie-Chart des aktiven Portfolios, Balken-Sektorallokation und Sektor-Divergenzen für den reinen Aktienanteil.
  - Sektor-Drilldown auf Einzeltitelebene.
- **Top 20 Einzeltitel & Vollständiger Look-Through:**
  - Rangliste der Top 20 Aktientitel (sortierbar nach P1, P2, P3).
  - Vollständige, durchsuchbare Look-Through-Tabelle mit Assetklassen-Filter (`Alle`, `Aktien`, `Bonds`, `Real Estate`, `Rohstoffe`, `Cash`).
- **Konzentrations- & Diversifikationsanalyse:**
  - Lorenz-Kurven, Herfindahl-Hirschman-Index (HHI), Effektive Titelanzahl ($N_{\text{eff}}$), Gini-Koeffizient und Top-N-Konzentration.
- **Portfolio-Editor & Persistenz:**
  - Live-Gewichtungsauswahl für 3 Portfolios.
  - Speichern im Browser-`localStorage` sowie JSON-Import/Export.

---

## ?? Starten

### 1. WebApp (Zero-Dependency)
- Öffnen Sie einfach `web/index.html` per Doppelklick im Browser.

### 2. R-Shiny App
```r
# In R oder RStudio ausführen:
shiny::runApp()
```

### 3. Datenaktualisierung
Um Daten aus `Data.xlsx` neu für die WebApp zu exportieren:
```bash
Rscript scripts/export_data_to_json.R
```

---

## ?? Projektstruktur

```
+-- app.R                          # R-Shiny Hauptanwendung
+-- Data.xlsx                      # ETF- und Holdings-Rohdaten
+-- saved_portfolios.json          # Standard-Portfoliokonfigurationen (TAA, SAA, TAA-Alt)
+-- R/
¦   +-- analytics.R                # Berechnungslogik (Look-Through, Kennzahlen, Diversifikation)
¦   +-- data_loader.R              # Einlesen & Bereinigen von Excel-Sheets
¦   +-- persistence.R              # JSON-Laden & -Speichern in R
¦   +-- ui_components.R            # Plotly-Charts & Reactable-Tabellen
+-- web/
¦   +-- index.html                 # WebApp Einstiegspunkt
¦   +-- css/custom.css             # Styling & Badges
¦   +-- data/                      # Exportierte Daten (JSON & JS)
¦   +-- js/
¦       +-- analytics.js           # Client-side Look-Through & Analytics Engine
¦       +-- app.js                 # App State Management & Event Handling
¦       +-- charts.js              # Plotly.js Visualisierungen
¦       +-- persistence.js         # LocalStorage & JSON Import/Export
¦       +-- tables.js              # Sortierbare HTML-Tabellen & Badges
+-- scripts/
    +-- export_data_to_json.R      # Konvertierungsskript Data.xlsx -> JSON/JS
    +-- verify_calculations.js     # Validierungstest für JS-Analytics
    +-- verify_r_calculations.R    # Validierungstest für R-Analytics
```
