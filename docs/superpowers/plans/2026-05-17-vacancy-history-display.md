# Vacancy History Display Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface `last_vacancy_*` dates in the leaflet popup and table row detail, remove the redundant `ever_vacancy_*` columns from the history schema, and add a `fast_render` Quarto parameter with a dashboard smoke test.

**Architecture:** Join `data/vacancy_history.csv` onto the live BC data at render time (guarded by `file.exists()`). The four `last_vacancy_*` date columns propagate through the existing `tbl_data` pipeline automatically via case-insensitive `contains('VACANCY_')` selects. The popup and row-detail vacancy table are updated to display the dates. The `ever_vacancy_*` columns are stripped from the history script, CSV, and tests as redundant.

**Tech Stack:** R, Quarto, dplyr, readr, glue, reactable, leaflet, testthat

---

## File Map

| File | Action | What changes |
|------|--------|--------------|
| `update_history.R` | Modify | Remove `ever_vacancy_*` from `HISTORY_COLS` and all three mutate functions |
| `data/vacancy_history.csv` | Modify | Drop the four `ever_vacancy_*` columns |
| `tests/test-update_history.R` | Modify | Remove `ever_vacancy_*` assertions; rewrite two tests |
| `dashboard.qmd` | Modify | Load history, update popup glue, update row-detail vacancy table, add `fast_render` param |
| `tests/test-dashboard.R` | Create | Smoke test that renders the dashboard with `fast_render = TRUE` |

---

### Task 1: Update tests for the new 7-column history schema

**Files:**
- Modify: `tests/test-update_history.R`

- [ ] **Step 1: Update `HISTORY_COLS` in `update_history.R`**

This step is needed first because the test file `source()`s `update_history.R` and the test `expect_equal(names(result), HISTORY_COLS)` compares against the constant. Open `update_history.R` and replace lines 10–22:

```r
HISTORY_COLS <- c(
  "FAC_PARTY_ID",
  "is_active",
  "date_first_seen",
  "last_vacancy_under36",
  "last_vacancy_30mos_5yrs",
  "last_vacancy_licpre",
  "last_vacancy_gr1_age12"
)
```

- [ ] **Step 2: Rewrite the two bootstrap tests that referenced `ever_vacancy_*`**

In `tests/test-update_history.R`, replace lines 30–43 with:

```r
test_that("bootstrap_history sets last_vacancy to today when vacancy is Y", {
  bccc <- make_bccc(1L, under36 = "Y", licpre = "Y")
  result <- bootstrap_history(bccc, today = as.Date("2026-05-16"))
  expect_equal(result$last_vacancy_under36, as.Date("2026-05-16"))
  expect_equal(result$last_vacancy_licpre, as.Date("2026-05-16"))
})

test_that("bootstrap_history sets last_vacancy to NA when vacancy is N", {
  result <- bootstrap_history(make_bccc(1L), today = as.Date("2026-05-16"))
  expect_true(is.na(result$last_vacancy_under36))
})
```

- [ ] **Step 3: Remove `ever_vacancy_*` assertions from `add_new_facilities` tests**

In `tests/test-update_history.R`, replace lines 65–83 with:

```r
test_that("add_new_facilities adds new facility with today as date_first_seen", {
  history <- bootstrap_history(make_bccc(1L), today = as.Date("2026-05-15"))
  bccc_new <- bind_rows(make_bccc(1L), make_bccc(2L, under36 = "Y"))
  result <- add_new_facilities(history, bccc_new, today = as.Date("2026-05-16"))
  expect_equal(nrow(result), 2L)
  new_row <- filter(result, FAC_PARTY_ID == 2L)
  expect_equal(new_row$date_first_seen, as.Date("2026-05-16"))
  expect_equal(new_row$last_vacancy_under36, as.Date("2026-05-16"))
})

test_that("add_new_facilities sets last_vacancy to NA for new facility with no vacancy", {
  history <- bootstrap_history(make_bccc(1L), today = as.Date("2026-05-15"))
  bccc_new <- bind_rows(make_bccc(1L), make_bccc(2L))
  result <- add_new_facilities(history, bccc_new, today = as.Date("2026-05-16"))
  new_row <- filter(result, FAC_PARTY_ID == 2L)
  expect_true(is.na(new_row$last_vacancy_under36))
})
```

- [ ] **Step 4: Remove `ever_vacancy_*` assertions from `update_vacancies` tests**

In `tests/test-update_history.R`, replace lines 87–130 with:

```r
test_that("update_vacancies sets last_vacancy when today vacancy is Y", {
  history <- bootstrap_history(make_bccc(1L), today = as.Date("2026-05-15"))
  result <- update_vacancies(
    history,
    make_bccc(1L, under36 = "Y"),
    today = as.Date("2026-05-16")
  )
  expect_equal(result$last_vacancy_under36, as.Date("2026-05-16"))
})

test_that("update_vacancies preserves existing last_* when today vacancy is N", {
  history <- bootstrap_history(
    make_bccc(1L, under36 = "Y"),
    today = as.Date("2026-05-15")
  )
  result <- update_vacancies(
    history,
    make_bccc(1L, under36 = "N"),
    today = as.Date("2026-05-16")
  )
  expect_equal(result$last_vacancy_under36, as.Date("2026-05-15"))
})

test_that("update_vacancies does not add BC vacancy columns to result", {
  history <- bootstrap_history(make_bccc(1L), today = as.Date("2026-05-15"))
  result <- update_vacancies(
    history,
    make_bccc(1L),
    today = as.Date("2026-05-16")
  )
  expect_equal(names(result), HISTORY_COLS)
})

test_that("update_vacancies updates all four vacancy groups independently", {
  history <- bootstrap_history(make_bccc(1L), today = as.Date("2026-05-15"))
  bccc <- make_bccc(1L, under36 = "Y", mos5 = "N", licpre = "Y", gr1 = "N")
  result <- update_vacancies(history, bccc, today = as.Date("2026-05-16"))
  expect_equal(result$last_vacancy_under36, as.Date("2026-05-16"))
  expect_true(is.na(result$last_vacancy_30mos_5yrs))
  expect_equal(result$last_vacancy_licpre, as.Date("2026-05-16"))
  expect_true(is.na(result$last_vacancy_gr1_age12))
})
```

- [ ] **Step 5: Run the tests — expect them to fail** because `update_history.R` still produces `ever_vacancy_*` columns, so `expect_equal(names(result), HISTORY_COLS)` will fail.

```bash
Rscript -e "testthat::test_file('tests/test-update_history.R')"
```

Expected: failures on `names(result) == HISTORY_COLS` tests.

---

### Task 2: Remove `ever_vacancy_*` from `update_history.R` functions

**Files:**
- Modify: `update_history.R`

- [ ] **Step 1: Replace `bootstrap_history` (lines 28–70)**

```r
bootstrap_history <- function(
  bccc,
  today = lubridate::today(tzone = "America/Vancouver")
) {
  bccc |>
    mutate(
      is_active = TRUE,
      date_first_seen = NA_Date_,
      last_vacancy_under36 = if_else(
        VACANCY_SRVC_UNDER36 == "Y",
        today,
        NA_Date_
      ),
      last_vacancy_30mos_5yrs = if_else(
        VACANCY_SRVC_30MOS_5YRS == "Y",
        today,
        NA_Date_
      ),
      last_vacancy_licpre = if_else(
        VACANCY_SRVC_LICPRE == "Y",
        today,
        NA_Date_
      ),
      last_vacancy_gr1_age12 = if_else(
        VACANCY_SRVC_OOS_GR1_AGE12 == "Y",
        today,
        NA_Date_
      )
    ) |>
    select(all_of(HISTORY_COLS))
}
```

- [ ] **Step 2: Replace `add_new_facilities` (lines 72–123)**

```r
add_new_facilities <- function(
  history,
  bccc,
  today = lubridate::today(tzone = "America/Vancouver")
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
      last_vacancy_under36 = if_else(
        VACANCY_SRVC_UNDER36 == "Y",
        today,
        NA_Date_
      ),
      last_vacancy_30mos_5yrs = if_else(
        VACANCY_SRVC_30MOS_5YRS == "Y",
        today,
        NA_Date_
      ),
      last_vacancy_licpre = if_else(
        VACANCY_SRVC_LICPRE == "Y",
        today,
        NA_Date_
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
```

- [ ] **Step 3: Replace `update_vacancies` (lines 125–184)**

```r
update_vacancies <- function(
  history,
  bccc,
  today = lubridate::today(tzone = "America/Vancouver")
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
      last_vacancy_under36 = if_else(
        VACANCY_SRVC_UNDER36 == "Y",
        today,
        last_vacancy_under36
      ),
      last_vacancy_30mos_5yrs = if_else(
        VACANCY_SRVC_30MOS_5YRS == "Y",
        today,
        last_vacancy_30mos_5yrs
      ),
      last_vacancy_licpre = if_else(
        VACANCY_SRVC_LICPRE == "Y",
        today,
        last_vacancy_licpre
      ),
      last_vacancy_gr1_age12 = if_else(
        VACANCY_SRVC_OOS_GR1_AGE12 == "Y",
        today,
        last_vacancy_gr1_age12
      )
    ) |>
    select(all_of(HISTORY_COLS))
}
```

