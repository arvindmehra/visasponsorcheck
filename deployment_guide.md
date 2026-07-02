# Deploying VisaSponsorUK to DigitalOcean with Kamal 2

## Architecture

Everything runs on a **single DigitalOcean Droplet**. Kamal manages two Docker containers:

```
┌─────────────── DigitalOcean Droplet ───────────────────┐
│                                                         │
│   ┌─────────────────────────────────────────────────┐  │
│   │  visasponsoruk (Rails app container)             │  │
│   │  Thruster → Puma → Rails 8                       │  │
│   └──────────────────────┬──────────────────────────┘  │
│                           │ Docker bridge network        │
│   ┌───────────────────────▼─────────────────────────┐  │
│   │  visasponsoruk-postgres (PostgreSQL 16)           │  │
│   │  /var/lib/postgresql/data → Droplet disk          │  │
│   └─────────────────────────────────────────────────┘  │
│                                                         │
│   ┌─────────────────────────────────────────────────┐  │
│   │  Traefik (Kamal proxy)                           │  │
│   │  Handles TLS (Let's Encrypt) + routing           │  │
│   └─────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
         ↑ port 80/443 exposed to internet
```

Kamal builds your Docker image locally, pushes it to Docker Hub (`arvind490/visasponsoruk`), SSHes into your Droplet, and does a **zero-downtime container swap** on every `kamal deploy`.

---

## Prerequisites checklist

- [ ] Docker Desktop installed and running locally
- [ ] Docker Hub account — username: `arvind490`, repo: `visasponsoruk` (Private)
- [ ] DigitalOcean account
- [ ] Domain: `visasponsoruk.com` with DNS access
- [ ] SSH key pair on your Mac (`~/.ssh/id_ed25519` or `~/.ssh/id_rsa`)

---

## Step 1 — Create a DigitalOcean Droplet

