# Cloudflare distribution

This directory is the public distribution layer for the installer repository.

It does not participate in the installer's component runtime. The installer downloads the approved release manifest from these static assets, then downloads DNSProxy, Zapret, and NSSM directly from their pinned upstream sources.

## Cloudflare Workers Builds

Push to `main` auto-builds and deploys via the dashboard Git integration:

- Build command: `bash cloudflare/build.sh` (or `npm run build:cloudflare`)
- Deploy command: `npm run deploy`
- Root directory: `/`, branch: `main`

The Linux build checks installer/manifest version match, then publishes the
`cloudflare/public` assets. The published `installer.ps1` is unsigned;
`version.json` carries the SHA-256 of the published file. Component
supply-chain security comes from per-asset SHA-256 checks inside the installer.

The GitHub Actions workflow in this repo runs checks only (no deploys, no
`CLOUDFLARE_API_TOKEN` secret) — Cloudflare builds directly from GitHub.

## Published files

- `/` (landing page with the install command, built from `cloudflare/landing.html`)
- `/installer.ps1`
- `/approved-releases.json`
- `/version.json`

Caching and security headers for these control files come from the generated
`_headers` file (the deploy is assets-only, no Worker script).

## Public endpoints

- `https://dl.taiyuanwangjie.dpdns.org/installer.ps1`
- `https://dl.taiyuanwangjie.dpdns.org/approved-releases.json`
- `https://dl.taiyuanwangjie.dpdns.org/version.json`

## Architecture

GitHub repository (`main`) -> Cloudflare Workers Builds (auto build + deploy) -> static assets -> dl.taiyuanwangjie.dpdns.org

The installer's default DoH upstream is `https://sdns.taiyuanwangjie.dpdns.org/dns-query`.
Presets (Cloudflare, Google, Quad9, AdGuard) or a custom URL can be picked
through the installer's menu.
