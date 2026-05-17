library(dplyr)
library(readr)
library(lubridate)
library(httr2)
library(rvest)
library(cli)
library(testthat)

BCCC_URL <- "https://catalogue.data.gov.bc.ca/dataset/4cc207cc-ff03-44f8-8c5f-415af5224646/resource/9a9f14e1-03ea-4a11-936a-6e77b15eeb39/download/childcare_locations.csv"
URLS_PATH <- "data/facility_urls.csv"

URL_COLS <- c(
  "FAC_PARTY_ID",
  "url",
  "url_source",
  "last_searched"
)

fetch_bc_data <- function(url = BCCC_URL) {
  readr::read_csv(url, show_col_types = FALSE)
}

.seed_url_cols <- function(bccc_subset) {
  bccc_subset |>
    mutate(
      url = if_else(!is.na(WEBSITE) & WEBSITE != "", WEBSITE, NA_character_),
      url_source = if_else(!is.na(url), "bc_dataset", NA_character_),
      last_searched = NA_Date_
    ) |>
    select(all_of(URL_COLS))
}

bootstrap_urls <- function(bccc) {
  .seed_url_cols(bccc)
}

add_new_facilities_urls <- function(urls, bccc) {
  new_ids <- setdiff(bccc$FAC_PARTY_ID, urls$FAC_PARTY_ID)
  if (length(new_ids) == 0L) {
    return(urls)
  }

  new_rows <- bccc |>
    filter(FAC_PARTY_ID %in% new_ids) |>
    .seed_url_cols()

  bind_rows(urls, new_rows)
}

search_duckduckgo <- function(name, city) {
  query <- paste(name, "childcare", city, "BC")
  url <- paste0(
    "https://html.duckduckgo.com/html/?q=",
    utils::URLencode(query, reserved = TRUE)
  )

  resp <- tryCatch(
    httr2::request(url) |>
      httr2::req_headers(
        "User-Agent" = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
      ) |>
      httr2::req_timeout(10) |>
      httr2::req_perform(),
    error = function(e) {
      cli_warn("DuckDuckGo request failed for {name}, {city}: {e$message}")
      NULL
    }
  )

  if (is.null(resp)) return(NA_character_)

  html <- httr2::resp_body_html(resp)
  first_link <- rvest::html_element(html, "a.result__a")
  if (inherits(first_link, "xml_missing")) return(NA_character_)

  href <- rvest::html_attr(first_link, "href")
  uddg <- regmatches(href, regexpr("(?<=uddg=)[^&]+", href, perl = TRUE))
  if (length(uddg) == 1L) utils::URLdecode(uddg) else NA_character_
}

if (!testthat::is_testing()) {
  today <- lubridate::today(tzone = "America/Vancouver")

  cli_alert_info("Fetching BC childcare data...")
  bccc <- fetch_bc_data()
  cli_alert_success("{nrow(bccc)} facilities in today's pull.")

  if (file.exists(URLS_PATH)) {
    cli_alert_info("Reading existing URL file...")
    urls <- readr::read_csv(
      URLS_PATH,
      col_types = readr::cols(
        FAC_PARTY_ID = readr::col_integer(),
        url = readr::col_character(),
        url_source = readr::col_character(),
        last_searched = readr::col_date()
      )
    )
    cli_alert_success("{nrow(urls)} facilities in URL file.")
    urls <- add_new_facilities_urls(urls, bccc)
  } else {
    cli_alert_warning("No URL file found — bootstrapping from BC dataset...")
    urls <- bootstrap_urls(bccc)
  }

  to_search <- urls |> dplyr::filter(is.na(url))
  cli_alert_info("{nrow(to_search)} facilities need URL lookup.")

  if (nrow(to_search) > 0L) {
    cli_progress_bar(
      "Searching DuckDuckGo",
      total = nrow(to_search),
      format = "{pb_bar} {pb_current}/{pb_total} | ETA: {pb_eta}"
    )

    results <- vector("list", nrow(to_search))
    for (i in seq_len(nrow(to_search))) {
      fac_id <- to_search$FAC_PARTY_ID[[i]]
      bccc_row <- bccc |> dplyr::filter(FAC_PARTY_ID == fac_id)
      found_url <- search_duckduckgo(bccc_row$NAME[[1]], bccc_row$CITY[[1]])

      results[[i]] <- tibble::tibble(
        FAC_PARTY_ID = fac_id,
        url = found_url,
        url_source = if (!is.na(found_url)) "duckduckgo" else NA_character_,
        last_searched = today
      )

      cli_progress_update()
      if (i < nrow(to_search)) Sys.sleep(2)
    }

    cli_progress_done()
    urls <- dplyr::rows_update(urls, dplyr::bind_rows(results), by = "FAC_PARTY_ID", unmatched = "error")
  }

  cli_alert_info("Writing {nrow(urls)} facilities to {.file {URLS_PATH}}")
  readr::write_csv(urls, URLS_PATH)
  cli_alert_success("Done.")
}
