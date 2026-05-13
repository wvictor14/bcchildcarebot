prepare_data <- function(x) {
  tbl_data <- x |>
    
    # filter columns
    select(
      SERVICE_TYPE_CD:CITY, 
      PHONE:EMAIL,
      LONGITUDE, LATITUDE,
      
      # certs
      ECE_CERTIFICATION_YN,
      ELF_PROGRAMMING_YN,
      IS_INCOMPLETE_IND, IS_CCFRI_AUTH,
      #    contains('OP_'),
      #   contains('SRVC_'),
      contains('LANG_'),
      contains('VACANCY_'),
      popup) |> 
    
    select(NAME, everything())  |> 
    
    # replace NA with blank
    
    mutate(EMAIL = ifelse(is.na(EMAIL), '', EMAIL)) |> 
    
    # 
    # mutate(
    #   popup = glue::glue(
    #     "<b>{NAME}</b>",
    #     "{SERVICE_TYPE_CD}", 
    #     "{PHONE}",
    #     "<br>Vacancy:", 
    #     "&nbsp;&nbsp;&nbsp;&nbsp;<36 months: {VACANCY_SRVC_UNDER36}",
    #     "&nbsp;&nbsp;&nbsp;&nbsp;30 months -- 5 years: {VACANCY_SRVC_30MOS_5YRS}",
    #     "&nbsp;&nbsp;&nbsp;&nbsp;Preschool: {VACANCY_SRVC_LICPRE}",
    #     "&nbsp;&nbsp;&nbsp;&nbsp;Grade 1 - Age 12: {VACANCY_SRVC_OOS_GR1_AGE12}",
    #     .sep = "<br>"
    #   )
    # ) |> 
    
    # # crosstalk key
    # mutate(id = row_number()) |> 
    
    # clean vacancy and other binary columns for filters
    # 
    # # if yes, replace with vacancy type, otherwise leave as NA
    # # NA will not show as a choice
    pivot_longer(
      cols =  c(
        contains('VACANCY_SRVC_'),
        contains('LANG_')
        # ECE_CERTIFICATION_YN,
        # ELF_PROGRAMMING_YN,
        # IS_CCFRI_AUTH,
        # IS_INCOMPLETE_IND
      ),
      names_to = 'name',
      values_to = 'value'
    ) |>
    mutate(
      value = ifelse(
        value == 'Y',
        str_remove_all(name, '^VACANCY_SRVC_') |>
          str_remove_all('^LANG_') |>
          str_remove_all('_YN$'),
        NA
      ),
      value = case_when(
        value == 'ECE_CERTIFICATION' ~ 'Early Childhood Educator (ECE)',
        value == 'ELF_PROGRAMMING' ~ 'ELF',
        value == 'IS_CCFRI_AUTH' ~ 'CCFRI authorized',

        value == '30MOS_5YRS' ~ "30 months - 5 years",
        value == 'UNDER36' ~ 'Under 36 months',
        value == 'LICPRE' ~ 'Licensed Pre-school',
        value == 'OOS_GR1_AGE12' ~ 'Grade 1 - Age 12',
        .default = value
      )
    ) |>
    pivot_wider(names_from = name, values_from = value)
  
  # add vacancy data into 1 column
  # list column where each list-element is a vector of the age groups a facility
  # has vacancies for
  tbl_data <- tbl_data |> 
    rowwise() |>
    mutate(VACANCY = list(c(
      c_across(contains('VACANCY_SRVC')) |> 
        na.omit()
    ))) |> 
    ungroup()
    
  return(tbl_data)
}