# ==============================================================================
# app.R - ETF Look-Through Shiny Application
# Multi-Asset Analyse (Aktien & Bonds), Sektoren, Währungen & Konzentration
# Mit Live-Editing Sidebar (Stepper-Buttons [-] / [+]) & Portfolio-Editor Tab
# ==============================================================================

library(shiny)
library(bslib)
library(bsicons)
library(reactable)
library(plotly)
library(dplyr)
library(tidyr)
library(readxl)
library(jsonlite)
library(shinyjs)
library(shinyWidgets)

# Module laden
source("R/data_loader.R")
source("R/persistence.R")
source("R/analytics.R")
source("R/ui_components.R")

# ------------------------------------------------------------------------------
# UI THEME & LAYOUT
# ------------------------------------------------------------------------------

app_theme <- bs_theme(
  version = 5,
  preset = "bootstrap",
  primary = "#1E40AF",   # LUKB / Corporate Navy
  secondary = "#475569", # Slate
  success = "#0D9488",   # Teal
  info = "#0284C7",      # Blue
  warning = "#D97706",   # Amber
  danger = "#E11D48",    # Rose
  bg = "#F8FAFC",        # Sehr helles Grau
  fg = "#0F172A",        # Dunkles Schiefergrau
  base_font = font_google("Inter"),
  heading_font = font_google("Inter"),
  code_font = font_google("Fira Code")
)

