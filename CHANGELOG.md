# Changelog

## 1.0.3

- Kill the remaining 1-2 minute outage after boot: dnsproxy now starts
  immediately (automatic) instead of delayed-auto, since static
  127.0.0.1 DNS turns every delayed minute into no network. Early
  crashes still self-heal via NSSM AppExit and SCM failure actions.

## 1.0.2

- Fix no-network after reboot: DNS adapters keep pointing at `127.0.0.1`
  while `dnsproxy-service` stayed `Stopped`.
- Harden boot: grant LocalService traverse on the install dir, set NSSM
  `AppExit Default Restart` plus SCM failure actions (`restart/5000/...`),
  watchdog self-heals stopped auto-start services (respects `-DnsOnly`),
  task runs AtStartup plus every 1 minute.
- Existing installs pick the fix up via Update (recreates services/task).

## 1.0.1

- Docs and cleanup, no behavior change: rewrote `README.md` and
  `cloudflare/README.md` (shorter, no duplicated sections), compressed
  installer comments and dropped internal review tags, removed an obsolete
  workflow example version.

## 1.0.0

- Initial release: Windows auto-installer for a local DoH gateway
  (`127.0.0.1`) with Zapret DPI bypass.
- Safe by design: stage-then-verify with per-asset SHA-256 pins, admin-only
  staging under ProgramData, reinstalls routed through the Update path
  (rename-old, abort on locked drivers), registry-based DNS backup/restore
  keyed by InterfaceGuid, manager self-restore, no reboot-deletion outside
  Uninstall.
- Local DNS on physical adapters, 3-minute watchdog with DHCP fallback and
  optional `-FailClosed`, DoH upstream presets plus custom URL,
  `-DnsOnly`/`-Clean`/`-Purge` modes.
- Supply chain: pinned manifest with embedded fallback, GitHub Releases as
  a second origin for hash cross-checks, CI (syntax, Pester, parity,
  Cloudflare build), upstream component watcher.
