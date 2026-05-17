library(dplyr)
library(readr)
library(lubridate)
library(cli)

BCCC_URL <- "https://catalogue.data.gov.bc.ca/dataset/4cc207cc-ff03-44f8-8c5f-415af5224646/resource/9a9f14e1-03ea-4a11-936a-6e77b15eeb39/download/childcare_locations.csv"
HISTORY_PATH <- "data/vacancy_history.csv"

HISTORY_COLS <- c(
  "FAC_PARTY_ID",
  "is_active",
  "date_first_seen",
  "ever_vacancy_under36",
  "last_vacancy_under36",
  "ever_vacancy_30mos_5yrs",
  "last_vacancy_30mos_5yrs",
  "ever_vacancy_licpre",
  "last_vacancy_licpre",
  "ever_vacancy_gr1_age12",
  "last_vacancy_gr1_age12"
)

fetch_bc_data <- function(url = BCCC_URL) {
  readr::read_csv(url, show_col_types = FALSE)
}

bootstrap_history <- function(
  bccc,
  today = lubridate::today(tzone = "Canada/Pacific")
) {
  bccc |>
    mutate(
      is_active = TRUE,
      date_first_seen = NA_Date_,
      ever_vacancy_under36 = if_else(VACANCY_SRVC_UNDER36 == "Y", TRUE, NA),
      last_vacancy_under36 = if_else(
        VACANCY_SRVC_UNDER36 == "Y",
        today,
        NA_Date_
      ),
      ever_vacancy_30mos_5yrs = if_else(
        VACANCY_SRVC_30MOS_5YRS == "Y",
        TRUE,
        NA
      ),
      last_vacancy_30mos_5yrs = if_else(
        VACANCY_SRVC_30MOS_5YRS == "Y",
        today,
        NA_Date_
      ),
      ever_vacancy_licpre = if_else(VACANCY_SRVC_LICPRE == "Y", TRUE, NA),
      last_vacancy_licpre = if_else(
        VACANCY_SRVC_LICPRE == "Y",
        today,
        NA_Date_
      ),
      ever_vacancy_gr1_age12 = if_else(
        VACANCY_SRVC_OOS_GR1_AGE12 == "Y",
        TRUE,
        NA
      ),
      last_vacancy_gr1_age12 = if_else(
        VACANCY_SRVC_OOS_GR1_AGE12 == "Y",
        today,
        NA_Date_
      )
    ) |>
    select(all_of(HISTORY_COLS))
}

add_new_facilities <- function(
  history,
  bccc,
  today = lubridate::today(tzone = "Canada/Pacific")
) {
  new_ids <- setdiff(bccc$FAC_PARTY_ID, history$FAC_PARTY_ID)
  if (length(new_ids) == 0L) {
    return(history)
  }

  new_rows <- bccc |>
    filter(FAC_PARTY_ID %in% new_ids) |>
    mutate(
      is_active = TRUE,
      date_first_seen = today,
      ever_vacancy_under36 = if_else(VACANCY_SRVC_UNDER36 == "Y", TRUE, NA),
      last_vacancy_under36 = if_else(
        VACANCY_SRVC_UNDER36 == "Y",
        today,
        NA_Date_
      ),
      ever_vacancy_30mos_5yrs = if_else(
        VACANCY_SRVC_30MOS_5YRS == "Y",
        TRUE,
        NA
      ),
      last_vacancy_30mos_5yrs = if_else(
        VACANCY_SRVC_30MOS_5YRS == "Y",
        today,
        NA_Date_
      ),
      ever_vacancy_licpre = if_else(VACANCY_SRVC_LICPRE == "Y", TRUE, NA),
      last_vacancy_licpre = if_else(
        VACANCY_SRVC_LICPRE == "Y",
        today,
        NA_Date_
      ),
      ever_vacancy_gr1_age12 = if_else(
        VACANCY_SRVC_OOS_GR1_AGE12 == "Y",
        TRUE,
        NA
      ),
      last_vacancy_gr1_age12 = if_else(
        VACANCY_SRVC_OOS_GR1_AGE12 == "Y",
        today,
        NA_Date_
      )
    ) |>
    select(all_of(HISTORY_COLS))

  bind_rows(history, new_rows)
}

