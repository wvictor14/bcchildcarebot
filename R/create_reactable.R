
row_details <- function(index, df) {
  df <- df[index, ] 
  # function that creates class based on colum name
  df_field <- function(name, ...) {
    if (any(is.na(...))) NULL
    else tagList(div(class = "detail-label", name), ...)
  }
  
  detail <- div(
    class = "tbl-detail",
    div(class = "detail-header", 
        span(class = "detail-title", df$NAME)),
    div(class = "detail-description", df$SERVICE_TYPE_CD),
    
    bscols(
      div(
        # column left
        df_field('Last Updated', df$VACANCY_LAST_UPDATE),
        df_field("Phone", df$PHONE),
        df_field("Website", df$WEBSITE),
        df_field("Email", df$EMAIL),
        df_field("Address", df$ADDRESS_1),
        df_field('Address 2', df$ADDRESS_2),
        df_field('City', df$CITY),
        df_field('ECE_CERTIFICATION_YN', df$ECE_CERTIFICATION_YN),
        df_field('ELF', df$ELF_PROGRAMMING_YN),
        df_field('IS_INCOMPLETE_IND', df$IS_INCOMPLETE_IND), 
        df_field('IS_CCFRI_AUTH', df$IS_CCFRI_AUTH)
      ),
      div( 
        # column right
        df_field(
          'Map', 
          df |> 
            leaflet() |>
            addProviderTiles(providers$CartoDB.Voyager) |>
            #addProviderTiles(providers$CartoDB.Positron) |>
            addCircleMarkers(lng = ~LONGITUDE, lat = ~LATITUDE)
        )
      )
    ),
    bscols(
      div(
        df_field(
          "Vacancy type",
          reactable(
            df |>  
              select(contains('VACANCY_SRVC_')) |> 
              pivot_longer(
                everything(), 
                names_to = 'Age Group', 
                values_to = 'Vacancy?',
                names_prefix = 'VACANCY_SRVC_'
              ) |> 
              mutate(`Vacancy?` = ifelse(!is.na(`Vacancy?`), 'Y', 'N'))
            ,
            pagination = FALSE,
            defaultColDef = colDef(headerClass = "header"),
            class = "vacancy-table",
            theme = reactableTheme(cellPadding = "8px 12px")
          )
        )
      ),
      div(
        df_field(
          'Language',
          reactable(
            df |>  
              select(contains('LANG_')) |> 
              pivot_longer(everything(), names_to = 'Language', values_to = 'Y/N') |> 
              mutate(
                Language = str_remove_all(Language, 'LANG_') |> 
                  str_remove_all('_YN'),
                `Y/N` = ifelse(!is.na(`Y/N`), 'Y', 'N'))
            ,
            pagination = FALSE,
            defaultColDef = colDef(headerClass = "header"),
            class = "vacancy-table",
            theme = reactableTheme(cellPadding = "8px 12px")
          )
        )
      )
    )
  )
  detail
}

create_coldefs <- function(df) {
  # columns to hide from unested view
  hide <- df |> 
    select(
      contains('VACANCY'), -VACANCY_LAST_UPDATE,
      LONGITUDE, LATITUDE,
      SERVICE_TYPE_CD,
      ADDRESS_1, PHONE,
      `ADDRESS_2`, WEBSITE, EMAIL,
      
      ECE_CERTIFICATION_YN,
      ELF_PROGRAMMING_YN,
      IS_INCOMPLETE_IND, IS_CCFRI_AUTH,
      popup,
      contains('LANG_')
      
    ) |> 
    colnames() %>%
    setNames(., .) |> 
    map(
      ~colDef(
        show = FALSE
      )
    )
  
  show <- list(
    VACANCY_LAST_UPDATE = colDef(name = 'Last Updated'),
    NAME = colDef(name = 'Name'),
    CITY = colDef(name = 'City')
  )
  
  coldefs <- purrr::list_flatten(list(hide, show))
  return(coldefs)
}