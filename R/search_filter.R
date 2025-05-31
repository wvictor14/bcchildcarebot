
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