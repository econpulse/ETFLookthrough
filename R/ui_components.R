# ==============================================================================
# R/ui_components.R
# Modul für UI-Komponenten, Plotly-Charts und Reactable-Tabellen (Hochoptimiert)
# Unterstützt Multi-Asset, Währungsallokation & Kennzahlen
# ==============================================================================

library(shiny)
library(bslib)
library(bsicons)
library(plotly)
library(reactable)
library(scales)

# Farbpalette für die Portfolios
PORTFOLIO_COLORS <- c(
  "portfolio_1" = "#1E40AF", # Tiefblau (Corporate)
  "portfolio_2" = "#0D9488", # Petrol / Teal
  "portfolio_3" = "#E11D48"  # Karminrot / Rose
)

PORTFOLIO_BG_COLORS <- c(
  "portfolio_1" = "#EFF6FF",
  "portfolio_2" = "#F0FDFA",
  "portfolio_3" = "#FFF1F2"
)

# Hilfsfunktion: Prozentbalken für Reactable-Zellen (R-Fallback)
create_reactable_bar <- function(value, max_val = 100, color = "#2563EB", suffix = "%", decimals = 2) {
  if (is.na(value) || value == 0) {
    return(span(style = "color: #9CA3AF; font-size: 0.85rem;", "0.00%"))
  }
  
  width_pct <- min(100, max(0, (value / max_val) * 100))
  formatted_val <- paste0(sprintf(paste0("%.", decimals, "f"), value), suffix)
  
  div(
    style = "display: flex; align-items: center; gap: 8px; width: 100%; font-family: monospace; font-size: 0.85rem;",
    div(
      style = "flex: 1; background: #E5E7EB; border-radius: 4px; height: 14px; overflow: hidden; position: relative;",
      div(
        style = paste0(
          "width: ", width_pct, "%; background: ", color, "; height: 100%; border-radius: 4px;"
        )
      )
    ),
    span(style = "min-width: 52px; text-align: right; font-weight: 500;", formatted_val)
  )
}

# Hilfsfunktion: Sektor-Badge für Reactable (R-Fallback)
create_sector_badge <- function(sector_name) {
  bg_color <- GICS_SECTOR_COLORS[sector_name]
  if (is.na(bg_color)) bg_color <- "#6B7280"
  
  span(
    style = paste0(
      "background-color: ", bg_color, "1A; ",
      "color: ", bg_color, "; ",
      "border: 1px solid ", bg_color, "40; ",
      "padding: 3px 8px; ",
      "border-radius: 12px; ",
      "font-size: 0.75rem; ",
      "font-weight: 600; ",
      "display: inline-block; ",
      "white-space: nowrap;"
    ),
    sector_name
  )
}

# Hilfsfunktion: Währungs-Badge für Reactable
create_currency_badge <- function(currency_code) {
  bg_color <- CURRENCY_COLORS[currency_code]
  if (is.na(bg_color)) bg_color <- "#6B7280"
  
  span(
    style = paste0(
      "background-color: ", bg_color, "1A; ",
      "color: ", bg_color, "; ",
      "border: 1px solid ", bg_color, "40; ",
      "padding: 2px 7px; ",
      "border-radius: 6px; ",
      "font-size: 0.75rem; ",
      "font-weight: 700; ",
      "font-family: monospace; ",
      "display: inline-block;"
    ),
    currency_code
  )
}

# ==============================================================================
# PLOTLY CHARTS (HOCHPERFORMANT)
# ==============================================================================

#' Erstellt ein vergleichendes Balkendiagramm für die 11 GICS Sektoren
create_sector_comparison_chart <- function(sector_df, p_names, active_keys = c("portfolio_1", "portfolio_2", "portfolio_3")) {
  sector_df <- sector_df %>%
    arrange(desc(weight_portfolio_1))
  
  p <- plot_ly()
  
  for (p_key in active_keys) {
    col_name <- paste0("weight_", p_key)
    p_name <- p_names[[p_key]]
    color <- PORTFOLIO_COLORS[[p_key]]
    
    trace_df <- sector_df %>%
      mutate(
        w_val = .data[[col_name]],
        hover_label = paste0(
          "<b>", gics_sector, "</b><br>",
          p_name, ": <b>", sprintf("%.1f%%", w_val), "</b> (des Aktienanteils)"
        )
      )
    
    p <- p %>% add_trace(
      data = trace_df,
      y = ~gics_sector,
      x = ~w_val,
      name = p_name,
      type = "bar",
      orientation = "h",
      marker = list(
        color = color,
        line = list(color = "#FFFFFF", width = 1)
      ),
      hovertext = ~hover_label,
      hoverinfo = "text",
      textposition = "none"
    )
  }
  
  p %>% layout(
    barmode = "group",
    bargap = 0.25,
    xaxis = list(
      title = "Sektoranteil am Aktiensegment (%)",
      ticksuffix = "%",
      showgrid = TRUE,
      gridcolor = "#F3F4F6",
      zeroline = FALSE
    ),
    yaxis = list(
      title = "",
      categoryorder = "total ascending",
      tickfont = list(size = 11, color = "#374151")
    ),
    legend = list(
      orientation = "h",
      xanchor = "center",
      x = 0.5,
      y = 1.12
    ),
    margin = list(l = 170, r = 20, t = 40, b = 40),
    plot_bgcolor = "rgba(0,0,0,0)",
    paper_bgcolor = "rgba(0,0,0,0)"
  ) %>% config(displayModeBar = FALSE)
}

#' Erstellt ein Donut-/Pie-Chart für die 11 GICS Sektoren eines Portfolios
create_sector_pie_chart <- function(sector_df, port_name = "Portfolio 1", p_key = "portfolio_1") {
  col_name <- paste0("weight_", p_key)
  if (!col_name %in% names(sector_df)) return(plotly_empty(type = "scatter", mode = "markers"))
  
  df_sub <- sector_df %>%
    dplyr::filter(.data[[col_name]] > 0.05) %>%
    dplyr::mutate(w_val = .data[[col_name]])
  
  if (nrow(df_sub) == 0) return(plotly_empty(type = "scatter", mode = "markers"))
  
  colors_vec <- unname(sapply(df_sub$gics_sector, function(s) {
    if (!is.na(GICS_SECTOR_COLORS[s])) GICS_SECTOR_COLORS[[s]] else "#94A3B8"
  }))
  
  plot_ly(
    data = df_sub,
    labels = ~gics_sector,
    values = ~w_val,
    type = "pie",
    hole = 0.5,
    marker = list(colors = colors_vec),
    textinfo = "label+percent",
    textposition = "inside",
    hoverinfo = "label+value+percent",
    hovertemplate = "<b>%{label}</b><br>Gewicht: %{value:.2f}%<br>Anteil am Aktienteil: %{percent}<extra></extra>"
  ) %>% layout(
    showlegend = FALSE,
    margin = list(t = 20, r = 20, l = 20, b = 20),
    annotations = list(
      list(
        text = paste0("<b>", port_name, "</b><br><span style='font-size:11px;color:#64748B;'>Aktiensektoren</span>"),
        showarrow = FALSE,
        font = list(size = 13, color = "#1E293B")
      )
    ),
    plot_bgcolor = "rgba(0,0,0,0)",
    paper_bgcolor = "rgba(0,0,0,0)"
  ) %>% config(displayModeBar = FALSE)
}

