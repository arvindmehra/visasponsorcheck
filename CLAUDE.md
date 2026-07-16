# Ground rules for Claude Code in this repo

## Never touch real data without explicit sign-off

- **Never run write operations (`create!`, `update_all`, `destroy`, imports, rake tasks that mutate data) against the dev/production database without asking first**, even to "verify a fix" or "test something quickly." If a test requires real data changes, do it inside a transaction that gets rolled back (`ActiveRecord::Base.transaction { ...; raise ActiveRecord::Rollback }`), or use a disposable test fixture with an obviously-fake name, and always clean it up in the same turn.
- **Never run `SponsorImporter.call` (or anything that calls `mark_unseen_licences_as_removed`) against a real database with fake/partial CSV data — including "just this once, to verify a fix end-to-end."** That method marks any licence not present in the current import batch as `removed` — a small test CSV against the real dev DB will mass-flip real licences. This has now happened **twice** (2026-07-11 and again 2026-07-12, the second time *while this exact rule was already written in this file*, in the course of "verifying" an unrelated `SponsorImporter` fix). If you need to test the importer end-to-end, use `bundle exec rspec spec/services/sponsor_importer_spec.rb` (isolated test DB, already covers this) — do not reach for a live `SponsorImporter.call` run against dev/production data as a shortcut, no matter how narrow the test CSV seems. RSpec coverage against the test DB is sufficient verification; a live run adds no real confidence and the downside is unbounded.
  - If this happens again anyway: `TaskStop` on a background `docker exec` only kills the client-side wrapper, not the process inside the container — use `docker restart <container>` to actually stop a runaway import. Recovery technique: the bad run creates its own `SponsorImportLog` (identifiable by a fake `source_url` or implausible `total_rows`); revert affected licences via `SponsorLicence.where(status: "removed", last_seen_at: ...< bad_log.started_at)`, verify the count matches the bad log's `SponsorChangeEvent` count *before* touching anything, then revert + delete the fake events/log inside one transaction.
- **Do not touch the dev or production database at all, including read-only checks.** The previous exception for read-only checks (`Company.count`, `bin/rails runner 'puts ...'`, `SELECT`) is removed — do not run `bin/rails runner`, `bin/rails console`, `bin/rails db:*`, `psql`, `docker exec ... psql`, `kamal app exec`, or anything else that connects to Postgres outside of the isolated RSpec test database, for any reason, even "just checking" or "read-only." Ask the user to run the command and share the output instead. The RSpec test database (`bundle exec rspec`) is unaffected by this and remains fine to write to freely — it's disposable and never holds real data.

## Docker Compose

- Dev mode is **`docker compose -f compose.yml -f compose.dev.yml up -d`** (or `--build`), always both files together. A bare `docker compose up -d` uses `compose.yml` alone, which boots a **separate, empty `visasponsoruk_production` database on a different volume** (`postgres_data`, not `postgres_dev_data`) — it looks like the app "lost its data" when really it's just connected to the wrong, empty database.
- `lib/` is not bind-mounted into the dev container (only `app/`, `config/`, `db/`, `public/`, `log/`, `tmp/` are — see `compose.dev.yml`). Rake task changes need `docker cp` into the running container to test live, or a rebuild.
- Postgres is reachable at `localhost:5433` (not 5432) from the host, database name `visasponsoruk_development` for dev data. `visasponsoruk_production` on the same port is a separate, normally-empty database — don't confuse the two in Postico/psql.

## Credentials

- Kamal decrypts `config/credentials.yml.enc` via `config/master.key` (the *default* credentials file) — not `config/credentials/production.yml.enc`. New production secrets (API keys, etc.) go in the default credentials file (`bin/rails credentials:edit`, no `--environment` flag) to actually be readable in production.
- Pure infrastructure secrets that no Rails process ever reads (e.g. `DATADOG_API_KEY` for the Datadog agent container) should stay as plain server-side env vars, matching how `.kamal/secrets` already treats `KAMAL_REGISTRY_PASSWORD`/`DB_PASSWORD` — don't route them through Rails credentials just for the sake of a single vault.

## Git

- Don't commit or push unless explicitly asked, per standing instructions.
- This repo has had concurrent edits landing mid-session from other tooling/sessions more than once — if a file you just edited looks reverted, check `git log -- <file>` before assuming your edit failed, and re-check `git status`/`git log` before starting a new destructive-adjacent task.

## CI

- The real test suite is RSpec (`bundle exec rspec`), not Rails' default Minitest `test` task — `bin/rails test`/`test:system` will silently run 0 examples since `test/` is just the unused default scaffold. CI must call `bundle exec rspec` explicitly.
- CI needs a `postgres` service (this app uses `pg_trgm`, jsonb, and other Postgres-only features) and a Tailwind build step (`bin/rails tailwindcss:build`) before running specs — `app/assets/builds/` is gitignored, so nothing produces `tailwind.css` in a fresh checkout otherwise.
