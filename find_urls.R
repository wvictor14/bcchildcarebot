# find_urls.R
#
# Discovers website URLs for BC childcare facilities and stores them in
# data/facility_urls.csv. Run manually with `Rscript find_urls.R` or
# automatically via the monthly GitHub Actions workflow (find_urls.yml).
#
# On first run (no CSV): bootstraps from the BC dataset's WEBSITE field,
# then searches DuckDuckGo for every facility still missing a URL.
#
# On subsequent runs: skips facilities that already have a URL, and skips
# facilities searched within the last DDG_RETRY_DAYS days. Re-searches
# older NA results in case a daycare has since built a website.
#
# Results are written to disk after every DDG_BATCH_SIZE facilities so the
# script can be interrupted and resumed without losing progress.
#
# Tuning knobs:
#   DDG_POOL        — concurrent DuckDuckGo requests per batch. Higher = faster
#                     but more likely to trigger rate limiting.
#   DDG_BATCH_SIZE  — facilities per write checkpoint. Lower = more frequent
#                     saves, slightly more disk I/O.
#   DDG_RETRY_DAYS  — days before re-searching a facility that previously
#                     returned no URL. Set higher to reduce redundant searches.

library(dplyr)
library(readr)
library(lubridate)
library(httr2)
library(rvest)
library(cli)
library(testthat)

BCCC_URL <- "https://catalogue.data.gov.bc.ca/dataset/4cc207cc-ff03-44f8-8c5f-415af5224646/resource/9a9f14e1-03ea-4a11-936a-6e77b15eeb39/download/childcare_locations.csv"
URLS_PATH <- "data/facility_urls.csv"
DDG_POOL <- 20L        # max_active concurrent requests; reduce if DDG starts blocking
DDG_BATCH_SIZE <- 100L # facilities per write checkpoint
DDG_RETRY_DAYS <- 150L # days before re-searching a facility that returned NA

URL_COLS <- c(
  "FAC_PARTY_ID",
  "url",
  "url_source",
  "last_searched"
)

fetch_bc_data <- function(url = BCCC_URL) {
  readr::read_csv(url, show_col_types = FALSE)
}

# Seeds url/url_source/last_searched columns from the BC dataset's WEBSITE
# field. Called on bootstrap and when adding new facilities.
.seed_url_cols <- function(bccc_subset) {
  bccc_subset |>
    mutate(
      url = if_else(!is.na(WEBSITE) & WEBSITE != "", WEBSITE, NA_character_),
      url_source = if_else(!is.na(url), "bc_dataset", NA_character_),
      last_searched = NA_Date_
    ) |>
    select(all_of(URL_COLS))
}

# Creates the initial facility_urls.csv from today's BC dataset pull.
# Facilities already having a WEBSITE are marked url_source = "bc_dataset".
# All others get url = NA and will be queued for DuckDuckGo search.
bootstrap_urls <- function(bccc) {
  .seed_url_cols(bccc)
}

# Appends rows for facilities present in today's BC pull but absent from the
# stored CSV (i.e. newly opened facilities). Seeds their URLs from WEBSITE
# where available, same as bootstrap.
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

# Builds a DuckDuckGo HTML search request for a single facility.
# Uses the plain HTML endpoint (not the JS app) so rvest can parse results.
# req_error(is_error = FALSE) prevents httr2 from throwing on non-2xx responses
# so req_perform_parallel can collect all results instead of stopping on error.
.build_ddg_request <- function(name, city) {
  query <- paste(name, "childcare", city, "BC")
  url <- paste0(
    "https://html.duckduckgo.com/html/?q=",
    utils::URLencode(query, reserved = TRUE)
  )
  httr2::request(url) |>
    httr2::req_headers(
      "User-Agent" = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
    ) |>
    httr2::req_timeout(10) |>
    httr2::req_error(is_error = \(resp) FALSE)
}

# Extracts the destination URL from a DuckDuckGo HTML response.
# DDG wraps outbound links as //duckduckgo.com/l/?uddg=<encoded-url>&...,
# so we pull the uddg parameter rather than using the raw href.
.parse_ddg_response <- function(resp) {
  if (is.null(resp) || inherits(resp, "error")) return(NA_character_)
  html <- httr2::resp_body_html(resp)
  first_link <- rvest::html_element(html, "a.result__a")
  if (inherits(first_link, "xml_missing")) return(NA_character_)
  href <- rvest::html_attr(first_link, "href")
  uddg <- regmatches(href, regexpr("(?<=uddg=)[^&]+", href, perl = TRUE))
  if (length(uddg) == 1L) utils::URLdecode(uddg) else NA_character_
}

# Convenience wrapper used in tests and one-off lookups. The main script
# uses .build_ddg_request + req_perform_parallel for parallel batch execution.
search_duckduckgo <- function(name, city) {
  resp <- tryCatch(
    .build_ddg_request(name, city) |> httr2::req_perform(),
    error = function(e) {
      cli_warn("DuckDuckGo request failed for {name}, {city}: {conditionMessage(e)}")
      NULL
    }
  )
  .parse_ddg_response(resp)
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

  # Queue facilities with no URL that have either never been searched or were
  # last searched more than DDG_RETRY_DAYS ago (giving new websites a chance
  # to appear in DDG results).
  retry_cutoff <- today - DDG_RETRY_DAYS
  to_search <- urls |> filter(is.na(url) & (is.na(last_searched) | last_searched < retry_cutoff))
  cli_alert_info("{nrow(to_search)} facilities need URL lookup.")

  if (nrow(to_search) > 0L) {
    batches <- split(
      seq_len(nrow(to_search)),
      ceiling(seq_len(nrow(to_search)) / DDG_BATCH_SIZE)
    )

    cli_progress_bar(
      "Searching DuckDuckGo",
      total = nrow(to_search),
      format = "{pb_bar} {pb_current}/{pb_total} | ETA: {pb_eta}"
    )

    for (idx in batches) {
      batch <- to_search[idx, ]
      bccc_batch <- bccc |> filter(FAC_PARTY_ID %in% batch$FAC_PARTY_ID)

      reqs <- lapply(seq_len(nrow(batch)), function(i) {
        row <- bccc_batch |> filter(FAC_PARTY_ID == batch$FAC_PARTY_ID[[i]])
        .build_ddg_request(row$NAME[[1]], row$CITY[[1]])
      })

      resps <- httr2::req_perform_parallel(reqs, max_active = DDG_POOL, on_error = "continue", progress = FALSE)

      results <- lapply(seq_len(nrow(batch)), function(i) {
        found_url <- .parse_ddg_response(resps[[i]])
        tibble::tibble(
          FAC_PARTY_ID = batch$FAC_PARTY_ID[[i]],
          url = found_url,
          url_source = if (!is.na(found_url)) "duckduckgo" else NA_character_,
          last_searched = today
        )
      })

      urls <- rows_update(urls, bind_rows(results), by = "FAC_PARTY_ID", unmatched = "error")
      readr::write_csv(urls, URLS_PATH)
      cli_progress_update(inc = nrow(batch))
    }

    cli_progress_done()
  }

  cli_alert_success("Done. {nrow(urls)} facilities written to {.file {URLS_PATH}}.")
}
