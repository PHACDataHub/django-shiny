library(shiny)
library(shinydashboard)
library(dplyr)
library(tidyr)
library(ggplot2)
library(ggrepel)
library(plotly)
library(scales)
library(lubridate)
library(shiny.i18n)
library(ggiraph)


# Load the data files
load("sample-output.RData")

# Merge ts and modeling into tsm
tsm <- ts %>%
  full_join(modeling, 
            by = c("pathogen", "date", "city", "province", "site", "output", "value", "unit"))

# Point to a translation file
i18n <- Translator$new(translation_json_path = "translation.json")
i18n$set_translation_language("English")
i18n$use_js()



### APP ###


# Define UI

ui <- dashboardPage(

    # Application title
    dashboardHeader(title = i18n$t("Wastewater")),

    # Set up the sidebar panel
    dashboardSidebar(
      sidebarMenu(
        menuItem(
          i18n$t("Language"), icon = icon("language"),
          shiny.i18n::usei18n(i18n),
          selectInput('selected_language',
                      i18n$t("Select language"),
                      choices = i18n$get_languages(),
                      selected = i18n$get_key_translation()
          )
        ),
        menuItem(i18n$t("About"), tabName = "about", icon = icon("file")),
        menuItem(i18n$t("Time-series"), tabName = "ts", icon = icon("chart-line")),
        menuItem(i18n$t("Modeling"), tabName = "modeling", icon = icon("chart-area")),
        menuItem(i18n$t("Trends"), tabName = "trends", icon = icon("arrow-trend-up")),
        menuItem(i18n$t("Tables"), tabName = "tables", icon = icon("table"))
      )
    ),
    
    dashboardBody(
      tabItems(
        tabItem(
          tabName = "about",
          fluidRow(
            column(width = 10, offset = 1, htmlOutput(outputId = "about.info"))
          )
        ),
        tabItem(
          tabName = "ts",
          fluidRow(
            box(
              title = i18n$t("Filters"),
              status = "primary",
              solidHeader = TRUE,
              width = 3,
              radioButtons(inputId = "pathogen.ts",
                           label = i18n$t("Select a pathogen"),
                           choices = sort(unique(ts$pathogen)),
                           selected = first(ts$pathogen)),
              
              # Filter by site, city, or province
              selectInput(inputId = "geography.ts", 
                          label = i18n$t("Select a geography"),
                          choices = c("City" = "city", "Province" = "province", 
                                      "Site" = "site")),
              
              # Checkbox group for unique values
              checkboxGroupInput(inputId = "subgeography.ts", label = "",
                                 choices = NULL),
              
              # Date range slider
              dateRangeInput(inputId = "date_range.ts", 
                             label = i18n$t("Select date range"),
                             start = min(ts$date), end = max(ts$date),
                             min = min(ts$date), max = max(ts$date),
                             separator = i18n$t("to")),
              
              # Checkbox for thresholds
              checkboxInput(
                inputId = "threshold.ts", label = i18n$t("Show thresholds")
              ),
              
              # Checkbox for smoothed values
              checkboxInput(
                inputId = "smoothed.ts", label = i18n$t("Display smoothed values")
              ),
              
              # Checkbox for log scale
              checkboxInput(
                inputId = "logscale.ts", label = i18n$t("Display y-axis on a log scale")
              )
            ),
            column(
              width = 9,
              fluidRow(
                column(width = 12, plotlyOutput(outputId = "plot1", height = "600px")),
                column(width = 12, plotlyOutput(outputId = "plot2", height = "600px"))
              )
            )
          )
        ),
        tabItem(
          tabName = "modeling",
          fluidRow(
            box(
              title = i18n$t("Filters"),
              status = "primary",
              solidHeader = TRUE,
              width = 3,
              radioButtons(inputId = "pathogen.m",
                           label = i18n$t("Select a pathogen"),
                           choices = sort(unique(tsm[tsm$output != "ts", "pathogen"])),
                           selected = first(tsm[tsm$output != "ts", "pathogen"], na_rm = TRUE)),
              
              # Filter by site, city, or province
              selectInput(inputId = "geography.m", 
                          label = i18n$t("Select a geography"),
                          choices = c("City" = "city", "Province" = "province", 
                                      "Site" = "site")),
              
              # Checkbox group for unique values
              checkboxGroupInput(inputId = "subgeography.m", label = "",
                                 choices = NULL),
              
              # Date range slider
              dateRangeInput(inputId = "date_range.m", 
                             label = i18n$t("Select date range"),
                             start = min(tsm[tsm$output != "ts", "date"], na.rm = TRUE), end = max(tsm[tsm$output != "ts", "date"], na.rm = TRUE),
                             min = min(tsm[tsm$output != "ts", "date"], na.rm = TRUE), max = max(tsm[tsm$output != "ts", "date"], na.rm = TRUE),
                             separator = i18n$t("to")),
              
              # Checkbox to show ts plot
              checkboxInput("show_ts", i18n$t("Display a time-series plot"), value = FALSE),
              
              # Show options for logscale, smoothed values, and showing thresholds if "show_ts" checkbox is checked
              conditionalPanel(
                condition = "input.show_ts",
                
                # Checkbox for thresholds
                checkboxInput(
                  inputId = "threshold.m", label = i18n$t("Show thresholds")
                ),
                
                # Checkbox for smoothed values
                checkboxInput(
                  inputId = "smoothed.m", label = i18n$t("Display smoothed values")
                ),
                
                # Checkbox for log scale
                checkboxInput(
                  inputId = "logscale.m", label = i18n$t("Display y-axis on a log scale")
                ))
            ),
            column(
              width = 9,
              fluidRow(
                conditionalPanel(
                  condition = "input.show_ts",
                  column(width = 12, plotlyOutput(outputId = "plot1_1", height = "600px"))
                ),
                column(width = 12, plotlyOutput(outputId = "plot3", height = "600px")),
                column(width = 12, htmlOutput(outputId = "text.m")),
                column(width = 12, plotlyOutput(outputId = "plot4", height = "600px"))
              )
            )
          )
        ),
        tabItem(
          tabName = "trends",
          fluidRow(
            box(
              title = i18n$t("Filters"),
              status = "primary",
              solidHeader = TRUE,
              width = 3,
              radioButtons(inputId = "pathogen.trends",
                           label = i18n$t("Select a pathogen"),
                           choices = sort(unique(trends$pathogen)),
                           selected = first(trends$pathogen)),
              # Filter by site, city, or province
              selectInput(inputId = "geography.trends", 
                          label = i18n$t("Select a geography"),
                          choices = c("City" = "city", "Province" = "province", 
                                      "Site" = "site"))
            ),
            column(
              width = 9,
              fluidRow(
                column(width = 12, 
                       plotOutput(outputId = "plot5", height = "600px")
                       )
              )
            )
          )
        ),
        tabItem(
          tabName = "tables",
          fluidRow(
            box(
              title = i18n$t("Filters"),
              status = "primary",
              solidHeader = TRUE,
              width = 3,
              # Input: Choose dataset
              selectInput(inputId = "dataset", 
                          label = i18n$t("Choose a dataset:"),
                          choices = c("Time-series", "Modeling", "Trends")),
              #Select data format
              selectInput(inputId = "file_format", 
                          label = i18n$t("Select file format:"),
                          choices = c("csv", "rds")),
              # Button
              downloadButton(outputId = "downloadData", label = i18n$t("Download"))
            ),
            column(
              width = 9,
              DT::dataTableOutput(outputId = "preview")
            )
          )
        )
      )
    )
    
)



