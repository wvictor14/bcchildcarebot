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
