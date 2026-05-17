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

test_that("bootstrap_urls sets url to NA when WEBSITE is empty string", {
  result <- bootstrap_urls(make_bccc(1L, website = ""))
  expect_true(is.na(result$url))
  expect_true(is.na(result$url_source))
})

test_that("bootstrap_urls sets last_searched to NA for all rows", {
  bccc <- bind_rows(make_bccc(1L, website = "https://example.com"), make_bccc(2L))
  result <- bootstrap_urls(bccc)
  expect_true(all(is.na(result$last_searched)))
})
