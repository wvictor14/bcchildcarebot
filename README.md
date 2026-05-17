# bcchildcarebot

[![Project Status: WIP – Initial development is in progress, but there has not yet been a stable, usable release suitable for the public.](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)

## What

The [BC Child Care Dashboard](https://victoryuan.com/bcchildcarebot/) is an interactive Quarto dashboard for finding open childcare vacancies across BC. It pulls daily data from the [BC Child Care dataset](https://catalogue.data.gov.bc.ca/dataset/child-care-map-data/resource/9a9f14e1-03ea-4a11-936a-6e77b15eeb39) published by the BC government and is published automatically via GitHub Actions.

The dashboard has interactive filters, a map view, and a facility listing to help navigate vacancies by location, age group, language, and certification.

## Vacancy History

In addition to the daily snapshot, this repo tracks per-facility vacancy history in `data/vacancy_history.csv`. This enables questions like:

- Has this facility ever had a vacancy for under-36-month-olds?
- When was the last time this facility had an open spot?
- When did this facility first appear in the dataset?

The history file is updated daily by a separate GitHub Action (`update_history.yml`) that runs 30 minutes before the dashboard publishes. It tracks one row per facility with these fields:

| Column | Description |
|---|---|
| `FAC_PARTY_ID` | Unique facility identifier |
| `is_active` | `FALSE` if facility no longer appears in BC data |
| `date_first_seen` | Date facility first appeared after tracking began (`NA` for facilities present at launch) |
| `ever_vacancy_under36` | Has ever had a vacancy for children under 36 months |
| `last_vacancy_under36` | Most recent date vacancy was open for under-36-month-olds |
| `ever_vacancy_30mos_5yrs` | Has ever had a vacancy for 30 months to 5 years |
| `last_vacancy_30mos_5yrs` | Most recent date vacancy was open for 30 months to 5 years |
| `ever_vacancy_licpre` | Has ever had a vacancy for licensed preschool |
| `last_vacancy_licpre` | Most recent date vacancy was open for licensed preschool |
| `ever_vacancy_gr1_age12` | Has ever had a vacancy for grade 1 to age 12 |
| `last_vacancy_gr1_age12` | Most recent date vacancy was open for grade 1 to age 12 |
