---
name: r-tidyverse-style
description: Use when writing R scripts or functions — enforces tidyverse style, cli for output, and testthat patterns. Use when the task involves dplyr, readr, data pipelines, standalone R scripts, or writing/running R tests.
---

# R Tidyverse Style

## Core Rules

**Always use tidyverse packages. Never use base R equivalents.**

| Task | Use | Never use |
|---|---|---|
| Read CSV | `readr::read_csv()` | `read.csv()` |
| Write CSV | `readr::write_csv()` | `write.csv()` |
| Filter rows | `dplyr::filter()` | `subset()` |
| Count/summarise | `dplyr::count()`, `dplyr::summarise()` | `aggregate()`, `table()` |
| Mutate columns | `dplyr::mutate()` | `df$col <-` |
| Select columns | `dplyr::select()` | `df[, c(...)]` |
| Pipe | `|>` | `%>%` |

## Progress Messages — cli, not message()

Always `library(cli)`. Never use `message()` or `glue()` for output.

```r
# ✅ correct
cli_alert_info("Fetching data for {today}...")
cli_alert_success("{nrow(df)} rows loaded.")
cli_alert_warning("No history found — bootstrapping...")
cli_alert_danger("Failed to connect.")

# ❌ wrong
message(glue("Fetching data for {today}..."))
message("Done.")
```

cli interpolates `{}` natively — no `glue()` needed. Use `{.file {path}}`, `{.val {n}}`, `{.pkg pkg}` for semantic formatting.

## Tests — testthat

Test files load libraries and source the script under test:

```r
# tests/test-myscript.R
library(testthat)
library(tibble)
source("../myscript.R")          # testthat::is_testing() returns TRUE here

test_that("filter keeps active rows", {
  df <- tibble(status = c("active", "inactive"))
  result <- filter(df, status == "active")
  expect_equal(nrow(result), 1L)
})
```

Run from repo root:
```bash
Rscript -e "testthat::test_file('tests/test-myscript.R')"
```

Guard the main execution block in scripts with `testthat::is_testing()` so tests can source the file without running it:

```r
if (!testthat::is_testing()) {
  # main execution
}
```

## Script Structure

```r
library(dplyr)
library(readr)
library(lubridate)
library(cli)

# SCREAMING_SNAKE_CASE for top-level constants
INPUT_URL   <- "https://..."
OUTPUT_PATH <- "data/result.csv"

# Pure functions first — testable, no side effects
process <- function(df) {
  df |>
    filter(status == "active") |>
    count(city)
}

# Main block guarded at bottom
if (!testthat::is_testing()) {
  cli_alert_info("Reading data...")
  df <- read_csv(INPUT_URL, show_col_types = FALSE)
  result <- process(df)
  write_csv(result, OUTPUT_PATH)
  cli_alert_success("Written to {.file {OUTPUT_PATH}}")
}
```

## Key Patterns

**`if_else()` not `ifelse()`** — type-safe, handles NA correctly:
```r
mutate(flag = if_else(status == "Y", TRUE, NA))
```

**Explicit NA types** — `NA_Date_`, `NA_character_`, `NA_integer_`, `NA_real_` in mutate/tibble contexts.

**`all_of()` for column vectors** — avoids ambiguity warnings:
```r
select(all_of(my_cols))
```
