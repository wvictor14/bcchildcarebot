# Facility URL Discovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a monthly GHA pipeline that discovers website URLs for all ~5,900 BC childcare facilities via DuckDuckGo HTML scraping and stores results in `data/facility_urls.csv`.

**Architecture:** A standalone `find_urls.R` script (mirroring `update_history.R`) handles bootstrapping from the BC dataset's `WEBSITE` field, appending new facilities, and filling missing URLs via DuckDuckGo. A new monthly GHA workflow runs the script and commits the CSV.

**Tech Stack:** R, tidyverse, httr2, rvest, cli, testthat; GitHub Actions

---

## File Map

| File | Action | Purpose |
|---|---|---|
| `find_urls.R` | Create | Main script: constants, pure functions, main block |
| `tests/test-find_urls.R` | Create | Unit tests for pure functions |
| `.github/workflows/find_urls.yml` | Create | Monthly GHA workflow |

---

### Task 1: Bootstrap and schema

**Files:**
- Create: `find_urls.R` (constants + `bootstrap_urls()` only)
- Create: `tests/test-find_urls.R`

- [ ] **Step 1: Write the failing tests**

Create `tests/test-find_urls.R`:

```r
library(testthat)
library(tibble)
library(dplyr)
source("../find_urls.R")

make_bccc <- function(id, name = "Happy Kids", city = "Vancouver", website = NA_character_) {
  tibble(
    FAC_PARTY_ID = as.integer(id),
    NAME = name,
    CITY = city,
    WEBSITE = website
  )
}

# --- bootstrap_urls ---

test_that("bootstrap_urls returns one row per facility", {
  bccc <- bind_rows(make_bccc(1L), make_bccc(2L), make_bccc(3L))
  result <- bootstrap_urls(bccc)
  expect_equal(nrow(result), 3L)
  expect_equal(result$FAC_PARTY_ID, 1:3L)
})

test_that("bootstrap_urls has all required columns", {
  result <- bootstrap_urls(make_bccc(1L))
  expect_equal(names(result), URL_COLS)
})

test_that("bootstrap_urls uses WEBSITE from BC dataset when present", {
  bccc <- make_bccc(1L, website = "https://happykids.ca")
  result <- bootstrap_urls(bccc)
  expect_equal(result$url, "https://happykids.ca")
  expect_equal(result$url_source, "bc_dataset")
})

test_that("bootstrap_urls sets url to NA when WEBSITE is missing", {
  result <- bootstrap_urls(make_bccc(1L))
  expect_true(is.na(result$url))
  expect_true(is.na(result$url_source))
})

test_that("bootstrap_urls sets last_searched to NA for all rows", {
  bccc <- bind_rows(make_bccc(1L, website = "https://example.com"), make_bccc(2L))
  result <- bootstrap_urls(bccc)
  expect_true(all(is.na(result$last_searched)))
})
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /home/vyuan/workspace/bcchildcarebot && Rscript -e "testthat::test_file('tests/test-find_urls.R')"
```

Expected: errors — `find_urls.R` does not exist yet.

- [ ] **Step 3: Create `find_urls.R` with constants and `bootstrap_urls()`**

```r
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

bootstrap_urls <- function(bccc) {
  bccc |>
    mutate(
      url = if_else(!is.na(WEBSITE) & WEBSITE != "", WEBSITE, NA_character_),
      url_source = if_else(!is.na(url), "bc_dataset", NA_character_),
      last_searched = NA_Date_
    ) |>
    select(all_of(URL_COLS))
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /home/vyuan/workspace/bcchildcarebot && Rscript -e "testthat::test_file('tests/test-find_urls.R')"
```

Expected: all 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add find_urls.R tests/test-find_urls.R
git commit -m "feat: add find_urls.R bootstrap and schema"
```

---

### Task 2: Add new facility handling

**Files:**
- Modify: `find_urls.R` — add `add_new_facilities_urls()`
- Modify: `tests/test-find_urls.R` — add tests

- [ ] **Step 1: Write the failing tests**

Append to `tests/test-find_urls.R`:

```r
# --- add_new_facilities_urls ---

test_that("add_new_facilities_urls returns urls unchanged when no new facilities", {
  bccc <- make_bccc(1L)
  urls <- bootstrap_urls(bccc)
  result <- add_new_facilities_urls(urls, bccc)
  expect_equal(nrow(result), 1L)
  expect_equal(result$FAC_PARTY_ID, 1L)
})

