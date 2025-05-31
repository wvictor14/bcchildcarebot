#' Custom Crosstalk select filter. This is a single-select input that works
#' on columns containing multiple values per row (list columns).
#' taken from https://glin.github.io/reactable/articles/popular-movies/popular-movies.html
select_filter <- function(id, label, shared_data, group, choices = NULL,
                          width = "100%", class = "filter-input") {
  values <- shared_data$data()[[group]]
  keys <- shared_data$key()
  if (is.list(values)) {
    # Multiple values per row
    flat_keys <- unlist(mapply(rep, keys, sapply(values, length)))
    keys_by_value <- split(flat_keys, unlist(values), drop = TRUE)
    choices <- if (is.null(choices)) sort(unique(unlist(values))) else choices
  } else {
    # Single value per row
    keys_by_value <- split(seq_along(keys), values, drop = TRUE)
    choices <- if (is.null(choices)) sort(unique(values)) else choices
  }
  
  script <- sprintf("
    window['__ct__%s'] = (function() {
      const handle = new window.crosstalk.FilterHandle('%s')
      const keys = %s
      return {
        filter: function(value) {
          if (!value) {
            handle.clear()
          } else {
            handle.set(keys[value])
          }
        }
      }
    })()
  ", id, shared_data$groupName(), toJSON(keys_by_value))
  
  div(
    class = class,
    tags$label(`for` = id, label),
    tags$select(
      id = id,
      onchange = sprintf("window['__ct__%s'].filter(this.value)", id),
      style = sprintf("width: %s", validateCssUnit(width)),
      tags$option(value = "", "All"),
      lapply(choices, function(value) tags$option(value = value, value))
    ),
    tags$script(HTML(script))
  )
}

#' # Custom Crosstalk search filter. This is a free-form text field that does
#' case-insensitive text searching on a single column.
#' taken from https://glin.github.io/reactable/articles/popular-movies/popular-movies.html
search_filter <- function(id, label, shared_data, group, width = "100%", class = "filter-input") {
  values <- as.list(shared_data$data()[[group]])
  values_by_key <- setNames(values, shared_data$key())
  
  script <- sprintf("
    window['__ct__%s'] = (function() {
      const handle = new window.crosstalk.FilterHandle('%s')
      const valuesByKey = %s
      return {
        filter: function(value) {
          if (!value) {
            handle.clear()
          } else {
            // Escape special characters in the search value for regex matching
            value = value.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&')
            const regex = new RegExp(value, 'i')
            const filtered = Object.keys(valuesByKey).filter(function(key) {
              const value = valuesByKey[key]
              if (Array.isArray(value)) {
                for (let i = 0; i < value.length; i++) {
                  if (regex.test(value[i])) {
                    return true
                  }
                }
              } else {
                return regex.test(value)
              }
            })
            handle.set(filtered)
          }
        }
      }
    })()
  ", id, shared_data$groupName(), jsonlite::toJSON(values_by_key))
  
  div(
    class = class,
    tags$label(`for` = id, label),
    tags$input(
      id = id,
      type = "search",
      oninput = sprintf("window['__ct__%s'].filter(this.value)", id),
      style = sprintf("width: %s", validateCssUnit(width))
    ),
    tags$script(HTML(script))
  )
}

#' Custom Crosstalk range filter. This is a simple range input that only filters
#' minimum values of a column.
#' taken from https://glin.github.io/reactable/articles/popular-movies/popular-movies.html
range_filter <- function(id, label, shared_data, group, min = NULL, max = NULL,
                         step = NULL, suffix = "", width = "100%", class = "filter-input") {
  values <- shared_data$data()[[group]]
  values_by_key <- setNames(as.list(values), shared_data$key())
  
  script <- sprintf("
    window['__ct__%s'] = (function() {
      const handle = new window.crosstalk.FilterHandle('%s')
      const valuesByKey = %s
      return {
        filter: function(value) {
          const filtered = Object.keys(valuesByKey).filter(function(key) {
            return valuesByKey[key] >= value
          })
          handle.set(filtered)
        }
      }
    })()
  ", id, shared_data$groupName(), toJSON(values_by_key))
  
  min <- if (!is.null(min)) min else min(values)
  max <- if (!is.null(max)) max else max(values)
  value <- min
  
  oninput <- paste(
    sprintf("document.getElementById('%s__value').textContent = this.value + '%s';", id, suffix),
    sprintf("window['__ct__%s'].filter(this.value)", id)
  )
  
  div(
    class = class,
    tags$label(`for` = id, label),
    div(
      tags$input(
        id = id,
        type = "range",
        min = min,
        max = max,
        step = step,
        value = value,
        oninput = oninput,
        onchange = oninput, # For IE11 support
        style = sprintf("width: %s", validateCssUnit(width))
      )
    ),
    span(id = paste0(id, "__value"), paste0(value, suffix)),
    tags$script(HTML(script))
  )
}