#' Erstellt ein Differenzdiagramm der Sektorgewichte (P1 vs P2 / P1 vs P3)
create_sector_delta_chart <- function(sector_df, p_names, compare_pair = "p1_p2") {
  delta_col <- switch(
    compare_pair,
    "p1_p2" = "delta_p1_p2",
    "p1_p3" = "delta_p1_p3",
    "p2_p3" = "delta_p2_p3"
  )
  
  title_text <- switch(
    compare_pair,
    "p1_p2" = paste0("Differenz: ", p_names$portfolio_1, " vs. ", p_names$portfolio_2),
    "p1_p3" = paste0("Differenz: ", p_names$portfolio_1, " vs. ", p_names$portfolio_3),
    "p2_p3" = paste0("Differenz: ", p_names$portfolio_2, " vs. ", p_names$portfolio_3)
  )
  
  pos_color <- switch(
    compare_pair,
    "p1_p2" = "#1E40AF",
    "p1_p3" = "#1E40AF",
    "p2_p3" = "#0D9488"
  )
  neg_color <- switch(
    compare_pair,
    "p1_p2" = "#0D9488",
    "p1_p3" = "#E11D48",
    "p2_p3" = "#E11D48"
  )
  
  chart_df <- sector_df %>%
    mutate(
      delta_raw = .data[[delta_col]],
      delta = ifelse(abs(delta_raw) < 0.001, 0, delta_raw),
      hover_label = paste0(
        "<b>", gics_sector, "</b><br>",
        "Δ Gewicht: <b>", sprintf("%+.1f%%-Pkt.", delta), "</b>"
      ),
      color_bar = ifelse(delta >= 0, pos_color, neg_color)
    ) %>%
    arrange(delta)
  
  max_abs_val <- max(abs(chart_df$delta), na.rm = TRUE)
  x_range <- if (is.na(max_abs_val) || max_abs_val < 0.5) {
    c(-2, 2)
  } else {
    span <- max_abs_val * 1.15
    c(-span, span)
  }
  
  p <- plot_ly(
    data = chart_df,
    y = ~gics_sector,
    x = ~delta,
    type = "bar",
    orientation = "h",
    marker = list(
      color = ~color_bar,
      line = list(color = "#FFFFFF", width = 1)
    ),
    hovertext = ~hover_label,
    hoverinfo = "text",
    textposition = "none"
  ) %>% layout(
    title = list(text = title_text, font = list(size = 14, color = "#1F2937"), x = 0.05),
    xaxis = list(
      title = "Differenz in Prozentpunkten (%-Pkt.)",
      ticksuffix = "%-Pkt",
      zeroline = TRUE,
      zerolinecolor = "#374151",
      zerolinewidth = 1.5,
      gridcolor = "#F3F4F6",
      range = x_range
    ),
    yaxis = list(title = "", categoryorder = "array", categoryarray = chart_df$gics_sector),
    margin = list(l = 170, r = 20, t = 50, b = 40),
    plot_bgcolor = "rgba(0,0,0,0)",
    paper_bgcolor = "rgba(0,0,0,0)"
  ) %>% config(displayModeBar = FALSE)
  
  p
}

#' Erstellt ein Differenzdiagramm der Regionengewichte (Aktien-Delta), gefiltert auf vorhandene Regionen
create_region_delta_chart <- function(region_df, p_names, compare_pair = "p1_p2") {
  delta_col <- switch(
    compare_pair,
    "p1_p2" = "delta_p1_p2",
    "p1_p3" = "delta_p1_p3",
    "p2_p3" = "delta_p2_p3"
  )
  
  col_a <- switch(
    compare_pair,
    "p1_p2" = "weight_portfolio_1",
    "p1_p3" = "weight_portfolio_1",
    "p2_p3" = "weight_portfolio_2"
  )
  col_b <- switch(
    compare_pair,
    "p1_p2" = "weight_portfolio_2",
    "p1_p3" = "weight_portfolio_3",
    "p2_p3" = "weight_portfolio_3"
  )
  
  title_text <- switch(
    compare_pair,
    "p1_p2" = paste0("Differenz: ", p_names$portfolio_1, " vs. ", p_names$portfolio_2),
    "p1_p3" = paste0("Differenz: ", p_names$portfolio_1, " vs. ", p_names$portfolio_3),
    "p2_p3" = paste0("Differenz: ", p_names$portfolio_2, " vs. ", p_names$portfolio_3)
  )
  
  pos_color <- switch(
    compare_pair,
    "p1_p2" = "#1E40AF",
    "p1_p3" = "#1E40AF",
    "p2_p3" = "#0D9488"
  )
  neg_color <- switch(
    compare_pair,
    "p1_p2" = "#0D9488",
    "p1_p3" = "#E11D48",
    "p2_p3" = "#E11D48"
  )
  
  # Nur Regionen herausfiltern, die tatsächlich in mindestens einem der beiden Portfolios vorkommen
  chart_df <- region_df %>%
    dplyr::filter((.data[[col_a]] > 0.001 | .data[[col_b]] > 0.001) & region != "Global") %>%
    dplyr::mutate(
      delta_raw = .data[[delta_col]],
      delta = ifelse(abs(delta_raw) < 0.001, 0, delta_raw),
      hover_label = paste0(
        "<b>", region, "</b><br>",
        "Δ Gewicht: <b>", sprintf("%+.1f%%-Pkt.", delta), "</b>"
      ),
      color_bar = ifelse(delta >= 0, pos_color, neg_color)
    ) %>%
    dplyr::arrange(delta)
  
  if (nrow(chart_df) == 0) {
    return(plotly_empty(type = "scatter", mode = "markers"))
  }
  
  max_abs_val <- max(abs(chart_df$delta), na.rm = TRUE)
  x_range <- if (is.na(max_abs_val) || max_abs_val < 0.5) {
    c(-2, 2)
  } else {
    span <- max_abs_val * 1.15
    c(-span, span)
  }
  
  plot_ly(
    data = chart_df,
    y = ~region,
    x = ~delta,
    type = "bar",
    orientation = "h",
    marker = list(
      color = ~color_bar,
      line = list(color = "#FFFFFF", width = 1)
    ),
    hovertext = ~hover_label,
    hoverinfo = "text",
    textposition = "none"
  ) %>% layout(
    title = list(text = title_text, font = list(size = 14, color = "#1F2937"), x = 0.05),
    xaxis = list(
      title = "Differenz in Prozentpunkten (%-Pkt.)",
      ticksuffix = "%-Pkt",
      zeroline = TRUE,
      zerolinecolor = "#374151",
      zerolinewidth = 1.5,
      gridcolor = "#F3F4F6",
      range = x_range
    ),
    yaxis = list(title = "", categoryorder = "array", categoryarray = chart_df$region),
    margin = list(l = 150, r = 20, t = 50, b = 40),
    plot_bgcolor = "rgba(0,0,0,0)",
    paper_bgcolor = "rgba(0,0,0,0)"
  ) %>% config(displayModeBar = FALSE)
}

