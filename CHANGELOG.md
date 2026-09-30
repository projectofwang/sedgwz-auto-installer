# Changelog

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
