# Cloudflare distribution

Static hosting for the installer. Cloudflare Workers Builds deploys this
directory's build output; it plays no role at component runtime — the
installer fetches its manifest here, then downloads binaries from their
pinned upstream sources.

## Deploy

Push to `main` auto-builds via the dashboard Git integration:

- Build: `bash cloudflare/build.sh` (`npm run build:cloudflare`)
- Deploy: `npm run deploy:cf` (primary, `cf` CLI)
- Fallback: `npm run deploy` (Wrangler; keep `wrangler.toml` for it)
- Root directory: `/`, branch: `main`

The build rejects installer/manifest version mismatch, then emits
`cloudflare/public/`. `version.json` carries the published `installer.ps1`
SHA-256; `_headers` applies `no-store` and security headers (assets-only
deploy, no Worker script). GitHub Actions runs checks only — no deploys, no
`CLOUDFLARE_API_TOKEN` secret.

Prerequisites: `npm install` at the repo root **and** in `cloudflare/`,
plus `cf auth login` for real deploys (dry runs need no sign-in).
Because `cf` beta cannot spawn its Wrangler delegate on Windows
(`spawn EFTYPE`), the build step calls the delegate directly through
`node`:

- Dry run: `npm run deploy:cf:dry`
- Deploy: `npm run deploy:cf`

When upstream `cf` fixes the Windows spawn, replace the delegate call
with plain `cf build`.

## Files

`/` (landing page with install command, from `landing.html`) ·
`/installer.ps1` · `/approved-releases.json` · `/version.json` · `/SHA256SUMS`

## Endpoints

- `https://dl.taiyuanwangjie.dpdns.org/installer.ps1`
- `https://dl.taiyuanwangjie.dpdns.org/approved-releases.json`
- `https://dl.taiyuanwangjie.dpdns.org/version.json`

Flow: GitHub `main` → Workers Builds → static assets → `dl.` subdomain.
The default DoH upstream is `https://sdns.taiyuanwangjie.dpdns.org/dns-query`;
other presets (Cloudflare, Google, Quad9, AdGuard) or a custom URL can be
picked in the installer's menu.
