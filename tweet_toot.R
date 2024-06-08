# Post vacancies to Twitter
# Victor Yuan, June 2024
library(rtweet)
library(purrr)
library(dplyr)
library(readr)
library(lubridate)
library(tidyr)
library(glue)

# parameters
max_nchar_per_toot <- 500-10 # 10 char buffer
max_toots <- 6

# Set tokens for interacting with APIs (stored as GitHub secrets)
twitter_token <- rtweet::rtweet_bot(
  api_key       = Sys.getenv("TWITTER_CONSUMER_API_KEY"),
  api_secret    = Sys.getenv("TWITTER_CONSUMER_API_SECRET"),
  access_token  = Sys.getenv("TWITTER_ACCESS_TOKEN"),
  access_secret = Sys.getenv("TWITTER_ACCESS_TOKEN_SECRET")
)

mastodon_token <- structure(
  list(
    bearer = Sys.getenv("RTOOT_DEFAULT_TOKEN"),
    type = "user",
    instance = "botsin.space"
  ),
  class = "rtoot_bearer"
) 

## read in bc child care data 
### set dates, set timezone to pst, see OlsonNames()
.today <- lubridate::today(tzone = 'Canada/Pacific')
  
url <- 'https://catalogue.data.gov.bc.ca/dataset/4cc207cc-ff03-44f8-8c5f-415af5224646/resource/9a9f14e1-03ea-4a11-936a-6e77b15eeb39/download/childcare_locations.csv'
bccc <- readr::read_csv(url)

## identify vacancies

## clean up
labels <- c('<36mo' = "VACANCY_SRVC_UNDER36",
  "30mo-5yr" = "VACANCY_SRVC_30MOS_5YRS",
  "Licensed Preschool" = "VACANCY_SRVC_LICPRE",
  "Grade1-Age12" = "VACANCY_SRVC_OOS_GR1_AGE12"
)

# vacancies for the last 7 days
bccc |> 
  filter(
    VACANCY_LAST_UPDATE >= .today - 7,
    VACANCY_SRVC_UNDER36 == 'Y'
  ) |> 
  count(VACANCY_LAST_UPDATE)

.text <- bccc |>
  #slice(1:10) |> 
  filter(
    VACANCY_LAST_UPDATE >= .today -1,
    VACANCY_SRVC_UNDER36 == 'Y'
  ) |> 
  select(NAME, CITY, PHONE) |> 
  mutate(
    text = glue::glue("{NAME},{CITY},{PHONE}"),
    n_char = nchar(text),
    n_char_cumsum = cumsum(n_char),
    n_char_cut = cut(
      n_char_cumsum, 
      breaks = seq(0, 500*max_toots, by = max_nchar_per_toot)) |> 
      as.numeric()
    
    ) |> 
  group_nest(n_char_cut) |> 
  mutate(text = purrr::map_chr(
    data, \(x) pull(x, text) |>  paste0(collapse = '\n')
  ),
      text = glue::glue("{n_char_cut}/{max(n_char_cut)}\n{text}")
  ) |> 
  pull(text)
 
if (length(.text) == 0) {
  .text <- 'No new vacancies today.'
}

# Post tweet to Twitter
#possibly_post_tweet <- purrr::possibly(rtweet::post_tweet)  # will fail silently
#possibly_post_tweet(
#  text           = .text,
#  token          = twitter_token
#)

message(glue('Sending {length(.text)} toots:'))
.text |>  purrr::walk(message)

.text |> 
  purrr::walk(
    \(x) rtoot::post_toot(
      status = x,
      token = mastodon_token
    )
  )