- [ ] **Step 4: Run the tests — expect them to pass**

```bash
Rscript -e "testthat::test_file('tests/test-update_history.R')"
```

Expected output: all tests pass, no failures.

- [ ] **Step 5: Commit**

```bash
git add update_history.R tests/test-update_history.R
git commit -m "remove ever_vacancy_* columns from history schema and tests"
```

---

### Task 3: Drop `ever_vacancy_*` columns from CSV

**Files:**
- Modify: `data/vacancy_history.csv`

- [ ] **Step 1: Drop the columns in-place with R**

```bash
Rscript -e "
library(readr)
h <- read_csv('data/vacancy_history.csv', show_col_types = FALSE)
h <- h[, !grepl('^ever_vacancy_', names(h))]
write_csv(h, 'data/vacancy_history.csv')
cat('Done. Columns:', paste(names(h), collapse=', '), '\n')
"
```

Expected output: `Done. Columns: FAC_PARTY_ID, is_active, date_first_seen, last_vacancy_under36, last_vacancy_30mos_5yrs, last_vacancy_licpre, last_vacancy_gr1_age12`

- [ ] **Step 2: Commit**

```bash
git add data/vacancy_history.csv
git commit -m "drop ever_vacancy_* columns from vacancy_history.csv"
```

---

### Task 4: Write the dashboard smoke test (will fail — fast_render param not yet added)

**Files:**
- Create: `tests/test-dashboard.R`

- [ ] **Step 1: Create the test file**

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

- [ ] **Step 2: Run the test — expect it to fail** because `dashboard.qmd` has no `params` block yet.

```bash
Rscript -e "testthat::test_file('tests/test-dashboard.R')"
```

Expected: Quarto error — either an unknown parameter error or a render failure because `params$fast_render` is not defined. The exact message depends on Quarto version but the test should not pass.

---

### Task 5: Add `fast_render` param and history load to `dashboard.qmd`

**Files:**
- Modify: `dashboard.qmd`

- [ ] **Step 1: Add `params` block to the YAML front matter**

In `dashboard.qmd`, add `params` to the existing YAML (after `editor_options`):

```yaml
params:
  fast_render: false
```

The front matter block should now end with:

```yaml
editor_options: 
  chunk_output_type: console
params:
  fast_render: false
```

- [ ] **Step 2: Load history and join to `bccc` in the `load_data` chunk**

In `dashboard.qmd`, after line 39 (`.today <- lubridate::today(...)`), append to the `load_data` chunk:

```r
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
  )
  bccc <- dplyr::left_join(bccc, history, by = "FAC_PARTY_ID")
} else {
  bccc$last_vacancy_under36   <- NA_Date_
  bccc$last_vacancy_30mos_5yrs <- NA_Date_
  bccc$last_vacancy_licpre    <- NA_Date_
  bccc$last_vacancy_gr1_age12 <- NA_Date_
}
```

- [ ] **Step 3: Add the `fast_render` filter in the `setup_tbl_data` chunk**

In `dashboard.qmd`, after line 45 (`dataset_last_update <- max(...)`), add:

```r
if (isTRUE(params$fast_render)) {
  bccc <- bccc |> dplyr::filter(VACANCY_LAST_UPDATE >= dataset_last_update - 3)
}
```

- [ ] **Step 4: Commit**

```bash
git add dashboard.qmd
git commit -m "add fast_render param and history join to dashboard"
```

---

### Task 6: Update the leaflet popup to show last vacancy dates

**Files:**
- Modify: `dashboard.qmd` (`setup_tbl_data` chunk, lines ~73–84)

- [ ] **Step 1: Replace the `mutate(popup = ...)` call**

Replace the existing popup mutate with this two-part mutate (label helpers + glue):

