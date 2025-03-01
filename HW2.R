# HW2 - Starbucks Global Store Analysis
# Author: Jihong Min
# Date: 2025-02-20

# Load necessary packages
library(shiny)
library(leaflet)
library(dplyr)
library(readr)
library(leaflet.extras)
library(sf)
library(rnaturalearth)
library(rnaturalearthdata)

# UI Component
ui <- fluidPage(
  titlePanel("Starbucks Global Store Analysis"),
  
  # Add CSS for better responsiveness
  tags$head(
    tags$style(HTML("
      .leaflet-container {
        height: 100%;
        min-height: 350px;
        max-height: 500px;
        width: 100%;
      }
      .map-container {
        position: relative;
        height: 350px;
        width: 100%;
        margin-bottom: 15px;
      }
      @media (max-width: 768px) {
        .map-container {
          height: 300px;
        }
      }
    "))
  ),
  
  # Filters (Improved Layout)
  fluidRow(
    column(4, selectInput("selected_country", "Select Country:",
                          choices = c("ALL"),  
                          selected = "ALL")),
    column(4, selectInput("selected_ownership", "Select Ownership Type:",
                          choices = c("ALL", "Company Owned (CO)", "Licensed Store (LS)"),
                          selected = "ALL"))
  ),
  
  div(style = "margin-top: 10px; margin-bottom: 10px;"),  # Reduced Spacing
  
  # Tabs for different maps with responsive height
  tabsetPanel(
    tabPanel("📍 Store Location Map", 
             div(class = "map-container", leafletOutput("map", height = "100%"))),
    tabPanel("🌎 Choropleth Map", 
             div(class = "map-container", leafletOutput("choropleth_map", height = "100%")))
  ),
  
  div(style = "margin-top: 10px; margin-bottom: 10px;"),  # Reduced Spacing
  
  # Store table output
  fluidRow(
    column(12, 
           div(style = "height: 300px; overflow-y: auto;", 
               tableOutput("store_table")))
  )
)

# Server Component
server <- function(input, output, session) {
  
  # Load Starbucks data (Inside server to avoid global scope issues)
  starbucks_data <- reactive({
    read_csv("https://raw.githubusercontent.com/JIHONGKING/Min/main/startbucks.csv") %>%
      select(storeNumber, countryCode, ownershipTypeCode, latitude, longitude, streetAddressLine1, streetAddressLine2) %>%
      mutate(full_address = ifelse(is.na(streetAddressLine2), streetAddressLine1, 
                                   paste(streetAddressLine1, streetAddressLine2, sep=", "))) %>%
      na.omit()
  })

  # Update country list dynamically after data is loaded
  observe({
    updateSelectInput(session, "selected_country", 
                      choices = c("ALL", unique(starbucks_data()$countryCode)))
  })
  
  # Reactive function to filter data
  filtered_data <- reactive({
    data <- starbucks_data()
    
    # Filter by country
    if (input$selected_country != "ALL") {
      data <- data %>% filter(countryCode == input$selected_country)
    }
    
    # Filter by ownership type
    if (input$selected_ownership == "Company Owned (CO)") {
      data <- data %>% filter(ownershipTypeCode == "CO")
    } else if (input$selected_ownership == "Licensed Store (LS)") {
      data <- data %>% filter(ownershipTypeCode == "LS")
    }
    
    return(data)
  })
  
  # Render Store Location Map
  output$map <- renderLeaflet({
    leaflet() %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      fitBounds(lng1 = min(starbucks_data()$longitude, na.rm = TRUE),
                lat1 = min(starbucks_data()$latitude, na.rm = TRUE),
                lng2 = max(starbucks_data()$longitude, na.rm = TRUE),
                lat2 = max(starbucks_data()$latitude, na.rm = TRUE))
  })
  
  # Update Store Location Map
  observe({
    data <- filtered_data()
    
    leafletProxy("map", data = data) %>%
      clearMarkers() %>%
      addCircleMarkers(~longitude, ~latitude, popup = ~paste("📍 Address:", full_address),
                       radius = 3, color = "blue", fillOpacity = 0.7)
  })
  
  # Render Choropleth Map
  output$choropleth_map <- renderLeaflet({
    # Compute Starbucks store count by country
    country_summary <- starbucks_data() %>%
      group_by(countryCode) %>%
      summarise(store_count = n())

    # Load world map
    world <- ne_countries(scale = "medium", returnclass = "sf")

    # Merge with Starbucks data
    world_starbucks <- left_join(world, country_summary, by = c("iso_a2" = "countryCode"))

    # Handle missing values in store_count
    world_starbucks$store_count[is.na(world_starbucks$store_count)] <- 0

    # Define improved color palette for visibility
    color_palette <- colorNumeric(palette = "Blues", domain = world_starbucks$store_count, na.color = "lightgray")

    # Generate Choropleth map
    leaflet(world_starbucks) %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      addPolygons(
        fillColor = ~color_palette(store_count),
        weight = 1, color = "white", fillOpacity = 0.7,
        popup = ~paste("<b>", name, "</b><br>☕ Stores: ", store_count),
        highlight = highlightOptions(weight = 3, color = "#666", bringToFront = TRUE)
      ) %>%
      addLegend(
        position = "topright",
        pal = color_palette,
        values = world_starbucks$store_count,
        title = "Starbucks Stores per Country",
        opacity = 1
      )
  })
  
  # Render Table with controlled height
  output$store_table <- renderTable({
    filtered_data() %>% 
      select(storeNumber, full_address, ownershipTypeCode) %>%
      head(100)  # Limit the number of rows to prevent excessive scrolling
  })
}

# Run Shiny App
shinyApp(ui = ui, server = server)