test_that("add_new_facilities_urls adds row for new facility not in urls", {
  urls <- bootstrap_urls(make_bccc(1L))
  bccc_new <- bind_rows(make_bccc(1L), make_bccc(2L))
  result <- add_new_facilities_urls(urls, bccc_new)
  expect_equal(nrow(result), 2L)
  expect_true(2L %in% result$FAC_PARTY_ID)
})

test_that("add_new_facilities_urls seeds url from BC dataset for new facility with website", {
  urls <- bootstrap_urls(make_bccc(1L))
  bccc_new <- bind_rows(make_bccc(1L), make_bccc(2L, website = "https://new.ca"))
  result <- add_new_facilities_urls(urls, bccc_new)
  new_row <- filter(result, FAC_PARTY_ID == 2L)
  expect_equal(new_row$url, "https://new.ca")
  expect_equal(new_row$url_source, "bc_dataset")
})

test_that("add_new_facilities_urls sets url to NA for new facility without website", {
  urls <- bootstrap_urls(make_bccc(1L))
  bccc_new <- bind_rows(make_bccc(1L), make_bccc(2L))
  result <- add_new_facilities_urls(urls, bccc_new)
  new_row <- filter(result, FAC_PARTY_ID == 2L)
  expect_true(is.na(new_row$url))
  expect_true(is.na(new_row$url_source))
  expect_true(is.na(new_row$last_searched))
})

