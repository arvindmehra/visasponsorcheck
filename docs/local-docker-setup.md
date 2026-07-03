# Running Locally in Docker → Pushing to Docker Hub

## The workflow

```
1. Install Docker Desktop
2. Build image locally
3. Run + test with docker compose
4. Push image to Docker Hub
5. kamal deploy → DigitalOcean
```

---

## Step 1 — Install Docker Desktop

Download and install from: **https://www.docker.com/products/docker-desktop/**

After installing, open Docker Desktop and wait for the whale icon in your menu bar to show **"Docker Desktop is running"**.

Verify in Terminal:
```bash
docker --version
# Docker version 27.x.x

docker compose version
# Docker Compose version v2.x.x
```

---

## Step 2 — Build the Docker image locally

```bash
# Navigate to your project
cd ~/Documents/commercial_projects/visasponsorcheck

# Build the image (takes 2-5 minutes on first run, faster after)
docker build -t visasponsorcheck:local .
```

Watch for these key stages:
```
[build 1/7] FROM ruby:4.0.5-slim          ← downloading base image
[build 3/7] RUN bundle install            ← installing gems (~2 min)
[build 5/7] RUN bootsnap precompile       ← caching for fast boots
[build 6/7] RUN assets:precompile         ← compiling CSS/JS
```

If the build succeeds you'll see:
```
Successfully built abc123def456
Successfully tagged visasponsorcheck:local
```

---

## Step 3 — Run locally with Docker Compose

The `compose.yml` starts **two containers**: your Rails app + PostgreSQL.

```bash
# Export your Rails master key (needed by the container)
export RAILS_MASTER_KEY=$(cat config/master.key)

# Build + start both containers
docker compose up --build
```

You'll see interleaved logs from both containers:
```
postgres  | PostgreSQL init process complete; ready for start up
postgres  | database system is ready to accept connections
web       | => Rails 8.1.3 application starting in production
web       | => Listening on http://0.0.0.0:3000
```

**Open your browser:** http://localhost:3000

> [!NOTE]
> On first boot, `db:prepare` runs automatically via `bin/docker-entrypoint` — it creates the database and runs all migrations. Wait for the Rails startup message before opening the browser.

---

## Step 4 — Verify everything works

| Check | URL |
| :--- | :--- |
| Health endpoint | http://localhost:3000/up |
| Home page | http://localhost:3000 |
| Sponsor search | http://localhost:3000/?q=google |
| Sponsor directory | http://localhost:3000/sponsors |
| London city page | http://localhost:3000/sponsors/city/london |
| FAQ | http://localhost:3000/faq |

```bash
# Check container status (both should show "Up")
docker compose ps

# Tail logs
docker compose logs -f web

# Run Rails console inside the container
docker compose exec web bin/rails console

# Check the database
docker compose exec web bin/rails db:migrate:status
```

---

## Step 5 — Stop the containers

```bash
# Stop (keeps DB data)
docker compose down

# Stop AND wipe the database (clean slate)
docker compose down -v
```

---

## Step 6 — Push to Docker Hub

Once you've verified it works locally:

### 6a. Log in to Docker Hub
```bash
docker login
# Username: YOUR_DOCKERHUB_USERNAME
# Password: YOUR_DOCKERHUB_PASSWORD
```

### 6b. Tag your image with your Docker Hub username
```bash
docker tag visasponsorcheck:local YOUR_DOCKERHUB_USERNAME/visasponsorcheck:latest
```

### 6c. Push to Docker Hub
```bash
docker push YOUR_DOCKERHUB_USERNAME/visasponsorcheck:latest
```

Output:
```
The push refers to repository [docker.io/YOUR_DOCKERHUB_USERNAME/visasponsorcheck]
latest: digest: sha256:abc123... size: 1234
```

### 6d. Update config/deploy.yml
Make sure the image name matches:
```yaml
image: YOUR_DOCKERHUB_USERNAME/visasponsorcheck
```

---

## Step 7 — Deploy to DigitalOcean with Kamal

Kamal does steps 6b–6c automatically on every deploy, so you won't need to tag/push manually again:

```bash
export KAMAL_REGISTRY_PASSWORD="your_docker_hub_password"
export DB_PASSWORD="your_chosen_db_password"

# First-time only (sets up server + starts everything)
kamal setup

# Every subsequent deploy
git add -A && git commit -m "your message"
kamal deploy
```

---

## Useful Docker commands reference

```bash
# List all local images
docker images

# List running containers
docker ps

# Remove the local test image (free up disk space)
docker rmi visasponsorcheck:local

# Remove all stopped containers and unused images
docker system prune

# View image layers and sizes
docker history visasponsorcheck:local
```

---

## Troubleshooting

| Problem | Fix |
| :--- | :--- |
| `Cannot connect to the Docker daemon` | Open Docker Desktop and wait for it to start |
| `port is already in use` | Another service uses port 3000; change `"3000:3000"` to `"3001:3000"` in compose.yml |
| `RAILS_MASTER_KEY` missing | Run `export RAILS_MASTER_KEY=$(cat config/master.key)` |
| `db:prepare fails` | Check postgres container is healthy: `docker compose ps` |
| Build fails at `assets:precompile` | Ensure `compose.yml` uses `DATABASE_URL=sqlite3::memory:` (already configured) |
| `public/assets/` exists and breaks dev | Delete it: `rm -rf public/assets/` — Propshaft switches to static resolver if this folder exists |
