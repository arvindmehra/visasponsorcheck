# SEO Engineering Walkthrough — VisaSponsorUK

## Summary
Complete programmatic SEO implementation across the entire Rails app. All pages verified working locally.

---

## What Was Built

### Phase 1 — Foundation
| Item | Detail |
|---|---|
| **Gems added** | `meta-tags 2.23`, `pagy 9.4`, `sitemap_generator 6.3` |
| **DB Migration** | Added `town_normalised` column (populated from existing `town` data), 6 new indexes on `companies.town`, `sponsor_licences.{status, rating, route, licence_type}` |
| **Routes** | 8 new routes + 301 redirect from `/companies/:id` → `/sponsor/:id` |

### Phase 2 — Programmatic Pages (5 new page types)

| URL | Target Keyword | Count |
|---|---|---|
| `/sponsors` | UK visa sponsor list, register of licensed sponsors | 1 page |
| `/sponsors/city/:city` | visa sponsors in [city] | **5,177 city pages** |
| `/sponsors/route/:route` | [route] visa sponsors UK | 17 route pages |
| `/sponsors/a-rated` | A-rated sponsor list UK | 1 page |
| `/sponsors/revoked` | revoked sponsor licence list | 1 page |
| `/faq` | UK visa sponsor FAQ | 1 page |

### Phase 3 — On-Page SEO

**All pages now have:**
- Dynamic `<title>` via `meta-tags` gem (keyword-rich, 60 char)
- Dynamic `<meta name="description">` (unique per page, 155 char)
- `<link rel="canonical">` on every page
- Navigation links: Browse Sponsors + FAQ in header
- Data freshness badge on homepage (last sync timestamp)
- Browse by City + Browse by Visa Route sections on homepage
- **All 126k+ company pages**: unique auto-generated SEO summary paragraph prevents thin content

**Structured Data (JSON-LD):**
- `Organization` + `WebSite` + `SearchAction` — global in layout
- `Organization` + `BreadcrumbList` — on every company page
- `CollectionPage` + `BreadcrumbList` + `ItemList` — on city/route pages
- `FAQPage` — on `/faq`

### Phase 4 — Sitemap
- `config/sitemap.rb` configured to generate compressed sitemap with all 126k company pages, cities, routes, and static pages
- Run with: `bin/rails sitemap:create RAILS_ENV=production`

### Phase 5 — Technical SEO
- `force_ssl = true` and `assume_ssl = true` enabled in `config/environments/production.rb`
- `robots.txt` updated with proper Allow/Disallow rules and `Sitemap:` directive pointing to `sitemap.xml.gz`
- `nofollow` added to external GOV.UK links
- `lang="en"` added to HTML root element

---

## Screenshots

![Homepage](/Users/arvind/.gemini/antigravity-ide/brain/e016ec75-9ad4-4c27-8344-a3750c9b0a11/homepage_1783080382072.png)

![Sponsors Directory](/Users/arvind/.gemini/antigravity-ide/brain/e016ec75-9ad4-4c27-8344-a3750c9b0a11/sponsors_directory_1783080390047.png)

![London City Page](/Users/arvind/.gemini/antigravity-ide/brain/e016ec75-9ad4-4c27-8344-a3750c9b0a11/london_sponsors_1783080399172.png)

![Skilled Worker Route Page](/Users/arvind/.gemini/antigravity-ide/brain/e016ec75-9ad4-4c27-8344-a3750c9b0a11/skilled_worker_sponsors_1783080408374.png)

![A-Rated Sponsors](/Users/arvind/.gemini/antigravity-ide/brain/e016ec75-9ad4-4c27-8344-a3750c9b0a11/a_rated_sponsors_1783080419280.png)

![FAQ Page](/Users/arvind/.gemini/antigravity-ide/brain/e016ec75-9ad4-4c27-8344-a3750c9b0a11/faq_page_1783080432611.png)

![Company Page](/Users/arvind/.gemini/antigravity-ide/brain/e016ec75-9ad4-4c27-8344-a3750c9b0a11/company_page_1783080448841.png)


---

## HTTP Verification Results

All routes return correct status codes:

| URL | Status |
|---|---|
| `/` | ✅ 200 |
| `/sponsors` | ✅ 200 |
| `/sponsors/city/london` | ✅ 200 |
| `/sponsors/route/skilled-worker` | ✅ 200 |
| `/sponsors/a-rated` | ✅ 200 |
| `/sponsors/revoked` | ✅ 200 |
| `/faq` | ✅ 200 |
| `/sponsor/:slug` | ✅ 200 |
| `/companies/:slug` (old URL) | ✅ 301 → `/sponsor/:slug` |

