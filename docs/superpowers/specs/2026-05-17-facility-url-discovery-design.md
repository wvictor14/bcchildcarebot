# Facility URL Discovery — Design Spec

**Date:** 2026-05-17
**Status:** Approved

## Goal

Build a monthly pipeline that discovers website URLs for BC childcare facilities and stores them in a CSV committed to the repo. The BC government dataset includes a website field but it is frequently missing; DuckDuckGo HTML scraping fills the gaps.

## Data File

**Path:** `data/facility_urls.csv`
**Committed to:** `main` branch
**Row count:** One per facility

### Schema

| Column | Type | Description |
|---|---|---|
| `FAC_PARTY_ID` | integer | Primary join key from BC dataset |
| `url` | character | Website URL, `NA` if not found |
| `url_source` | character | `"bc_dataset"`, `"duckduckgo"`, or `NA` |
| `last_searched` | date | Date DuckDuckGo was last queried for this facility; `NA` for bc_dataset rows |

### Bootstrap case (file missing)

Pull today's BC CSV. For facilities that already have a website in the dataset, set `url` and `url_source = "bc_dataset"`. Leave all others with `url = NA`, `url_source = NA`, `last_searched = NA`.

### Subsequent runs

Skip any row where `url` is already populated. Only query DuckDuckGo for facilities with `url = NA`.

## Script: `find_urls.R`

Standalone R script using tidyverse conventions (`|>`, dplyr verbs), consistent with `update_history.R`.

### Logic

1. Pull today's BC CSV from the government URL
2. Read `data/facility_urls.csv`; bootstrap if missing (see above)
3. Filter to facilities where `url` is `NA`
4. For each facility: query `https://duckduckgo.com/html/?q={NAME}+childcare+{CITY}+BC`, extract the first result URL, sleep 2 seconds between requests
5. Update rows: set `url`, `url_source = "duckduckgo"`, `last_searched = today`
6. Write result back to `data/facility_urls.csv`

### Failure handling

If DuckDuckGo returns no results or the request fails, leave `url = NA` and set `last_searched = today`. The facility will not be retried within the same run but will be retried on the next monthly run.

### Rate limiting

2-second sleep between requests. Worst case (all 5,900 facilities unsearched): ~3.3 hours, within GHA's 6-hour job limit. Subsequent runs are fast since already-found URLs are skipped.

## Workflow: `.github/workflows/find_urls.yml`

| Property | Value |
|---|---|
| Trigger | Monthly cron: `0 16 1 * *` (4:00 AM UTC, 1st of each month); manual dispatch |
| Runner | `ubuntu-latest` |

### Steps

1. Checkout repo
2. Setup R (`r-lib/actions/setup-r@v2`)
3. Install system dependencies (same as existing workflows)
4. Restore renv (`r-lib/actions/setup-renv@v2`)
5. `Rscript find_urls.R`
6. Commit and push `data/facility_urls.csv` if changed
