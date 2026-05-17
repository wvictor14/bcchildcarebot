# Vacancy History Display Design

**Date:** 2026-05-17

## Summary

Surface `last_vacancy_*` dates from `data/vacancy_history.csv` in the leaflet map popups and the reactable table row detail. Simultaneously remove the redundant `ever_vacancy_*` columns from the history schema, script, CSV, and tests. Add a `fast_render` Quarto parameter and a dashboard smoke test.

## Change Areas

### 1. `update_history.R` — remove `ever_vacancy_*`

- Remove the four `ever_vacancy_*` entries from `HISTORY_COLS`.
- Remove the corresponding `mutate()` lines from `bootstrap_history()`, `add_new_facilities()`, and `update_vacancies()`.
- No logic changes. `HISTORY_COLS` goes from 11 to 7 columns: `FAC_PARTY_ID`, `is_active`, `date_first_seen`, `last_vacancy_under36`, `last_vacancy_30mos_5yrs`, `last_vacancy_licpre`, `last_vacancy_gr1_age12`.

### 2. `data/vacancy_history.csv` — drop redundant columns

- Drop the four `ever_vacancy_*` columns from the existing CSV in-place using R (no re-fetch from API).

### 3. `tests/test-update_history.R` — update for schema change

- Remove all assertions on `ever_vacancy_*` columns.
- Rewrite tests whose sole purpose was asserting `ever_vacancy_*` to instead assert the equivalent `last_vacancy_*` behavior (non-NA date when vacancy is Y, NA when N).
- Tests that asserted `names(result) == HISTORY_COLS` continue to work unchanged since `HISTORY_COLS` itself is updated.

### 4. `dashboard.qmd` — load and display history

**Data layer (`load_data` chunk):**

Load history guarded by `file.exists()`, then left-join `last_vacancy_*` columns onto `bccc` by `FAC_PARTY_ID`. If the file is absent, the four columns default to `NA_Date_` and all downstream display gracefully omits dates.

```r
history_cols <- c(
  "FAC_PARTY_ID",
  "last_vacancy_under36",
  "last_vacancy_30mos_5yrs",
  "last_vacancy_licpre",
  "last_vacancy_gr1_age12"
)

if (file.exists("data/vacancy_history.csv")) {
  history <- readr::read_csv(
    "data/vacancy_history.csv",
    col_types = readr::cols(
      FAC_PARTY_ID = readr::col_integer(),
      last_vacancy_under36 = readr::col_date(),
      last_vacancy_30mos_5yrs = readr::col_date(),
      last_vacancy_licpre = readr::col_date(),
      last_vacancy_gr1_age12 = readr::col_date(),
      .default = readr::col_skip()
    )
  ) |>
    select(all_of(history_cols))
  bccc <- left_join(bccc, history, by = "FAC_PARTY_ID")
} else {
  bccc[setdiff(history_cols, "FAC_PARTY_ID")] <- NA_Date_
}
```

**Popup (`setup_tbl_data` chunk):**

Update the `glue()` string to append the last vacancy date in parentheses when available, e.g.:

```
<36 months: Y (last seen 2026-05-16)
<36 months: N
```

Use `format(last_vacancy_under36, "%Y-%m-%d")` for date formatting; when the date is `NA`, omit the parenthetical.

**Table row detail (`render_reactable` chunk):**

In `row_details()`, add a "Last vacancy" column to the nested vacancy pivot table. The pivot currently produces `Age Group` and `Vacancy?` columns; add a third column sourced from the appropriate `last_vacancy_*` column, showing the date as a string or `"Never"` when `NA`.

**`fast_render` parameter (`setup_tbl_data` chunk):**

Add to YAML front matter:

```yaml
params:
  fast_render: false
```

In `setup_tbl_data`, after computing `dataset_last_update`, apply the filter conditionally:

```r
if (isTRUE(params$fast_render)) {
  tbl_data <- tbl_data |>
    filter(VACANCY_LAST_UPDATE >= dataset_last_update - 3)
}
```

### 5. `tests/test-dashboard.R` (new file)

Smoke test that renders the dashboard with `fast_render = TRUE` and asserts `dashboard.html` is produced. The test must be run from the project root (not from `tests/`) since `quarto_render` uses relative paths. Use `withr::with_dir()` to ensure the correct working directory:

```r
library(testthat)

test_that("dashboard renders without error", {
  skip_if_not_installed("quarto")
  withr::with_dir("..", {
    quarto::quarto_render(
      "dashboard.qmd",
      execute_params = list(fast_render = TRUE)
    )
    expect_true(file.exists("dashboard.html"))
  })
})
```

Runs in CI. Fast due to `fast_render = TRUE` filtering the dataset to the most recent 3 days.

## What is not in scope

- Time-series vacancy charts (requires richer daily snapshot storage).
- Showing `date_first_seen` or `is_active` in the dashboard UI.
- Changes to the GitHub Actions publish workflow.
