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
# Requests are throttled and run sequentially because DDG's HTML endpoint
# returns anti-bot challenge pages (HTTP 202) under burst load. Results are
# written to disk every DDG_BATCH_SIZE facilities so the script can be
# interrupted and resumed without losing progress. Facilities whose request
# is blocked (non-200, missing result markup) are NOT marked last_searched,
# so they're retried on the next run rather than locked out for DDG_RETRY_DAYS.
#
# Tuning knobs:
#   DDG_THROTTLE_SECS     — seconds between DuckDuckGo requests. Lower = faster
#                           but more likely to trigger rate limiting.
#   DDG_BATCH_SIZE        — facilities per write checkpoint. Lower = more frequent
#                           saves, slightly more disk I/O.
#   DDG_RETRY_DAYS        — days before re-searching a facility that previously
#                           returned no URL. Set higher to reduce redundant searches.
#   DDG_MAX_RUNTIME_SECS  — wall-clock budget for the search loop. Script
#                           checkpoints and exits cleanly when reached so the
#                           monthly cron stays under the GHA 6h job limit.
#   DDG_MAX_CONSEC_BLOCKS — abort the run after this many consecutive blocked
#                           responses (DDG is rate-limiting our IP).

library(dplyr)
library(readr)
library(lubridate)
library(httr2)
library(rvest)
library(cli)
library(testthat)

BCCC_URL <- "https://catalogue.data.gov.bc.ca/dataset/4cc207cc-ff03-44f8-8c5f-415af5224646/resource/9a9f14e1-03ea-4a11-936a-6e77b15eeb39/download/childcare_locations.csv"
URLS_PATH <- "data/facility_urls.csv"
# At DDG_THROTTLE_SECS=3, searching ~5800 facilities takes ~4.8h.
# DDG_MAX_RUNTIME_SECS=18000 (5h) leaves ~1h headroom under GHA's 6h job limit.
# DDG_MAX_CONSEC_BLOCKS=100 tolerates ~5 min of transient blocking (100 × 3s)
# before giving up, so a temporary IP cooldown doesn't abort the whole run.
DDG_THROTTLE_SECS     <- as.numeric(Sys.getenv("DDG_THROTTLE_SECS",     "3"))    # seconds between sequential DDG requests
DDG_BATCH_SIZE        <- as.integer(Sys.getenv("DDG_BATCH_SIZE",        "100"))  # facilities per write checkpoint
DDG_RETRY_DAYS        <- as.integer(Sys.getenv("DDG_RETRY_DAYS",        "150"))  # days before re-searching a facility that returned NA
DDG_MAX_RUNTIME_SECS  <- as.numeric(Sys.getenv("DDG_MAX_RUNTIME_SECS",  "18000")) # 5h, leaves headroom under GHA 6h job limit
DDG_MAX_CONSEC_BLOCKS <- as.integer(Sys.getenv("DDG_MAX_CONSEC_BLOCKS", "100"))  # abort after this many consecutive blocked responses

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
# req_throttle enforces DDG_THROTTLE_SECS between requests in the "duckduckgo"
# realm, even across many request objects, to avoid triggering rate limits.
# req_error(is_error = FALSE) lets the parser see the raw response so it can
# distinguish "no results" from "blocked by anti-bot".
.build_ddg_request <- function(name, city) {
  query <- paste(name, city, "British Columbia daycare childcare preschool")
  url <- paste0(
    "https://html.duckduckgo.com/html/?q=",
    utils::URLencode(query, reserved = TRUE)
  )
  httr2::request(url) |>
    httr2::req_headers(
      "User-Agent" = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
    ) |>
    httr2::req_timeout(10) |>
    httr2::req_throttle(rate = 1 / DDG_THROTTLE_SECS, realm = "duckduckgo") |>
    httr2::req_error(is_error = \(resp) FALSE)
}