# Define server logic required to draw a histogram
server <- function(input, output, session) {
  
  
  # Update language in session
  
  observeEvent(input$selected_language, {
    shiny.i18n::update_lang(input$selected_language, session)
  })
  
  
  # Filter the data based on the user input
  
  filtered_ts <- reactive({
    ts %>%
      filter(pathogen == input$pathogen.ts) %>%
      filter_at(vars(input$geography.ts), 
                all_vars(. %in% input$subgeography.ts)) %>%
      filter(date >= input$date_range.ts[1] & date <= input$date_range.ts[2]) %>%
      group_by(input$geography.ts)
  })
  
  filtered_modeling <- reactive({
    tsm %>%
      filter(pathogen == input$pathogen.m) %>%
      filter_at(vars(input$geography.m), 
                all_vars(. %in% input$subgeography.m)) %>%
      filter(date >= input$date_range.m[1] & date <= input$date_range.m[2]) %>%
      group_by(input$geography.m)
  })

  filtered_trends <-
    reactive({
      trends %>%
        filter(input$geography.trends == !!input$geography.trends & 
                 !is.na(!!sym(input$geography.trends))) %>%
        group_by(input$geography.trends)
    })
  
  # subset ts dataset to only contain values corresponding to the max date within selected range
  
  ts_recent <- reactive({
    filtered_data <- filtered_ts()
    groups <- unique(filtered_data[[input$geography.ts]])
    
    if(nrow(filtered_data) == 0){
      return(NULL)
    } else {
      ts_r <- filtered_data %>%
        group_by(!!sym(input$geography.ts)) %>%
        summarize(max_date = max(date, na.rm = TRUE), value = value[date == max(date, na.rm = TRUE)]) %>%
        filter(!!sym(input$geography.ts) %in% groups)
    }
    
  })
  
  
  # Update the filter choices based on the selected column
  # ts
  
  observe({
    if (input$selected_language == "Français"){
      updateSelectInput(
        session,
        "geography.ts",
        choices = c(
          "Ville" = "city", "Province" = "province", "Site" = "site"
        )
      )
    } else {
      updateSelectInput(
        session,
        "geography.ts",
        choices = c(
          "City" = "city", "Province" = "province", "Site" = "site"
        )
      )
    }
  })

  observe({
    choices <- sort(unique(ts[, input$geography.ts]))
    updateCheckboxGroupInput(session, "subgeography.ts", 
                             label = i18n$t(paste0("Select a ", input$geography.ts)), 
                             choices = choices)
  })
  
  
  # modeling
  
  observe({
    if (input$selected_language == "Français"){
      updateSelectInput(
        session,
        "geography.m",
        choices = c(
          "Ville" = "city", "Province" = "province", "Site" = "site"
        )
      )
    } else {
      updateSelectInput(
        session,
        "geography.m",
        choices = c(
          "City" = "city", "Province" = "province", "Site" = "site"
        )
      )
    }
  })
  
  observe({
    choices <- sort(unique(modeling[, input$geography.m]))
    updateCheckboxGroupInput(session, "subgeography.m", 
                             label = i18n$t(paste0("Select a ", input$geography.m)), 
                             choices = choices)
  })
  
  
  # trends
  
  observe({
    if (input$selected_language == "Français"){
      updateSelectInput(
        session,
        "geography.trends",
        choices = c(
          "Ville" = "city", "Province" = "province", "Site" = "site"
        )
      )
    } else {
      updateSelectInput(
        session,
        "geography.trends",
        choices = c(
          "City" = "city", "Province" = "province", "Site" = "site"
        )
      )
    }
  })
  
  
  # tables
  
  observe({
    if (input$selected_language == "Français"){
      updateSelectInput(
        session,
        "dataset",
        choices = c(
          "Série temporelle", "Modélisation", "Tendances"
        )
      )
    } else {
      updateSelectInput(
        session,
        "dataset",
        choices = c(
          "Time-series", "Modeling", "Trends"
        )
      )
    }
  })  
  
  
  # Reactive expression for the y-axis variable (ts plot)
  
  yaxis.ts <- reactive({
    if (input$smoothed.ts == TRUE){
      filtered_ts()$val.smooth
    } else {
      filtered_ts()$value
    }
  })
  
  yaxis.m <- reactive({
    filtered_tsm <- filtered_modeling() %>% filter(output == "ts")
    if (input$smoothed.m == TRUE){
      filtered_tsm$val.smooth
    } else {
      filtered_tsm$value
    }
  })
  
  
  # Reactive value to control visibility of plot 1_1
  show_ts_reactive <- reactive({
    input$show_ts
  })
  
  
  
  ## TAB 1 - ABOUT PAGE  
  
  # text box
  
  output$about.info <- renderUI({
    
    str1 <- h1(i18n$t("Wastewater modeling dashboard"))
    str2 <- p(i18n$t("This dashboard provides modeling data based on the viral concentration of various acute respiratory illnesses found in wastewater across Canada. This dashboard includes concentration data, modeling outputs estimating effective reproductive number (Rt) and inferred incidence, and trending information based on historic levels and recent changes in concentration."),
              style = "font-size:18px;")
    str3 <- p(i18n$t("The dashboard was last updated on "), Sys.Date(), ".",
              style = "font-size:18px;")
    
    HTML(paste(str1, str2, str3, sep = '<br/>'))
    
  })
  
  
  
  ### CREATE THE PLOTS
  
  ## TAB 2 - TIME-SERIES
  
  
  # plot 1
  
  output$plot1 <- renderPlotly({
    ts <- filtered_ts()
    upper_threshold = ts[[paste0("upper.threshold.", input$geography.ts)]]
    lower_threshold = ts[[paste0("lower.threshold.", input$geography.ts)]]
    
    validate(need(input$subgeography.ts, i18n$t(paste0("Please select a ", input$geography.ts))))
    req(nrow(ts) > 0)
    
    p1 = ggplot(ts,
             aes(x = date, y = yaxis.ts(),
                 text = paste0(i18n$t("Date: "), date, "<br>",
                               i18n$t("Value: "), round(yaxis.ts(), 4), "<br>",
                               i18n$t("Upper Threshold: "), round(upper_threshold, 4), "<br>",
                               i18n$t("Lower Threshold: "), round(lower_threshold, 4)),
                 group = 1)) +
        geom_step() +
        labs(title = i18n$t("Time-series"),
             y = unique(ts$unit)) +
        theme(plot.background = element_rect(fill = "#ECF0F5"),
              panel.background = element_rect(fill = "white"),
              panel.grid.major = element_line(colour = "lightgrey")) +
        facet_wrap(input$geography.ts)
      
    # Add threshold lines if checkbox is clicked
    
    if (input$threshold.ts == FALSE){
      p1 
    } else {
      p1 = p1 + geom_line(aes(y = upper_threshold), color = "red") + 
        geom_line(aes(y = lower_threshold), color = "green")
    }
    
    # Change the y-axis to log if checkbox is clicked
    
    if (input$logscale.ts == FALSE){
      p1 
    } else {
      p1 = p1 + scale_y_log10()
    }
    
  ggplotly(p1, tooltip = "text")
  
  })  
  
  
  # plot 2
  
  output$plot2 <- renderPlotly({
    ts <- filtered_ts()
    ts_recent <- as.data.frame(ts_recent())
    count <- rep(0, nrow(ts_recent))
    upper_threshold = ts[[paste0("upper.threshold.", input$geography.ts)]]
    lower_threshold = ts[[paste0("lower.threshold.", input$geography.ts)]]
    
    validate(need(input$subgeography.ts, ""))
    req(nrow(ts) > 0)
    
    bin_min <- seq(min(ts$value, na.rm = TRUE), max(ts$value, na.rm = TRUE), 10)
    bin_max <- bin_min + 10
    bin_range <- paste0(round(bin_min, 4) , " - ", round(bin_max, 4))
    
    p2 = ggplot(ts, aes(x = value, group = 1)) +
      suppressWarnings(
        geom_histogram(binwidth = 10,
                       aes(text = paste0(i18n$t("Bin width: 10"), "<br>", 
                                         i18n$t("Value range: "), bin_range,  "<br>",
                                         i18n$t("Count: "), after_stat(count))))) +
      suppressWarnings(
        geom_point(data = ts_recent, 
                   aes(x = value, y = count, 
                       text = paste0(i18n$t("Latest date: "), max_date, "<br>", 
                                     i18n$t("Value: "), round(value, 4))), 
                   shape = 24, size = 4, color = "red", fill = "yellow")) +
      labs(title = i18n$t("Histogram"),
           x = unique(ts$unit), y = i18n$t("count")) +
      theme(plot.background = element_rect(fill = "#ECF0F5"),
            panel.background = element_rect(fill = "white"),
            panel.grid.major = element_line(colour = "lightgrey")) +
      facet_wrap(input$geography.ts)

    
    # Add threshold lines if radio button selection = "On"
    
    if (input$threshold.ts == FALSE){
      p2
    } else {
      p2 = p2 + 
        suppressWarnings(
          geom_vline(
            aes(
              xintercept = upper_threshold,
              text = paste0(i18n$t("Upper Threshold: "), round(upper_threshold, 4), "<br>",
                            i18n$t("Lower Threshold: "), round(lower_threshold, 4))),
            color = "red")) +
        suppressWarnings(
          geom_vline(
            aes(
              xintercept = lower_threshold,
              text = paste0(i18n$t("Upper Threshold: "), round(upper_threshold, 4), "<br>",
                            i18n$t("Lower Threshold: "), round(lower_threshold, 4))),
            color = "green"))
    }
    
    ggplotly(p2, tooltip = "text")
    
  })
  
  
  ## TAB 3 - MODELING
  
  # plot 1_1
  
  output$plot1_1 <- renderPlotly({
    
    # Check if plot 1_1 should be shown
    if (show_ts_reactive()) {
      
      ts <- filtered_modeling() %>% filter(output == "ts")
      upper_threshold = ts[[paste0("upper.threshold.", input$geography.ts)]]
      lower_threshold = ts[[paste0("lower.threshold.", input$geography.ts)]]
      
      validate(need(input$subgeography.m, ""))
      req(nrow(ts) > 0)
      
      p1_1 = ggplot(ts,
                    aes(x = date, y = yaxis.m(),
                        text = paste0(i18n$t("Date: "), date, "<br>",
                                      i18n$t("Value: "), round(yaxis.ts(), 4), "<br>",
                                      i18n$t("Upper Threshold: "), round(upper_threshold, 4), "<br>",
                                      i18n$t("Lower Threshold: "), round(lower_threshold, 4)),
                        group = 1)) +
        geom_step() +
        labs(title = i18n$t("Time-series"),
             y = unique(ts$unit)) +
        theme(plot.background = element_rect(fill = "#ECF0F5"),
              panel.background = element_rect(fill = "white"),
              panel.grid.major = element_line(colour = "lightgrey")) +
        facet_wrap(input$geography.m)
      
      # Add threshold lines if checkbox is clicked
      
      if (input$threshold.m == FALSE){
        p1_1
      } else {
        p1_1 = p1_1 + geom_line(aes(y = upper_threshold), color = "red") +
          geom_line(aes(y = lower_threshold), color = "green")
      }
      
      # Change the y-axis to log if checkbox is clicked
      
      if (input$logscale.m == FALSE){
        p1_1
      } else {
        p1_1 = p1_1 + scale_y_log10()
      }
      
      ggplotly(p1_1, tooltip = "text")
      
    } else {
      NULL
    }
    
  })  
  
  
  # plot 3
  
  output$plot3 <- renderPlotly({
    rt <- filtered_modeling() %>% filter(output == "Rt")
    
    validate(need(input$subgeography.m, i18n$t(paste0("Please select a ", input$geography.m))))
    req(nrow(rt) > 0)
    
    ggplotly(
      ggplot(rt, aes(x = date, y = value, group = 1)) +
        suppressWarnings(
          geom_ribbon(aes(ymin = lower.val, ymax = upper.val,
                          text = paste0(i18n$t("95% confidence interval"), "<br>",
                                        i18n$t("Upper Value: "), round(upper.val, 4), "<br>",
                                        i18n$t("Lower Value: "), round(lower.val, 4))), 
                      fill = "moccasin",
                      alpha = 0.5)) +
        geom_hline(yintercept = 1, linetype="dashed", color = "darkgrey") +
        suppressWarnings(
          geom_line(aes(text = paste0(i18n$t("Date: "), date, "<br>",
                                      i18n$t("Value: "), round(value, 4))),
                    color = 'darkorange4')) +
        scale_y_continuous(labels = label_number(accuracy = 0.1)) +
        labs(title = i18n$t("Rt"),
             y = unique(rt$unit)) +
        theme(plot.background = element_rect(fill = "#ECF0F5"),
              panel.background = element_rect(fill = "white"),
              panel.grid.major = element_line(colour = "lightgrey")) +
        facet_wrap(input$geography.m),
      tooltip = "text"
    )
  })
  
  
  # text box
  
  output$text.m <- renderUI({
    incidence <- filtered_modeling() %>% filter(output == "incidence")
    validate(need(input$subgeography.m, ""),
             need(any(filtered_modeling()$output == "incidence"), ""))
    
    str1 <- paste0("<span style='display: inline-block; padding-left: 50px;'>",
                   i18n$t("The forecast date is "), unique(incidence$forecast.date), 
                   i18n$t(" and is shown in the plot below as a vertical grey dotted line."), 
                   "</span>")
    str2 <- paste0("<span style='display: inline-block; padding-left: 50px;'>",
                   i18n$t("The "), "<span style='background-color: #FFE4B5;'>",
                   i18n$t("light orange"), "</span>",
                   i18n$t(" and "), "<span style='background-color: #ADD8E6;'>",
                   i18n$t("light blue"), "</span>",
                   i18n$t(" areas in the plots depict 95% confidence intervals."),
                   "</span>")
    
    HTML(paste("<div style='margin-top: 10px; margin-bottom: 20px;'>",
               "<span style='font-size: 16px;'>", 
               str1, str2, "</span>", sep = '<br/>'))
  })
  
  
  # plot 4
  
  output$plot4 <- renderPlotly({
    incidence <- filtered_modeling() %>% filter(output == "incidence")
    
    validate(need(input$subgeography.m, ""),
             need(any(filtered_modeling()$output == "incidence"), ""))
    req(nrow(incidence) > 0)
    
    ggplotly(
      ggplot(incidence, aes(x = date, y = value, group = 1)) +
        suppressWarnings(
          geom_ribbon(aes(ymin = lower.val, ymax = upper.val,
                          text = paste0(i18n$t("95% confidence interval"), "<br>",
                                        i18n$t("Upper Value: "), round(upper.val, 4), "<br>",
                                        i18n$t("Lower Value: "), round(lower.val, 4), "<br>",
                                        i18n$t("Forecast date: "), forecast.date)), 
                      fill = "lightblue",
                      alpha = 0.5)) +
        suppressWarnings(
          geom_line(aes(text = paste0(i18n$t("Date: "), date, "<br>",
                                      i18n$t("Value: "), round(value, 4), "<br>",
                                      i18n$t("Forecast date: "), forecast.date)), 
                    color = "darkblue")) +
        suppressWarnings(
          geom_vline(aes(xintercept = as.numeric(forecast.date),
                         text = paste0(i18n$t("Forecast date: "), forecast.date)),
                     linetype = "dotted", color = "darkgrey")) +
        labs(title = i18n$t("Inferred incidence"),
             y = i18n$t(unique(incidence$unit))) +
        theme(plot.background = element_rect(fill = "#ECF0F5"),
              panel.background = element_rect(fill = "white"),
              panel.grid.major = element_line(colour = "lightgrey")) +
        facet_wrap(input$geography.m),
      tooltip = "text"
    )
  })
  
  
  ## TAB 4 - TRENDS
  
  
  # Specs for trends matrix
  xmin = 0
  xmax = 1
  ymin = -500 
  ymax = 600 
  ymin.guides = 1.3*ymin
  sz.label = 3
  dy0 = 100
  alpha.guides = 0.8
  alpha.grid = 0.25
  wvlab = 0.05  # width vertical label "increasing/decreasing"
  arrow.xshift = wvlab / 1.5
  q.lo = 0.25
  q.hi = 0.75
  
  lab.low  = paste0('below ', q.lo*100, 'th percentile')
  lab.mid  = paste0('b/w ', q.lo*100, 'th and ', q.hi*100, 'th percentiles')
  lab.high = paste0('above ', q.hi*100, 'th percentile')
  
  
  # plot 5
  
  output$plot5 <- renderPlot({
    trends <- filtered_trends()
    ggplot(trends,
           aes(x = lastval.scaled, y = deriv.idx)) + 
      geom_vline(xintercept = c(q.lo, q.hi), 
                 alpha = alpha.grid, linetype = 'dotted') +
      geom_hline(yintercept = 0, alpha = alpha.grid, linetype = 'dotted') + 
      #
      # ---- Levels
      #
      annotate('rect', xmin = xmin, xmax = q.lo - 0.01, 
               ymin = ymin.guides, ymax = 0.9*ymin.guides, 
               fill = 'steelblue1', alpha = alpha.guides) + 
      annotate('rect', xmin = q.lo + 0.01, xmax = q.hi - 0.01, 
               ymin = ymin.guides, ymax = 0.9*ymin.guides, 
               fill = 'steelblue3', alpha = alpha.guides) + 
      annotate('rect', xmin = q.hi + 0.01, xmax = 1, 
               ymin = ymin.guides, ymax = 0.9*ymin.guides, 
               fill = 'steelblue4', alpha = alpha.guides) + 
      geom_text(data = data.frame(x = 0.15, y = 0.94*ymin.guides),
                aes(x = x, y = y), hjust = 0.5, size = sz.label + 1,
                label = i18n$t(lab.low), fontface = 'bold.italic', 
                colour = 'white') + 
      geom_text(data = data.frame(x = 0.5, y = 0.94*ymin.guides),
                aes(x = x, y = y), hjust = 0.5, size = sz.label + 1,
                label = i18n$t(lab.mid), fontface = 'bold.italic', 
                colour = 'white') + 
      geom_text(data = data.frame(x = 0.85, y = 0.94*ymin.guides),
                aes(x = x, y = y), hjust = 0.5, size = sz.label + 1, 
                label = i18n$t(lab.high), fontface = 'bold.italic', 
                colour = 'white') +
      #
      # --- Changes
      #
      annotate('rect', xmin = xmin, xmax = xmin + wvlab, 
               ymin = 0.8*ymin.guides, ymax = -dy0, 
               fill='seagreen3', alpha = alpha.guides) + 
      geom_text(data = data.frame(x = xmin + 0.01, y = 0.3*ymin),
                aes(x = x, y = y), hjust = 1, size = sz.label + 1, angle = 90,
                label = i18n$t('decreasing'), fontface = 'bold.italic', color='white') + 
      geom_segment(aes(x = xmin + arrow.xshift, xend = xmin+arrow.xshift, 
                       y = -120, yend = 0.95*ymin), 
                   color = 'white',
                   arrow = arrow(length = unit(0.25, "cm"),
                                 type = 'closed')) +
      
      annotate('rect', xmin = xmin, xmax = xmin + wvlab, 
               ymin = -dy0, ymax = dy0, 
               fill = 'darkgray', alpha = alpha.guides) + 
      geom_text(data = data.frame(x = xmin+0.01, y=15),
                aes(x = x, y = y), hjust = 1, size = sz.label + 1, angle = 90,
                label = i18n$t('stable'), fontface = 'bold.italic', color='white') +
      geom_segment(aes(x = xmin + arrow.xshift, xend = xmin + arrow.xshift, 
                       y = -90, yend = 90), 
                   color = 'white',
                   arrow = arrow(length = unit(0.25, "cm"), 
                                 ends = 'both', type = 'closed')) +
      
      annotate('rect', xmin = xmin, xmax = xmin + wvlab, 
               ymin = dy0, ymax = ymax, 
               fill = 'indianred2', alpha = alpha.guides) + 
      geom_text(data = data.frame(x = xmin + 0.01, y = 0.3*ymax),
                aes(x = x, y = y), hjust = 0, size = sz.label + 1, angle = 90,
                label = i18n$t('increasing'), fontface = 'bold.italic', color = 'white') + 
      geom_segment(aes(x = xmin + arrow.xshift, xend = xmin + arrow.xshift, 
                       y = 120, yend = 0.95*ymax), 
                   color = 'white',
                   arrow = arrow(length = unit(0.25, "cm"), 
                                 type = 'closed')) +
      #
      # --- Labels
      #
      geom_text_repel(aes(label = !!sym(input$geography.trends)),
                      force = 15,
                      segment.colour = NA,
                      fontface = 'bold', 
                      alpha = 0.75, size = 5) +
      geom_point(size = 3, shape = 21, stroke = 1.5, fill = 'grey90') +
      
      #
      # --- cosmetics
      #
      theme(panel.grid = element_blank(), 
            axis.text = element_blank(), 
            axis.ticks = element_blank(), 
            strip.background = element_rect(fill='steelblue4'),
            strip.text = element_text(face = 'bold', color = 'white'),
            axis.title = element_text(size = 14),
            plot.title = element_text(size = 20, face = "bold"),
            plot.background = element_rect(fill = "#ECF0F5", color = NA),
            panel.background = element_rect(fill = "white", color = NA)) + 
      scale_x_continuous(limits = c(xmin,xmax)) +
      scale_y_continuous(limits = c(ymin.guides, ymax)) +
      scale_fill_gradient(low = 'seagreen1', high = 'tomato1') +
      labs(x = i18n$t('latest level compared to city\'s historical values'), 
           y = i18n$t('recent trend'), 
           title = i18n$t('Wastewater Levels & Trends')) +
      guides(fill = 'none')
    
    
  })
  

  
  ## TAB 5 - TABLES
  
  # Reactive value for selected dataset
  datasetInput <- reactive({
    switch(input$dataset,
           "Time-series" = ts,
           "Modeling" = modeling,
           "Trends" = trends,
           "Série temporelle" = ts,
           "Modélisation" = modeling,
           "Tendances" = trends)
  })

  
  
  # Preview selected dataset
  observe({
  if (input$selected_language == "English"){
  output$preview <- DT::renderDataTable({
    DT::datatable(data = datasetInput(), options = list(
      scrollX = TRUE))
  })
  } else {
    output$preview <- DT::renderDataTable({
      DT::datatable(data = datasetInput(), options = list(
        scrollX = TRUE, 
        language = list(url = 'https://cdn.datatables.net/plug-ins/1.10.11/i18n/French.json')))
    })
  }
  })
  
  
  # Downloadable csv/rds of selected dataset
  output$downloadData <- downloadHandler(
    filename = function() {
      paste(input$dataset, input$file_format, sep = ".")
    },
    content = function(file) {
      if (input$file_format == "csv"){
        write.csv(datasetInput(), file, row.names = FALSE)
      } else {
        saveRDS(datasetInput(), file)
      } 
    }
  )
  
  
}

# Run the application 
shinyApp(ui = ui, server = server)
