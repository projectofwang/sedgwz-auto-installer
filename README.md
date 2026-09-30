# Serverless Edge DNS Gateway with Zapret DPI Bypass

## Install

Open **PowerShell as Administrator** and run:

```powershell
irm https://dl.taiyuanwangjie.dpdns.org/installer.ps1 | iex
```

## Requirements

- 64-bit Windows 10 1803+ (x64 only; ARM64 is refused because WinDivert has no ARM64 driver).
- PowerShell 5.1+, Administrator rights.
- Memory Integrity (HVCI), Defender or third-party AV may block `WinDivert64.sys`.
  If `winws-service` fails to start, check `zapret\winws.log` first; the DNS
  watchdog keeps the machine online by falling back to DHCP.

## What gets installed (in order)

Target directory: `C:\serverless-edge-dns-gateway` (locked to admins/SYSTEM;
standard users get read/execute only). Staging lives in an admin-only
`%ProgramData%\serverless-edge-dns-gateway\staging` directory (never `%TEMP%`).

1. Backs up current per-adapter DNS to `%ProgramData%\serverless-edge-dns-gateway\`
   via registry `NameServer` keyed by `InterfaceGuid` (never overwritten with a
   tainted local/bootstrap snapshot). If a newer manager exists
   online, it is downloaded, SHA-256 verified and re-executed first.
2. Stages everything (manifest, binaries, SHA-256 checks) in the admin-only
   staging dir before touching the live system. A staging failure aborts while
   any existing setup keeps running. Reinstall routes through Update unless
   `-Clean` is given.
3. Applies temporary bootstrap DNS (`1.1.1.1`/`8.8.8.8`) on physical adapters
   only if `github.com`, `nssm.cc` or the manifest host does not resolve.
4. Fetches the approved version manifest (`approved-releases.json`) and rejects
   unexpected schema/policy or installer version mismatch.
5. Downloads exact release assets over direct `github.com/.../releases/download`
   URLs (no GitHub API, no rate limits) with SHA-256 verification:
   - DNSProxy `v0.85.0` → `dnsproxy\dnsproxy.exe` (local DoH gateway)
   - Zapret `v72.13` (windows-x86_64) → `zapret\winws.exe`, `cygwin1.dll`, `WinDivert.dll`, `WinDivert64.sys`
   - NSSM `2.24` → `nssm.exe` (service manager, manifest `mirror` as fallback)
6. On reinstall, existing `config.yaml`, `blacklist.txt` and `winws-args.txt`
   are preserved across the wipe. Fresh installs write the `config.yaml`
   template (DoH upstream `https://sdns.taiyuanwangjie.dpdns.org/dns-query`,
   fallback `https://cloudflare-dns.com/dns-query`, bootstrap
   `1.1.1.1`/`8.8.8.8`/`9.9.9.9`/`208.67.222.222`, cache on with 4MB
   cap, 3600s max TTL and optimistic cache), `zapret\blacklist.txt` (empty by
   default: winws `--hostlist` matches nothing until you add domains) and
   `zapret\winws-args.txt` (UTF-8 without BOM).
7. Creates two auto-start services: `winws-service` (DPI bypass) and
   `dnsproxy-service` (DoH, LocalService, delayed start, no hard dependency on
   winws so DNS survives a driver failure), plus the `SEDG-DNS-Watchdog`
   scheduled task (every 3 minutes, `gateway-enabled` flag).
8. Drops `manager.ps1` (self-restores from memory/download if the running file
   was wiped) + the single self-elevating launcher `Gateway-Manager.bat`.
9. Starts both services, verifies UDP/TCP listeners on `127.0.0.1:53` (`::1`
   best-effort with a warning when absent).
10. Points IPv4 DNS of every active **physical** adapter to `127.0.0.1` (virtual/
    VPN adapters keep theirs) and IPv6 DNS to `::1` (DHCP fallback with warning).
11. Writes `state.json`, deletes the download TEMP, shows the summary.

Any failure aborts without leaving the machine broken: downloads are fully
staged and verified before existing services are touched, Install renames the
old directory aside (locked drivers abort before any delete with old services
restarted), an update failure restarts the previous services, and DNS is
restored from the pre-install backup (falling back to DHCP when no backup
applies). Locked drivers are never scheduled for reboot-deletion outside
Uninstall: reboot Windows and retry instead.

Flags: `-Clean` (full wipe reinstall), `-DnsOnly` (skip Zapret),
`-ForceUpdate`, `-Purge` (uninstall also drops logs + saved language),
`-FailClosed` (watchdog never falls back to DHCP; DNS stays local).

Limits: browsers with their own DoH bypass the gateway; virtual adapters keep
their DNS by default; an empty `blacklist.txt` means winws matches nothing.

