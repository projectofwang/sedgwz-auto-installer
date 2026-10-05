# Changelog

## [Unreleased]

## [1.0.5] - 2026-10-05

- Component updates: dnsproxy `v0.85.0` -> `v0.86.0`, zapret kept at
  `v72.13`; embedded manifest and `approved-releases.json` bumped to
  installer `1.0.5` with refreshed SHA-256 pins.

## [1.0.4] - 2026-10-01

- Update now always refreshes `state.json`, even when binaries are
  already current (previously a skipped commit left a stale
  `InstallerVersion`, making a successful Update look like it never ran).

## [1.0.3] - 2026-10-01

- Kill the remaining 1-2 minute outage after boot: dnsproxy now starts
  immediately (automatic) instead of delayed-auto, since static
  127.0.0.1 DNS turns every delayed minute into no network. Early
  crashes still self-heal via NSSM AppExit and SCM failure actions.

## [1.0.2] - 2026-09-30

- Fix no-network after reboot: DNS adapters keep pointing at `127.0.0.1`
  while `dnsproxy-service` stayed `Stopped`.
- Harden boot: grant LocalService traverse on the install dir, set NSSM
  `AppExit Default Restart` plus SCM failure actions (`restart/5000/...`),
  watchdog self-heals stopped auto-start services (respects `-DnsOnly`),
  task runs AtStartup plus every 1 minute.
- Existing installs pick the fix up via Update (recreates services/task).

## [1.0.1] - 2026-09-30

- Docs cleanup, no behavior change: rewrote `README.md` and
  `cloudflare/README.md` (shorter, no duplicated sections), compressed
  installer comments, removed internal review tags, and dropped an obsolete
  workflow example version.

## [1.0.0] - 2026-09-30

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

[Unreleased]: https://github.com/projectofwang/sedgwz-auto-installer/compare/v1.0.5...HEAD
[1.0.5]: https://github.com/projectofwang/sedgwz-auto-installer/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/projectofwang/sedgwz-auto-installer/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/projectofwang/sedgwz-auto-installer/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/projectofwang/sedgwz-auto-installer/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/projectofwang/sedgwz-auto-installer/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/projectofwang/sedgwz-auto-installer/releases/tag/v1.0.0