#' Erstellt ein horizontales Delta-Balkendiagramm für Assetklassen-Divergenzen
#' 
#' @param asset_df Dataframe aus calculate_asset_class_comparison()
#' @param p_names Benannte Liste mit Anzeigenamen der Portfolios
#' @param compare_pair Vergleichspaar ("p1_p2", "p1_p3", "p2_p3")
create_asset_delta_chart <- function(asset_df, p_names, compare_pair = "p1_p2") {
  if (is.null(asset_df) || nrow(asset_df) == 0) {
    return(plotly_empty(type = "scatter", mode = "markers"))
  }
  
  delta_col <- switch(
    compare_pair,
    "p1_p2" = "delta_p1_p2",
    "p1_p3" = "delta_p1_p3",
    "p2_p3" = "delta_p2_p3"
  )
  
  col_a <- switch(
    compare_pair,
    "p1_p2" = "weight_portfolio_1",
    "p1_p3" = "weight_portfolio_1",
    "p2_p3" = "weight_portfolio_2"
  )
  col_b <- switch(
    compare_pair,
    "p1_p2" = "weight_portfolio_2",
    "p1_p3" = "weight_portfolio_3",
    "p2_p3" = "weight_portfolio_3"
  )
  
  title_text <- switch(
    compare_pair,
    "p1_p2" = paste0("Assetklassen: ", p_names$portfolio_1, " vs. ", p_names$portfolio_2),
    "p1_p3" = paste0("Assetklassen: ", p_names$portfolio_1, " vs. ", p_names$portfolio_3),
    "p2_p3" = paste0("Assetklassen: ", p_names$portfolio_2, " vs. ", p_names$portfolio_3)
  )
  
  pos_color <- switch(
    compare_pair,
    "p1_p2" = "#1E40AF",
    "p1_p3" = "#1E40AF",
    "p2_p3" = "#0D9488"
  )
  neg_color <- switch(
    compare_pair,
    "p1_p2" = "#0D9488",
    "p1_p3" = "#E11D48",
    "p2_p3" = "#E11D48"
  )
  
  chart_df <- asset_df %>%
    dplyr::filter(.data[[col_a]] > 0.001 | .data[[col_b]] > 0.001) %>%
    dplyr::mutate(
      delta_raw = .data[[delta_col]],
      delta = ifelse(abs(delta_raw) < 0.001, 0, delta_raw),
      hover_label = paste0(
        "<b>", asset_type, "</b><br>",
        "Δ Gewicht: <b>", sprintf("%+.1f%%-Pkt.", delta), "</b>"
      ),
      color_bar = ifelse(delta >= 0, pos_color, neg_color)
    ) %>%
    dplyr::arrange(delta)
  
  if (nrow(chart_df) == 0) {
    return(plotly_empty(type = "scatter", mode = "markers"))
  }
  
  max_abs_val <- max(abs(chart_df$delta), na.rm = TRUE)
  x_range <- if (is.na(max_abs_val) || max_abs_val < 0.5) {
    c(-2, 2)
  } else {
    span <- max_abs_val * 1.15
    c(-span, span)
  }
  
  plot_ly(
    data = chart_df,
    y = ~asset_type,
    x = ~delta,
    type = "bar",
    orientation = "h",
    marker = list(
      color = ~color_bar,
      line = list(color = "#FFFFFF", width = 1)
    ),
    hovertext = ~hover_label,
    hoverinfo = "text",
    textposition = "none"
  ) %>% layout(
    title = list(text = title_text, font = list(size = 14, color = "#1F2937"), x = 0.05),
    xaxis = list(
      title = "Differenz in Prozentpunkten (%-Pkt.)",
      ticksuffix = "%-Pkt",
      zeroline = TRUE,
      zerolinecolor = "#374151",
      zerolinewidth = 1.5,
      gridcolor = "#F3F4F6",
      range = x_range
    ),
    yaxis = list(title = "", categoryorder = "array", categoryarray = chart_df$asset_type),
    margin = list(l = 150, r = 20, t = 50, b = 40),
    plot_bgcolor = "rgba(0,0,0,0)",
    paper_bgcolor = "rgba(0,0,0,0)"
  ) %>% config(displayModeBar = FALSE)
}

#' Erstellt ein gestapeltes Asset Allocation Balkendiagramm (Aktien vs. Bonds)
create_asset_allocation_chart <- function(summary_metrics, p_names, active_keys = c("portfolio_1", "portfolio_2", "portfolio_3")) {
  if (is.null(summary_metrics) || nrow(summary_metrics) == 0) {
    return(plotly_empty(type = "scatter", mode = "markers"))
  }
  
  df_plot <- summary_metrics %>%
    dplyr::filter(portfolio_key %in% active_keys & is_active)
  
  if (nrow(df_plot) == 0) {
    return(plotly_empty(type = "scatter", mode = "markers"))
  }
  
  p <- plot_ly(
    data = df_plot,
    y = ~portfolio_name,
    x = ~equity_weight_pct,
    name = "Aktien",
    type = "bar",
    orientation = "h",
    marker = list(color = "#1E40AF", line = list(color = "#FFFFFF", width = 1)),
    hovertemplate = "<b>%{y}</b><br>Aktien: <b>%{x:.1f}%</b><extra></extra>"
  ) %>%
    add_trace(
      x = ~bond_weight_pct,
      name = "Bonds (Anleihen)",
      marker = list(color = "#0D9488", line = list(color = "#FFFFFF", width = 1)),
      hovertemplate = "<b>%{y}</b><br>Bonds: <b>%{x:.1f}%</b><extra></extra>"
    )
  
  if (any(df_plot$real_estate_weight_pct > 0)) {
    p <- p %>% add_trace(
      x = ~real_estate_weight_pct,
      name = "Real Estate",
      marker = list(color = "#8C564B", line = list(color = "#FFFFFF", width = 1)),
      hovertemplate = "<b>%{y}</b><br>Real Estate: <b>%{x:.1f}%</b><extra></extra>"
    )
  }

  if (any(df_plot$commodity_weight_pct > 0)) {
    p <- p %>% add_trace(
      x = ~commodity_weight_pct,
      name = "Rohstoffe",
      marker = list(color = "#D97706", line = list(color = "#FFFFFF", width = 1)),
      hovertemplate = "<b>%{y}</b><br>Rohstoffe: <b>%{x:.1f}%</b><extra></extra>"
    )
  }

  if (any(df_plot$cash_weight_pct > 0)) {
    p <- p %>% add_trace(
      x = ~cash_weight_pct,
      name = "Cash",
      marker = list(color = "#16A34A", line = list(color = "#FFFFFF", width = 1)),
      hovertemplate = "<b>%{y}</b><br>Cash: <b>%{x:.1f}%</b><extra></extra>"
    )
  }
  
  if (any(df_plot$other_weight_pct > 0)) {
    p <- p %>% add_trace(
      x = ~other_weight_pct,
      name = "Sonstige",
      marker = list(color = "#9CA3AF", line = list(color = "#FFFFFF", width = 1)),
      hovertemplate = "<b>%{y}</b><br>Sonstige: <b>%{x:.1f}%</b><extra></extra>"
    )
  }
  
  p %>% layout(
    barmode = "stack",
    xaxis = list(
      title = "Anteil am Portfolio (%)",
      ticksuffix = "%",
      range = c(0, 100),
      gridcolor = "#F3F4F6"
    ),
    yaxis = list(title = "", categoryorder = "array", categoryarray = rev(df_plot$portfolio_name)),
    legend = list(orientation = "h", xanchor = "center", x = 0.5, y = 1.15),
    margin = list(l = 150, r = 20, t = 40, b = 40),
    plot_bgcolor = "rgba(0,0,0,0)",
    paper_bgcolor = "rgba(0,0,0,0)"
  ) %>% config(displayModeBar = FALSE)
}

