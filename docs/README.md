# VisaSponsorUK — Documentation

Project documentation for the VisaSponsorUK Rails application.

## Contents

| Document | Description |
| :--- | :--- |
| [deployment.md](deployment.md) | Full guide: provisioning a DigitalOcean Droplet, configuring Kamal 2, running `kamal setup` / `kamal deploy`, operations reference, and database backups |
| [local-docker-setup.md](local-docker-setup.md) | Running the app locally with Docker Compose, building images, pushing to Docker Hub, and common troubleshooting |
| [seo-implementation.md](seo-implementation.md) | SEO engineering walkthrough: programmatic pages (city, route, rating), structured data (JSON-LD), sitemap config, technical SEO, and post-deployment checklist |

## Quick commands

```bash
# Local development
export RAILS_MASTER_KEY=$(cat config/master.key)
docker compose -f compose.yml -f compose.dev.yml up

# Deploy to production
kamal deploy

# Rails console on production
kamal console

# Generate sitemap on production
kamal app exec 'bin/rails sitemap:create RAILS_ENV=production'

# View live logs
kamal logs
```