## DNS upstream presets

Menu `[7]` offers Taiyuan SDNS (default), Cloudflare, Google, Quad9, AdGuard,
or a custom `https://`/`tls://`/`h3://`/`quic://` URL. The active upstream is
stored in `config.yaml` and shown by Status.

## Watchdog

`SEDG-DNS-Watchdog` (SYSTEM, every 3 minutes) probes the gateway via `127.0.0.1`.
After 3 consecutive failures it moves gateway-pointing adapters to DHCP and
restores `127.0.0.1` once healthy (fail-open by design: queries leak to ISP
during fallback; pass `-FailClosed` at Install/Update to stay on local DNS
instead). It stays idle while paused/uninstalled
(`gateway-enabled` flag missing, no adapter uses local DNS and no failover
flag) and covers newly plugged physical adapters. Status shows its state;
`watchdog-fallback.flag` / `watchdog-count.txt` in the install dir are its state.

## Troubleshooting

- `winws-service` won't stay running: read `zapret\winws.log`; HVCI/Defender/AV
  often block `WinDivert64.sys`. The watchdog keeps DNS on DHCP meanwhile.
- `Update` reports version mismatch: normally self-heals via manager
  self-update; with no network, update the manager manually first.
- `Reboot required` after update: the staged WinDivert driver differs from the
  loaded one; reboot, then run Update again.
- New adapter (USB/VPN) has no local DNS: run menu `[8]` System DNS, or set it
  manually to `127.0.0.1` / `::1`. Status warns about uncovered adapters.
- Slow downloads on old PowerShell: progress output is silenced by design;
  downloads still retry 3x (curl preferred, PowerShell fallback).

## Trust & Privacy

- Default DoH upstream (`sdns.taiyuanwangjie.dpdns.org`) sees all your DNS
  queries and can answer arbitrarily; switch presets via menu `[7]` if needed.
- Downloads fetch release zips from `github.com` and `nssm.cc`; manifests from
  the Cloudflare domain with a GitHub-raw fallback.
- The installer writes services, a scheduled task, and per-adapter DNS; logs
  live under the install dir and `%ProgramData%\serverless-edge-dns-gateway\logs`.
- No telemetry is sent anywhere by this project itself.

## Release manifest

`approved-releases.json` is a plain-JSON version pin (schema 1, `approved-only`):
component tags, asset names and SHA-256 hashes, plus the matching
`installer.ps1` version. To publish new component versions, use the helper
(it downloads, hashes, verifies archives, and syncs the embedded fallback):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Update-Manifest.ps1 -DnsproxyTag v0.86.0 -ZapretTag v72.14
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Update-Manifest.ps1 -SkipDownload  # re-sync only
```

Then bump `$script:InstallerVersion` and `installer.version` together. The build
fails if installer and manifest versions differ. A weekly
`component-watch` workflow checks upstream tags and opens a review PR when
either component moves; merging it publishes as usual.

The Cloudflare build publishes `approved-releases.json` and applies `no-store`
security headers to the control endpoints.

Production deploys automatically: push to `main` triggers Cloudflare Workers Builds
(Build: `bash cloudflare/build.sh`, Deploy: `npm run deploy`). The published
`installer.ps1` is unsigned; `version.json` records its SHA-256 so the download
can be checked before running, and `SHA256SUMS` lets users cross-check the
Cloudflare copy against GitHub Releases (different origin). Binary integrity
is enforced by per-asset SHA-256 verification inside the installer. Every
`vX.Y.Z` tag also publishes `installer.ps1` + `SHA256SUMS` to GitHub Releases
via the `release` workflow (tag must match the installer version); artifact
attestation + Authenticode signing remain future work (see H6 plan).

Trust model: manifest content is trusted via HTTPS (static assets + GitHub
fallback) and the installer/manifest version match — there is no detached
signature and no signing key to manage. Protect the supply chain accordingly:
enable branch protection with required reviews on `main`, and secure the
Cloudflare account with 2FA, since anyone able to push to `main`
or publish the deployment can change which binaries users install.
`taiyuanwangjie.dpdns.org` is a subdomain registered to the maintainer and
managed in the maintainer's own Cloudflare account (`dl.` serves the
installer/manifest, `sdns.` serves the default DoH upstream); it is not a
shared host any other dpdns.org user can claim. Compromising updates still
requires the Cloudflare account or a push to `main`.

## Thanks

Thanks to **BIBICADOTNET** for the original automatic installation script and concept.
Thanks to the **AdGuard DNSProxy**, **Zapret**, and **NSSM** projects for their open-source software.
Thanks to everyone testing and reporting issues.