#' Erstellt ein vergleichendes horizontales Balkendiagramm für Währungsallokationen (Top N + "Übrige")
create_currency_breakdown_chart <- function(curr_compare_df, p_names, active_keys = c("portfolio_1", "portfolio_2", "portfolio_3"), top_n = 8, other_label = "Übrige", x_axis_title = "Gewicht im Portfolio (%)") {
  if (is.null(curr_compare_df) || nrow(curr_compare_df) == 0) {
    return(plotly_empty(type = "scatter", mode = "markers"))
  }
  
  active_col_names <- paste0("weight_", active_keys)
  active_col_names <- intersect(active_col_names, names(curr_compare_df))
  if (length(active_col_names) == 0) return(plotly_empty(type = "scatter", mode = "markers"))
  
  # Sortiere nach maximalem Gewicht über alle aktiven Portfolios absteigend
  curr_compare_df$max_weight <- apply(curr_compare_df[, active_col_names, drop = FALSE], 1, max, na.rm = TRUE)
  curr_sorted <- curr_compare_df %>% arrange(desc(max_weight))
  
  top_df <- head(curr_sorted, top_n)
  rest_df <- if (nrow(curr_sorted) > top_n) tail(curr_sorted, nrow(curr_sorted) - top_n) else tibble()
  
  if (nrow(rest_df) > 0) {
    other_row <- tibble(currency = other_label)
    for (cn in active_col_names) {
      other_row[[cn]] <- sum(rest_df[[cn]], na.rm = TRUE)
    }
    df_plot <- bind_rows(top_df, other_row)
  } else {
    df_plot <- top_df
  }
  
  # Kategorien-Reihenfolge (Top 1 oben, Übrige ganz unten)
  cat_order <- rev(df_plot$currency)
  
  p <- plot_ly()
  
  for (p_key in active_keys) {
    col_name <- paste0("weight_", p_key)
    p_name <- p_names[[p_key]]
    color <- PORTFOLIO_COLORS[[p_key]]
    
    if (col_name %in% names(df_plot)) {
      p <- p %>% add_trace(
        data = df_plot,
        y = ~currency,
        x = as.formula(paste0("~", col_name)),
        name = p_name,
        type = "bar",
        orientation = "h",
        marker = list(
          color = color,
          line = list(color = "#FFFFFF", width = 1)
        ),
        hovertemplate = paste0(
          "<b>Währung: %{y}</b><br>",
          p_name, ": <b>%{x:.2f}%</b><extra></extra>"
        )
      )
    }
  }
  
  p %>% layout(
    barmode = "group",
    bargap = 0.25,
    xaxis = list(
      title = x_axis_title,
      ticksuffix = "%",
      showgrid = TRUE,
      gridcolor = "#F3F4F6",
      zeroline = FALSE
    ),
    yaxis = list(
      title = "",
      categoryorder = "array",
      categoryarray = cat_order,
      tickfont = list(size = 11, color = "#374151", family = "monospace")
    ),
    legend = list(
      orientation = "h",
      xanchor = "center",
      x = 0.5,
      y = 1.12
    ),
    margin = list(l = 100, r = 20, t = 40, b = 40),
    plot_bgcolor = "rgba(0,0,0,0)",
    paper_bgcolor = "rgba(0,0,0,0)"
  ) %>% config(displayModeBar = FALSE)
}

#' Erstellt ein vergleichendes Balkendiagramm der Top 20 Holdings
create_top_holdings_chart <- function(combined_top_df, p_names, active_keys = c("portfolio_1", "portfolio_2", "portfolio_3"), top_n = 20) {
  if (is.null(combined_top_df) || nrow(combined_top_df) == 0) {
    return(plotly_empty(type = "scatter", mode = "markers"))
  }
  
  df_plot <- head(combined_top_df, top_n) %>%
    mutate(
      label = paste0(holding_name, " (", holding_ric, ")")
    ) %>%
    arrange(desc(max_weight))
  
  p <- plot_ly()
  
  for (p_key in active_keys) {
    col_name <- paste0("weight_", p_key)
    p_name <- p_names[[p_key]]
    color <- PORTFOLIO_COLORS[[p_key]]
    
    p <- p %>% add_trace(
      data = df_plot,
      y = ~label,
      x = as.formula(paste0("~", col_name)),
      name = p_name,
      type = "bar",
      orientation = "h",
      marker = list(
        color = color,
        line = list(color = "#FFFFFF", width = 0.5)
      ),
      hovertemplate = paste0(
        "<b>%{y}</b><br>",
        "Sektor: ", df_plot$gics_sector, "<br>",
        p_name, ": <b>%{x:.2f}%</b><extra></extra>"
      )
    )
  }
  
  p %>% layout(
    barmode = "group",
    bargap = 0.2,
    xaxis = list(
      title = "Look-Through Gewicht (%)",
      ticksuffix = "%",
      showgrid = TRUE,
      gridcolor = "#F3F4F6"
    ),
    yaxis = list(
      title = "",
      categoryorder = "total ascending",
      tickfont = list(size = 10, color = "#374151")
    ),
    legend = list(
      orientation = "h",
      xanchor = "center",
      x = 0.5,
      y = 1.08
    ),
    margin = list(l = 230, r = 20, t = 40, b = 40),
    plot_bgcolor = "rgba(0,0,0,0)",
    paper_bgcolor = "rgba(0,0,0,0)"
  ) %>% config(displayModeBar = FALSE)
}

#' Erstellt die kumulative Konzentrationskurve (Lorenz-Kurve)
create_lorenz_chart <- function(lorenz_df, p_names) {
  if (is.null(lorenz_df) || nrow(lorenz_df) == 0) {
    return(plotly_empty(type = "scatter", mode = "markers"))
  }
  
  p <- plot_ly()
  
  # Gleichverteilungslinie (Diagonale)
  p <- p %>% add_trace(
    x = c(0, 100),
    y = c(0, 100),
    type = "scatter",
    mode = "lines",
    name = "Perfekte Gleichverteilung",
    line = list(color = "#9CA3AF", dash = "dash", width = 1.5),
    hoverinfo = "none"
  )
  
  unique_portfolios <- unique(lorenz_df$portfolio_key)
  
  for (p_key in unique_portfolios) {
    sub_df <- lorenz_df %>% filter(portfolio_key == p_key)
    p_name <- p_names[[p_key]]
    color <- PORTFOLIO_COLORS[[p_key]]
    
    p <- p %>% add_trace(
      data = sub_df,
      x = ~pct_holdings,
      y = ~cum_weight,
      type = "scatter",
      mode = "lines",
      name = p_name,
      line = list(color = color, width = 2.5),
      hovertemplate = paste0(
        "<b>", p_name, "</b><br>",
        "Top %{x:.1f}% der Titel: <b>%{y:.1f}%</b> des Portfolios<br>",
        "Rang: #%{customdata}<extra></extra>"
      ),
      customdata = sub_df$rank
    )
  }
  
  p %>% layout(
    title = list(text = "Kumulative Konzentrationskurve (Lorenz-Kurve)", font = list(size = 14)),
    xaxis = list(
      title = "Anteil der Titel im Portfolio (% sortiert nach Gewicht)",
      ticksuffix = "%",
      range = c(0, 100),
      gridcolor = "#F3F4F6"
    ),
    yaxis = list(
      title = "Kumuliertes Portfoliogewicht (%)",
      ticksuffix = "%",
      range = c(0, 100),
      gridcolor = "#F3F4F6"
    ),
    legend = list(
      orientation = "h",
      xanchor = "center",
      x = 0.5,
      y = -0.2
    ),
    margin = list(l = 60, r = 20, t = 40, b = 60),
    plot_bgcolor = "rgba(0,0,0,0)",
    paper_bgcolor = "rgba(0,0,0,0)"
  ) %>% config(displayModeBar = FALSE)
}

# ==============================================================================
# REACTABLE TABLES (HOCHPERFORMANT MIT JS RENDERING)
# ==============================================================================

