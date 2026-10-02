# Serverless Edge DNS Gateway with Zapret DPI Bypass

Windows auto-installer for a local DoH gateway (`127.0.0.1`) with DPI bypass.

## Install

Run in **PowerShell as Administrator**:

```powershell
irm https://dl.taiyuanwangjie.dpdns.org/installer.ps1 | iex
```

## Requirements

- 64-bit Windows 10 1803+ (x64 only; WinDivert has no ARM64 driver).
- PowerShell 5.1+, Administrator rights.
- If `winws-service` won't start, read `zapret\winws.log` — HVCI, Defender,
  or AV often blocks `WinDivert64.sys`. DNS stays online via DHCP fallback
  (see Watchdog).

## What it does

Installs to `C:\serverless-edge-dns-gateway` (admins/SYSTEM only):

1. Backs up per-adapter DNS (registry `NameServer` by `InterfaceGuid`) to
   ProgramData. The backup is never overwritten with local/bootstrap addresses.
2. Stages and SHA-256-verifies every download in an admin-only staging dir
   before touching the live system. Reinstalls go through Update unless
   `-Clean` is given.
3. Downloads pinned releases over HTTPS (no GitHub API): DNSProxy `v0.85.0`,
   Zapret `v72.13`, NSSM `2.24` (with mirror fallback).
4. Preserves `config.yaml`, `blacklist.txt`, `winws-args.txt` across reinstalls.
   Fresh installs write a `config.yaml` template (DoH upstream + neutral
   fallback, bootstrap resolvers, cache with 3600s max TTL), an empty
   `blacklist.txt`, and a commented `winws-args.txt` (UTF-8, no BOM).
5. Creates `winws-service` (DPI bypass) and `dnsproxy-service` (DoH,
   LocalService, no hard dependency on winws so DNS survives driver failure),
   plus the `SEDG-DNS-Watchdog` scheduled task (every 3 minutes).
6. Drops `manager.ps1` (self-restores if wiped mid-install) with the single
   self-elevating launcher `Gateway-Manager.bat`.
7. Points physical adapters at `127.0.0.1` / `::1`. VPN/virtual adapters keep
   their DNS. Temporary bootstrap DNS (`1.1.1.1`/`8.8.8.8`) is applied only
   when release hosts don't resolve.

Any failure restores the previous state: old services restart and DNS rolls
back to the pre-install backup (DHCP when no backup applies). Locked drivers
abort the install — reboot and retry. Nothing is scheduled for reboot-deletion
outside Uninstall.

Flags: `-Clean` (full wipe reinstall), `-DnsOnly` (skip Zapret),
`-ForceUpdate`, `-Purge` (uninstall also drops logs + saved language),
`-FailClosed` (watchdog never falls back to DHCP).

Limits: browsers with their own DoH bypass the gateway; an empty
`blacklist.txt` matches nothing until you add domains.

## DNS upstream

Menu `[7]` offers Taiyuan SDNS (default), Cloudflare, Google, Quad9, AdGuard,
or a custom `https://`/`tls://`/`h3://`/`quic://` URL. The active upstream is
stored in `config.yaml` and shown by Status.

## Watchdog

`SEDG-DNS-Watchdog` (SYSTEM, every 3 minutes) probes the gateway via
`127.0.0.1`. After 3 consecutive failures it moves gateway adapters to DHCP
and restores local DNS on recovery — fail-open by design, so pass
`-FailClosed` at Install/Update to stay on local DNS instead. It stays idle
while paused/uninstalled and also covers newly plugged physical adapters.
State files: `watchdog-fallback.flag`, `watchdog-count.txt`.

## Troubleshooting

- `winws-service` won't stay running: read `zapret\winws.log` (HVCI/AV
  blocking the driver is the usual cause); DNS stays on DHCP meanwhile.
- `Reboot required` after update: the staged driver differs from the loaded
  one; reboot, then run Update again.
- New adapter without local DNS: run menu `[8]` System DNS, or set
  `127.0.0.1` / `::1` manually. Status warns about uncovered adapters.
- Slow downloads on old PowerShell: progress output is silenced by design;
  downloads use curl with retries (PowerShell fallback).

## Trust and privacy

- The default DoH upstream sees all your DNS queries and can answer
  arbitrarily; switch presets via menu `[7]` if needed.
- Release zips come from `github.com` and `nssm.cc`; the manifest comes from
  the Cloudflare domain with a GitHub-raw fallback.
- The installer writes services, a scheduled task, and per-adapter DNS. Logs
  live under the install dir and `%ProgramData%\serverless-edge-dns-gateway\logs`.
- No telemetry is sent anywhere by this project.
- Verify before running (commands on the landing page): compare the download
  hash against `version.json`, then cross-check `SHA256SUMS` against GitHub
  Releases (different origin).

## For maintainers

Run the local tests before pushing (Pester 5.2+ required; Windows PowerShell
5.1, no admin and no network needed):

```powershell
Install-Module Pester -RequiredVersion 5.2.0 -Scope CurrentUser -Force
Import-Module Pester -MinimumVersion 5.2.0 -Force
Invoke-Pester ./tests
```

Contribution, lint, parity and release conventions: see
[CONTRIBUTING.md](CONTRIBUTING.md).

`approved-releases.json` pins component tags, asset names, and SHA-256 hashes
plus the matching installer version. To ship new component versions:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Update-Manifest.ps1 -DnsproxyTag v0.86.0 -ZapretTag v72.14
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Update-Manifest.ps1 -SkipDownload  # re-sync only
```

Then bump `$script:InstallerVersion` and `installer.version` together — the
build fails on mismatch. A weekly `component-watch` workflow opens a review PR
on new upstream tags; merging to `main` deploys via Cloudflare, and pushing a
`vX.Y.Z` tag publishes GitHub Releases (tag must match the installer version;
tags and releases are immutable).

Trust model: HTTPS transport plus installer/manifest version match. The
installer is unsigned — there is no detached signature to verify. The
`taiyuanwangjie.dpdns.org` subdomain is registered to the maintainer and
managed in the maintainer's own Cloudflare account (`dl.` serves the
installer/manifest, `sdns.` the default upstream). `main` blocks force-pushes
and `v*` tags cannot be deleted or moved, so protect the Cloudflare account
(2FA) and the `COMPONENT_WATCH_TOKEN` secret: anyone able to push to `main`
or publish the deployment controls what users install. Third-party licenses:
see `THIRD-PARTY.md`.

## Thanks

Thanks to **BIBICADOTNET** for the original automatic installation script and concept.
Thanks to the **AdGuard DNSProxy**, **Zapret**, and **NSSM** projects for their open-source software.
Thanks to everyone testing and reporting issues.
