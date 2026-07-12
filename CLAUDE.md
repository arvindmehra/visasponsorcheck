# Ground rules for Claude Code in this repo

## Never touch real data without explicit sign-off

- **Never run write operations (`create!`, `update_all`, `destroy`, imports, rake tasks that mutate data) against the dev/production database without asking first**, even to "verify a fix" or "test something quickly." If a test requires real data changes, do it inside a transaction that gets rolled back (`ActiveRecord::Base.transaction { ...; raise ActiveRecord::Rollback }`), or use a disposable test fixture with an obviously-fake name, and always clean it up in the same turn.
- **Never run `SponsorImporter.call` (or anything that calls `mark_unseen_licences_as_removed`) against a real database with fake/partial CSV data.** That method marks any licence not present in the current import batch as `removed` — a small test CSV against the real dev DB will mass-flip real licences. This happened once already (2026-07-11): a 1-row test CSV silently flipped all 140,902 real sponsor_licences from `active` to `removed`. If you need to test the importer, stub `SponsorCsvDownloader` with a CSV containing the *full* current dataset, or test against a scratch database, or just test the unit under `SponsorImporter#upsert_company`/`#upsert_licence` directly instead of the full `.call` pipeline.
- Read-only checks (`Company.count`, `bin/rails runner 'puts ...'`, `SELECT`) are always fine without asking.

## Docker Compose

- Dev mode is **`docker compose -f compose.yml -f compose.dev.yml up -d`** (or `--build`), always both files together. A bare `docker compose up -d` uses `compose.yml` alone, which boots a **separate, empty `visasponsoruk_production` database on a different volume** (`postgres_data`, not `postgres_dev_data`) — it looks like the app "lost its data" when really it's just connected to the wrong, empty database.
- `lib/` is not bind-mounted into the dev container (only `app/`, `config/`, `db/`, `public/`, `log/`, `tmp/` are — see `compose.dev.yml`). Rake task changes need `docker cp` into the running container to test live, or a rebuild.
- Postgres is reachable at `localhost:5433` (not 5432) from the host, database name `visasponsoruk_development` for dev data. `visasponsoruk_production` on the same port is a separate, normally-empty database — don't confuse the two in Postico/psql.

## Credentials

- Kamal decrypts `config/credentials.yml.enc` via `config/master.key` (the *default* credentials file) — not `config/credentials/production.yml.enc`. New production secrets (API keys, etc.) go in the default credentials file (`bin/rails credentials:edit`, no `--environment` flag) to actually be readable in production.
- Pure infrastructure secrets that no Rails process ever reads (e.g. `DD_API_KEY` for the Datadog agent container) should stay as plain server-side env vars, matching how `.kamal/secrets` already treats `KAMAL_REGISTRY_PASSWORD`/`DB_PASSWORD` — don't route them through Rails credentials just for the sake of a single vault.

## Git

- Don't commit or push unless explicitly asked, per standing instructions.
- This repo has had concurrent edits landing mid-session from other tooling/sessions more than once — if a file you just edited looks reverted, check `git log -- <file>` before assuming your edit failed, and re-check `git status`/`git log` before starting a new destructive-adjacent task.

## CI

- The real test suite is RSpec (`bundle exec rspec`), not Rails' default Minitest `test` task — `bin/rails test`/`test:system` will silently run 0 examples since `test/` is just the unused default scaffold. CI must call `bundle exec rspec` explicitly.
- CI needs a `postgres` service (this app uses `pg_trgm`, jsonb, and other Postgres-only features) and a Tailwind build step (`bin/rails tailwindcss:build`) before running specs — `app/assets/builds/` is gitignored, so nothing produces `tailwind.css` in a fresh checkout otherwise.
