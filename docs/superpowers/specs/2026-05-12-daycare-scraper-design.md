Title: Daycare Scraper MVP Design
Date: 2026-05-12
Author: Copilot

Overview

Goal: Create a minimal, cloud-first MVP that seeds a Postgres DB from the BC Child Care CSV, runs a lightweight scraper to fetch each facility's public website, extracts contact info and a short description, stores parsed fields and raw HTML, and exposes data for the existing dashboard.

MVP Scope (what will be built)

- Seed stage: download BC CSV and upsert canonical facility records to Postgres (Supabase).
- Scraper stage: for facilities with a website, fetch HTML (requests), extract phone, meta description/first paragraph, and store raw_html and parsed fields.
- Storage: Postgres for structured fields + raw_html column; use Supabase-managed Postgres and Storage later if desired.
- Orchestration: scheduled GitHub Actions job that runs the seeder and a batch scraper once per day (configurable).
- No headless browser or paid APIs in MVP.

Data model (core fields)

- daycares(id, source_id, name, address, city, postal_code, phone, website, latitude, longitude, capacity, age_groups JSONB, vacancies JSONB, hours, license_status, ece_certified boolean, photos JSONB, program_descriptions TEXT, raw_html TEXT, last_scraped_at TIMESTAMPTZ, sources JSONB, created_at, updated_at)

Pipeline

1. Seeder: downloads CSV, normalizes name/address/website, upserts daycares.
2. Scraper runner: selects N facilities (batch), requests website HTML, parses phone (tel: links or regex), meta description or first paragraph, writes raw_html and parsed fields to DB; rate-limits and sleeps between requests.
3. Error handling: log and store scrape failures in scrape_jobs table; retry policy is simple (skip, reattempt next run).
4. Dedupe: rely on unique(name,address) index for canonical records; manual review later for duplicates.

Infrastructure & Hosting

- Supabase Postgres (free tier) for DB; store secrets in GitHub Actions as SUPABASE_DATABASE_URL.
- Use GitHub Actions scheduled workflow for daily seed+scrape jobs.
- Python scraper with requests + BeautifulSoup; small requirements.txt maintained in repo.

Security & Legal

- Honor robots.txt and site rate limits; include identifiable User-Agent and link to repo/contact.
- Do not collect or expose sensitive personal data beyond public business contact info.
- Provide a clear takedown/contact process in README.

Acceptance criteria

- Seeder successfully upserts BC CSV records into Postgres.
- Scraper updates at least 100 facility records' raw_html and phone/description fields without error on first run.
- GitHub Action runs daily and logs success/failure status.
- Dashboard can read the updated daycares table and show scraped fields.

Risks & Mitigations

- Site structure changes: log failures and surface most-failed domains for manual extractor updates.
- Robots.txt restrictions: skip disallowed domains and record reason in scrape_jobs.
- Broken/malformed websites: catch exceptions and continue.

Next Steps (after user approval)

1. Run spec self-review and fix any placeholders.
2. On approval, invoke writing-plans to produce a narrow implementation plan: create DB migration, seed script, scraper runner, GH Actions workflow, minimal README entries, and tests.

