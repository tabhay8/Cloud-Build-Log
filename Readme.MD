# Cloud Build Log — local-first Azure stack

Version 2 of the portfolio workload. Everything runs on your machine first; Azure comes later.

## What is new in v2

**Frontend** — full-viewport responsive layout, dark/light theme, live search and tag
filtering, skeleton loading states, an API status indicator, and an architecture panel.

**API** — fail-fast config validation, structured JSON logs with request IDs, split
`/health` (liveness) and `/ready` (readiness) probes, SQL retry with exponential backoff,
connection pooling, graceful shutdown, and optional Application Insights.

**Platform** — Terraform foundation with remote state, central naming module, and a
secrets policy that keeps credentials out of code and state.

## Layout

```
api/          Express API (src/config, src/db, src/routes, server.js)
web/          Static frontend (index.html, styles.css, app.js, config.js)
db/           init.sql - schema plus seed rows
infra/        Terraform: bootstrap/, envs/dev/, modules/naming/
scripts/      init-local-env.sh
```

## Run it locally

```bash
bash scripts/init-local-env.sh   # copies the .env templates
# edit .env and api/.env, replacing every <placeholder> with your own values
docker compose up --build
```

Then open:

| URL | What it is |
|---|---|
| http://localhost:8080 | the portfolio site |
| http://localhost:3000/api/projects | project data as JSON |
| http://localhost:3000/health | liveness |
| http://localhost:3000/ready | readiness including SQL |

Run the API without Docker:

```bash
cd api && npm install && npm start
npm test          # config unit tests
```

## Secrets policy

No credentials appear in any tracked file - not in compose, not in the Terraform, not in
the tests. Every credential is a `<placeholder>` in `.env.example` and `api/.env.example`;
the real `.env` files are git-ignored. Compose references secrets as `${VAR:?}` so it fails
fast rather than falling back to a default. Usernames are variables too, so no account name
is baked in. In Azure, set `SQL_USE_MANAGED_IDENTITY=true` and leave `SQL_USER` and
`SQL_PASSWORD` empty so no password exists at all.

## API contract

`GET /api/projects?limit=50&tag=Azure` returns:

```json
[{ "id": 1, "title": "...", "description": "...", "tags": "Azure,Terraform",
   "imageUrl": null, "repoUrl": "https://...", "createdAt": "2026-07-21T00:00:00Z" }]
```

Returns `503` with an error body when the data source is unreachable, which the frontend
retries automatically.

## Pointing the frontend at a different API

`web/config.js` sets `API_BASE` at runtime — no rebuild needed. Empty means same-origin;
set it to the Container App URL for cross-origin testing, and add that origin to
`CORS_ALLOWED_ORIGINS` on the API.

## Terraform

```bash
cd infra/bootstrap && terraform init && terraform apply   # once: creates the state store
# paste the backend_snippet output into infra/envs/dev/providers.tf
cd ../envs/dev && terraform init && terraform plan
```

The dev environment currently creates the resource group and naming foundation. Network,
observability, data, and container hosting modules follow in later phases.
