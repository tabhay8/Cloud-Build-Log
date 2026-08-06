# Cloud Build Log

A portfolio site that's also the workload — built to be deployed on Azure Static Web Apps,
with project data eventually served by a containerized API on Azure Container Apps backed
by Azure SQL. Right now the frontend is static HTML/CSS/JS with hardcoded project data as
a fallback while the API is being built.

**Live site:** _add your Azure Static Web Apps URL here once deployed_

## Structure

```
.
├── index.html        # Markup
├── styles.css         # All styling (theming via CSS variables, light/dark mode)
├── config.js           # Runtime config (API base URL, timeouts, retries)
├── projects.js         # Hardcoded project data — used as a fallback until the API is live
├── app.js               # Fetches /api/projects, falls back to projects.js, handles search/filter/render
└── images/               # Project screenshots referenced by projects.js
```

## How data loading works

`app.js` tries `GET {API_BASE}/api/projects`. If that fails (no API deployed yet, network
error, etc.) it falls back to the hardcoded array in `projects.js` and shows a
"Showing saved data - live API not connected yet" status. Once a real API exists, set
`API_BASE` in `config.js` to point at it — no other code changes needed, the data shape
already matches.

## Local development

No build step. Just serve the folder statically, e.g.:

```bash
npx serve .
# or
python3 -m http.server 8080
```

Then open `http://localhost:8080` (or whichever port is printed).

## Deployment

Deployed via **Azure Static Web Apps**, connected directly to this GitHub repo. Every push
to `main` triggers a GitHub Actions build/deploy automatically (workflow file added under
`.github/workflows/` once the Static Web App resource is created in Azure).

- App location: `/`
- Output location: _(empty — no build step)_
- Api location: _(empty for now — will point at the Container Apps API later)_

## Roadmap

- [ ] Stand up the Container Apps API and Azure SQL database
- [ ] Point `config.js` at the live API
- [ ] Wire up CI for the API (build → push image to ACR → new Container Apps revision)
- [ ] Terraform for all of the above