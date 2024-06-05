# bcchildcarevacancybot

[![Project Status: WIP – Initial development is in progress, but there has not yet been a stable, usable release suitable for the public.](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)

## What

Source for the BC child care vacancy bot [placeholder for bot link]() built by [Victor Yuan](https://victoryuan.com). The repo contains a [GitHub Action](https://github.com/features/actions) that executes R code on every day to:

1. Pull out data from BC Child care vacancies dataset
2. Compare to yesterday's dataset to identify any new vacancies
3. Generate a summary of new vacancies
4. report vacancies to Twitter

This bot is built following [Matt Dray's](https://www.matt-dray.com) [@londonmapbot](https://www.twitter.com/londonmapbot).

## How

For detail on the original Twitter bot see:

* my talk at LondonR in Feb 2022 (see the [blog](https://www.rostrum.blog/posts/2022-02-12-mapbot-londonr/), [slides](https://matt-dray.github.io/mapbot-londonr/#1), [video](https://player.vimeo.com/video/683004567)) 
* my [original blog post](https://www.rostrum.blog/2020/09/21/londonmapbot/) that introduces the bot
* my [blog post](https://www.rostrum.blog/posts/2023-02-09-londmapbotstodon/) about porting the bot to Mastodon, following [Matt Kerlogue's advice](https://lapsedgeographer.london/2022-11/mastodon-switch/)

### twitter version of londonbot

View this version of [twitter-londmapbot](https://github.com/matt-dray/londonmapbot/tree/65aa64722c475fc9bda274c49674cd66ff695b4b)
You can make your own Twitter bot. See the links above for details, or this excellent introduction by Oscar Baruffa, but in brief:

1. Create a Twitter account for your bot
2. Sign up for developer status with Twitter (including 'elevated access') and MapBox
3. Fork this repo, or click the green 'use this template' button
4. Get your API keys from MapBox and Twitter and add them as GitHub secrets to your repo
5. Edit the lat and lon variables in londonmapbot-tweet.R to change where coordinates are sampled from (see the mapbotverse for other ways to sample from within geographic boundaries)
6. Adjust the .github/workflows/londonmapbot.yml file to adjust the cron schedule if you want
7. GitHub Actions will recognise the .yml file and execute the code on the schedule provided
8. Mark the account as an automated account