```r
mutate(
  lbl_under36 = if_else(
    !is.na(last_vacancy_under36),
    paste0(" (last seen ", format(last_vacancy_under36, "%Y-%m-%d"), ")"),
    ""
  ),
  lbl_30mos = if_else(
    !is.na(last_vacancy_30mos_5yrs),
    paste0(" (last seen ", format(last_vacancy_30mos_5yrs, "%Y-%m-%d"), ")"),
    ""
  ),
  lbl_licpre = if_else(
    !is.na(last_vacancy_licpre),
    paste0(" (last seen ", format(last_vacancy_licpre, "%Y-%m-%d"), ")"),
    ""
  ),
  lbl_gr1 = if_else(
    !is.na(last_vacancy_gr1_age12),
    paste0(" (last seen ", format(last_vacancy_gr1_age12, "%Y-%m-%d"), ")"),
    ""
  ),
  popup = glue::glue(
    "<b>{NAME}</b>",
    "{SERVICE_TYPE_CD}",
    "{PHONE}",
    "<br>Vacancy:",
    "&nbsp;&nbsp;&nbsp;&nbsp;<36 months: {VACANCY_SRVC_UNDER36}{lbl_under36}",
    "&nbsp;&nbsp;&nbsp;&nbsp;30 months - 5 years: {VACANCY_SRVC_30MOS_5YRS}{lbl_30mos}",
    "&nbsp;&nbsp;&nbsp;&nbsp;Preschool: {VACANCY_SRVC_LICPRE}{lbl_licpre}",
    "&nbsp;&nbsp;&nbsp;&nbsp;Grade 1 - Age 12: {VACANCY_SRVC_OOS_GR1_AGE12}{lbl_gr1}",
    .sep = "<br>"
  )
) |>
select(-starts_with("lbl_")) |>
```

The `select(-starts_with("lbl_"))` prevents the helper columns from appearing in the shared data.

- [ ] **Step 2: Commit**

```bash
git add dashboard.qmd
git commit -m "show last vacancy date in leaflet popup"
```

---

### Task 7: Update the row-detail vacancy table to add a Last vacancy column

**Files:**
- Modify: `dashboard.qmd` (`row_details` function, lines ~382–396)

- [ ] **Step 1: Replace the `reactable(bccc |> select(contains('VACANCY_SRVC_')) |> ...)` call**

Replace the existing reactable vacancy table in `row_details` with:

```r
df_field(
  "Vacancy type",
  reactable(
    tibble::tibble(
      `Age Group` = c(
        "Under 36 months",
        "30 months - 5 years",
        "Licensed Pre-school",
        "Grade 1 - Age 12"
      ),
      `Vacancy?` = c(
        ifelse(!is.na(bccc$VACANCY_SRVC_UNDER36), "Y", "N"),
        ifelse(!is.na(bccc$VACANCY_SRVC_30MOS_5YRS), "Y", "N"),
        ifelse(!is.na(bccc$VACANCY_SRVC_LICPRE), "Y", "N"),
        ifelse(!is.na(bccc$VACANCY_SRVC_OOS_GR1_AGE12), "Y", "N")
      ),
      `Last vacancy` = c(
        ifelse(is.na(bccc$last_vacancy_under36), "Never",
               format(bccc$last_vacancy_under36, "%Y-%m-%d")),
        ifelse(is.na(bccc$last_vacancy_30mos_5yrs), "Never",
               format(bccc$last_vacancy_30mos_5yrs, "%Y-%m-%d")),
        ifelse(is.na(bccc$last_vacancy_licpre), "Never",
               format(bccc$last_vacancy_licpre, "%Y-%m-%d")),
        ifelse(is.na(bccc$last_vacancy_gr1_age12), "Never",
               format(bccc$last_vacancy_gr1_age12, "%Y-%m-%d"))
      )
    ),
    pagination = FALSE,
    defaultColDef = colDef(headerClass = "header"),
    class = "vacancy-table",
    theme = reactableTheme(cellPadding = "8px 12px")
  )
)
```

- [ ] **Step 2: Commit**

```bash
git add dashboard.qmd
git commit -m "add Last vacancy column to row-detail vacancy table"
```

---

### Task 8: Run smoke test and verify everything works

**Files:**
- (no file changes — verification only)

- [ ] **Step 1: Run the smoke test**

```bash
Rscript -e "testthat::test_file('tests/test-dashboard.R')"
```

Expected: test passes, `dashboard.html` produced.

- [ ] **Step 2: Also run the history unit tests to confirm nothing regressed**

```bash
Rscript -e "testthat::test_file('tests/test-update_history.R')"
```

Expected: all tests pass.

- [ ] **Step 3: Commit the smoke test file**

```bash
git add tests/test-dashboard.R
git commit -m "add dashboard smoke test with fast_render parameter"
```