test_that("add_new_facilities_urls preserves URL_COLS column order", {
  urls <- bootstrap_urls(make_bccc(1L))
  result <- add_new_facilities_urls(urls, bind_rows(make_bccc(1L), make_bccc(2L)))
  expect_equal(names(result), URL_COLS)
})
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /home/vyuan/workspace/bcchildcarebot && Rscript -e "testthat::test_file('tests/test-find_urls.R')"
```

Expected: 5 new failures — `add_new_facilities_urls` not defined.

- [ ] **Step 3: Implement `add_new_facilities_urls()`**

Add to `find_urls.R` after `bootstrap_urls`:

```r
add_new_facilities_urls <- function(urls, bccc) {
  new_ids <- setdiff(bccc$FAC_PARTY_ID, urls$FAC_PARTY_ID)
  if (length(new_ids) == 0L) {
    return(urls)
  }

  new_rows <- bccc |>
    filter(FAC_PARTY_ID %in% new_ids) |>
    mutate(
      url = if_else(!is.na(WEBSITE) & WEBSITE != "", WEBSITE, NA_character_),
      url_source = if_else(!is.na(url), "bc_dataset", NA_character_),
      last_searched = NA_Date_
    ) |>
    select(all_of(URL_COLS))

  bind_rows(urls, new_rows)
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /home/vyuan/workspace/bcchildcarebot && Rscript -e "testthat::test_file('tests/test-find_urls.R')"
```

Expected: all 10 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add find_urls.R tests/test-find_urls.R
git commit -m "feat: add new facility handling to find_urls"
```

---

### Task 3: DuckDuckGo search function

**Files:**
- Modify: `find_urls.R` — add `search_duckduckgo()`

This function makes live HTTP requests and is not unit tested. Manual smoke test is sufficient.

- [ ] **Step 1: Implement `search_duckduckgo()`**

Add to `find_urls.R` after `add_new_facilities_urls`:

```r
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
    error = function(e) NULL
  )

  if (is.null(resp)) return(NA_character_)

  html <- httr2::resp_body_html(resp)
  first_link <- rvest::html_element(html, "a.result__a")
  if (inherits(first_link, "xml_missing")) return(NA_character_)

  rvest::html_attr(first_link, "href")
}
```

- [ ] **Step 2: Smoke test with a known facility**

```r
Rscript -e "
  source('find_urls.R')
  result <- search_duckduckgo('YMCA', 'Vancouver')
  cat('Result:', result, '\n')
"
```

Expected: a URL string (e.g. `https://ymca.ca/...`) or `NA` if DDG blocks the request.

- [ ] **Step 3: Commit**

```bash
git add find_urls.R
git commit -m "feat: add DuckDuckGo search function"
```

---

### Task 4: Main script block

**Files:**
- Modify: `find_urls.R` — add main execution block

- [ ] **Step 1: Add the main block to `find_urls.R`**

Append to `find_urls.R`:

```r
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
      format = "{cli::pb_bar} {cli::pb_current}/{cli::pb_total} | ETA: {cli::pb_eta}"
    )

    for (i in seq_len(nrow(to_search))) {
      fac_id <- to_search$FAC_PARTY_ID[[i]]
      bccc_row <- bccc |> dplyr::filter(FAC_PARTY_ID == fac_id)
      found_url <- search_duckduckgo(bccc_row$NAME[[1]], bccc_row$CITY[[1]])

      urls <- urls |>
        dplyr::mutate(
          url = dplyr::if_else(FAC_PARTY_ID == fac_id, found_url, url),
          url_source = dplyr::if_else(
            FAC_PARTY_ID == fac_id & !is.na(found_url),
            "duckduckgo",
            url_source
          ),
          last_searched = dplyr::if_else(
            FAC_PARTY_ID == fac_id,
            today,
            last_searched
          )
        )

      cli_progress_update()
      Sys.sleep(2)
    }

    cli_progress_done()
  }

  cli_alert_info("Writing {nrow(urls)} facilities to {.file {URLS_PATH}}")
  readr::write_csv(urls, URLS_PATH)
  cli_alert_success("Done.")
}
```

- [ ] **Step 2: Smoke test with a small subset (do not run full 5,900)**

```bash
cd /home/vyuan/workspace/bcchildcarebot && Rscript -e "
  library(dplyr); library(readr); library(lubridate); library(httr2)
  library(rvest); library(cli); library(testthat)
  source('find_urls.R')
  today <- lubridate::today(tzone = 'America/Vancouver')
  bccc <- fetch_bc_data() |> slice_head(n = 3)
  urls <- bootstrap_urls(bccc)
  to_search <- urls |> filter(is.na(url))
  cat('Facilities to search:', nrow(to_search), '\n')
  for (i in seq_len(nrow(to_search))) {
    fac_id <- to_search\$FAC_PARTY_ID[[i]]
    bccc_row <- bccc |> filter(FAC_PARTY_ID == fac_id)
    found <- search_duckduckgo(bccc_row\$NAME[[1]], bccc_row\$CITY[[1]])
    cat(bccc_row\$NAME[[1]], '->', found, '\n')
    Sys.sleep(2)
  }
"
```

Expected: 3 facility names with URLs or NA printed, no errors.

- [ ] **Step 3: Commit**

```bash
git add find_urls.R
git commit -m "feat: add main execution block to find_urls"
```

---

### Task 5: GitHub Actions workflow

**Files:**
- Create: `.github/workflows/find_urls.yml`

- [ ] **Step 1: Create the workflow file**

```yaml
name: Find Facility URLs

on:
  schedule:
    - cron: '0 16 1 * *'  # 4:00 AM UTC on the 1st of each month
  workflow_dispatch:

jobs:
  find-urls:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - name: Setup R
        uses: r-lib/actions/setup-r@v2
        with:
          r-version: '4.6.0'

      - name: Install system dependencies
        run: sudo apt-get install -y libudunits2-dev libcurl4-openssl-dev libgdal-dev

      - name: Install R dependencies
        uses: r-lib/actions/setup-renv@v2

      - name: Find facility URLs
        run: Rscript find_urls.R

      - name: Commit and push
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add data/facility_urls.csv
          git diff --staged --quiet || git commit -m "[skip ci] update facility URLs $(date -u +%Y-%m-%d)"
          git push
```

- [ ] **Step 2: Verify workflow parses correctly**

```bash
cd /home/vyuan/workspace/bcchildcarebot && python3 -c "import yaml; yaml.safe_load(open('.github/workflows/find_urls.yml'))" && echo "YAML valid"
```

Expected: `YAML valid`

- [ ] **Step 3: Install missing R packages (httr2, rvest) into renv if needed**

```bash
cd /home/vyuan/workspace/bcchildcarebot && Rscript -e "
  pkgs <- c('httr2', 'rvest')
  missing <- pkgs[!sapply(pkgs, requireNamespace, quietly = TRUE)]
  if (length(missing) > 0) {
    install.packages(missing)
    renv::snapshot()
  } else {
    cat('All packages already available\n')
  }
"
```

Expected: packages available and `renv.lock` updated if any were missing.

- [ ] **Step 4: Run full test suite to confirm no regressions**

```bash
cd /home/vyuan/workspace/bcchildcarebot && Rscript -e "testthat::test_dir('tests')"
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/find_urls.yml renv.lock
git commit -m "feat: add monthly find_urls GHA workflow"
```
