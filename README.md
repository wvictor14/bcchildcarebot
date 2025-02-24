# bcchildcarebot

[![Project Status: WIP – Initial development is in progress, but there has not yet been a stable, usable release suitable for the public.](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)
[![](https://img.shields.io/badge/@bcchildcarebot@botsin.space-white?style=flat&labelColor=purple&logo=Mastodon&logoColor=white)](https://botsin.space/@bcchildcarebot)

## What

To better find open vacancies for childcare in BC, I created two tools: a website that lets interactive exploration of childcare facilities in BC with open vacancies, and 2. a twitter (mastodon) bot that reports daily open vacancies. 

These data are updated daily using the BC Childcare Map dataset from the [BC Child Care dataset](https://catalogue.data.gov.bc.ca/dataset/child-care-map-data/resource/9a9f14e1-03ea-4a11-936a-6e77b15eeb39) from the BC government's website.

### The dashboard

The [BC Child Care Dashboard](https://victoryuan.com/bcchildcarebot/) is a quarto dashboard to help find open vacancies across BC Childcare facilities. It uses github actions to pull up-to-date data from the BC government's dataset resources directly. It has a combination of interactive filters, map views, and listings to help navigate through the dataset.

### The mastodon bot

Source for the BC child care vacancy bot [@bcchildcarebot](https://botsin.space/@bcchildcarebot) built by [Victor Yuan](https://victoryuan.com). The repo contains a [GitHub Action](https://github.com/features/actions) that executes R code on every day to:

1. Pull out data from [BC Child Care dataset](https://catalogue.data.gov.bc.ca/dataset/child-care-map-data/resource/9a9f14e1-03ea-4a11-936a-6e77b15eeb39)
2. Check daily for any new vacancies
3. Generate a summary of new vacancies
4. report vacancies to Mastodon / Twitter

This bot is built following [Matt Dray's](https://www.matt-dray.com) post on the [@londonmapbot](https://www.botsin.space/londonmapbot).

#### How to follow

For Mastodon, create an account on a Instance of your choosing (not botsin.space, which is only for bot accounts). Then follow [![](https://img.shields.io/badge/@bcchildcarebot@botsin.space-white?style=flat&labelColor=purple&logo=Mastodon&logoColor=white)](https://botsin.space/@bcchildcarebot) and turn on notifications.

#### How it works

##### mastodon 

1. Create a mastdon account for your bot botsin.space
2. add api keys as secrets (see github actions)
3. Write r script to use `rtoot`  to post to mastodon
4. set up github actions cron job to run daily

##### twitter / x

TBD
