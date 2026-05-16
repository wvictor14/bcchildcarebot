# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

bcchildcarebot is a Quarto dashboard for exploring BC childcare facilities with open vacancies. It pulls data from the [BC Child Care dataset](https://catalogue.data.gov.bc.ca/dataset/child-care-map-data/resource/9a9f14e1-03ea-4a11-936a-6e77b15eeb39) published by the BC government and is published to GitHub Pages at this link: https://victoryuan.com/bcchildcarebot/ .

## Development Environment

### Setup

- **Dependency Management**: renv - run `renv::restore()` after cloning to restore packages

```bash
# Restore R dependencies
Rscript -e "renv::restore()"
```

### Common Development Commands

**Render the dashboard locally:**
```bash
quarto render dashboard.qmd
# Opens dashboard.html in browser
```

**In RStudio:**
- Open dashboard.qmd and use "Render" button for interactive development

## Architecture

### Dashboard (`dashboard.qmd`)

The Quarto dashboard uses **crosstalk** for client-side interactivity without server overhead:

- **Data Loading**: Fetches CSV directly from BC government API on render
- **Filters**: City, service type, language, certifications, vacancy status via crosstalk widgets
- **Map View**: Leaflet map with popup markers showing facility details and vacancy info
- **Table View**: Reactable showing facility listings with vacancy columns
- **Styling**: custom.scss defines dashboard theme colors and layout

Key R libraries:
- `tidyverse`: Data manipulation and visualization
- `reactable`: Interactive table rendering
- `leaflet`: Interactive maps
- `crosstalk`: Client-side filtering across widgets
- `htmltools`: HTML generation for popups

## GitHub Actions / Automation

**publish.yml**
- **Trigger**: Push to main branch, manual dispatch, or daily at 3:41 PM UTC (8:41 AM PST)
- **Process**: Renders dashboard.qmd → publishes to gh-pages branch
- **Deployment**: Accessible at https://victoryuan.com/bcchildcarebot/

## Data Source

- **URL**: https://catalogue.data.gov.bc.ca/dataset/.../childcare_locations.csv
- **Update Frequency**: BC government publishes data regularly; dashboard renders on schedule
- **Key Columns**:
  - `VACANCY_LAST_UPDATE`: Last timestamp of vacancy status change
  - `VACANCY_SRVC_UNDER36`, `VACANCY_SRVC_30MOS_5YRS`, etc.: Vacancy flags by age group
  - `CITY`, `NAME`, `PHONE`: Facility contact info
  - `LATITUDE`, `LONGITUDE`: Map coordinates

## Code Style Notes

- Uses tidyverse conventions: pipe operator `|>`, dplyr verbs
- Dashboard uses functional approach with reactable + crosstalk
- Custom styling in custom.scss (dashboard colors, table formatting)

## Testing & Validation

- Render dashboard locally and verify filters work and map displays correctly
- Check that vacancy columns update when data changes
- Verify responsive layout on different screen sizes

## Common Issues

**renv restore fails**: Ensure you have system dependencies installed (see GitHub Action step "Install system dependencies" for required packages)

**Dashboard doesn't render**: Verify BC government data URL is accessible; check CSV format hasn't changed

## Related Links

- **Dashboard**: https://victoryuan.com/bcchildcarebot/
- **GitHub Repo**: https://github.com/wvictor14/bcchildcarebot
- **Data Source**: https://catalogue.data.gov.bc.ca/dataset/child-care-map-data
