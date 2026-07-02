# syntax=docker/dockerfile:1
# check=error=true

# ============================================================
# Production Dockerfile for Kamal deployment on DigitalOcean
# Thruster acts as the HTTP proxy in front of Puma.
#
# Build locally (optional):
#   docker build -t visasponsoruk .
# Deployed automatically by:
#   kamal deploy
# ============================================================

# Match the Ruby version in .ruby-version
ARG RUBY_VERSION=4.0.5
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# ── Runtime packages ───────────────────────────────────────
# libvips  → Active Storage image processing
# libpq5   → PostgreSQL client runtime (required by pg gem)
# curl     → Health-check probes
# libjemalloc2 → Low-latency memory allocator for Ruby
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libjemalloc2 \
      libpq5 \
      libvips && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# ── Build arguments (overridable from compose) ────────────────
# Default values are for production. compose.dev.yml overrides these.
ARG BUNDLE_WITHOUT="development:test"
ARG RAILS_ENV="production"

# ── Environment ────────────────────────────────────────────
ENV RAILS_ENV=$RAILS_ENV \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT=$BUNDLE_WITHOUT \
    RAILS_LOG_TO_STDOUT="true" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# Create a stable symlink for jemalloc so LD_PRELOAD works on both
# amd64 and arm64 without needing $(uname -m) which ENV doesn't evaluate.
RUN ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so


# ============================================================
# Build stage – compile gems and assets then discard
# ============================================================
FROM base AS build

# Build-time packages (not included in the final image)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libpq-dev \
      libvips \
      libyaml-dev \
      pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# ── Install gems ───────────────────────────────────────────
COPY Gemfile Gemfile.lock ./

RUN bundle install && \
    # Strip gem cache and git metadata to shrink image size
    rm -rf ~/.bundle/ \
           "${BUNDLE_PATH}"/ruby/*/cache \
           "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # Pre-compile bootsnap (-j 1 avoids QEMU parallelism bug)
    bundle exec bootsnap precompile -j 1 --gemfile

# ── Copy application source ────────────────────────────────
COPY . .

# Pre-compile bootsnap cache for app code
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# ── Compile assets ─────────────────────────────────────────
# DATABASE_URL=sqlite3::memory: → no PostgreSQL server exists at build time;
#   this prevents Rails from trying to connect to any socket.
# SECRET_KEY_BASE_DUMMY=1 → Rails generates a temporary in-memory secret
#   instead of crashing due to missing credentials at build time.
RUN DATABASE_URL=sqlite3::memory: SECRET_KEY_BASE_DUMMY=1 \
    ./bin/rails assets:precompile


# ============================================================
# Final image – lean runtime, no build tools
# ============================================================
FROM base

# Non-root user for container security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

# Copy compiled gems and application code from build stage
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

USER 1000:1000

# ── Entrypoint ─────────────────────────────────────────────
# Runs db:prepare (create + migrate) before the server starts on first boot.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Thruster listens on port 80 and proxies to Puma on 3000.
# It also serves static assets and handles HTTP/2 + TLS termination.
EXPOSE 80

CMD ["./bin/thrust", "./bin/rails", "server"]