---

## Files Changed

| File | Change |
|---|---|
| `Gemfile` | Added `meta-tags`, `pagy`, `sitemap_generator` |
| `db/migrate/20260703115005_add_seo_indexes.rb` | New migration |
| `config/routes.rb` | New SEO-optimised routes + 301 redirects |
| `app/models/company.rb` | `town=` syncs `town_normalised`, new scopes + helpers |
| `app/controllers/application_controller.rb` | Pagy, NumberHelper, default meta tags |
| `app/controllers/home_controller.rb` | Meta tags, top cities/routes |
| `app/controllers/companies_controller.rb` | `set_meta_tags` with dynamic data |
| `app/controllers/sponsors_controller.rb` | **NEW** — city, route, a_rated, revoked, index |
| `app/controllers/pages_controller.rb` | **NEW** — FAQ page |
| `app/helpers/application_helper.rb` | Pagy::Frontend |
| `app/views/layouts/application.html.erb` | meta-tags, JSON-LD, nav + footer links |
| `app/views/home/index.html.erb` | Data freshness badge, city/route browse sections |
| `app/views/companies/show.html.erb` | JSON-LD, city breadcrumb, SEO summary |
| `app/views/sponsors/index.html.erb` | **NEW** |
| `app/views/sponsors/city.html.erb` | **NEW** |
| `app/views/sponsors/route.html.erb` | **NEW** |
| `app/views/sponsors/a_rated.html.erb` | **NEW** |
| `app/views/sponsors/revoked.html.erb` | **NEW** |
| `app/views/pages/faq.html.erb` | **NEW** |
| `config/initializers/pagy.rb` | **NEW** |
| `config/sitemap.rb` | **NEW** |
| `config/environments/production.rb` | `force_ssl`, `assume_ssl` enabled |
| `public/robots.txt` | SEO robots rules + Sitemap directive |

---

## RSpec Test Suite & Coverage

Comprehensive RSpec coverage has been added across the whole application stack (Models, Controllers, Services, Jobs, and System integration).

### Test Suite Summary
*   **Total Examples**: 114
*   **Failures**: 0
*   **Overall Line Coverage**: **94.39%**

### Coverage by Component

| File | Coverage % | Description |
|:---|:---|:---|
| `app/models/company.rb` | **100.0%** | Scopes, town normalisation, active/removed checks |
| `app/models/sponsor_licence.rb` | **93.33%** | Validations, routes, type and rating parser |
| `app/models/sponsor_change_event.rb` | **96.0%** | Event logging descriptions & helper methods |
| `app/models/sponsor_import_log.rb` | **100.0%** | Pend, run, done, fail state transitions |
| `app/services/sponsor_csv_downloader.rb` | **87.5%** | Scrapes Gov.uk URL and downloads registry CSV |
| `app/services/sponsor_csv_parser.rb` | **96.77%** | Normalises columns and fields of Home Office CSV |
| `app/services/sponsor_importer.rb` | **90.32%** | Import transactions, database diff, removal events |
| `app/controllers/sponsors_controller.rb` | **100.0%** | Page routing for cities, routes, A-rated, revoked |
| `app/controllers/companies_controller.rb` | **100.0%** | Dynamic metadata & canonical set on show |
| `app/controllers/search_controller.rb` | **90.91%** | Fuzzy search and typeahead result formats |
| `app/controllers/home_controller.rb` | **100.0%** | Main search form landing page |
| `app/controllers/pages_controller.rb` | **100.0%** | FAQ page logic |
| `app/jobs/sponsor_sync_job.rb` | **100.0%** | Triggers importer and queues sitemap refresh |
| `app/jobs/sitemap_refresh_job.rb` | **100.0%** | Rake sitemap generator trigger |

### Untested Files
*   `app/mailers/application_mailer.rb`: 0.0% (boilerplate file containing only configuration; no mailers are used in this application).

---

## Next Steps (Post-Deployment)

1. **Deploy to production**: `kamal deploy`
2. **Generate sitemap**: `bin/rails sitemap:create RAILS_ENV=production` on the server
3. **Submit sitemap** to Google Search Console at: `https://search.google.com/search-console`
4. **Validate JSON-LD** at: `https://search.google.com/test/rich-results`
5. **Set up Google Analytics** (or Plausible) to track organic traffic growth

> [!TIP]
> After deploying, submit the sitemap URL `https://visasponsoruk.com/sitemap.xml.gz` to Google Search Console. With 5,177 city pages + 17 route pages + 126k company pages, expect to see significant crawl activity within 1-2 weeks.

