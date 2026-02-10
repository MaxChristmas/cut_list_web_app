# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Cut List Web App — a Rails 8.1 application for optimizing material cutting layouts. Users create projects with sheet dimensions, and the app computes optimized cutting plans (stored as JSONB in the `optimizations` table).

## Tech Stack

- Ruby 3.3.6, Rails 8.1, PostgreSQL
- Node 25.3.0 with Yarn (for JS/CSS bundling)
- Hotwire (Turbo + Stimulus), Propshaft asset pipeline
- jsbundling-rails + cssbundling-rails
- Devise for authentication
- Kamal for deployment

## Common Commands

```bash
bin/setup              # Install deps, prepare DB, start server
bin/dev                # Start development server
bin/rails test         # Run all tests
bin/rails test test/models/project_test.rb        # Run a single test file
bin/rails test test/models/project_test.rb:10     # Run a single test at line
bin/rubocop            # Lint Ruby (rubocop-rails-omakase style)
bin/brakeman --quiet --no-pager  # Security static analysis
bin/bundler-audit      # Gem vulnerability audit
bin/ci                 # Full CI pipeline (setup, lint, security, tests)
```

## Data Model

```
User -has_many-> Project -has_many-> Optimization
```

- **User**: Devise auth (email/password)
- **Project**: `name`, `sheet_width`, `sheet_height`, `allow_rotation` — belongs to User
- **Optimization**: `result` (JSONB), `efficiency` (decimal), `sheets_count`, `status` — belongs to Project

## Database

PostgreSQL. Databases: `cut_list_web_app_development` / `cut_list_web_app_test`.

```bash
bin/rails db:prepare   # Create and migrate
bin/rails db:migrate   # Run pending migrations
bin/rails db:reset     # Drop, create, migrate, seed
```