# Classifies a DuckDuckGo HTML response and extracts the first result URL.
# Returns list(url, status) where status is one of:
#   "found"      - a result URL was extracted
#   "no_results" - DDG responded normally but had no parseable result links
#   "blocked"    - non-200 status, transport error, or anti-bot challenge page
# The caller MUST treat "blocked" specially: do not record last_searched, so
# the facility is retried next run rather than locked out for DDG_RETRY_DAYS.
.parse_ddg_response <- function(resp) {
  if (is.null(resp) || inherits(resp, "error")) {
    return(list(url = NA_character_, status = "blocked"))
  }
  if (httr2::resp_status(resp) != 200L) {
    return(list(url = NA_character_, status = "blocked"))
  }
  html <- httr2::resp_body_html(resp)
  first_link <- rvest::html_element(html, "a.result__a")
  if (inherits(first_link, "xml_missing")) {
    # 200 OK but no result markup. Could be a genuine zero-result page or a
    # disguised challenge page; either way we can't extract a URL. Treat as
    # blocked to be safe — better to re-search than to lock out for 150 days.
    return(list(url = NA_character_, status = "blocked"))
  }
  href <- rvest::html_attr(first_link, "href")
  uddg <- regmatches(href, regexpr("(?<=uddg=)[^&]+", href, perl = TRUE))
  if (length(uddg) != 1L) {
    return(list(url = NA_character_, status = "no_results"))
  }
  list(url = utils::URLdecode(uddg), status = "found")
}

# Convenience wrapper used in tests and one-off lookups. Returns the URL
# string (or NA) for backwards compatibility with callers that don't care
# about block vs. no-results.
search_duckduckgo <- function(name, city) {
  resp <- tryCatch(
    .build_ddg_request(name, city) |> httr2::req_perform(),
    error = function(e) {
      cli_warn("DuckDuckGo request failed for {name}, {city}: {conditionMessage(e)}")
      NULL
    }
  )
  .parse_ddg_response(resp)$url
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

  n_found <- 0L
  n_no_results <- 0L
  n_blocked <- 0L
  consec_blocks <- 0L
  abort_reason <- NULL
  run_start <- Sys.time()

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
      if (!is.null(abort_reason)) break
      batch <- to_search[idx, ]
      bccc_batch <- bccc |> filter(FAC_PARTY_ID %in% batch$FAC_PARTY_ID)

      batch_results <- list()
      for (i in seq_len(nrow(batch))) {
        elapsed <- as.numeric(difftime(Sys.time(), run_start, units = "secs"))
        if (elapsed > DDG_MAX_RUNTIME_SECS) {
          abort_reason <- cli::format_inline("runtime budget reached ({round(elapsed)}s > {DDG_MAX_RUNTIME_SECS}s)")
          break
        }
        if (consec_blocks >= DDG_MAX_CONSEC_BLOCKS) {
          abort_reason <- cli::format_inline("{consec_blocks} consecutive blocked responses (DDG rate-limiting)")
          break
        }

        row <- bccc_batch |> filter(FAC_PARTY_ID == batch$FAC_PARTY_ID[[i]])
        resp <- tryCatch(
          .build_ddg_request(row$NAME[[1]], row$CITY[[1]]) |> httr2::req_perform(),
          error = function(e) NULL
        )
        parsed <- .parse_ddg_response(resp)

        if (parsed$status == "found") {
          n_found <- n_found + 1L
          consec_blocks <- 0L
        } else if (parsed$status == "no_results") {
          n_no_results <- n_no_results + 1L
          consec_blocks <- 0L
        } else {
          n_blocked <- n_blocked + 1L
          consec_blocks <- consec_blocks + 1L
        }

        # Only record a result row when the request actually completed. Blocked
        # rows are left untouched so they're retried on the next run instead of
        # being locked out for DDG_RETRY_DAYS days.
        if (parsed$status != "blocked") {
          batch_results[[length(batch_results) + 1L]] <- tibble::tibble(
            FAC_PARTY_ID = batch$FAC_PARTY_ID[[i]],
            url = parsed$url,
            url_source = if (!is.na(parsed$url)) "duckduckgo" else NA_character_,
            last_searched = today
          )
        }

        cli_progress_update(inc = 1)
      }

      if (length(batch_results) > 0L) {
        urls <- rows_update(urls, bind_rows(batch_results), by = "FAC_PARTY_ID", unmatched = "error")
        readr::write_csv(urls, URLS_PATH)
      }
    }

    cli_progress_done()
  }

  cli_alert_info("Found: {n_found} | No results: {n_no_results} | Blocked: {n_blocked}")
  if (!is.null(abort_reason)) {
    cli_alert_warning("Aborted early: {abort_reason}. Re-run to continue.")
  }
  cli_alert_success("Done. {nrow(urls)} facilities written to {.file {URLS_PATH}}.")
}