update_vacancies <- function(
  history,
  bccc,
  today = lubridate::today(tzone = "Canada/Pacific")
) {
  today_vac <- bccc |>
    select(
      FAC_PARTY_ID,
      VACANCY_SRVC_UNDER36,
      VACANCY_SRVC_30MOS_5YRS,
      VACANCY_SRVC_LICPRE,
      VACANCY_SRVC_OOS_GR1_AGE12
    )

  history |>
    left_join(today_vac, by = "FAC_PARTY_ID") |>
    mutate(
      ever_vacancy_under36 = if_else(
        VACANCY_SRVC_UNDER36 == "Y",
        TRUE,
        ever_vacancy_under36
      ),
      last_vacancy_under36 = if_else(
        VACANCY_SRVC_UNDER36 == "Y",
        today,
        last_vacancy_under36
      ),
      ever_vacancy_30mos_5yrs = if_else(
        VACANCY_SRVC_30MOS_5YRS == "Y",
        TRUE,
        ever_vacancy_30mos_5yrs
      ),
      last_vacancy_30mos_5yrs = if_else(
        VACANCY_SRVC_30MOS_5YRS == "Y",
        today,
        last_vacancy_30mos_5yrs
      ),
      ever_vacancy_licpre = if_else(
        VACANCY_SRVC_LICPRE == "Y",
        TRUE,
        ever_vacancy_licpre
      ),
      last_vacancy_licpre = if_else(
        VACANCY_SRVC_LICPRE == "Y",
        today,
        last_vacancy_licpre
      ),
      ever_vacancy_gr1_age12 = if_else(
        VACANCY_SRVC_OOS_GR1_AGE12 == "Y",
        TRUE,
        ever_vacancy_gr1_age12
      ),
      last_vacancy_gr1_age12 = if_else(
        VACANCY_SRVC_OOS_GR1_AGE12 == "Y",
        today,
        last_vacancy_gr1_age12
      )
    ) |>
    select(all_of(HISTORY_COLS))
}

update_active_status <- function(history, bccc) {
  history |>
    mutate(is_active = FAC_PARTY_ID %in% bccc$FAC_PARTY_ID)
}

if (!testthat::is_testing()) {
  today <- lubridate::today(tzone = "Canada/Pacific")

  cli_alert_info("Fetching BC childcare data for {today}...")
  bccc <- fetch_bc_data()
  cli_alert_success("{nrow(bccc)} facilities in today's pull.")

  if (file.exists(HISTORY_PATH)) {
    cli_alert_info("Reading existing history...")
    history <- readr::read_csv(
      HISTORY_PATH,
      col_types = readr::cols(
        FAC_PARTY_ID            = readr::col_integer(),
        is_active               = readr::col_logical(),
        date_first_seen         = readr::col_date(),
        ever_vacancy_under36    = readr::col_logical(),
        last_vacancy_under36    = readr::col_date(),
        ever_vacancy_30mos_5yrs = readr::col_logical(),
        last_vacancy_30mos_5yrs = readr::col_date(),
        ever_vacancy_licpre     = readr::col_logical(),
        last_vacancy_licpre     = readr::col_date(),
        ever_vacancy_gr1_age12  = readr::col_logical(),
        last_vacancy_gr1_age12  = readr::col_date()
      )
    )
    cli_alert_success("{nrow(history)} facilities in history.")
    history <- add_new_facilities(history, bccc, today)
    history <- update_vacancies(history, bccc, today)
    history <- update_active_status(history, bccc)
  } else {
    cli_alert_warning("No history file found — bootstrapping from today's data...")
    history <- bootstrap_history(bccc, today)
  }

  cli_alert_info("Writing {nrow(history)} facilities to {.file {HISTORY_PATH}}")
  readr::write_csv(history, HISTORY_PATH)
  cli_alert_success("Done.")
}