#' Erstellt die Reactable-Tabelle für den Währungsvergleich (schnell mit JS)
render_currency_reactable <- function(curr_compare_df, p_names, active_keys = c("portfolio_1", "portfolio_2", "portfolio_3")) {
  curr_colors_json <- jsonlite::toJSON(as.list(CURRENCY_COLORS), auto_unbox = TRUE)
  
  col_defs <- list(
    currency = colDef(
      name = "Währung",
      minWidth = 120,
      html = TRUE,
      cell = JS(sprintf("
        function(cellInfo) {
          var code = cellInfo.value;
          if (!code) return '';
          var colors = %s;
          var c = colors[code] || '#6B7280';
          return '<span style=\"background-color:' + c + '1A;color:' + c + ';border:1px solid ' + c + '40;padding:2px 8px;border-radius:6px;font-size:0.8rem;font-weight:700;font-family:monospace;display:inline-block;\">' + code + '</span>';
        }
      ", curr_colors_json))
    )
  )
  
  for (p_key in active_keys) {
    col_name <- paste0("weight_", p_key)
    p_name <- p_names[[p_key]]
    color <- PORTFOLIO_COLORS[[p_key]]
    
    if (col_name %in% names(curr_compare_df)) {
      col_defs[[col_name]] <- colDef(
        name = p_name,
        minWidth = 150,
        html = TRUE,
        cell = JS(sprintf("
          function(cellInfo) {
            var val = cellInfo.value;
            if (val === null || val === undefined || val === 0) {
              return '<span style=\"color: #9CA3AF; font-size: 0.85rem;\">0.00%%</span>';
            }
            var maxVal = 100;
            var widthPct = Math.min(100, Math.max(0, (val / maxVal) * 100));
            var formatted = val.toFixed(2) + '%%';
            return '<div style=\"display:flex;align-items:center;gap:8px;width:100%%;font-family:monospace;font-size:0.85rem;\">' +
                   '<div style=\"flex:1;background:#E5E7EB;border-radius:4px;height:14px;overflow:hidden;\">' +
                   '<div style=\"width:' + widthPct + '%%;background:%s;height:100%%;border-radius:4px;\"></div></div>' +
                   '<span style=\"min-width:52px;text-align:right;font-weight:500;\">' + formatted + '</span></div>';
          }
        ", color))
      )
    }
  }
  
  reactable(
    curr_compare_df,
    columns = col_defs,
    striped = TRUE,
    highlight = TRUE,
    pagination = FALSE,
    theme = reactableTheme(
      borderColor = "#E5E7EB",
      stripedColor = "#F9FAFB",
      highlightColor = "#F3F4F6",
      cellPadding = "8px 12px",
      style = list(fontFamily = "inherit", fontSize = "0.9rem")
    )
  )
}

#' Erstellt die Reactable-Tabelle für den Aktien-Währungsmix inkl. KGV, KBV & Div. Yield nach Währung
render_equity_currency_reactable <- function(equity_curr_df, p_names, active_keys = c("portfolio_1", "portfolio_2", "portfolio_3")) {
  if (is.null(equity_curr_df) || nrow(equity_curr_df) == 0) {
    return(div(
      class = "p-3 text-muted text-center",
      bs_icon("info-circle", class = "me-1"),
      "Keine Aktien-Positionen in den aktiven Portfolios vorhanden."
    ))
  }
  
  df_display <- equity_curr_df %>%
    dplyr::filter(portfolio_key %in% active_keys)
  
  if (nrow(df_display) == 0) {
    return(div(
      class = "p-3 text-muted text-center",
      bs_icon("info-circle", class = "me-1"),
      "Keine Aktien-Positionen in den ausgewählten Portfolios vorhanden."
    ))
  }
  
  curr_colors_json <- jsonlite::toJSON(as.list(CURRENCY_COLORS), auto_unbox = TRUE)
  
  reactable(
    df_display %>% dplyr::select(
      portfolio_name, currency, pct_of_equity, pct_of_portfolio, weighted_div_yield, weighted_pe, weighted_pb, n_positions
    ),
    columns = list(
      portfolio_name = colDef(
        name = "Portfolio",
        minWidth = 140,
        style = list(fontWeight = 600)
      ),
      currency = colDef(
        name = "Währung",
        minWidth = 90,
        align = "center",
        html = TRUE,
        cell = JS(sprintf("
          function(cellInfo) {
            var code = cellInfo.value;
            if (!code) return '';
            var colors = %s;
            var c = colors[code] || '#6B7280';
            return '<span style=\"background-color:' + c + '1A;color:' + c + ';border:1px solid ' + c + '40;padding:2px 7px;border-radius:6px;font-size:0.75rem;font-weight:700;font-family:monospace;display:inline-block;\">' + code + '</span>';
          }
        ", curr_colors_json))
      ),
      pct_of_equity = colDef(
        name = "Anteil an Aktien (%)",
        minWidth = 140,
        html = TRUE,
        cell = JS("
          function(cellInfo) {
            var val = cellInfo.value;
            if (val === null || val === undefined || val === 0) {
              return '<span style=\"color: #9CA3AF; font-size: 0.85rem;\">0.00%</span>';
            }
            var widthPct = Math.min(100, Math.max(0, val));
            var formatted = val.toFixed(1) + '%';
            return '<div style=\"display:flex;align-items:center;gap:8px;width:100%;font-family:monospace;font-size:0.85rem;\">' +
                   '<div style=\"flex:1;background:#E5E7EB;border-radius:4px;height:14px;overflow:hidden;\">' +
                   '<div style=\"width:' + widthPct + '%;background:#1E40AF;height:100%;border-radius:4px;\"></div></div>' +
                   '<span style=\"min-width:45px;text-align:right;font-weight:500;\">' + formatted + '</span></div>';
          }
        ")
      ),
      pct_of_portfolio = colDef(
        name = "Gewicht im Portfolio",
        minWidth = 115,
        align = "right",
        cell = function(v) sprintf("%.1f%%", v),
        style = list(fontFamily = "monospace")
      ),
      weighted_div_yield = colDef(
        name = "Div. Yield",
        minWidth = 95,
        align = "right",
        style = list(color = "#1E40AF", fontWeight = 600, fontFamily = "monospace"),
        cell = function(v) if (is.na(v)) "-" else sprintf("%.2f%%", v)
      ),
      weighted_pe = colDef(
        name = "Gew. KGV",
        minWidth = 95,
        align = "right",
        style = list(color = "#1E40AF", fontWeight = 700, fontFamily = "monospace"),
        cell = function(v) if (is.na(v) || v <= 0) "-" else sprintf("%.1fx", v)
      ),
      weighted_pb = colDef(
        name = "Gew. KBV",
        minWidth = 95,
        align = "right",
        style = list(fontWeight = 600, fontFamily = "monospace"),
        cell = function(v) if (is.na(v) || v <= 0) "-" else sprintf("%.2fx", v)
      ),
      n_positions = colDef(
        name = "Holdings",
        minWidth = 90,
        align = "center",
        cell = function(v) paste0(v, " Titel")
      )
    ),
    striped = TRUE,
    highlight = TRUE,
    pagination = FALSE,
    theme = reactableTheme(
      borderColor = "#E5E7EB",
      stripedColor = "#F9FAFB",
      highlightColor = "#F3F4F6",
      cellPadding = "8px 12px",
      style = list(fontFamily = "inherit", fontSize = "0.9rem")
    )
  )
}

#' Erstellt die Reactable-Tabelle für den Anleihen-Währungsmix inkl. YTM & Duration nach Währung
render_bond_currency_reactable <- function(bond_curr_df, p_names, active_keys = c("portfolio_1", "portfolio_2", "portfolio_3")) {
  if (is.null(bond_curr_df) || nrow(bond_curr_df) == 0) {
    return(div(
      class = "p-3 text-muted text-center",
      bs_icon("info-circle", class = "me-1"),
      "Keine Anleihen-Positionen in den aktiven Portfolios vorhanden."
    ))
  }
  
  df_display <- bond_curr_df %>%
    dplyr::filter(portfolio_key %in% active_keys)
  
  if (nrow(df_display) == 0) {
    return(div(
      class = "p-3 text-muted text-center",
      bs_icon("info-circle", class = "me-1"),
      "Keine Anleihen-Positionen in den ausgewählten Portfolios vorhanden."
    ))
  }
  
  curr_colors_json <- jsonlite::toJSON(as.list(CURRENCY_COLORS), auto_unbox = TRUE)
  
  reactable(
    df_display %>% dplyr::select(
      portfolio_name, currency, pct_of_bonds, pct_of_portfolio, weighted_ytm, weighted_duration, weighted_maturity_years, n_positions
    ),
    columns = list(
      portfolio_name = colDef(
        name = "Portfolio",
        minWidth = 140,
        style = list(fontWeight = 600)
      ),
      currency = colDef(
        name = "Währung",
        minWidth = 90,
        align = "center",
        html = TRUE,
        cell = JS(sprintf("
          function(cellInfo) {
            var code = cellInfo.value;
            if (!code) return '';
            var colors = %s;
            var c = colors[code] || '#6B7280';
            return '<span style=\"background-color:' + c + '1A;color:' + c + ';border:1px solid ' + c + '40;padding:2px 7px;border-radius:6px;font-size:0.75rem;font-weight:700;font-family:monospace;display:inline-block;\">' + code + '</span>';
          }
        ", curr_colors_json))
      ),
      pct_of_bonds = colDef(
        name = "Anteil an Bonds (%)",
        minWidth = 140,
        html = TRUE,
        cell = JS("
          function(cellInfo) {
            var val = cellInfo.value;
            if (val === null || val === undefined || val === 0) {
              return '<span style=\"color: #9CA3AF; font-size: 0.85rem;\">0.00%</span>';
            }
            var widthPct = Math.min(100, Math.max(0, val));
            var formatted = val.toFixed(1) + '%';
            return '<div style=\"display:flex;align-items:center;gap:8px;width:100%;font-family:monospace;font-size:0.85rem;\">' +
                   '<div style=\"flex:1;background:#E5E7EB;border-radius:4px;height:14px;overflow:hidden;\">' +
                   '<div style=\"width:' + widthPct + '%;background:#0D9488;height:100%;border-radius:4px;\"></div></div>' +
                   '<span style=\"min-width:45px;text-align:right;font-weight:500;\">' + formatted + '</span></div>';
          }
        ")
      ),
      pct_of_portfolio = colDef(
        name = "Gewicht im Portfolio",
        minWidth = 115,
        align = "right",
        cell = function(v) sprintf("%.1f%%", v),
        style = list(fontFamily = "monospace")
      ),
      weighted_ytm = colDef(
        name = "Gew. YTM",
        minWidth = 100,
        align = "right",
        style = list(color = "#0D9488", fontWeight = 700, fontFamily = "monospace"),
        cell = function(v) if (is.na(v)) "-" else sprintf("%.2f%%", v)
      ),
      weighted_duration = colDef(
        name = "Gew. Duration",
        minWidth = 110,
        align = "right",
        style = list(fontWeight = 600, fontFamily = "monospace"),
        cell = function(v) if (is.na(v)) "-" else sprintf("%.2f J.", v)
      ),
      weighted_maturity_years = colDef(
        name = "Gew. Restlaufzeit",
        minWidth = 115,
        align = "right",
        style = list(fontWeight = 600, fontFamily = "monospace"),
        cell = function(v) if (is.na(v)) "-" else sprintf("%.2f J.", v)
      ),
      n_positions = colDef(
        name = "Holdings",
        minWidth = 90,
        align = "center",
        cell = function(v) paste0(v, " Titel")
      )
    ),
    striped = TRUE,
    highlight = TRUE,
    pagination = FALSE,
    theme = reactableTheme(
      borderColor = "#E5E7EB",
      stripedColor = "#F9FAFB",
      highlightColor = "#F3F4F6",
      cellPadding = "8px 12px",
      style = list(fontFamily = "inherit", fontSize = "0.9rem")
    )
  )
}

#' Erstellt die Reactable-Tabelle für den Sektorvergleich (schnell mit JS)
render_sector_reactable <- function(sector_df, p_names, active_keys = c("portfolio_1", "portfolio_2", "portfolio_3")) {
  sector_colors_json <- jsonlite::toJSON(as.list(GICS_SECTOR_COLORS), auto_unbox = TRUE)
  
  col_defs <- list(
    gics_sector = colDef(
      name = "GICS Sektor",
      minWidth = 180,
      html = TRUE,
      cell = JS(sprintf("
        function(cellInfo) {
          var sec = cellInfo.value;
          if (!sec) return '';
          var colors = %s;
          var c = colors[sec] || '#6B7280';
          return '<span style=\"background-color:' + c + '1A;color:' + c + ';border:1px solid ' + c + '40;padding:3px 8px;border-radius:12px;font-size:0.75rem;font-weight:600;display:inline-block;white-space:nowrap;\">' + sec + '</span>';
        }
      ", sector_colors_json))
    )
  )
  
  for (p_key in active_keys) {
    col_name <- paste0("weight_", p_key)
    p_name <- p_names[[p_key]]
    color <- PORTFOLIO_COLORS[[p_key]]
    
    col_defs[[col_name]] <- colDef(
      name = p_name,
      minWidth = 160,
      html = TRUE,
      cell = JS(sprintf("
        function(cellInfo) {
          var val = cellInfo.value;
          if (val === null || val === undefined || val === 0) {
            return '<span style=\"color: #9CA3AF; font-size: 0.85rem;\">0.00%%</span>';
          }
          var widthPct = Math.min(100, Math.max(0, (val / 40) * 100));
          var formatted = val.toFixed(2) + '%%';
          return '<div style=\"display:flex;align-items:center;gap:8px;width:100%%;font-family:monospace;font-size:0.85rem;\">' +
                 '<div style=\"flex:1;background:#E5E7EB;border-radius:4px;height:14px;overflow:hidden;\">' +
                 '<div style=\"width:' + widthPct + '%%;background:%s;height:100%%;border-radius:4px;\"></div></div>' +
                 '<span style=\"min-width:52px;text-align:right;font-weight:500;\">' + formatted + '</span></div>';
        }
      ", color))
    )
  }
  
  if ("portfolio_1" %in% active_keys && "portfolio_2" %in% active_keys) {
    col_defs$delta_p1_p2 <- colDef(
      name = "Δ (P1 - P2)",
      minWidth = 120,
      html = TRUE,
      cell = JS("
        function(cellInfo) {
          var val = cellInfo.value;
          if (val === null || val === undefined || isNaN(val)) return '-';
          var col = val > 0.05 ? '#1E40AF' : (val < -0.05 ? '#0D9488' : '#6B7280');
          var prefix = val > 0 ? '+' : '';
          return '<span style=\"color:' + col + ';font-weight:600;font-family:monospace;\">' + prefix + val.toFixed(2) + '%-Pkt</span>';
        }
      ")
    )
  } else {
    col_defs$delta_p1_p2 <- colDef(show = FALSE)
  }
  
  if ("portfolio_1" %in% active_keys && "portfolio_3" %in% active_keys) {
    col_defs$delta_p1_p3 <- colDef(
      name = "Δ (P1 - P3)",
      minWidth = 120,
      html = TRUE,
      cell = JS("
        function(cellInfo) {
          var val = cellInfo.value;
          if (val === null || val === undefined || isNaN(val)) return '-';
          var col = val > 0.05 ? '#1E40AF' : (val < -0.05 ? '#E11D48' : '#6B7280');
          var prefix = val > 0 ? '+' : '';
          return '<span style=\"color:' + col + ';font-weight:600;font-family:monospace;\">' + prefix + val.toFixed(2) + '%-Pkt</span>';
        }
      ")
    )
  } else {
    col_defs$delta_p1_p3 <- colDef(show = FALSE)
  }
  
  if ("portfolio_2" %in% active_keys && "portfolio_3" %in% active_keys) {
    col_defs$delta_p2_p3 <- colDef(
      name = "Δ (P2 - P3)",
      minWidth = 120,
      html = TRUE,
      cell = JS("
        function(cellInfo) {
          var val = cellInfo.value;
          if (val === null || val === undefined || isNaN(val)) return '-';
          var col = val > 0.05 ? '#0D9488' : (val < -0.05 ? '#E11D48' : '#6B7280');
          var prefix = val > 0 ? '+' : '';
          return '<span style=\"color:' + col + ';font-weight:600;font-family:monospace;\">' + prefix + val.toFixed(2) + '%-Pkt</span>';
        }
      ")
    )
  } else {
    col_defs$delta_p2_p3 <- colDef(show = FALSE)
  }
  
  reactable(
    sector_df,
    columns = col_defs,
    defaultSorted = "weight_portfolio_1",
    defaultSortOrder = "desc",
    striped = TRUE,
    highlight = TRUE,
    bordered = FALSE,
    pagination = FALSE,
    theme = reactableTheme(
      borderColor = "#E5E7EB",
      stripedColor = "#F9FAFB",
      highlightColor = "#F3F4F6",
      cellPadding = "8px 12px",
      style = list(fontFamily = "inherit", fontSize = "0.9rem")
    )
  )
}

#' Erstellt die Reactable-Tabelle für die Top 20 Holdings (schnell mit JS)
render_top_holdings_reactable <- function(combined_top_df, p_names, active_keys = c("portfolio_1", "portfolio_2", "portfolio_3")) {
  sector_colors_json <- jsonlite::toJSON(as.list(GICS_SECTOR_COLORS), auto_unbox = TRUE)
  
  col_defs <- list(
    holding_name = colDef(
      name = "Titel Name",
      minWidth = 200,
      html = TRUE,
      cell = JS("
        function(cellInfo) {
          var row = cellInfo.row;
          return '<div><div style=\"font-weight:600;color:#111827;\">' + cellInfo.value + '</div>' +
                 '<div style=\"font-size:0.75rem;color:#6B7280;font-family:monospace;\">' + row.holding_ric + '</div></div>';
        }
      ")
    ),
    holding_ric = colDef(show = FALSE),
    gics_sector = colDef(
      name = "GICS Sektor",
      minWidth = 170,
      html = TRUE,
      cell = JS(sprintf("
        function(cellInfo) {
          var sec = cellInfo.value;
          if (!sec) return '';
          var colors = %s;
          var c = colors[sec] || '#6B7280';
          return '<span style=\"background-color:' + c + '1A;color:' + c + ';border:1px solid ' + c + '40;padding:3px 8px;border-radius:12px;font-size:0.75rem;font-weight:600;display:inline-block;white-space:nowrap;\">' + sec + '</span>';
        }
      ", sector_colors_json))
    ),
    max_weight = colDef(show = FALSE)
  )
  
  for (p_key in active_keys) {
    col_name <- paste0("weight_", p_key)
    p_name <- p_names[[p_key]]
    color <- PORTFOLIO_COLORS[[p_key]]
    
    col_defs[[col_name]] <- colDef(
      name = p_name,
      minWidth = 140,
      html = TRUE,
      cell = JS(sprintf("
        function(cellInfo) {
          var val = cellInfo.value;
          if (val === null || val === undefined || val === 0) {
            return '<span style=\"color: #9CA3AF; font-size: 0.85rem;\">0.00%%</span>';
          }
          var widthPct = Math.min(100, Math.max(0, (val / 15) * 100));
          var formatted = val.toFixed(2) + '%%';
          return '<div style=\"display:flex;align-items:center;gap:8px;width:100%%;font-family:monospace;font-size:0.85rem;\">' +
                 '<div style=\"flex:1;background:#E5E7EB;border-radius:4px;height:14px;overflow:hidden;\">' +
                 '<div style=\"width:' + widthPct + '%%;background:%s;height:100%%;border-radius:4px;\"></div></div>' +
                 '<span style=\"min-width:52px;text-align:right;font-weight:500;\">' + formatted + '</span></div>';
        }
      ", color))
    )
  }
  
  reactable(
    head(combined_top_df, 20),
    columns = col_defs,
    striped = TRUE,
    highlight = TRUE,
    pagination = FALSE,
    theme = reactableTheme(
      borderColor = "#E5E7EB",
      stripedColor = "#F9FAFB",
      highlightColor = "#F3F4F6",
      cellPadding = "8px 12px",
      style = list(fontFamily = "inherit", fontSize = "0.9rem")
    )
  )
}

#' Erstellt die vollständige durchsuchbare Look-Through Reactable Tabelle (Ultra-Fast JS Rendering)
render_full_lookthrough_reactable <- function(holdings_df, portfolio_name, p_key = "portfolio_1") {
  if (is.null(holdings_df) || nrow(holdings_df) == 0) {
    return(div(
      class = "p-4 text-muted text-center",
      bs_icon("inbox", class = "fs-3 d-block mb-2 text-secondary"),
      "Keine Positionen in diesem Portfolio vorhanden. Fügen Sie im Portfolio-Editor ETFs hinzu."
    ))
  }
  
  color <- PORTFOLIO_COLORS[[p_key]]
  max_w <- max(holdings_df$portfolio_weight, na.rm = TRUE)
  if (is.na(max_w) || max_w <= 0) max_w <- 10
  
  # JS Farbtabelle für die 11 GICS Sektoren & Währungen
  sector_colors_json <- jsonlite::toJSON(as.list(GICS_SECTOR_COLORS), auto_unbox = TRUE)
  curr_colors_json <- jsonlite::toJSON(as.list(CURRENCY_COLORS), auto_unbox = TRUE)
  
  reactable(
    holdings_df,
    columns = list(
      holding_ric = colDef(
        name = "RIC",
        minWidth = 95,
        style = list(fontFamily = "monospace", fontWeight = 500)
      ),
      holding_name = colDef(
        name = "Titel Name",
        minWidth = 220,
        style = list(fontWeight = 600)
      ),
      asset_type = colDef(
        name = "Klasse",
        minWidth = 85,
        align = "center",
        html = TRUE,
        cell = JS("
          function(cellInfo) {
            var val = cellInfo.value;
            if (val === 'Bonds') {
              return '<span class=\"badge bg-teal-subtle text-teal border\" style=\"background-color:#E6FFFA;color:#0D9488;border-color:#5EEAD4;\">Bonds</span>';
            }
            if (val === 'Real Estate') {
              return '<span class=\"badge\" style=\"background-color:#FDF2F0;color:#8C564B;border:1px solid #F5C6CB;\">Real Estate</span>';
            }
            if (val === 'Cash') {
              return '<span class=\"badge\" style=\"background-color:#F0FDF4;color:#16A34A;border:1px solid #BBF7D0;\">Cash</span>';
            }
            if (val === 'Rohstoffe') {
              return '<span class=\"badge\" style=\"background-color:#FFFBEB;color:#D97706;border:1px solid #FDE68A;\">Rohstoffe</span>';
            }
            return '<span class=\"badge bg-primary-subtle text-primary border\" style=\"background-color:#EFF6FF;color:#1E40AF;border-color:#BFDBFE;\">Aktien</span>';
          }
        ")
      ),
      gics_sector = colDef(
        name = "GICS Sektor",
        minWidth = 170,
        html = TRUE,
        cell = JS(sprintf("
          function(cellInfo) {
            var sec = cellInfo.value;
            if (!sec) return '<span style=\"color:#9CA3AF;font-size:0.8rem;\">-</span>';
            var colors = %s;
            var c = colors[sec] || '#6B7280';
            return '<span style=\"background-color:' + c + '1A;color:' + c + ';border:1px solid ' + c + '40;padding:3px 8px;border-radius:12px;font-size:0.75rem;font-weight:600;display:inline-block;white-space:nowrap;\">' + sec + '</span>';
          }
        ", sector_colors_json))
      ),
      currency = colDef(
        name = "Währung",
        minWidth = 85,
        align = "center",
        html = TRUE,
        cell = JS(sprintf("
          function(cellInfo) {
            var code = cellInfo.value;
            if (!code || code === 'NA') return '<span style=\"color:#9CA3AF;font-size:0.8rem;\">-</span>';
            var colors = %s;
            var c = colors[code] || '#6B7280';
            return '<span style=\"background-color:' + c + '1A;color:' + c + ';border:1px solid ' + c + '40;padding:2px 7px;border-radius:6px;font-size:0.75rem;font-weight:700;font-family:monospace;display:inline-block;\">' + code + '</span>';
          }
        ", curr_colors_json))
      ),
      portfolio_weight = colDef(
        name = "Gewicht im Portfolio",
        minWidth = 160,
        defaultSortOrder = "desc",
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
        ", max_w, color))
      ),
      div_yield = colDef(
        name = "Div. Yield",
        minWidth = 95,
        align = "right",
        cell = function(v) if (is.na(v)) "-" else sprintf("%.2f%%", v)
      ),
      pe = colDef(
        name = "KGV",
        minWidth = 85,
        align = "right",
        style = list(fontWeight = 600, fontFamily = "monospace", color = "#1E40AF"),
        cell = function(v) if (is.na(v) || v <= 0) "-" else sprintf("%.1fx", v)
      ),
      pb = colDef(
        name = "KBV",
        minWidth = 85,
        align = "right",
        style = list(fontFamily = "monospace"),
        cell = function(v) if (is.na(v) || v <= 0) "-" else sprintf("%.2fx", v)
      ),
      ytm = colDef(
        name = "YTM",
        minWidth = 85,
        align = "right",
        cell = function(v) if (is.na(v)) "-" else sprintf("%.2f%%", v)
      ),
      mod_duration = colDef(
        name = "Duration",
        minWidth = 90,
        align = "right",
        cell = function(v) if (is.na(v)) "-" else sprintf("%.2f J.", v)
      ),
      maturity_date = colDef(
        name = "Fälligkeit",
        minWidth = 100,
        align = "center",
        html = TRUE,
        cell = JS("
          function(cellInfo) {
            var val = cellInfo.value;
            if (!val || val === 'NA' || val === '') return '<span style=\"color:#9CA3AF;font-size:0.8rem;\">-</span>';
            return '<span class=\"badge bg-light text-secondary border font-monospace\">' + val + '</span>';
          }
        ")
      ),
      n_etfs = colDef(
        name = "ETFs",
        minWidth = 65,
        align = "center",
        html = TRUE,
        cell = JS("
          function(cellInfo) {
            var v = cellInfo.value;
            if (v > 1) {
              return '<span class=\"badge rounded-pill bg-warning text-dark\">' + v + 'x</span>';
            }
            return '<span class=\"badge rounded-pill bg-light text-muted border\">' + v + 'x</span>';
          }
        ")
      ),
      etf_breakdown = colDef(
        name = "ETF Herkunft & Beitragsgewicht",
        minWidth = 240,
        style = list(fontSize = "0.8rem", color = "#4B5563")
      )
    ),
    searchable = TRUE,
    filterable = TRUE,
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
}

#' Rendert die Bond Region x Issuer Type Breakdown Matrix als Reactable
#' 
#' @param breakdown_res Ergebnisliste aus calculate_bond_region_issuer_breakdown()
#' @return Reactable HTML-Widget
render_bond_region_issuer_reactable <- function(breakdown_res) {
  if (is.null(breakdown_res) || !isTRUE(breakdown_res$is_active) || nrow(breakdown_res$matrix_df) == 0) {
    return(reactable(
      tibble(Hinweis = "Keine Fixed-Income (Bond) Positionen im ausgewählten Portfolio enthalten."),
      columns = list(Hinweis = colDef(align = "center", style = list(color = "#9CA3AF", padding = "20px"))),
      outlined = TRUE, borderless = TRUE
    ))
  }
  
  df <- breakdown_res$matrix_df
  issuer_cols <- breakdown_res$issuer_cols
  
  issuer_labels <- c(
    "SOV"    = "Sovereigns (SOV)",
    "FIN"    = "Financials (FIN)",
    "CORP"   = "Corporates (CORP)",
    "AGCY"   = "Agencies (AGCY)",
    "SUPR"   = "Supranationals (SUPR)",
    "SSOV"   = "Sub-Sovereigns (SSOV)",
    "Andere" = "Andere / Sonstige"
  )
  
  col_defs <- list(
    bond_region = colDef(
      name = "Region",
      minWidth = 140,
      style = function(value, index) {
        if (df$bond_region[index] == "Total") {
          list(fontWeight = 700, backgroundColor = "#F1F5F9")
        } else {
          list(fontWeight = 600)
        }
      }
    )
  )
  
  for (col in issuer_cols) {
    lbl <- if (col %in% names(issuer_labels)) issuer_labels[[col]] else col
    col_defs[[col]] <- colDef(
      name = col,
      header = function(value) htmltools::tags$span(title = lbl, value),
      minWidth = 85,
      align = "right",
      style = function(value, index) {
        if (df$bond_region[index] == "Total") {
          list(fontWeight = 700, fontFamily = "monospace", backgroundColor = "#F1F5F9")
        } else {
          list(fontFamily = "monospace")
        }
      },
      cell = function(v) {
        if (is.na(v) || v == 0) "-" else sprintf("%.2f%%", v)
      }
    )
  }
  
  col_defs[["Total"]] <- colDef(
    name = "Total (%)",
    minWidth = 95,
    align = "right",
    style = function(value, index) {
      if (df$bond_region[index] == "Total") {
        list(fontWeight = 700, color = "#0D9488", fontFamily = "monospace", backgroundColor = "#E6FFFA")
      } else {
        list(fontWeight = 700, fontFamily = "monospace", backgroundColor = "#F8FAFC")
      }
    },
    cell = function(v) sprintf("%.2f%%", v)
  )
  
  reactable(
    df,
    columns = col_defs,
    pagination = FALSE,
    highlight = TRUE,
    bordered = FALSE,
    striped = FALSE,
    class = "table-hover border rounded",
    theme = reactableTheme(
      borderColor = "#E2E8F0",
      headerStyle = list(backgroundColor = "#F8FAFC", fontWeight = 600, fontSize = "0.85rem", color = "#475569")
    )
  )
}