ui <- page_navbar(
  theme = app_theme,
  title = div(
    style = "display: flex; align-items: center; gap: 10px; font-weight: 700;",
    bs_icon("pie-chart-fill", class = "text-primary fs-4"),
    span("ETF Look-Through Analytics")
  ),
  id = "main_nav",
  
  # ----------------------------------------------------------------------------
  # GLOBALE SCHLANKE LIVE-SIDEBAR MIT STEPPER-BUTTONS [-] / [+]
  # ----------------------------------------------------------------------------
  sidebar = sidebar(
    title = div(
      class = "d-flex justify-content-between align-items-center w-100",
      span(bs_icon("sliders", class = "me-1 text-primary"), "Live-Gewichte"),
      uiOutput("sidebar_sum_badge")
    ),
    width = 340,
    open = "open",
    
    # Portfolio Umschalter (P1 / P2 / P3)
    div(
      class = "mb-2",
      shinyWidgets::radioGroupButtons(
        inputId = "sidebar_active_port",
        label = NULL,
        choices = c("P1" = "portfolio_1", "P2" = "portfolio_2", "P3" = "portfolio_3"),
        selected = "portfolio_1",
        justified = TRUE,
        status = "outline-primary",
        size = "sm"
      )
    ),
    
    # Dynamischer Inhalt des ausgewählten Portfolios (Stepper Controls)
    uiOutput("ui_sidebar_portfolio_controls"),
    
    # Footer & Speichern in der Sidebar
    hr(class = "my-2"),
    div(
      class = "d-flex flex-column gap-1",
      div(
        class = "d-flex justify-content-between align-items-center mb-1",
        span(class = "text-muted small", "Status:"),
        uiOutput("sidebar_save_status_badge")
      ),
      div(
        class = "d-flex gap-2",
        actionButton("sidebar_btn_save", "Speichern", icon = icon("floppy-disk"), class = "btn btn-primary btn-sm flex-fill fw-semibold"),
        actionButton("sidebar_btn_reset", "Reset", icon = icon("arrow-rotate-left"), class = "btn btn-outline-danger btn-sm", title = "Standardwerte wiederherstellen")
      )
    )
  ),
  
  header = tagList(
    useShinyjs(),
    tags$head(
      tags$style(HTML("
        .navbar { box-shadow: 0 1px 3px rgba(0,0,0,0.05); padding-top: 0.6rem; padding-bottom: 0.6rem; }
        .card { box-shadow: 0 1px 3px rgba(0,0,0,0.04), 0 1px 2px rgba(0,0,0,0.06); border: 1px solid #E2E8F0; border-radius: 10px; margin-bottom: 1rem; }
        .card-header { background: #FFFFFF; border-bottom: 1px solid #E2E8F0; font-weight: 600; font-size: 0.95rem; }
        .value-box { border-radius: 10px; box-shadow: 0 1px 3px rgba(0,0,0,0.04); }
        .nav-pills .nav-link.active { background-color: #1E40AF; }
        .badge-sector { padding: 4px 8px; border-radius: 6px; font-weight: 600; font-size: 0.75rem; }
        .weight-pill { font-family: monospace; font-weight: 600; }
        .etf-item-box { background: #FFFFFF; border: 1px solid #E2E8F0; border-radius: 8px; padding: 8px 10px; margin-bottom: 6px; transition: all 0.2s ease; }
        .etf-item-box:hover { border-color: #CBD5E1; box-shadow: 0 2px 4px rgba(0,0,0,0.04); }
        .metric-card-box { background: #FFFFFF; border: 1px solid #E2E8F0; border-radius: 8px; padding: 12px; text-align: center; }
        .sidebar-etf-row { background: #FFFFFF; border: 1px solid #E2E8F0; border-radius: 6px; padding: 6px 8px; margin-bottom: 5px; }
        .sidebar-etf-row:hover { border-color: #CBD5E1; background: #F8FAFC; }
      "))
    )
  ),
  
  # ----------------------------------------------------------------------------
  # TAB 1: 📊 DASHBOARD & ÜBERSICHT
  # ----------------------------------------------------------------------------
  nav_panel(
    title = span(bs_icon("speedometer2"), "Dashboard"),
    value = "tab_dashboard",
    
    div(
      class = "container-fluid py-2",
      
      div(
        class = "d-flex justify-content-between align-items-center mb-3 pb-2 border-bottom",
        div(
          h4(class = "mb-0 fw-bold text-dark", "Portfolio-Übersicht & Multi-Asset Look-Through"),
          p(class = "text-muted small mb-0", "Direkte Live-Aktualisierung bei Anpassungen in der Sidebar.")
        ),
        div(
          class = "d-flex align-items-center gap-3",
          uiOutput("opt_normalize_toggle"),
          actionButton(
            "btn_go_config",
            label = "Portfolio-Editor →",
            icon = icon("sliders"),
            class = "btn btn-outline-primary btn-sm fw-semibold"
          )
        )
      ),
      
      # Dynamische Multi-Asset KPI Boxes
      uiOutput("ui_kpi_value_boxes"),
      
      # Hauptbereich Dashboard
      layout_columns(
        col_widths = c(7, 5),
        
        # Linke Spalte: Assetklassen-Divergenzen
        card(
          card_header(
            div(
              class = "d-flex justify-content-between align-items-center",
              span(bs_icon("stack"), " Assetklassen-Divergenzen (Delta)"),
              selectInput(
                "dash_asset_delta_pair",
                label = NULL,
                choices = c("P1 vs. P2" = "p1_p2", "P1 vs. P3" = "p1_p3", "P2 vs. P3" = "p2_p3"),
                width = "140px"
              )
            )
          ),
          card_body(
            plotlyOutput("plot_dash_asset_delta", height = "360px")
          )
        ),
        
        # Rechte Spalte: Top Holdings Snapshot (Aktien)
        card(
          card_header(
            div(
              class = "d-flex justify-content-between align-items-center",
              span(bs_icon("trophy"), " Top 10 Einzeltitel Snapshot (Aktien)"),
              actionLink("link_to_holdings", "Alle 20+ Titel →", class = "small text-primary text-decoration-none fw-semibold")
            )
          ),
          card_body(
            reactableOutput("table_dash_top10")
          )
        )
      ),
      
      # Untere Zeile: Asset-Allokation & Multi-Asset Matrix
      card(
        card_header(
          div(
            class = "d-flex justify-content-between align-items-center",
            span(bs_icon("globe"), " Asset-Allokation & Renditekennzahlen im Überblick"),
            actionLink("link_to_allocation", "Währungsdetails & Asset-Split →", class = "small text-primary text-decoration-none fw-semibold")
          )
        ),
        card_body(
          reactableOutput("table_dash_multi_asset")
        )
      )
    )
  ),
  
  # ----------------------------------------------------------------------------
  # TAB 2: 🌐 ALLOKATION & WÄHRUNGEN
  # ----------------------------------------------------------------------------
  nav_panel(
    title = span(bs_icon("globe"), "Allokation & Währungen"),
    value = "tab_allocation",
    
    div(
      class = "container-fluid py-2",
      
      div(
        class = "d-flex justify-content-between align-items-center mb-3 pb-2 border-bottom",
        div(
          h4(class = "mb-0 fw-bold text-dark", "Asset-Allokation, Währungsmix & Renditekennzahlen"),
          p(class = "text-muted small mb-0", "Aufteilung in Aktien vs. Anleihen, gewichtete Dividendenrendite, Yield to Maturity und Modified Duration nach Währung.")
        )
      ),
      
      # Reihe 1: Asset-Allokation & Gesamtportfolio-Währungsmix
      layout_columns(
        col_widths = c(6, 6),
        
        card(
          card_header(span(bs_icon("stack"), " Assetklassen-Aufteilung (Aktien vs. Bonds)")),
          card_body(
            plotlyOutput("plot_asset_allocation", height = "280px")
          )
        ),
        
        card(
          card_header(span(bs_icon("currency-exchange"), " Gesamter Währungsmix (Look-Through)")),
          card_body(
            plotlyOutput("plot_overall_currency", height = "280px")
          )
        )
      ),
      
      # Reihe 2: Deep-Dive: Aktien vs. Bonds
      layout_columns(
        col_widths = c(6, 6),
        
        # Linke Box: Aktien-Segment
        card(
          class = "border-primary",
          card_header(
            class = "bg-primary text-white d-flex justify-content-between align-items-center",
            span(bs_icon("graph-up-arrow"), " Aktien-Segment (Equity)")
          ),
          card_body(
            uiOutput("ui_equity_kpi_card"),
            h6(class = "fw-bold text-secondary mt-3 mb-2", "Währungsmix im Aktienanteil (%):"),
            plotlyOutput("plot_equity_currency", height = "240px")
          )
        ),
        
        # Rechte Box: Anleihen-Segment (Bonds)
        card(
          class = "border-success",
          card_header(
            class = "bg-success text-white d-flex justify-content-between align-items-center",
            span(bs_icon("bank"), " Anleihen-Segment (Bonds / Fixed Income)")
          ),
          card_body(
            uiOutput("ui_bond_kpi_card"),
            h6(class = "fw-bold text-secondary mt-3 mb-2", "Währungsmix im Anleihenanteil (%):"),
            plotlyOutput("plot_bond_currency", height = "240px")
          )
        )
      ),
      
      # Reihe 3: Währungstabellen (Gesamtportfolio & Segment-Details)
      layout_columns(
        col_widths = c(6, 6),
        
        card(
          card_header(span(bs_icon("table"), " Währungs-Vergleichstabelle (Gesamtportfolio)")),
          card_body(
            reactableOutput("table_overall_currency_detail")
          )
        ),
        
        navset_card_tab(
          title = span(bs_icon("currency-exchange"), " Währungs-Details nach Segment"),
          nav_panel(
            title = span(bs_icon("graph-up"), " Aktien (KGV, KBV, Div)"),
            reactableOutput("table_equity_currency_detail")
          ),
          nav_panel(
            title = span(bs_icon("activity"), " Anleihen (YTM, Duration)"),
            reactableOutput("table_bond_currency_detail")
          )
        )
      ),
      
      # Reihe 4: Anleihen-Breakdown nach Region & Emittententyp (FI-Portfolio)
      card(
        class = "mt-3 border-success",
        card_header(
          class = "d-flex justify-content-between align-items-center bg-white",
          span(bs_icon("diagram-2", class = "text-success me-1"), strong("Anleihen-Breakdown nach Region & Emittententyp (FI-Portfolio)")),
          div(
            class = "d-flex align-items-center gap-2",
            span(class = "small text-muted", "Portfolio:"),
            selectInput(
              "select_shiny_bond_breakdown_port",
              label = NULL,
              choices = c("Portfolio 1" = "portfolio_1", "Portfolio 2" = "portfolio_2", "Portfolio 3" = "portfolio_3"),
              selected = "portfolio_1",
              width = "180px"
            )
          )
        ),
        card_body(
          reactableOutput("table_shiny_bond_region_issuer_breakdown")
        ),
        card_footer(
          class = "bg-light d-flex justify-content-between align-items-center py-1 px-3",
          span(class = "text-muted small", bs_icon("info-circle"), " Prozentual auf das gesamte Fixed-Income (FI) Segment des ausgewählten Portfolios hochgerechnet (Summe = 100%). Bei Schwellenländern wird zwischen EM HC und EM LC unterschieden."),
          uiOutput("ui_shiny_bond_fi_total_badge")
        )
      )
    )
  ),
  
  # ----------------------------------------------------------------------------
  # TAB 3: 🏢 SEKTOREN (11 GICS - AKTIEN)
  # ----------------------------------------------------------------------------
  nav_panel(
    title = span(bs_icon("diagram-3"), "Sektor-Mix"),
    value = "tab_sectors",
    
    div(
      class = "container-fluid py-2",
      
      div(
        class = "d-flex justify-content-between align-items-center mb-3 pb-2 border-bottom",
        div(
          h4(class = "mb-0 fw-bold text-dark", "GICS Sektor-Mix & Allokationsdifferenzen (Aktien)"),
          p(class = "text-muted small mb-0", "Bereinigt auf die offiziellen 11 GICS-Sektoren für den Aktienanteil der Portfolios.")
        ),
        div(
          class = "badge bg-light text-secondary border px-3 py-2",
          bs_icon("shield-check", class = "text-success me-1"), "11 GICS Standard-Klassifikation"
        )
      ),

      
      card(
        card_header(span(bs_icon("table"), " Detaillierte Sektor-Vergleichstabelle")),
        card_body(
          reactableOutput("table_sectors_detail")
        )
      ),
      
      card(
        card_header(
          div(
            class = "d-flex justify-content-between align-items-center flex-wrap gap-2",
            span(bs_icon("search"), " Sektor-Drilldown: Aktien-Einzeltitel nach GICS-Sektor"),
            div(
              style = "min-width: 250px;",
              selectInput(
                "select_drilldown_sector",
                label = NULL,
                choices = GICS_11_SECTORS,
                selected = "Health Care",
                width = "250px"
              )
            )
          )
        ),
        card_body(
          p(class = "text-muted small", "Zeigt alle Aktientitel im ausgewählten Sektor und deren kumuliertes Look-Through-Gewicht:"),
          reactableOutput("table_sector_drilldown")
        )
      )
    )
  ),
  
  # ----------------------------------------------------------------------------
  # ----------------------------------------------------------------------------
  # TAB 4: 🏆 TOP HOLDINGS & LOOK-THROUGH
  # ----------------------------------------------------------------------------
  nav_panel(
    title = span(bs_icon("trophy"), "Top Holdings"),
    value = "tab_holdings",
    
    div(
      class = "container-fluid py-2",
      
      div(
        class = "d-flex justify-content-between align-items-center mb-3 pb-2 border-bottom",
        div(
          h4(class = "mb-0 fw-bold text-dark", "Vollständiger Look-Through"),
          p(class = "text-muted small mb-0", "Transparenz über alle aggregierten Einzeltitel, Assetklassen und ETF-Überlappungen.")
        )
      ),
      
      card(
        card_header(
          div(
            class = "d-flex justify-content-between align-items-center flex-wrap gap-2",
            span(bs_icon("search-heart"), " Vollständiger Einzeltitel-Lookthrough (Durchsuchbar & Filterbar)"),
            div(
              class = "d-flex gap-2 align-items-center flex-wrap",
              div(
                style = "min-width: 175px;",
                selectInput(
                  "select_full_table_asset_class",
                  label = NULL,
                  choices = c(
                    "Alle Assetklassen" = "all",
                    "Aktien" = "Aktien",
                    "Bonds" = "Bonds",
                    "Real Estate" = "Real Estate",
                    "Rohstoffe" = "Rohstoffe",
                    "Cash" = "Cash"
                  ),
                  selected = "all",
                  width = "175px"
                )
              ),
              div(
                style = "min-width: 175px;",
                selectInput(
                  "select_full_table_portfolio",
                  label = NULL,
                  choices = c("Portfolio 1" = "portfolio_1", "Portfolio 2" = "portfolio_2", "Portfolio 3" = "portfolio_3"),
                  width = "175px"
                )
              )
            )
          )
        ),
        card_body(
          reactableOutput("table_full_lookthrough")
        )
      )
    )
  ),
  
  # ----------------------------------------------------------------------------
  # TAB 5: 📈 KONZENTRATIONSMASSE & DIVERSIFIKATION
  # ----------------------------------------------------------------------------
  nav_panel(
    title = span(bs_icon("graph-up"), "Konzentration"),
    value = "tab_concentration",
    
    div(
      class = "container-fluid py-2",
      
      div(
        class = "d-flex justify-content-between align-items-center mb-3 pb-2 border-bottom",
        div(
          h4(class = "mb-0 fw-bold text-dark", "Konzentrations- und Diversifikationsanalyse (Aktien)"),
          p(class = "text-muted small mb-0", "Herfindahl-Hirschman Index (HHI), Effektive Titelanzahl (N_eff) und Lorenz-Kurve für den Aktienteil.")
        )
      ),
      
      layout_columns(
        col_widths = c(6, 6),
        
        card(
          card_header(span(bs_icon("activity"), " Kumulative Konzentrationskurve (Lorenz-Kurve)")),
          card_body(
            plotlyOutput("plot_lorenz", height = "380px"),
            p(class = "text-muted small mt-2 mb-0", "Je steiler die Kurve links ansteigt, desto stärker konzentrieren wenige Titel das gesamte Aktiengewicht.")
          )
        ),
        
        card(
          card_header(span(bs_icon("info-circle"), " Kennzahlen-Vergleich (Aktien)")),
          card_body(
            reactableOutput("table_concentration_full"),
            hr(class = "my-3"),
            div(
              class = "small text-secondary",
              tags$ul(
                class = "ps-3 mb-0",
                tags$li(tags$strong("N_eff (Effektive Titelanzahl): "), "1 / sum(w_i^2). Entspricht der Diversifikation eines fiktiven Portfolios aus N_eff gleichgewichteten Titeln."),
                tags$li(tags$strong("HHI (Herfindahl-Hirschman): "), "Summe der quadrierten Prozentgewichte (0 bis 10'000). Unter 1'500 gilt als breit diversifiziert."),
                tags$li(tags$strong("Top 10 / 20: "), "Kumulierter Prozentanteil der grössten 10 bzw. 20 Aktienpositionen am Gesamtportfolio.")
              )
            )
          )
        )
      ),
      
      card(
        card_header(span(bs_icon("list-ol"), " Top 20 Aktien-Holdings Rangliste")),
        card_body(
          reactableOutput("table_top20_detail")
        )
      )
    )
  ),
  
  # ----------------------------------------------------------------------------
  # TAB 6: ⚙️ PORTFOLIO-EDITOR & METADATEN (VOLLSTÄNDIGER TAB)
  # ----------------------------------------------------------------------------
  nav_panel(
    title = span(bs_icon("gear"), "Portfolio-Editor"),
    value = "tab_config",
    
    div(
      class = "container-fluid py-2",
      
      div(
        class = "d-flex justify-content-between align-items-center mb-3 pb-2 border-bottom flex-wrap gap-2",
        div(
          h4(class = "mb-0 fw-bold text-dark", "Portfolio-Baukasten & Permanenz-Verwaltung"),
          p(class = "text-muted small mb-0", "Detaillierte Übersicht und Bearbeitung aller drei Portfolios nebeneinander.")
        ),
        div(
          class = "d-flex align-items-center gap-2",
          actionButton("btn_tab_save_config", "Jetzt Speichern", icon = icon("floppy-disk"), class = "btn btn-primary btn-sm fw-semibold"),
          actionButton("btn_tab_reset_config", "Standardwerte", icon = icon("arrow-rotate-left"), class = "btn btn-outline-danger btn-sm")
        )
      ),
      
      # 3 Portfolio Karten nebeneinander
      layout_columns(
        col_widths = c(4, 4, 4),
        
        # Portfolio 1
        card(
          class = "border-primary",
          card_header(
            class = "bg-primary text-white d-flex justify-content-between align-items-center",
            span(bs_icon("briefcase-fill"), " Portfolio 1"),
            uiOutput("p1_sum_badge_tab")
          ),
          card_body(
            textInput("p1_name_tab", label = "Portfolio Name:", value = "Portfolio 1"),
            hr(class = "my-2"),
            h6(class = "fw-bold text-secondary mb-2", "Enthaltene ETFs:"),
            uiOutput("ui_p1_etf_list_tab"),
            hr(class = "my-2"),
            h6(class = "fw-bold text-secondary mb-2", "ETF hinzufügen:"),
            uiOutput("ui_p1_add_section_tab"),
            hr(class = "my-3"),
            div(
              class = "d-flex gap-2",
              actionButton("btn_p1_norm_tab", "100% Skalieren", icon = icon("scale-balanced"), class = "btn btn-sm btn-outline-primary w-50"),
              actionButton("btn_p1_eq_tab", "Gleichgewichtung", icon = icon("equals"), class = "btn btn-sm btn-outline-secondary w-50")
            )
          )
        ),
        
        # Portfolio 2
        card(
          class = "border-success",
          card_header(
            class = "bg-success text-white d-flex justify-content-between align-items-center",
            div(
              checkboxInput("p2_enabled_tab", label = tags$strong("Portfolio 2 aktivieren"), value = TRUE),
              style = "margin-bottom: 0;"
            ),
            uiOutput("p2_sum_badge_tab")
          ),
          card_body(
            textInput("p2_name_tab", label = "Portfolio Name:", value = "Portfolio 2"),
            hr(class = "my-2"),
            h6(class = "fw-bold text-secondary mb-2", "Enthaltene ETFs:"),
            uiOutput("ui_p2_etf_list_tab"),
            hr(class = "my-2"),
            h6(class = "fw-bold text-secondary mb-2", "ETF hinzufügen:"),
            uiOutput("ui_p2_add_section_tab"),
            hr(class = "my-3"),
            div(
              class = "d-flex gap-2",
              actionButton("btn_p2_norm_tab", "100% Skalieren", icon = icon("scale-balanced"), class = "btn btn-sm btn-outline-success w-50"),
              actionButton("btn_p2_eq_tab", "Gleichgewichtung", icon = icon("equals"), class = "btn btn-sm btn-outline-secondary w-50")
            )
          )
        ),
        
        # Portfolio 3
        card(
          class = "border-danger",
          card_header(
            class = "bg-danger text-white d-flex justify-content-between align-items-center",
            div(
              checkboxInput("p3_enabled_tab", label = tags$strong("Portfolio 3 aktivieren"), value = TRUE),
              style = "margin-bottom: 0;"
            ),
            uiOutput("p3_sum_badge_tab")
          ),
          card_body(
            textInput("p3_name_tab", label = "Portfolio Name:", value = "Portfolio 3"),
            hr(class = "my-2"),
            h6(class = "fw-bold text-secondary mb-2", "Enthaltene ETFs:"),
            uiOutput("ui_p3_etf_list_tab"),
            hr(class = "my-2"),
            h6(class = "fw-bold text-secondary mb-2", "ETF hinzufügen:"),
            uiOutput("ui_p3_add_section_tab"),
            hr(class = "my-3"),
            div(
              class = "d-flex gap-2",
              actionButton("btn_p3_norm_tab", "100% Skalieren", icon = icon("scale-balanced"), class = "btn btn-sm btn-outline-danger w-50"),
              actionButton("btn_p3_eq_tab", "Gleichgewichtung", icon = icon("equals"), class = "btn btn-sm btn-outline-secondary w-50")
            )
          )
        )
      )
    )
  ),
  
  # ----------------------------------------------------------------------------
  # TAB 7: 📚 ETF-UNIVERSUM & METADATEN (EIGENER DEDIZIERTER TAB)
  # ----------------------------------------------------------------------------
  nav_panel(
    title = span(bs_icon("database"), "ETF-Universum"),
    value = "tab_universe",
    
    div(
      class = "container-fluid py-2",
      
      div(
        class = "d-flex justify-content-between align-items-center mb-3 pb-2 border-bottom flex-wrap gap-2",
        div(
          h4(class = "mb-0 fw-bold text-dark", "Verfügbares ETF-Universum & Stammdaten"),
          p(class = "text-muted small mb-0", "Vollständige Übersicht aller in Data.xlsx hinterlegten ETFs, Assetklassen, Regionen und Bewertungskennzahlen.")
        ),
        uiOutput("ui_universe_stat_badges")
      ),
      
      card(
        card_header(span(bs_icon("database-check"), " Geladene ETFs & Index-Metadaten")),
        card_body(
          reactableOutput("table_etf_meta_summary")
        )
      )
    )
  ),
  
  # Footer
  nav_spacer(),
  nav_item(
    div(
      class = "py-2 px-3 text-muted small d-flex align-items-center gap-2",
      bs_icon("check-circle-fill", class = "text-success"),
      "ETF Look-Through Engine v2.2 (Robust Stepper)"
    )
  )
)

# ------------------------------------------------------------------------------
# SERVER DEFINITION
# ------------------------------------------------------------------------------

server <- function(input, output, session) {
  
  # 1. Daten laden & bereinigen
  raw_data_reactive <- reactiveVal(NULL)
  save_status_reactive <- reactiveVal("Gespeichert")
  portfolios_state <- reactiveVal(NULL)
  
  # Initiales Laden der ETF-Daten
  observe({
    tryCatch({
      loaded <- load_etf_data("Data.xlsx")
      raw_data_reactive(loaded)
      
      saved <- load_portfolios("saved_portfolios.json", available_etfs = loaded$available_etfs, ticker_df = loaded$ticker_df)
      portfolios_state(saved)
    }, error = function(e) {
      showNotification(paste("Fehler beim Laden von Data.xlsx:", e$message), type = "error", duration = NULL)
    })
  })
  
  # ----------------------------------------------------------------------------
  # DYNAMISCHE STEUERUNG IN DER LIVE-SIDEBAR (STEPPER [-] / [+])
  # ----------------------------------------------------------------------------
  
  output$sidebar_sum_badge <- renderUI({
    req(portfolios_state(), input$sidebar_active_port)
    p_key <- input$sidebar_active_port
    p_conf <- portfolios_state()[[p_key]]
    
    if (is.null(p_conf$weights) || length(p_conf$weights) == 0) {
      return(span(class = "badge bg-light text-muted border small", "Leer"))
    }
    
    s <- sum(unlist(p_conf$weights), na.rm = TRUE)
    badge_class <- if (abs(s - 100) < 0.01) "bg-success text-white fw-bold" else "bg-warning text-dark fw-bold"
    span(
      class = paste("badge rounded-pill weight-pill", badge_class),
      sprintf("%.1f%%", s)
    )
  })
  
  output$sidebar_save_status_badge <- renderUI({
    span(class = "badge bg-light text-muted border small", bs_icon("clock-history", class = "me-1"), save_status_reactive())
  })
  
  output$ui_sidebar_portfolio_controls <- renderUI({
    req(raw_data_reactive(), portfolios_state(), input$sidebar_active_port)
    d <- raw_data_reactive()
    ports <- portfolios_state()
    p_key <- input$sidebar_active_port
    p_conf <- ports[[p_key]]
    
    p_prefix <- switch(p_key, "portfolio_1" = "sb_p1", "portfolio_2" = "sb_p2", "portfolio_3" = "sb_p3")
    
    # ETF-Metadaten Helfer
    get_meta <- function(ric) {
      m <- d$ticker_df %>% dplyr::filter(ric == !!ric)
      if (nrow(m) > 0) {
        list(label = m$label[1], region = m$region[1], asset_type = m$asset_type[1])
      } else {
        list(label = ric, region = "Global", asset_type = "Aktien")
      }
    }
    
    current_weights <- p_conf$weights
    current_etfs <- names(current_weights)
    all_available <- d$ticker_df
    unassigned <- all_available %>% dplyr::filter(!(ric %in% current_etfs))
    
    choices_vec <- if (nrow(unassigned) > 0) {
      setNames(
        unassigned$ric,
        paste0(unassigned$label, " (", unassigned$ric, ")")
      )
    } else {
      NULL
    }
    
    tagList(
      # Name & Status
      div(
        class = "d-flex justify-content-between align-items-center mb-2",
        tags$strong(class = "text-dark", p_conf$name),
        if (p_key != "portfolio_1") {
          checkboxInput(paste0(p_prefix, "_enabled"), label = "Aktiv", value = isTRUE(p_conf$enabled), width = "auto")
        }
      ),
      
      # Schnell-Aktionen (100%, Equal, Clear)
      div(
        class = "d-flex gap-1 mb-2",
        actionButton(paste0("btn_norm_", p_prefix), "100%", class = "btn btn-xs btn-outline-primary flex-fill", style = "font-size: 0.75rem; padding: 2px 4px;", title = "Auf 100% skalieren"),
        actionButton(paste0("btn_eq_", p_prefix), "= Equal", class = "btn btn-xs btn-outline-secondary flex-fill", style = "font-size: 0.75rem; padding: 2px 4px;", title = "Gleichgewichten"),
        actionButton(paste0("btn_clear_", p_prefix), "Leeren", class = "btn btn-xs btn-outline-danger flex-fill", style = "font-size: 0.75rem; padding: 2px 4px;", title = "Portfolio leeren")
      ),
      
      # ETF Liste mit Stepper Buttons [-] / [+]
      if (is.null(current_weights) || length(current_weights) == 0) {
        div(
          class = "alert alert-light border text-center py-2 text-muted small my-2",
          "Keine ETFs enthalten."
        )
      } else {
        div(
          style = "max-height: 620px; overflow-y: auto; padding-right: 2px;",
          lapply(current_etfs, function(ric) {
            clean_ric <- gsub("[^A-Za-z0-9]", "_", ric)
            meta <- get_meta(ric)
            w_val <- current_weights[[ric]]
            if (is.null(w_val) || is.na(w_val)) w_val <- 0
            
            btn_dec_id <- paste0("sb_dec_", p_prefix, "_", clean_ric)
            btn_inc_id <- paste0("sb_inc_", p_prefix, "_", clean_ric)
            del_btn_id <- paste0("sb_del_", p_prefix, "_", clean_ric)
            
            asset_badge <- if (meta$asset_type == "Bonds") {
              span(class = "badge bg-teal-subtle text-teal border ms-1", style = "background-color:#E6FFFA;color:#0D9488;border-color:#5EEAD4;font-size:0.65rem;padding:2px 4px;", "B")
            } else if (meta$asset_type == "Real Estate") {
              span(class = "badge ms-1", style = "background-color:#FDF2F0;color:#8C564B;border:1px solid #F5C6CB;font-size:0.65rem;padding:2px 4px;", "RE")
            } else if (meta$asset_type == "Cash") {
              span(class = "badge ms-1", style = "background-color:#F0FDF4;color:#16A34A;border:1px solid #BBF7D0;font-size:0.65rem;padding:2px 4px;", "C")
            } else if (meta$asset_type == "Rohstoffe") {
              span(class = "badge ms-1", style = "background-color:#FFFBEB;color:#D97706;border:1px solid #FDE68A;font-size:0.65rem;padding:2px 4px;", "ROH")
            } else {
              span(class = "badge bg-primary-subtle text-primary border ms-1", style = "background-color:#EFF6FF;color:#1E40AF;border-color:#BFDBFE;font-size:0.65rem;padding:2px 4px;", "A")
            }
            
            div(
              class = "sidebar-etf-row",
              div(
                class = "d-flex justify-content-between align-items-center mb-1",
                div(
                  tags$span(class = "fw-semibold text-dark", style = "font-size: 0.82rem;", meta$label),
                  asset_badge
                ),
                actionButton(
                  inputId = del_btn_id,
                  label = "×",
                  class = "btn btn-outline-danger btn-sm p-0 px-1 border-0 fw-bold",
                  style = "line-height: 1; font-size: 1rem;",
                  title = "ETF entfernen"
                )
              ),
              div(
                class = "d-flex align-items-center justify-content-between",
                actionButton(
                  inputId = btn_dec_id,
                  label = "-",
                  class = "btn btn-outline-secondary btn-sm px-2 py-0 fw-bold",
                  style = "font-size: 0.85rem; height: 26px; line-height: 1;"
                ),
                span(
                  class = "badge bg-light text-dark border px-2 py-1 font-monospace fw-bold",
                  style = "font-size: 0.85rem; min-width: 65px; text-align: center;",
                  sprintf("%.1f%%", w_val)
                ),
                actionButton(
                  inputId = btn_inc_id,
                  label = "+",
                  class = "btn btn-outline-primary btn-sm px-2 py-0 fw-bold",
                  style = "font-size: 0.85rem; height: 26px; line-height: 1;"
                )
              )
            )
          })
        )
      },
      
      # ETF Hinzufügen Sektion
      hr(class = "my-2"),
      if (!is.null(choices_vec)) {
        div(
          class = "d-flex gap-1 align-items-center",
          div(
            style = "flex: 1;",
            selectInput(
              inputId = paste0("sel_add_", p_prefix),
              label = NULL,
              choices = choices_vec,
              width = "100%"
            )
          ),
          actionButton(
            inputId = paste0("btn_add_", p_prefix),
            label = "+",
            class = "btn btn-sm btn-primary px-2 fw-bold",
            title = "ETF hinzufügen"
          )
        )
      } else {
        div(class = "text-muted small fst-italic text-center py-1", "Alle ETFs bereits im Portfolio.")
      }
    )
  })
  
  # ----------------------------------------------------------------------------
  # OBSERVER FÜR SIDEBAR BUTTONS (EINMAL REGISTRIEREN BEIM LADEN)
  # ----------------------------------------------------------------------------
  
  lapply(1:3, function(p_idx) {
    p_key <- paste0("portfolio_", p_idx)
    p_prefix <- paste0("sb_p", p_idx)
    
    # Enabled Observer
    observeEvent(input[[paste0(p_prefix, "_enabled")]], {
      val <- input[[paste0(p_prefix, "_enabled")]]
      if (!is.null(val)) {
        current <- isolate(portfolios_state())
        if (!is.null(current) && isTRUE(current[[p_key]]$enabled) != isTRUE(val)) {
          current[[p_key]]$enabled <- isTRUE(val)
          portfolios_state(current)
          save_portfolios(current, "saved_portfolios.json")
          save_status_reactive(paste0("Auto-Save: ", format(Sys.time(), "%H:%M:%S")))
        }
      }
    }, ignoreInit = TRUE)
    
    # Add ETF Observer
    observeEvent(input[[paste0("btn_add_", p_prefix)]], {
      sel_ric <- input[[paste0("sel_add_", p_prefix)]]
      if (!is.null(sel_ric) && sel_ric != "") {
        current <- isolate(portfolios_state())
        if (is.null(current[[p_key]]$weights)) current[[p_key]]$weights <- list()
        
        current_sum <- sum(unlist(current[[p_key]]$weights), na.rm = TRUE)
        default_w <- if (current_sum < 100) round(100 - current_sum, 1) else 10
        current[[p_key]]$weights[[sel_ric]] <- default_w
        
        portfolios_state(current)
        save_portfolios(current, "saved_portfolios.json")
        save_status_reactive(paste0("Auto-Save: ", format(Sys.time(), "%H:%M:%S")))
      }
    }, ignoreInit = TRUE)
    
    # Normalisieren & Gleichgewichtung & Leeren
    observeEvent(input[[paste0("btn_norm_", p_prefix)]], {
      current <- isolate(portfolios_state())
      w <- unlist(current[[p_key]]$weights)
      if (length(w) > 0 && sum(w) > 0) {
        w_norm <- round((w / sum(w)) * 100, 1)
        diff <- 100 - sum(w_norm)
        w_norm[1] <- w_norm[1] + diff
        current[[p_key]]$weights <- as.list(w_norm)
        portfolios_state(current)
        save_portfolios(current, "saved_portfolios.json")
        save_status_reactive(paste0("Auto-Save: ", format(Sys.time(), "%H:%M:%S")))
      }
    }, ignoreInit = TRUE)
    
    observeEvent(input[[paste0("btn_eq_", p_prefix)]], {
      current <- isolate(portfolios_state())
      w_keys <- names(current[[p_key]]$weights)
      n <- length(w_keys)
      if (n > 0) {
        eq_val <- round(100 / n, 1)
        w_new <- as.list(rep(eq_val, n))
        names(w_new) <- w_keys
        sum_w <- sum(unlist(w_new))
        if (sum_w != 100) w_new[[1]] <- w_new[[1]] + (100 - sum_w)
        current[[p_key]]$weights <- w_new
        portfolios_state(current)
        save_portfolios(current, "saved_portfolios.json")
        save_status_reactive(paste0("Auto-Save: ", format(Sys.time(), "%H:%M:%S")))
      }
    }, ignoreInit = TRUE)
    
    observeEvent(input[[paste0("btn_clear_", p_prefix)]], {
      current <- isolate(portfolios_state())
      current[[p_key]]$weights <- list()
      portfolios_state(current)
      save_portfolios(current, "saved_portfolios.json")
      save_status_reactive(paste0("Auto-Save: ", format(Sys.time(), "%H:%M:%S")))
    }, ignoreInit = TRUE)
  })
  
  # Observer-Registrierung für alle ETFs genau EINMAL beim Laden der Daten
  observeEvent(raw_data_reactive(), {
    d <- raw_data_reactive()
    req(d)
    all_rics <- d$available_etfs
    
    # 1. Sidebar Stepper [-], [+] und Lösch-Buttons
    lapply(1:3, function(p_idx) {
      p_key <- paste0("portfolio_", p_idx)
      p_prefix <- paste0("sb_p", p_idx)
      
      for (ric in all_rics) {
        local({
          r <- ric
          clean_r <- gsub("[^A-Za-z0-9]", "_", r)
          btn_dec_id <- paste0("sb_dec_", p_prefix, "_", clean_r)
          btn_inc_id <- paste0("sb_inc_", p_prefix, "_", clean_r)
          del_btn_id <- paste0("sb_del_", p_prefix, "_", clean_r)
          
          # [-] Stepper: präzise -0.5
          observeEvent(input[[btn_dec_id]], {
            current <- isolate(portfolios_state())
            if (!is.null(current) && !is.null(current[[p_key]]$weights[[r]])) {
              w_curr <- as.numeric(current[[p_key]]$weights[[r]])
              w_new <- max(0, round(w_curr - 0.5, 1))
              current[[p_key]]$weights[[r]] <- w_new
              portfolios_state(current)
              save_portfolios(current, "saved_portfolios.json")
              save_status_reactive(paste0("Auto-Save: ", format(Sys.time(), "%H:%M:%S")))
            }
          }, ignoreInit = TRUE)
          
          # [+] Stepper: präzise +0.5
          observeEvent(input[[btn_inc_id]], {
            current <- isolate(portfolios_state())
            if (!is.null(current) && !is.null(current[[p_key]]$weights[[r]])) {
              w_curr <- as.numeric(current[[p_key]]$weights[[r]])
              w_new <- min(100, round(w_curr + 0.5, 1))
              current[[p_key]]$weights[[r]] <- w_new
              portfolios_state(current)
              save_portfolios(current, "saved_portfolios.json")
              save_status_reactive(paste0("Auto-Save: ", format(Sys.time(), "%H:%M:%S")))
            }
          }, ignoreInit = TRUE)
          
          # Löschen Button in Sidebar
          observeEvent(input[[del_btn_id]], {
            current <- isolate(portfolios_state())
            if (!is.null(current) && !is.null(current[[p_key]]$weights[[r]])) {
              current[[p_key]]$weights[[r]] <- NULL
              portfolios_state(current)
              save_portfolios(current, "saved_portfolios.json")
              save_status_reactive(paste0("Auto-Save: ", format(Sys.time(), "%H:%M:%S")))
            }
          }, ignoreInit = TRUE)
        })
      }
    })
    
    # 2. Tab 6 Editor Observers (Numeric Inputs & Delete Buttons)
    lapply(1:3, function(p_idx) {
      p_key <- paste0("portfolio_", p_idx)
      p_prefix <- paste0("p", p_idx)
      
      for (ric in all_rics) {
        local({
          r <- ric
          clean_r <- gsub("[^A-Za-z0-9]", "_", r)
          del_id <- paste0("del_tab_", p_prefix, "_", clean_r)
          input_id <- paste0("w_tab_", p_prefix, "_", clean_r)
          
          observeEvent(input[[del_id]], {
            current <- isolate(portfolios_state())
            if (!is.null(current) && !is.null(current[[p_key]]$weights[[r]])) {
              current[[p_key]]$weights[[r]] <- NULL
              portfolios_state(current)
              save_portfolios(current, "saved_portfolios.json")
              save_status_reactive(paste0("Auto-Save: ", format(Sys.time(), "%H:%M:%S")))
            }
          }, ignoreInit = TRUE)
          
          observeEvent(input[[input_id]], {
            val <- input[[input_id]]
            if (!is.null(val) && !is.na(val)) {
              current <- isolate(portfolios_state())
              if (!is.null(current) && !is.null(current[[p_key]]$weights) && (r %in% names(current[[p_key]]$weights))) {
                if (as.numeric(current[[p_key]]$weights[[r]]) != as.numeric(val)) {
                  current[[p_key]]$weights[[r]] <- as.numeric(val)
                  portfolios_state(current)
                  save_portfolios(current, "saved_portfolios.json")
                  save_status_reactive(paste0("Auto-Save: ", format(Sys.time(), "%H:%M:%S")))
                }
              }
            }
          }, ignoreInit = TRUE)
        })
      }
    })
  })
  
  # ----------------------------------------------------------------------------
  # TAB 6: PORTFOLIO-EDITOR RENDERING & OBSERVER
  # ----------------------------------------------------------------------------
  
  lapply(1:3, function(p_idx) {
    p_key <- paste0("portfolio_", p_idx)
    p_prefix <- paste0("p", p_idx)
    
    output[[paste0(p_prefix, "_sum_badge_tab")]] <- renderUI({
      req(portfolios_state())
      p_conf <- portfolios_state()[[p_key]]
      weights <- unlist(p_conf$weights)
      if (length(weights) == 0) return(span(class = "badge bg-light text-muted border small", "Leer"))
      s <- sum(weights, na.rm = TRUE)
      badge_class <- if (abs(s - 100) < 0.01) "bg-light text-dark border fw-bold" else "bg-warning text-dark fw-bold"
      span(class = paste("badge rounded-pill weight-pill", badge_class), sprintf("Summe: %.1f%%", s))
    })
    
    output[[paste0("ui_", p_prefix, "_etf_list_tab")]] <- renderUI({
      req(raw_data_reactive(), portfolios_state())
      d <- raw_data_reactive()
      p_conf <- portfolios_state()[[p_key]]
      current_weights <- p_conf$weights
      
      if (is.null(current_weights) || length(current_weights) == 0) {
        return(div(class = "alert alert-light border text-center py-3 text-muted small my-2", "Dieses Portfolio ist aktuell leer."))
      }
      
      get_meta <- function(ric) {
        m <- d$ticker_df %>% dplyr::filter(ric == !!ric)
        if (nrow(m) > 0) list(label = m$label[1], region = m$region[1], asset_type = m$asset_type[1]) else list(label = ric, region = "Global", asset_type = "Aktien")
      }
      
      etf_keys <- names(current_weights)
      tagList(
        lapply(etf_keys, function(ric) {
          clean_ric <- gsub("[^A-Za-z0-9]", "_", ric)
          meta <- get_meta(ric)
          w_val <- current_weights[[ric]]
          if (is.null(w_val) || is.na(w_val)) w_val <- 0
          
          input_id <- paste0("w_tab_", p_prefix, "_", clean_ric)
          del_btn_id <- paste0("del_tab_", p_prefix, "_", clean_ric)
          
          asset_badge <- if (meta$asset_type == "Bonds") {
            span(class = "badge bg-teal-subtle text-teal border ms-1 small", style = "background-color:#E6FFFA;color:#0D9488;border-color:#5EEAD4;", "Bonds")
          } else if (meta$asset_type == "Real Estate") {
            span(class = "badge ms-1 small", style = "background-color:#FDF2F0;color:#8C564B;border:1px solid #F5C6CB;", "Real Estate")
          } else if (meta$asset_type == "Cash") {
            span(class = "badge ms-1 small", style = "background-color:#F0FDF4;color:#16A34A;border:1px solid #BBF7D0;", "Cash")
          } else if (meta$asset_type == "Rohstoffe") {
            span(class = "badge ms-1 small", style = "background-color:#FFFBEB;color:#D97706;border:1px solid #FDE68A;", "Rohstoffe")
          } else {
            span(class = "badge bg-primary-subtle text-primary border ms-1 small", style = "background-color:#EFF6FF;color:#1E40AF;border-color:#BFDBFE;", "Aktien")
          }
          
          div(
            class = "etf-item-box",
            div(
              class = "d-flex justify-content-between align-items-center mb-1",
              div(
                tags$strong(class = "text-dark", meta$label),
                span(class = "badge bg-light text-secondary border ms-1 small", ric),
                asset_badge
              ),
              actionButton(del_btn_id, label = NULL, icon = icon("trash"), class = "btn btn-outline-danger btn-sm p-1 px-2 border-0", title = "Entfernen")
            ),
            div(
              class = "input-group input-group-sm mt-1",
              span(class = "input-group-text bg-light small", "Gewicht (%):"),
              numericInput(input_id, label = NULL, value = w_val, min = 0, max = 100, step = 0.5, width = "100%")
            )
          )
        })
      )
    })
    
    output[[paste0("ui_", p_prefix, "_add_section_tab")]] <- renderUI({
      req(raw_data_reactive(), portfolios_state())
      d <- raw_data_reactive()
      p_conf <- portfolios_state()[[p_key]]
      current_etfs <- names(p_conf$weights)
      unassigned <- d$ticker_df %>% dplyr::filter(!(ric %in% current_etfs))
      
      if (nrow(unassigned) == 0) return(div(class = "text-muted small text-center py-1 fst-italic", "Alle ETFs bereits enthalten."))
      
      choices_vec <- setNames(unassigned$ric, paste0(unassigned$label, " (", unassigned$ric, " - ", unassigned$asset_type, ")"))
      
      div(
        class = "d-flex gap-2 align-items-center",
        div(style = "flex: 1;", selectInput(paste0("sel_add_tab_", p_prefix), label = NULL, choices = choices_vec, width = "100%")),
        actionButton(paste0("btn_add_tab_", p_prefix), label = "Hinzufügen", icon = icon("plus"), class = "btn btn-sm btn-primary text-nowrap")
      )
    })
    
    # Tab 6 Name Observers
    observeEvent(input[[paste0("p", p_idx, "_name_tab")]], {
      val <- input[[paste0("p", p_idx, "_name_tab")]]
      if (!is.null(val) && val != "") {
        current <- isolate(portfolios_state())
        if (!is.null(current) && current[[p_key]]$name != val) {
          current[[p_key]]$name <- val
          portfolios_state(current)
        }
      }
    }, ignoreInit = TRUE)
    
    # Tab 6 Enabled Observers
    if (p_idx > 1) {
      observeEvent(input[[paste0("p", p_idx, "_enabled_tab")]], {
        val <- input[[paste0("p", p_idx, "_enabled_tab")]]
        if (!is.null(val)) {
          current <- isolate(portfolios_state())
          if (!is.null(current) && isTRUE(current[[p_key]]$enabled) != isTRUE(val)) {
            current[[p_key]]$enabled <- isTRUE(val)
            portfolios_state(current)
          }
        }
      }, ignoreInit = TRUE)
    }
    
    # Tab 6 Add ETF Observer
    observeEvent(input[[paste0("btn_add_tab_", p_prefix)]], {
      sel_ric <- input[[paste0("sel_add_tab_", p_prefix)]]
      if (!is.null(sel_ric) && sel_ric != "") {
        current <- isolate(portfolios_state())
        if (is.null(current[[p_key]]$weights)) current[[p_key]]$weights <- list()
        current_sum <- sum(unlist(current[[p_key]]$weights), na.rm = TRUE)
        default_w <- if (current_sum < 100) round(100 - current_sum, 1) else 10
        current[[p_key]]$weights[[sel_ric]] <- default_w
        portfolios_state(current)
        save_portfolios(current, "saved_portfolios.json")
        save_status_reactive(paste0("Auto-Save: ", format(Sys.time(), "%H:%M:%S")))
      }
    }, ignoreInit = TRUE)
  })
  
  observeEvent(input$btn_p1_norm_tab, normalize_portfolio("portfolio_1"))
  observeEvent(input$btn_p2_norm_tab, normalize_portfolio("portfolio_2"))
  observeEvent(input$btn_p3_norm_tab, normalize_portfolio("portfolio_3"))
  
  observeEvent(input$btn_p1_eq_tab, equal_weight_portfolio("portfolio_1"))
  observeEvent(input$btn_p2_eq_tab, equal_weight_portfolio("portfolio_2"))
  observeEvent(input$btn_p3_eq_tab, equal_weight_portfolio("portfolio_3"))
  
  normalize_portfolio <- function(p_key) {
    current <- isolate(portfolios_state())
    w <- unlist(current[[p_key]]$weights)
    if (length(w) > 0 && sum(w) > 0) {
      w_norm <- round((w / sum(w)) * 100, 1)
      diff <- 100 - sum(w_norm)
      w_norm[1] <- w_norm[1] + diff
      current[[p_key]]$weights <- as.list(w_norm)
      portfolios_state(current)
      save_portfolios(current, "saved_portfolios.json")
      save_status_reactive(paste0("Auto-Save: ", format(Sys.time(), "%H:%M:%S")))
    }
  }
  
  equal_weight_portfolio <- function(p_key) {
    current <- isolate(portfolios_state())
    w_keys <- names(current[[p_key]]$weights)
    n <- length(w_keys)
    if (n > 0) {
      eq_val <- round(100 / n, 1)
      w_new <- as.list(rep(eq_val, n))
      names(w_new) <- w_keys
      sum_w <- sum(unlist(w_new))
      if (sum_w != 100) w_new[[1]] <- w_new[[1]] + (100 - sum_w)
      current[[p_key]]$weights <- w_new
      portfolios_state(current)
      save_portfolios(current, "saved_portfolios.json")
      save_status_reactive(paste0("Auto-Save: ", format(Sys.time(), "%H:%M:%S")))
    }
  }
  
  # Global Save & Reset Buttons in Sidebar & Tab
  save_handler <- function() {
    ports <- isolate(portfolios_state())
    success <- save_portfolios(ports, "saved_portfolios.json")
    if (success) {
      save_status_reactive(paste0("Gespeichert um ", format(Sys.time(), "%H:%M:%S")))
      showNotification("Portfoliokonfiguration dauerhaft gespeichert!", type = "message", duration = 3)
    } else {
      showNotification("Fehler beim Speichern der Portfolios!", type = "error")
    }
  }
  
  observeEvent(input$sidebar_btn_save, save_handler())
  observeEvent(input$btn_tab_save_config, save_handler())
  
  reset_handler <- function() {
    req(raw_data_reactive())
    d <- raw_data_reactive()
    defaults <- get_default_portfolios(d$available_etfs, d$ticker_df)
    portfolios_state(defaults)
    save_portfolios(defaults, "saved_portfolios.json")
    save_status_reactive(paste0("Standardwerte: ", format(Sys.time(), "%H:%M:%S")))
    showNotification("Portfolios auf Standardwerte zurückgesetzt.", type = "warning", duration = 4)
  }
  
  observeEvent(input$sidebar_btn_reset, reset_handler())
  observeEvent(input$btn_tab_reset_config, reset_handler())
  
  output$opt_normalize_toggle <- renderUI({
    shinyWidgets::materialSwitch(
      inputId = "opt_normalize",
      label = span(class = "small fw-semibold text-secondary", "100% Look-Through Skalierung"),
      value = TRUE,
      status = "primary",
      inline = TRUE
    )
  })
  
  # Navigation Links
  observeEvent(input$btn_go_config, { updateNavbarPage(session, "main_nav", selected = "tab_config") })
  observeEvent(input$link_to_allocation, { updateNavbarPage(session, "main_nav", selected = "tab_allocation") })
  observeEvent(input$link_to_sectors, { updateNavbarPage(session, "main_nav", selected = "tab_sectors") })
  observeEvent(input$link_to_holdings, { updateNavbarPage(session, "main_nav", selected = "tab_holdings") })
  observeEvent(input$link_to_concentration, { updateNavbarPage(session, "main_nav", selected = "tab_concentration") })
  
  # ----------------------------------------------------------------------------
  # REAKTIVE BERECHNUNGEN (SYNCHRON IN ECHTZEIT)
  # ----------------------------------------------------------------------------
  
  calculated_results <- reactive({
    req(raw_data_reactive(), portfolios_state())
    ports <- portfolios_state()
    clean_d <- raw_data_reactive()$data_clean
    use_norm <- isTRUE(input$opt_normalize)
    
    calculate_all_portfolios(ports, clean_d, use_normalized_etf_weights = use_norm)
  })
  
  active_portfolio_keys <- reactive({
    req(portfolios_state())
    ports <- portfolios_state()
    keys <- "portfolio_1"
    if (isTRUE(ports$portfolio_2$enabled)) keys <- c(keys, "portfolio_2")
    if (isTRUE(ports$portfolio_3$enabled)) keys <- c(keys, "portfolio_3")
    keys
  })
  
  portfolio_names_map <- reactive({
    req(portfolios_state())
    ports <- portfolios_state()
    list(
      portfolio_1 = if (!is.null(ports$portfolio_1$name)) ports$portfolio_1$name else "Portfolio 1",
      portfolio_2 = if (!is.null(ports$portfolio_2$name)) ports$portfolio_2$name else "Portfolio 2",
      portfolio_3 = if (!is.null(ports$portfolio_3$name)) ports$portfolio_3$name else "Portfolio 3"
    )
  })
  
  asset_currency_metrics_results <- reactive({
    req(calculated_results(), raw_data_env$ticker_df)
    calculate_portfolio_asset_and_currency_metrics(
      calculated_portfolios = calculated_results(),
      ticker_df = raw_data_env$ticker_df,
      corr_matrix = raw_data_env$corr_matrix,
      raw_portfolios = portfolios_state()
    )
  })
  
  sector_results <- reactive({
    req(calculated_results())
    calculate_sector_comparison(calculated_results())
  })
  
  top_holdings_results <- reactive({
    req(calculated_results())
    calculate_top_holdings(calculated_results(), top_n = 20)
  })
  
  concentration_metrics_results <- reactive({
    req(calculated_results())
    calculate_concentration_metrics(calculated_results())
  })
  
  lorenz_results <- reactive({
    req(calculated_results())
    calculate_lorenz_curves(calculated_results())
  })
  
  # ----------------------------------------------------------------------------
  # TAB 1: DASHBOARD OUTPUTS
  # ----------------------------------------------------------------------------
  
  output$ui_kpi_value_boxes <- renderUI({
    req(concentration_metrics_results(), asset_currency_metrics_results(), portfolio_names_map())
    conc_metrics <- concentration_metrics_results()
    ac_metrics <- asset_currency_metrics_results()$summary_metrics
    active_keys <- active_portfolio_keys()
    
    cols <- lapply(active_keys, function(p_key) {
      cm <- conc_metrics %>% dplyr::filter(portfolio_key == p_key)
      am <- ac_metrics %>% dplyr::filter(portfolio_key == p_key)
      if (nrow(am) == 0 || !am$is_active) return(NULL)
      
      bg_style <- switch(
        p_key,
        "portfolio_1" = "background: linear-gradient(135deg, #1E40AF10, #FFFFFF); border-left: 4px solid #1E40AF;",
        "portfolio_2" = "background: linear-gradient(135deg, #0D948810, #FFFFFF); border-left: 4px solid #0D9488;",
        "portfolio_3" = "background: linear-gradient(135deg, #E11D4810, #FFFFFF); border-left: 4px solid #E11D48;"
      )
      
      is_empty_port <- (am$total_weight == 0)
      
      div(
        class = "card p-3 mb-3",
        style = bg_style,
        div(
          class = "d-flex justify-content-between align-items-center mb-2",
          h6(class = "fw-bold mb-0 text-dark", am$portfolio_name),
          if (is_empty_port) {
            span(class = "badge bg-light text-muted border", "Leer")
          } else {
            div(
              span(class = "badge bg-primary text-white me-1", sprintf("%.0f%% Aktien", am$equity_weight_pct)),
              if (am$bond_weight_pct > 0) span(class = "badge text-white me-1", style = "background-color:#0D9488;", sprintf("%.0f%% Bonds", am$bond_weight_pct)),
              if (isTRUE(am$real_estate_weight_pct > 0)) span(class = "badge text-white me-1", style = "background-color:#8C564B;", sprintf("%.0f%% RE", am$real_estate_weight_pct)),
              if (isTRUE(am$commodity_weight_pct > 0)) span(class = "badge me-1", style = "background-color:#FFFBEB;color:#D97706;border:1px solid #FDE68A;", sprintf("%.0f%% Rohstoffe", am$commodity_weight_pct)),
              if (isTRUE(am$cash_weight_pct > 0)) span(class = "badge me-1", style = "background-color:#F0FDF4;color:#16A34A;border:1px solid #BBF7D0;", sprintf("%.0f%% Cash", am$cash_weight_pct))
            )
          }
        ),
        if (is_empty_port) {
          div(class = "text-center text-muted small py-2", "Keine ETFs / Positionen zugewiesen.")
        } else {
          div(
            class = "row g-2 align-items-stretch",
            
            # 1. Links: Portfolio-Kennzahlen (1 Spalte, 3 Zeilen)
            div(
              class = "col-12 col-md-3",
              div(
                class = "card h-100 p-2 mb-0 shadow-sm border-primary-subtle d-flex flex-column justify-content-between bg-white",
                div(
                  class = "d-flex justify-content-between align-items-center py-1 border-bottom",
                  span(class = "small fw-semibold text-primary", "Erw. Rendite:"),
                  span(class = "fw-bold text-primary font-monospace", if (is.na(am$expected_return)) "-" else sprintf("%.2f%%", am$expected_return))
                ),
                div(
                  class = "d-flex justify-content-between align-items-center py-1 border-bottom",
                  span(class = "small fw-semibold text-muted", "Erw. Vola:"),
                  span(class = "fw-bold text-dark font-monospace", if (is.na(am$expected_vol)) "-" else sprintf("%.2f%%", am$expected_vol))
                ),
                div(
                  class = "d-flex justify-content-between align-items-center py-1",
                  span(class = "small fw-semibold text-success", "Sharpe Ratio:"),
                  span(class = "fw-bold text-success font-monospace", if (is.na(am$sharpe_ratio)) "-" else sprintf("%.2f", am$sharpe_ratio))
                )
              )
            ),
            
            # 2. Asset-Allokation (2x2 Block)
            div(
              class = "col-12 col-md-3",
              div(
                class = "card h-100 p-2 mb-0 shadow-sm bg-white",
                div(
                  class = "row g-1 h-100",
                  div(
                    class = "col-6",
                    div(class = "p-1 rounded bg-light border text-center h-100 d-flex flex-column justify-content-center",
                        div(class = "small text-muted", style = "font-size:0.7rem;font-weight:600;", "AKTIEN"),
                        div(class = "fw-bold text-primary", sprintf("%.1f%%", am$equity_weight_pct)))
                  ),
                  div(
                    class = "col-6",
                    div(class = "p-1 rounded border text-center h-100 d-flex flex-column justify-content-center", style = "background-color:#F0FDFA;",
                        div(class = "small", style = "font-size:0.7rem;font-weight:600;color:#0D9488;", "BONDS"),
                        div(class = "fw-bold", style = "color:#0D9488;", sprintf("%.1f%%", am$bond_weight_pct)))
                  ),
                  div(
                    class = "col-6",
                    div(class = "p-1 rounded border text-center h-100 d-flex flex-column justify-content-center", style = "background-color:#FDF2F0;",
                        div(class = "small", style = "font-size:0.7rem;font-weight:600;color:#8C564B;", "REAL ESTATE"),
                        div(class = "fw-bold", style = "color:#8C564B;", sprintf("%.1f%%", am$real_estate_weight_pct %||% 0)))
                  ),
                  div(
                    class = "col-6",
                    div(class = "p-1 rounded border text-center h-100 d-flex flex-column justify-content-center", style = "background-color:#FFFBEB;",
                        div(class = "small", style = "font-size:0.7rem;font-weight:600;color:#D97706;", "ROHSTOFFE"),
                        div(class = "fw-bold", style = "color:#D97706;", sprintf("%.1f%%", am$commodity_weight_pct %||% 0)))
                  )
                )
              )
            ),
            
            # 3. Bewertung & Anleihen (2x2 Block)
            div(
              class = "col-12 col-md-4",
              div(
                class = "card h-100 p-2 mb-0 shadow-sm bg-white",
                div(
                  class = "row g-1 h-100",
                  div(
                    class = "col-6",
                    div(class = "p-1 rounded bg-light border text-center h-100 d-flex flex-column justify-content-center",
                        div(class = "small text-muted", style = "font-size:0.7rem;font-weight:600;", "DIV. YIELD"),
                        div(class = "fw-bold text-success", if (is.na(am$equity_weighted_div_yield)) "-" else sprintf("%.2f%%", am$equity_weighted_div_yield)))
                  ),
                  div(
                    class = "col-6",
                    div(class = "p-1 rounded bg-light border text-center h-100 d-flex flex-column justify-content-center",
                        div(class = "small text-muted", style = "font-size:0.7rem;font-weight:600;", "KGV (P/E)"),
                        div(class = "fw-bold text-dark", if (is.na(am$equity_weighted_pe) || am$equity_weighted_pe <= 0) "-" else sprintf("%.1fx", am$equity_weighted_pe)))
                  ),
                  div(
                    class = "col-6",
                    div(class = "p-1 rounded border text-center h-100 d-flex flex-column justify-content-center", style = "background-color:#F0FDFA;",
                        div(class = "small text-muted", style = "font-size:0.7rem;font-weight:600;", "YTM (BONDS)"),
                        div(class = "fw-bold", style = "color:#0D9488;", if (is.na(am$bond_weighted_ytm)) "-" else sprintf("%.2f%%", am$bond_weighted_ytm)))
                  ),
                  div(
                    class = "col-6",
                    div(class = "p-1 rounded border text-center h-100 d-flex flex-column justify-content-center", style = "background-color:#F0FDF4;",
                        div(class = "small text-muted", style = "font-size:0.7rem;font-weight:600;", "DURATION"),
                        div(class = "fw-bold", style = "color:#16A34A;", if (is.na(am$bond_weighted_mod_duration)) "-" else sprintf("%.2f J.", am$bond_weighted_mod_duration)))
                  )
                )
              )
            ),
            
            # 4. Rechts: N_eff
            div(
              class = "col-12 col-md-2",
              div(
                class = "card h-100 p-2 mb-0 shadow-sm d-flex flex-column justify-content-center text-center bg-light",
                div(class = "small text-muted text-uppercase mb-1", style = "font-size:0.7rem;font-weight:600;", "N_eff (Holdings)"),
                div(class = "fs-4 fw-bold text-dark", if (nrow(cm) > 0 && cm$n_eff > 0) cm$n_eff else "-"),
                div(class = "small text-muted", style = "font-size:0.68rem;", "Effektive Titel")
              )
            )
          )
        }
      )
    })
    
    div(class = paste0("row row-cols-1 row-cols-md-", length(active_keys), " g-3 mb-2"), cols)
  })
  
  output$plot_dash_asset_delta <- renderPlotly({
    req(asset_currency_metrics_results(), portfolio_names_map(), input$dash_asset_delta_pair)
    create_asset_delta_chart(
      asset_currency_metrics_results()$asset_class_comparison,
      portfolio_names_map(),
      input$dash_asset_delta_pair
    )
  })
  
  output$table_dash_top10 <- renderReactable({
    req(top_holdings_results(), portfolio_names_map(), active_portfolio_keys())
    top_df <- top_holdings_results()$combined_top
    render_top_holdings_reactable(head(top_df, 10), portfolio_names_map(), active_portfolio_keys())
  })
  
  output$table_dash_multi_asset <- renderReactable({
    req(asset_currency_metrics_results(), portfolio_names_map(), active_portfolio_keys())
    summary_df <- asset_currency_metrics_results()$summary_metrics %>% dplyr::filter(is_active)
    if (nrow(summary_df) == 0) return(NULL)
    
    active_keys <- active_portfolio_keys()
    p_names <- portfolio_names_map()
    
    # Rows Definition
    metric_rows <- tibble::tribble(
      ~section, ~metric_label, ~key, ~type,
      "Asset-Allokation", "Aktien (%)", "equity_weight_pct", "pct",
      "Asset-Allokation", "Anleihen / Bonds (%)", "bond_weight_pct", "pct",
      "Asset-Allokation", "Real Estate (%)", "real_estate_weight_pct", "pct",
      "Asset-Allokation", "Rohstoffe (%)", "commodity_weight_pct", "pct",
      "Asset-Allokation", "Cash (%)", "cash_weight_pct", "pct",
      "Risk & Return", "Erw. Rendite (p.a.)", "expected_return", "pct2",
      "Risk & Return", "Erw. Volatilität (p.a.)", "expected_vol", "pct2",
      "Risk & Return", "Sharpe Ratio", "sharpe_ratio", "num2",
      "Aktien-Kennzahlen", "Dividendenrendite", "equity_weighted_div_yield", "pct2",
      "Aktien-Kennzahlen", "KGV (Harmonisch)", "equity_weighted_pe", "x1",
      "Aktien-Kennzahlen", "KBV (Harmonisch)", "equity_weighted_pb", "x2",
      "Anleihen-Kennzahlen", "Yield to Maturity (YTM)", "bond_weighted_ytm", "pct2",
      "Anleihen-Kennzahlen", "Mod. Duration", "bond_weighted_mod_duration", "years",
      "Anleihen-Kennzahlen", "Restlaufzeit", "bond_weighted_maturity_years", "years"
    )
    
    # Build columns for each active portfolio
    for (pk in active_keys) {
      row_match <- summary_df %>% dplyr::filter(portfolio_key == pk)
      col_vals <- sapply(seq_len(nrow(metric_rows)), function(i) {
        k <- metric_rows$key[i]
        t <- metric_rows$type[i]
        if (nrow(row_match) == 0 || !(k %in% names(row_match)) || is.na(row_match[[k]])) return("-")
        v <- row_match[[k]]
        switch(t,
          "pct" = sprintf("%.1f%%", v),
          "pct2" = sprintf("%.2f%%", v),
          "num2" = sprintf("%.2f", v),
          "x1" = sprintf("%.1fx", v),
          "x2" = sprintf("%.2fx", v),
          "years" = sprintf("%.2f J.", v),
          as.character(v)
        )
      })
      metric_rows[[pk]] <- col_vals
    }
    
    col_defs <- list(
      section = colDef(name = "Kategorie", minWidth = 150, style = list(fontWeight = 700, color = "#475569")),
      metric_label = colDef(name = "Kennzahl", minWidth = 190, style = list(fontWeight = 600)),
      key = colDef(show = FALSE),
      type = colDef(show = FALSE)
    )
    
    for (pk in active_keys) {
      p_name <- p_names[[pk]]
      col_defs[[pk]] <- colDef(
        name = p_name,
        align = "right",
        minWidth = 130,
        style = function(value, index) {
          k <- metric_rows$key[index]
          if (k == "expected_return") {
            list(fontWeight = 700, color = "#1E40AF", backgroundColor = "#EFF6FF")
          } else if (k == "expected_vol") {
            list(fontWeight = 600, color = "#1E293B", backgroundColor = "#F8FAFC")
          } else if (k == "sharpe_ratio") {
            list(fontWeight = 700, color = "#16A34A", backgroundColor = "#F0FDF4")
          } else {
            list(fontFamily = "monospace")
          }
        }
      )
    }
    
    reactable(
      metric_rows,
      groupBy = "section",
      columns = col_defs,
      bordered = FALSE,
      striped = TRUE,
      highlight = TRUE,
      pagination = FALSE,
      defaultExpanded = TRUE
    )
  })
  
  # ----------------------------------------------------------------------------
  # TAB 2: ALLOKATION & WÄHRUNGEN OUTPUTS
  # ----------------------------------------------------------------------------
  
  output$plot_asset_allocation <- renderPlotly({
    req(asset_currency_metrics_results(), portfolio_names_map(), active_portfolio_keys())
    create_asset_allocation_chart(asset_currency_metrics_results()$summary_metrics, portfolio_names_map(), active_portfolio_keys())
  })
  
  output$plot_overall_currency <- renderPlotly({
    req(asset_currency_metrics_results(), portfolio_names_map(), active_portfolio_keys())
    create_currency_breakdown_chart(
      asset_currency_metrics_results()$overall_currency_compare,
      portfolio_names_map(),
      active_portfolio_keys(),
      top_n = 8,
      x_axis_title = "Gewicht im Portfolio (%)"
    )
  })
  
  output$ui_equity_kpi_card <- renderUI({
    req(asset_currency_metrics_results(), active_portfolio_keys())
    am <- asset_currency_metrics_results()$summary_metrics %>% dplyr::filter(portfolio_key %in% active_portfolio_keys() & is_active)
    
    div(
      class = "row g-2",
      lapply(1:nrow(am), function(i) {
        row <- am[i, ]
        div(
          class = paste0("col-", 12 / nrow(am)),
          div(
            class = "metric-card-box bg-light",
            div(class = "small text-muted fw-semibold", row$portfolio_name),
            div(
              class = "d-flex justify-content-around my-1",
              div(
                div(class = "small text-muted", "Div. Yield"),
                div(class = "fs-6 fw-bold text-primary", if (is.na(row$equity_weighted_div_yield)) "-" else sprintf("%.2f%%", row$equity_weighted_div_yield))
              ),
              div(
                div(class = "small text-muted", "KGV (P/E)"),
                div(class = "fs-6 fw-bold text-primary", if (is.na(row$equity_weighted_pe) || row$equity_weighted_pe <= 0) "-" else sprintf("%.1fx", row$equity_weighted_pe))
              ),
              div(
                div(class = "small text-muted", "KBV (P/B)"),
                div(class = "fs-6 fw-bold text-secondary", if (is.na(row$equity_weighted_pb) || row$equity_weighted_pb <= 0) "-" else sprintf("%.2fx", row$equity_weighted_pb))
              )
            ),
            div(class = "small text-secondary", sprintf("Aktienanteil: %.0f%%", row$equity_weight_pct))
          )
        )
      })
    )
  })
  
  output$plot_equity_currency <- renderPlotly({
    req(asset_currency_metrics_results(), portfolio_names_map(), active_portfolio_keys())
    eq_df <- asset_currency_metrics_results()$equity_currency
    if (nrow(eq_df) == 0) return(plotly_empty(type = "scatter", mode = "markers"))
    
    p_names <- portfolio_names_map()
    active_keys <- active_portfolio_keys()
    
    all_currs <- unique(eq_df$currency)
    comp_df <- tibble(currency = all_currs)
    for (pk in active_keys) {
      sub_c <- eq_df %>% dplyr::filter(portfolio_key == pk)
      if (nrow(sub_c) > 0) {
        comp_df <- comp_df %>%
          dplyr::left_join(sub_c %>% dplyr::select(currency, pct_of_equity), by = "currency") %>%
          dplyr::mutate(pct_of_equity = ifelse(is.na(pct_of_equity), 0, pct_of_equity))
        names(comp_df)[names(comp_df) == "pct_of_equity"] <- paste0("weight_", pk)
      } else {
        comp_df[[paste0("weight_", pk)]] <- 0
      }
    }
    
    create_currency_breakdown_chart(comp_df, p_names, active_keys, top_n = 5, x_axis_title = "Anteil am Aktiensegment (%)")
  })
  
  output$ui_bond_kpi_card <- renderUI({
    req(asset_currency_metrics_results(), active_portfolio_keys())
    am <- asset_currency_metrics_results()$summary_metrics %>% dplyr::filter(portfolio_key %in% active_portfolio_keys() & is_active)
    
    div(
      class = "row g-2",
      lapply(1:nrow(am), function(i) {
        row <- am[i, ]
        div(
          class = paste0("col-", 12 / nrow(am)),
          div(
            class = "metric-card-box bg-light",
            div(class = "small text-muted fw-semibold", row$portfolio_name),
            div(
              class = "d-flex justify-content-around my-1",
              div(
                div(class = "small text-muted", "YTM"),
                div(class = "fs-5 fw-bold text-success", if (is.na(row$bond_weighted_ytm)) "-" else sprintf("%.2f%%", row$bond_weighted_ytm))
              ),
              div(
                div(class = "small text-muted", "Duration"),
                div(class = "fs-5 fw-bold text-secondary", if (is.na(row$bond_weighted_mod_duration)) "-" else sprintf("%.2f J.", row$bond_weighted_mod_duration))
              )
            ),
            div(class = "small text-secondary", sprintf("Anleihenanteil: %.0f%%", row$bond_weight_pct))
          )
        )
      })
    )
  })
  
  output$plot_bond_currency <- renderPlotly({
    req(asset_currency_metrics_results(), portfolio_names_map(), active_portfolio_keys())
    bd_df <- asset_currency_metrics_results()$bond_currency
    if (nrow(bd_df) == 0) return(plotly_empty(type = "scatter", mode = "markers"))
    
    p_names <- portfolio_names_map()
    active_keys <- active_portfolio_keys()
    
    all_currs <- unique(bd_df$currency)
    comp_df <- tibble(currency = all_currs)
    for (pk in active_keys) {
      sub_c <- bd_df %>% dplyr::filter(portfolio_key == pk)
      if (nrow(sub_c) > 0) {
        comp_df <- comp_df %>%
          dplyr::left_join(sub_c %>% dplyr::select(currency, pct_of_bonds), by = "currency") %>%
          dplyr::mutate(pct_of_bonds = ifelse(is.na(pct_of_bonds), 0, pct_of_bonds))
        names(comp_df)[names(comp_df) == "pct_of_bonds"] <- paste0("weight_", pk)
      } else {
        comp_df[[paste0("weight_", pk)]] <- 0
      }
    }
    
    create_currency_breakdown_chart(comp_df, p_names, active_keys, top_n = 5, x_axis_title = "Anteil am Anleihensegment (%)")
  })
  
  output$table_overall_currency_detail <- renderReactable({
    req(asset_currency_metrics_results(), portfolio_names_map(), active_portfolio_keys())
    curr_df <- asset_currency_metrics_results()$overall_currency_compare
    render_currency_reactable(curr_df, portfolio_names_map(), active_portfolio_keys())
  })
  
  output$table_equity_currency_detail <- renderReactable({
    req(asset_currency_metrics_results(), portfolio_names_map(), active_portfolio_keys())
    eq_curr_df <- asset_currency_metrics_results()$equity_currency
    render_equity_currency_reactable(eq_curr_df, portfolio_names_map(), active_portfolio_keys())
  })
  
  output$table_bond_currency_detail <- renderReactable({
    req(asset_currency_metrics_results(), portfolio_names_map(), active_portfolio_keys())
    bond_curr_df <- asset_currency_metrics_results()$bond_currency
    render_bond_currency_reactable(bond_curr_df, portfolio_names_map(), active_portfolio_keys())
  })

  # Anleihen Region x Issuer-Type Breakdown
  observe({
    req(portfolio_names_map(), active_portfolio_keys())
    active_keys <- active_portfolio_keys()
    p_names <- portfolio_names_map()
    choices_list <- stats::setNames(active_keys, sapply(active_keys, function(k) p_names[[k]]))
    cur_sel <- input$select_shiny_bond_breakdown_port
    if (is.null(cur_sel) || !cur_sel %in% active_keys) {
      cur_sel <- active_keys[1]
    }
    updateSelectInput(session, "select_shiny_bond_breakdown_port", choices = choices_list, selected = cur_sel)
  })
  
  bond_breakdown_res <- reactive({
    req(input$select_shiny_bond_breakdown_port, portfolios_state(), raw_data_env$clean_data, raw_data_env$ticker_df)
    calculate_bond_region_issuer_breakdown(
      portfolio_key = input$select_shiny_bond_breakdown_port,
      portfolios_list = portfolios_state(),
      clean_data = raw_data_env$clean_data,
      ticker_df = raw_data_env$ticker_df
    )
  })
  
  output$table_shiny_bond_region_issuer_breakdown <- renderReactable({
    req(bond_breakdown_res())
    render_bond_region_issuer_reactable(bond_breakdown_res())
  })
  
  output$ui_shiny_bond_fi_total_badge <- renderUI({
    req(bond_breakdown_res())
    res <- bond_breakdown_res()
    tot_fi <- if (!is.null(res$total_fi_weight)) res$total_fi_weight else 0
    span(
      class = "badge font-monospace",
      style = "background-color: #CCFBF1; color: #0F766E; font-size: 0.82rem;",
      sprintf("FI-Anteil am Portfolio: %.1f%%", tot_fi)
    )
  })

  
  # ----------------------------------------------------------------------------
  # TAB 3: SEKTOREN TAB OUTPUTS (AKTIEN)
  # ----------------------------------------------------------------------------
  
  output$plot_sector_pie <- renderPlotly({
    req(sector_results(), portfolio_names_map(), active_portfolio_keys())
    p_key <- active_portfolio_keys()[1]
    p_name <- portfolio_names_map()[[p_key]]
    create_sector_pie_chart(sector_results(), port_name = p_name, p_key = p_key)
  })

  output$plot_sector_bars <- renderPlotly({
    req(sector_results(), portfolio_names_map(), active_portfolio_keys())
    create_sector_comparison_chart(sector_results(), portfolio_names_map(), active_portfolio_keys())
  })
  
  output$plot_sector_delta <- renderPlotly({
    req(sector_results(), portfolio_names_map(), input$select_delta_pair)
    create_sector_delta_chart(sector_results(), portfolio_names_map(), input$select_delta_pair)
  })
  
  output$table_sectors_detail <- renderReactable({
    req(sector_results(), portfolio_names_map(), active_portfolio_keys())
    render_sector_reactable(sector_results(), portfolio_names_map(), active_portfolio_keys())
  })
  
  output$table_sector_drilldown <- renderReactable({
    req(calculated_results(), input$select_drilldown_sector, active_portfolio_keys(), portfolio_names_map())
    
    sec <- input$select_drilldown_sector
    calc_res <- calculated_results()
    p_names <- portfolio_names_map()
    active_keys <- active_portfolio_keys()
    
    drill_list <- list()
    for (p_key in active_keys) {
      p_res <- calc_res[[p_key]]
      if (isTRUE(p_res$enabled) && nrow(p_res$holdings) > 0) {
        all_equity <- p_res$holdings %>% dplyr::filter(asset_type == "Aktien")
        tot_eq_w <- sum(all_equity$portfolio_weight, na.rm = TRUE)
        
        sub_h <- all_equity %>%
          dplyr::filter(gics_sector == sec) %>%
          dplyr::mutate(
            equity_weight = if (tot_eq_w > 0) (portfolio_weight / tot_eq_w) * 100 else 0
          ) %>%
          dplyr::select(holding_ric, holding_name, equity_weight, etf_breakdown)
        
        names(sub_h)[names(sub_h) == "equity_weight"] <- paste0("w_", p_key)
        names(sub_h)[names(sub_h) == "etf_breakdown"] <- paste0("breakdown_", p_key)
        drill_list[[p_key]] <- sub_h
      }
    }
    
    if (length(drill_list) == 0) {
      return(div(class = "p-3 text-muted text-center", paste0("Keine Aktien-Holdings im Sektor '", sec, "' in den aktiven Portfolios.")))
    }
    
    combined_drill <- drill_list[[1]]
    if (length(drill_list) > 1) {
      for (i in 2:length(drill_list)) {
        combined_drill <- full_join(
          combined_drill,
          drill_list[[i]],
          by = c("holding_ric", "holding_name")
        )
      }
    }
    
    w_cols <- character()
    for (p_key in active_keys) {
      col <- paste0("w_", p_key)
      if (col %in% names(combined_drill)) {
        combined_drill[[col]][is.na(combined_drill[[col]])] <- 0
      } else {
        combined_drill[[col]] <- 0
      }
      w_cols <- c(w_cols, col)
    }
    
    w_mat <- as.matrix(combined_drill[, w_cols, drop = FALSE])
    w_mat[is.na(w_mat)] <- 0
    combined_drill$max_weight <- apply(w_mat, 1, max)
    combined_drill <- combined_drill %>% dplyr::arrange(desc(max_weight))
    
    max_drill_w <- max(combined_drill$max_weight, na.rm = TRUE)
    if (is.na(max_drill_w) || max_drill_w <= 0) max_drill_w <- 10
    
    col_defs <- list(
      holding_ric = colDef(name = "RIC", minWidth = 90, style = list(fontFamily = "monospace", fontWeight = 500)),
      holding_name = colDef(name = "Titel Name", minWidth = 220, style = list(fontWeight = 600)),
      max_weight = colDef(show = FALSE)
    )
    
    for (p_key in active_keys) {
      b_col <- paste0("breakdown_", p_key)
      if (b_col %in% names(combined_drill)) {
        col_defs[[b_col]] <- colDef(show = FALSE)
      }
    }
    
    for (p_key in active_keys) {
      col <- paste0("w_", p_key)
      p_name <- p_names[[p_key]]
      color <- PORTFOLIO_COLORS[[p_key]]
      
      col_defs[[col]] <- colDef(
        name = p_name,
        minWidth = 150,
        html = TRUE,
        cell = JS(sprintf("
          function(cellInfo) {
            var val = cellInfo.value;
            if (val === null || val === undefined || val === 0) {
              return '<span style=\"color: #9CA3AF; font-size: 0.85rem;\">0.00%%</span>';
            }
            var maxVal = %f;
            var widthPct = Math.min(100, Math.max(0, (val / maxVal) * 100));
            var formatted = val.toFixed(2) + '%%';
            return '<div style=\"display:flex;align-items:center;gap:8px;width:100%%;font-family:monospace;font-size:0.85rem;\">' +
                   '<div style=\"flex:1;background:#E5E7EB;border-radius:4px;height:14px;overflow:hidden;\">' +
                   '<div style=\"width:' + widthPct + '%%;background:%s;height:100%%;border-radius:4px;\"></div></div>' +
                   '<span style=\"min-width:52px;text-align:right;font-weight:500;\">' + formatted + '</span></div>';
          }
        ", max_drill_w, color))
      )
    }
    
    reactable(
      combined_drill,
      columns = col_defs,
      searchable = TRUE,
      striped = TRUE,
      highlight = TRUE,
      defaultPageSize = 15,
      showPageSizeOptions = TRUE,
      pageSizeOptions = c(10, 15, 25, 50, 100),
      theme = reactableTheme(
        borderColor = "#E5E7EB",
        stripedColor = "#F9FAFB",
        highlightColor = "#F3F4F6",
        searchInputStyle = list(width = "100%", padding = "6px 12px", borderRadius = "6px", border = "1px solid #D1D5DB"),
        cellPadding = "8px 12px",
        style = list(fontFamily = "inherit", fontSize = "0.9rem")
      )
    )
  })
  
  # ----------------------------------------------------------------------------
  # TAB 4: TOP HOLDINGS TAB OUTPUTS
  # ----------------------------------------------------------------------------
  
  output$plot_top20_bars <- renderPlotly({
    req(top_holdings_results(), portfolio_names_map(), active_portfolio_keys())
    create_top_holdings_chart(top_holdings_results()$combined_top, portfolio_names_map(), active_portfolio_keys(), top_n = 20)
  })
  
  output$table_top20_detail <- renderReactable({
    req(top_holdings_results(), portfolio_names_map(), active_portfolio_keys())
    render_top_holdings_reactable(top_holdings_results()$combined_top, portfolio_names_map(), active_portfolio_keys())
  })
  
  output$table_full_lookthrough <- renderReactable({
    req(calculated_results(), input$select_full_table_portfolio, input$select_full_table_asset_class, portfolio_names_map())
    p_key <- input$select_full_table_portfolio
    p_res <- calculated_results()[[p_key]]
    
    if (is.null(p_res) || !isTRUE(p_res$enabled) || nrow(p_res$holdings) == 0) {
      return(div(
        class = "p-4 text-muted text-center",
        bs_icon("inbox", class = "fs-3 d-block mb-2 text-secondary"),
        "Keine Holdings in diesem Portfolio vorhanden. Fügen Sie im Portfolio-Editor ETFs hinzu."
      ))
    }
    
    h_data <- p_res$holdings
    if (input$select_full_table_asset_class != "all") {
      h_data <- h_data %>% dplyr::filter(asset_type == input$select_full_table_asset_class)
    }
    
    if (nrow(h_data) == 0) {
      return(div(
        class = "p-4 text-muted text-center",
        bs_icon("funnel", class = "fs-3 d-block mb-2 text-secondary"),
        paste0("Keine Holdings in der Assetklasse '", input$select_full_table_asset_class, "' in diesem Portfolio vorhanden.")
      ))
    }
    
    render_full_lookthrough_reactable(h_data, p_res$name, p_key = p_key)
  })
  
  # ----------------------------------------------------------------------------
  # TAB 5: KONZENTRATIONSTAB OUTPUTS (AKTIEN)
  # ----------------------------------------------------------------------------
  
  output$plot_lorenz <- renderPlotly({
    req(lorenz_results(), portfolio_names_map())
    create_lorenz_chart(lorenz_results(), portfolio_names_map())
  })
  
  output$table_concentration_full <- renderReactable({
    req(concentration_metrics_results())
    metrics <- concentration_metrics_results() %>% dplyr::filter(is_active)
    
    reactable(
      metrics %>% dplyr::select(
        portfolio_name, n_eff, hhi, top1_weight, top5_weight, top10_weight, top20_weight, gini_coefficient
      ),
      columns = list(
        portfolio_name = colDef(name = "Portfolio", minWidth = 160, style = list(fontWeight = 600)),
        n_eff = colDef(
          name = "N_eff",
          align = "center",
          style = list(fontWeight = 700, color = "#1E40AF"),
          cell = function(v) if (v == 0) "-" else v
        ),
        hhi = colDef(name = "HHI", align = "center", cell = function(v) if (v == 0) "-" else v),
        top1_weight = colDef(name = "Top 1", align = "right", cell = function(v) sprintf("%.2f%%", v)),
        top5_weight = colDef(name = "Top 5", align = "right", cell = function(v) sprintf("%.2f%%", v)),
        top10_weight = colDef(name = "Top 10", align = "right", cell = function(v) sprintf("%.2f%%", v)),
        top20_weight = colDef(name = "Top 20", align = "right", cell = function(v) sprintf("%.2f%%", v)),
        gini_coefficient = colDef(name = "Gini Koeffizient", align = "center", cell = function(v) if (v == 0) "-" else v)
      ),
      striped = TRUE,
      bordered = FALSE,
      pagination = FALSE
    )
  })
  
  # ----------------------------------------------------------------------------
  # TAB 7: ETF-UNIVERSUM & METADATEN OUTPUTS
  # ----------------------------------------------------------------------------
  
  output$ui_universe_stat_badges <- renderUI({
    req(raw_data_reactive())
    d <- raw_data_reactive()
    n_total <- nrow(d$etf_summary)
    n_aktien <- sum(d$etf_summary$asset_type == "Aktien", na.rm = TRUE)
    n_bonds <- sum(d$etf_summary$asset_type == "Bonds", na.rm = TRUE)
    n_re <- sum(d$etf_summary$asset_type == "Real Estate", na.rm = TRUE)
    n_cmd <- sum(d$etf_summary$asset_type == "Rohstoffe", na.rm = TRUE)
    n_cash <- sum(d$etf_summary$asset_type == "Cash", na.rm = TRUE)
    n_holdings <- d$clean_row_count
    
    div(
      class = "d-flex gap-2 align-items-center flex-wrap",
      span(class = "badge bg-primary px-3 py-2 fw-semibold", sprintf("%d Titel im Universum", n_total)),
      span(class = "badge bg-primary-subtle text-primary border px-3 py-2 fw-semibold", sprintf("%d Aktien-ETFs", n_aktien)),
      span(class = "badge bg-teal-subtle text-teal border px-3 py-2 fw-semibold", style = "background-color:#E6FFFA;color:#0D9488;border-color:#5EEAD4;", sprintf("%d Bond-ETFs", n_bonds)),
      if (n_re > 0) span(class = "badge px-3 py-2 fw-semibold", style = "background-color:#FDF2F0;color:#8C564B;border:1px solid #F5C6CB;", sprintf("%d Real Estate", n_re)),
      if (n_cmd > 0) span(class = "badge px-3 py-2 fw-semibold", style = "background-color:#FFFBEB;color:#D97706;border:1px solid #FDE68A;", sprintf("%d Rohstoffe", n_cmd)),
      if (n_cash > 0) span(class = "badge px-3 py-2 fw-semibold", style = "background-color:#F0FDF4;color:#16A34A;border:1px solid #BBF7D0;", sprintf("%d Cash", n_cash)),
      span(class = "badge bg-light text-secondary border px-3 py-2 fw-semibold", sprintf("%s Holding-Positionen", format(n_holdings, big.mark = "'")))
    )
  })
  
  output$table_etf_meta_summary <- renderReactable({
    req(raw_data_reactive())
    summary_df <- raw_data_reactive()$etf_summary
    
    reactable(
      summary_df,
      columns = list(
        etf_ric = colDef(name = "RIC", minWidth = 110, style = list(fontFamily = "monospace", fontWeight = 600)),
        etf_label = colDef(name = "Name / Index", minWidth = 170, style = list(fontWeight = 600)),
        asset_type = colDef(
          name = "Assetklasse",
          minWidth = 110,
          align = "center",
          html = TRUE,
          cell = JS("
            function(cellInfo) {
              var val = cellInfo.value;
              if (val === 'Bonds') {
                return '<span class=\"badge bg-teal-subtle text-teal border\" style=\"background-color:#E6FFFA;color:#0D9488;border-color:#5EEAD4;font-size:0.8rem;padding:3px 8px;\">Bonds</span>';
              }
              if (val === 'Real Estate') {
                return '<span class=\"badge\" style=\"background-color:#FDF2F0;color:#8C564B;border:1px solid #F5C6CB;font-size:0.8rem;padding:3px 8px;\">Real Estate</span>';
              }
              if (val === 'Cash') {
                return '<span class=\"badge\" style=\"background-color:#F0FDF4;color:#16A34A;border:1px solid #BBF7D0;font-size:0.8rem;padding:3px 8px;\">Cash</span>';
              }
              if (val === 'Rohstoffe') {
                return '<span class=\"badge\" style=\"background-color:#FFFBEB;color:#D97706;border:1px solid #FDE68A;font-size:0.8rem;padding:3px 8px;\">Rohstoffe</span>';
              }
              return '<span class=\"badge bg-primary-subtle text-primary border\" style=\"background-color:#EFF6FF;color:#1E40AF;border-color:#BFDBFE;font-size:0.8rem;padding:3px 8px;\">Aktien</span>';
            }
          ")
        ),
        etf_region = colDef(name = "Region", minWidth = 120, align = "center"),
        n_holdings = colDef(name = "Holdings", minWidth = 110, align = "center", cell = function(v) paste0(v, " Titel")),
        raw_weight_sum = colDef(name = "Abdeckung (%)", minWidth = 115, align = "right", cell = function(v) sprintf("%.1f%%", v), style = list(fontFamily = "monospace")),
        avg_div_yield = colDef(name = "Ø Div. Yield", minWidth = 110, align = "right", style = list(color = "#1E40AF", fontWeight = 600, fontFamily = "monospace"), cell = function(v) if (is.na(v)) "-" else sprintf("%.2f%%", v)),
        avg_pe = colDef(name = "Ø KGV (P/E)", minWidth = 110, align = "right", style = list(fontWeight = 600, color = "#1E40AF", fontFamily = "monospace"), cell = function(v) if (is.na(v) || v <= 0) "-" else sprintf("%.1fx", v)),
        avg_pb = colDef(name = "Ø KBV (P/B)", minWidth = 110, align = "right", style = list(fontFamily = "monospace"), cell = function(v) if (is.na(v) || v <= 0) "-" else sprintf("%.2fx", v)),
        avg_ytm = colDef(name = "Ø YTM", minWidth = 100, align = "right", style = list(color = "#0D9488", fontWeight = 600, fontFamily = "monospace"), cell = function(v) if (is.na(v)) "-" else sprintf("%.2f%%", v)),
        avg_mod_duration = colDef(name = "Ø Duration", minWidth = 110, align = "right", style = list(fontWeight = 600, fontFamily = "monospace"), cell = function(v) if (is.na(v)) "-" else sprintf("%.2f J.", v)),
        avg_maturity_years = colDef(name = "Ø Restlaufzeit", minWidth = 115, align = "right", style = list(fontFamily = "monospace"), cell = function(v) if (is.na(v)) "-" else sprintf("%.2f J.", v)),
        n_sectors = colDef(show = FALSE),
        top_holding = colDef(show = FALSE),
        top_holding_weight = colDef(show = FALSE)
      ),
      searchable = TRUE,
      highlight = TRUE,
      striped = TRUE,
      defaultSorted = "asset_type",
      pagination = FALSE,
      theme = reactableTheme(
        borderColor = "#E5E7EB",
        stripedColor = "#F9FAFB",
        highlightColor = "#F3F4F6",
        searchInputStyle = list(width = "100%", padding = "6px 12px", borderRadius = "6px", border = "1px solid #D1D5DB"),
        cellPadding = "10px 14px",
        style = list(fontFamily = "inherit", fontSize = "0.9rem")
      )
    )
  })
}

# ------------------------------------------------------------------------------
# APP START
# ------------------------------------------------------------------------------
shinyApp(ui = ui, server = server)
