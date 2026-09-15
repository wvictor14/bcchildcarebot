library(testthat)
library(tibble)
source("../update_history.R")

# Minimal bccc row factory — only the columns the helpers use
make_bccc <- function(id, under36 = "N", mos5 = "N", licpre = "N", gr1 = "N") {
  tibble(
    FAC_PARTY_ID = as.integer(id),
    VACANCY_SRVC_UNDER36 = under36,
    VACANCY_SRVC_30MOS_5YRS = mos5,
    VACANCY_SRVC_LICPRE = licpre,
    VACANCY_SRVC_OOS_GR1_AGE12 = gr1
  )
}

# --- bootstrap_history ---

test_that("bootstrap_history returns one row per facility", {
  bccc <- bind_rows(make_bccc(1L), make_bccc(2L), make_bccc(3L))
  result <- bootstrap_history(bccc, today = as.Date("2026-05-16"))
  expect_equal(nrow(result), 3L)
  expect_equal(result$FAC_PARTY_ID, 1:3L)
})

test_that("bootstrap_history has all required columns", {
  result <- bootstrap_history(make_bccc(1L), today = as.Date("2026-05-16"))
  expect_equal(names(result), HISTORY_COLS)
})

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

test_that("bootstrap_history sets date_first_seen to NA for all rows", {
  result <- bootstrap_history(make_bccc(1L), today = as.Date("2026-05-16"))
  expect_true(is.na(result$date_first_seen))
})

test_that("bootstrap_history sets is_active to TRUE for all rows", {
  result <- bootstrap_history(make_bccc(1L), today = as.Date("2026-05-16"))
  expect_true(result$is_active)
})

# --- add_new_facilities ---

test_that("add_new_facilities returns history unchanged when no new facilities", {
  bccc <- make_bccc(1L)
  history <- bootstrap_history(bccc, today = as.Date("2026-05-15"))
  result <- add_new_facilities(history, bccc, today = as.Date("2026-05-16"))
  expect_equal(nrow(result), 1L)
  expect_equal(result$FAC_PARTY_ID, 1L)
})

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

# --- update_vacancies ---

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

# --- update_active_status ---

test_that("update_active_status marks facility absent from today as inactive", {
  history <- bootstrap_history(
    bind_rows(make_bccc(1L), make_bccc(2L)),
    today = as.Date("2026-05-15")
  )
  result <- update_active_status(history, make_bccc(1L))
  expect_true(result$is_active[result$FAC_PARTY_ID == 1L])
  expect_false(result$is_active[result$FAC_PARTY_ID == 2L])
})

test_that("update_active_status marks returning facility as active", {
  history <- bootstrap_history(make_bccc(1L), today = as.Date("2026-05-15"))
  history$is_active <- FALSE
  result <- update_active_status(history, make_bccc(1L))
  expect_true(result$is_active)
})

test_that("update_active_status does not change column names", {
  history <- bootstrap_history(make_bccc(1L), today = as.Date("2026-05-15"))
  result <- update_active_status(history, make_bccc(1L))
  expect_equal(names(result), HISTORY_COLS)
})
