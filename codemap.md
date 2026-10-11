# Repository Atlas: sedgwz-auto-installer

## Project Responsibility
Auto-installer Windows cho DNS gateway (dnsproxy) + DPI-bypass routing (zapret/winws), quản lý bằng NSSM services + watchdog scheduled task. One-script PowerShell 5.1 monolith (`installer.ps1`, 113 functions, ~199KB), manifest pinning `approved-only`, phân phối tĩnh qua Cloudflare assets-only.

## System Entry Points
- `installer.ps1 -Action <X>` (mặc định `Menu`): `Install-All/Update-All/Status/Restart/Uninstall -Purge/Show-Menu`; chạy trực tiếp hoặc `irm https://dl.../installer.ps1 | iex` (self-path fallback L49-55).
- `approved-releases.json`: source of truth pin version + sha256 (installer v1.2.0, dnsproxy v0.86.0, zapret v72.13, nssm 2.24).
- `npm run build:cloudflare` / `deploy(:cf)`: build + deploy kênh phân phối tĩnh.
- `tools/Update-Manifest.ps1`: dev-time bump manifest + sync embedded fallback vào installer.
- `Invoke-Pester ./tests` / `npm test`: unit + mocked + E2E smoke (admin).

## Root Assets
| File | Role |
|---|---|
| `installer.ps1` | Entry point duy nhất, `-Action` dispatcher (switch ~L3600), staged download → verify → commit, watchdog, i18n `T()` |
| `approved-releases.json` | Pinned manifest `schema:1/policy:approved-only`, mỗi component có `tag/asset/url/sha256` |
| `package.json` | npm scripts → Pester + build/deploy cloudflare; devDep wrangler 4.147.0 |
| `tools/Update-Manifest.ps1` | Regen manifest + patch installer (xem tools/codemap.md) |
| `cloudflare/` | Kênh phân phối tĩnh dl.* (xem cloudflare/codemap.md) |
| `tests/` | Pester unit/mocked + integration fixtures (excluded khỏi codemap init theo skill) |

## Directory Map (Aggregated)
| Directory | Responsibility Summary | Detailed Map |
|---|---|---|
| `tools/` | Maintainer-only manifest tooling: giữ `approved-releases.json` + embedded fallback trong installer đồng bộ. | [View Map](tools/codemap.md) |
| `cloudflare/` | Static distribution channel assets-only (không Worker script): publish installer + manifest + integrity files + landing page lên `dl.*`. | [View Map](cloudflare/codemap.md) |

## Flow (end-to-end)
1. User → landing `dl.taiyuanwangjie.dpdns.org` → `irm .../installer.ps1 | iex`.
2. `build.sh` copy installer + manifest + landing → `cloudflare/public/` (CRLF normalize) → sinh `_headers/version.json/SHA256SUMS`, assert version parity → deploy static (push main).
3. `Get-ApprovedManifest` (~L704) fetch manifest từ project endpoint → fallback raw GitHub → fallback embedded copy (warn).
4. `Install-StageComponents` (~L1580): download từng asset theo repo/tag → staging admin-only → `Verify-Sha256` (~L770).
5. `Install-CommitComponents` (~L1723): swap vào `C:\serverless-edge-dns-gateway`, tạo 2 NSSM services + task `SEDG-DNS-Watchdog`.
6. Watchdog (`Write-WatchdogFile` ~L2259) mỗi phút set DNS adapter → local resolver; 3 fail → DHCP fail-open (hoặc `-FailClosed`).
7. Release: tag `vX.Y.Z` khớp `$script:InstallerVersion` (~L71) → CI sinh version/SHA; `Update-Manifest.ps1` bump pin khi component mới.

## Integration / Parity Gates
- Seams: `SEDG_INSTALL_PATH`, `SEDG_MANIFEST_URL`, `SEDG_ASSET_BASE_URL` (test/packaging).
- 3-way config parity: `wrangler.toml` ↔ `wrangler.config.ts` ↔ `cloudflare.config.ts` (có test enforce).
- Version parity: `$script:InstallerVersion` ↔ `approved-releases.json.installer.version` (build.sh + CI assert).
- Cross-origin check: CF `version.json`/`SHA256SUMS` vs GitHub Releases assets.
- Installer không serve binary từ CF host — chỉ manifest + installer; binary từ pinned upstream.

## Design
- Single-script dispatcher facade; staged 2-phase (download → verify → commit) + rollback.
- Manifest pinning + embedded fallback; env-var seams cho E2E; mirror config + test parity; i18n key table; self-elevation + re-fetch hash-verified copy.
