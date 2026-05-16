# Vacancy History Pipeline — Design Spec

**Date:** 2026-05-16
**Status:** Approved

## Goal

Build a daily data pipeline that tracks per-facility vacancy history over time from the BC Childcare dataset. The pipeline persists a summary CSV to the repo, updated by a dedicated GitHub Actions workflow.

## Background

The existing dashboard pulls a fresh snapshot of BC childcare data daily and discards it after rendering. This pipeline adds a persistent layer that answers two questions per facility:

1. Has this facility ever had a vacancy for each age group?
2. When was the last time it had an open vacancy for each age group?

It also tracks when new facilities first appear in the dataset (approximating their opening date).

## Data File

**Path:** `data/vacancy_history.csv`
**Committed to:** `main` branch
**Row count:** One per facility — never grows beyond the total number of facilities (~5,900)

### Schema

| Column | Type | Description |
|---|---|---|
| `FAC_PARTY_ID` | integer | Primary join key from BC dataset |
| `is_active` | logical | `FALSE` when facility no longer appears in daily pull |
| `date_first_seen` | date | Date facility first appeared post-pipeline-launch; `NA` for facilities present at bootstrap |
| `ever_vacancy_under36` | logical | Has ever had vacancy for <36 months |
| `last_vacancy_under36` | date | Most recent date vacancy was `Y` for <36 months |
| `ever_vacancy_30mos_5yrs` | logical | Has ever had vacancy for 30 months–5 years |
| `last_vacancy_30mos_5yrs` | date | Most recent date vacancy was `Y` for 30 months–5 years |
| `ever_vacancy_licpre` | logical | Has ever had vacancy for licensed preschool |
| `last_vacancy_licpre` | date | Most recent date vacancy was `Y` for licensed preschool |
| `ever_vacancy_gr1_age12` | logical | Has ever had vacancy for grade 1–age 12 |
| `last_vacancy_gr1_age12` | date | Most recent date vacancy was `Y` for grade 1–age 12 |

Missing history is represented as `NA` (not zero or empty string).

## Script: `update_history.R`

Standalone R script using tidyverse conventions (`|>`, dplyr verbs).

### Logic

1. Pull today's BC CSV from the government URL
2. Read `data/vacancy_history.csv`
   - **Bootstrap case** (file missing): create a new history table from today's facilities with `date_first_seen = NA` for all, `is_active = TRUE` for all. For each facility: if today's vacancy = `Y`, set `ever_* = TRUE` and `last_* = today`; if today's vacancy = `N`, set `ever_* = NA` and `last_* = NA` (we cannot know prior history)
3. Identify new facilities: `FAC_PARTY_ID` in today's pull but absent from history → add new rows with `date_first_seen = today`, `is_active = TRUE`, vacancy columns from today
4. Update existing facilities: for each facility where today's `VACANCY_SRVC_* == "Y"`, set `ever_* = TRUE` and `last_* = today`
5. Mark inactive: set `is_active = FALSE` for any `FAC_PARTY_ID` in history not present in today's pull; set `is_active = TRUE` for all others
6. Write result back to `data/vacancy_history.csv`

### Source columns from BC dataset

| BC column | Maps to |
|---|---|
| `VACANCY_SRVC_UNDER36` | `ever_vacancy_under36`, `last_vacancy_under36` |
| `VACANCY_SRVC_30MOS_5YRS` | `ever_vacancy_30mos_5yrs`, `last_vacancy_30mos_5yrs` |
| `VACANCY_SRVC_LICPRE` | `ever_vacancy_licpre`, `last_vacancy_licpre` |
| `VACANCY_SRVC_OOS_GR1_AGE12` | `ever_vacancy_gr1_age12`, `last_vacancy_gr1_age12` |

## Workflow: `.github/workflows/update_history.yml`

| Property | Value |
|---|---|
| Trigger | Daily cron: `10 15 * * *` (3:10 PM UTC) |
| Runs before | `publish.yml` at `41 15 * * *` (3:41 PM UTC) |
| Runner | `ubuntu-latest` |

### Steps

1. Checkout repo
2. Setup R (r-lib/actions/setup-r@v2, R 4.4.0)
3. Install system dependencies (`libudunits2-dev libcurl4-openssl-dev libgdal-dev`)
4. Restore renv (r-lib/actions/setup-renv@v2)
5. `Rscript update_history.R`
6. Git config + commit `data/vacancy_history.csv` with message `[skip ci] update vacancy history`
7. Push to `main` using `GITHUB_TOKEN`

The `[skip ci]` tag prevents the push from re-triggering other workflows.

## Out of Scope

- Dashboard integration (future work)
- Web scraping to augment facility data (future work)
- Update frequency tracking
- Pre-computed summaries (computed at render time from raw history)
