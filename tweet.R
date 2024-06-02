# Post vacancies to Twitter
# Victor Yuan, June 2024

library(rtweet)
library(purrr)
library(dplyr)
library(readr)

# Set tokens for interacting with APIs (stored as GitHub secrets)
twitter_token <- rtweet::rtweet_bot(
  api_key       = Sys.getenv("TWITTER_CONSUMER_API_KEY"),
  api_secret    = Sys.getenv("TWITTER_CONSUMER_API_SECRET"),
  access_token  = Sys.getenv("TWITTER_ACCESS_TOKEN"),
  access_secret = Sys.getenv("TWITTER_ACCESS_TOKEN_SECRET")
)

# generate tweet

## identify vacancies
## craft tweet message
tweet_message <- c('Test')
# Post tweet to Twitter
possibly_post_tweet <- purrr::possibly(rtweet::post_tweet)  # will fail silently

possibly_post_tweet(
  text           = tweet_message,
  token          = twitter_token
)