1. Log into [cloud.digitalocean.com](https://cloud.digitalocean.com)
2. Click **Create → Droplets**
3. Choose:
   - **Region**: `London` (closest to UK users)
   - **Image**: `Ubuntu 24.04 LTS`
   - **Size**: `Basic → Regular → $12/mo (2 GB RAM / 1 vCPU)` minimum
     *(2 GB RAM comfortably runs Rails + PostgreSQL + Kamal proxy)*
   - **Authentication**: **SSH Key** → paste contents of `~/.ssh/id_ed25519.pub`
   - **Hostname**: `visasponsoruk`
4. Click **Create Droplet**
5. Note the **IP address** (e.g. `167.99.201.191`) — needed in the next steps

---

## Step 2 — Add your SSH key to the Droplet

If you haven't already installed your SSH key:

```bash
ssh-copy-id root@167.99.201.191

# Verify it works (should not ask for a password)
ssh root@167.99.201.191 "echo connected"
```

---

## Step 3 — Point DNS to the Droplet

In your DNS provider (Cloudflare, Namecheap, etc.), add two A records for `visasponsoruk.com`:

| Type | Name | Value | TTL |
| :--- | :--- | :--- | :--- |
| `A` | `@` | `167.99.201.191` | Auto |
| `A` | `www` | `167.99.201.191` | Auto |

> [!NOTE]
> DNS propagation takes up to 30 minutes. Traefik needs a valid DNS record to automatically issue a Let's Encrypt TLS certificate. Verify DNS has propagated before running `kamal setup`:
> ```bash
> dig visasponsoruk.com
> ```

---

## Step 4 — Configure deploy.yml

Edit [config/deploy.yml](file:///Users/arvind/Documents/commercial_projects/visasponsorcheck/config/deploy.yml) and replace the placeholders with your Droplet IP:

```yaml
image: arvind490/visasponsoruk

builder:
  arch: amd64

servers:
  web:
    hosts:
      - 167.99.201.191    # ← your actual Droplet IP

proxy:
  ssl: true
  host: visasponsoruk.com
  healthcheck:
    path: /up
    interval: 5
    timeout: 10

accessories:
  postgres:
    host: 167.99.201.191  # ← same IP again
```

Everything else in [config/deploy.yml](file:///Users/arvind/Documents/commercial_projects/visasponsorcheck/config/deploy.yml) is already configured:

| Setting | Value |
| :--- | :--- |
| `service` | `visasponsoruk` |
| `image` | `arvind490/visasponsoruk` |
| `registry.username` | `arvind490` |
| `proxy.host` | `visasponsoruk.com` |
| `DATABASE_URL` | Defined under `secret` (constructed in `.kamal/secrets`) |

---

## Step 5 — Set secrets on your local machine

Kamal reads secrets from your **local shell environment** at deploy time. Export these before running any kamal command:

```bash
export KAMAL_REGISTRY_PASSWORD="your_docker_hub_password_or_access_token"
export DB_PASSWORD="choose_a_strong_password_min_20_chars"
```

Generate a strong DB password:
```bash
openssl rand -base64 24
# example: kQ3mNpL8vXr2JwYs1TqA9cZb
```

Your **`RAILS_MASTER_KEY`** is read automatically from `config/master.key` — no action needed.

To make these permanent, add them to `~/.zshrc`:
```bash
echo 'export KAMAL_REGISTRY_PASSWORD="..."' >> ~/.zshrc
echo 'export DB_PASSWORD="..."' >> ~/.zshrc
source ~/.zshrc
```

---

## Step 6 — Verify Kamal config

```bash
kamal config
```

This should print the merged configuration with no errors. If you see missing variable errors, check your shell exports.

---

## Step 7 — First deployment (runs once only)

```bash
kamal setup
```

`kamal setup` does all of this automatically:
1. SSHes into the Droplet as `root`
2. Installs Docker Engine on Ubuntu
3. Starts the **Traefik** proxy container (handles SSL)
4. Starts the **PostgreSQL** accessory container
5. Builds your Docker image locally
6. Pushes it to Docker Hub (`arvind490/visasponsoruk`)
7. Pulls and runs the app container on the Droplet
8. Runs `db:prepare` on first boot (creates all tables)

Expected output:
```
INFO [kamal] Running kamal setup on 167.99.201.191
INFO [kamal] Starting accessory postgres on 167.99.201.191
INFO [kamal] Deploying app containers to 167.99.201.191
INFO [kamal] App container is healthy
```

---

## Step 8 — Verify the deployment

```bash
# Check all containers are running
kamal app details

# Tail live application logs
kamal logs

# Health check (should return HTTP 200)
curl -I https://visasponsoruk.com/up
```

---

## Deploying code changes (day-to-day)

```bash
# Standard deploy flow
git add -A
git commit -m "your message"
git push
kamal deploy
```

Kamal will:
1. Build a new Docker image locally
2. Push it to Docker Hub
3. Pull and swap the container on the Droplet (zero downtime)

---

## Operations reference

```bash
# Rails console on the live server
kamal console
# or via alias:
kamal app exec --interactive --reuse 'bin/rails console'

# psql database console on the live server
kamal app exec --interactive --reuse 'bin/rails dbconsole'

# Run a one-off command
kamal app exec 'bin/rails db:migrate:status'

# Run pending migrations
kamal app exec 'bin/rails db:migrate'

# View live application logs
kamal logs
# or:
kamal app logs -f

# View PostgreSQL container logs
kamal accessory logs postgres

# List all running containers on the Droplet
kamal app containers

# Rollback to the previous release instantly
kamal rollback

# Open a bash shell on the server
kamal app exec --interactive --reuse 'bash'
```

---

## Database backups

PostgreSQL data lives on the Droplet disk at `/var/lib/postgresql/data`.

```bash
# SSH into the Droplet
ssh root@167.99.201.191

# Backup the database (run on the Droplet)
docker exec visasponsoruk-postgres \
  pg_dump -U visasponsoruk visasponsoruk_production \
  > /root/backup_$(date +%Y%m%d_%H%M).sql

# Exit the Droplet, then copy the backup to your Mac
scp root@167.99.201.191:/root/backup_*.sql ~/Desktop/
```

> [!TIP]
> Enable **DigitalOcean Droplet Backups** (20% of Droplet cost/month) in the Droplet settings for automated weekly snapshots of the entire disk including PostgreSQL data.

---

## Files reference

| File | Purpose |
| :--- | :--- |
| [Dockerfile](file:///Users/arvind/Documents/commercial_projects/visasponsorcheck/Dockerfile) | Multi-stage production image — thruster, jemalloc, asset precompile |
| [config/deploy.yml](file:///Users/arvind/Documents/commercial_projects/visasponsorcheck/config/deploy.yml) | Kamal 2 config — servers, proxy, PostgreSQL accessory |
| [.kamal/secrets](file:///Users/arvind/Documents/commercial_projects/visasponsorcheck/.kamal/secrets) | Secret variable names (safe to commit — no raw values) |
| [bin/docker-entrypoint](file:///Users/arvind/Documents/commercial_projects/visasponsorcheck/bin/docker-entrypoint) | Runs `db:prepare` before server starts on each boot |

---

## Environment variables summary

| Variable | Value | Where it comes from |
| :--- | :--- | :--- |
| `RAILS_MASTER_KEY` | Contents of `config/master.key` | `.kamal/secrets` (auto-read) |
| `DB_PASSWORD` | Your chosen strong password | Shell `export` |
| `POSTGRES_PASSWORD` | Set to same value as `DB_PASSWORD` | `.kamal/secrets` |
| `KAMAL_REGISTRY_PASSWORD` | Docker Hub password/token | Shell `export` |
| `DATABASE_URL` | Built from `DB_PASSWORD` in `.kamal/secrets` | `.kamal/secrets` |
| `RAILS_ENV` | `production` | `config/deploy.yml` |
| `WEB_CONCURRENCY` | `0` (single Puma process, saves RAM) | `config/deploy.yml` |
| `MALLOC_ARENA_MAX` | `2` (reduces memory fragmentation) | `config/deploy.yml` |

---

## Troubleshooting

| Error | Fix |
| :--- | :--- |
| `Permission denied (publickey)` | Run `ssh-copy-id root@YOUR_DROPLET_IP` |
| `Docker not found on server` | Run `kamal server bootstrap` |
| `SSL certificate not issued` | Wait for DNS to propagate (`dig visasponsoruk.com`), then redeploy |
| `db:prepare fails on first boot` | PostgreSQL may still be initialising — check `kamal accessory logs postgres`, then retry `kamal deploy` |
| `connection refused to postgres` | Accessory hostname must be `visasponsoruk-postgres` — verify in `DATABASE_URL` in deploy.yml |
| `BUNDLE_WITHOUT` gem error at build | Ensure `SECRET_KEY_BASE_DUMMY=1 DATABASE_URL=sqlite3::memory:` are set in Dockerfile assets precompile step |
