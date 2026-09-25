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

test_that("rendered dashboard includes filter-bar script and data", {
  skip_if_not_installed("quarto")
  withr::with_dir("..", {
    skip_if_not(file.exists("dashboard.html"), "dashboard.html not rendered")
    html <- paste(readLines("dashboard.html", warn = FALSE), collapse = "\n")
    required <- c(
      "window.bcClearAll = function",
      "crosstalk.FilterHandle(BC_CT_GROUP)",
      "window.BC_DATE_OFFSETS = ",
      'name="updated_within"',
      'data-bs-toggle="popover"',
      "Latest vacancy report"
    )
    for (needle in required) {
      found <- grepl(needle, html, fixed = TRUE)
      if (!found) message("Missing from dashboard.html: ", needle)
      expect_true(found, info = needle)
    }
  })
})
