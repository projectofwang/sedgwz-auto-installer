# installer.ps1 — Full Function Map (dòng 1–3640)

Đọc toàn bộ qua 5 lanes song song (mỗi lane ~700 dòng, biên lấn tới hết function).
Biên nối: 702/704, 1414/1416, 2122/2124, 2929/2931. Tổng ~110 functions + dispatcher top-level.

## 0. Bootstrap & session (1–64)

Params (`-Action` ValidateSet + `-Upstream/-Language/-FailClosed/-DnsOnly/-Clean/-Purge/-ForceUpdate/-IncludeCdnTest`),
`StrictMode Latest`, lưu/khôi phục host prefs (22-25), ép TLS 1.2/1.3, UTF-8 console,
`SelfPath`/`SelfContent` snapshot source cho self-elevation + self-update (46-63).

## 1. Layout & config (65–125)

`InstallerVersion='1.2.0'` (71), `InstallPath` (+`SEDG_INSTALL_PATH` seam),
`DnsProxyPath/ZapretPath/NssmPath`, `DnsBackupDir` (ProgramData), `TempPath` staging admin-only,
`ConfigFile/BlacklistFile/WinwsArgsFile/StateFile`, `GatewayFlag/FailClosedFile`,
`manifestUrl` (+`SEDG_MANIFEST_URL`), `Sources` + `NssmVersion/NssmSha256`,
`LangDir/LangFile`, `OptionalUpstreams` (5 preset DoH), `AllowedReleaseRepos`.

## 2. i18n & console UI (127–502)

| Function | Dòng | Vai trò |
|---|---|---|
| `Get-ViInfo` / `T` / `Get-SavedLang` / `Save-Lang` | 404–427 | EN/VI lookup + persist `%APPDATA%` |
| `Write-Step` / `Write-Done` / `Write-Title` / `Write-Section` / `Write-StatusLine` | 435–502 | Console UI |
| `Write-CreditBanner` / `Write-Box*` | 443–485 | Banner + khung box 70 chars |

Bảng `Texts` viết dạng `\uXXXX` ASCII (decode 1 lần vì PS5.1 BOM-less corrupt UTF-8).

## 3. Preflight: admin/mutex/transcript/platform (504–625)

| Function | Dòng | Vai trò |
|---|---|---|
| `Test-Administrator` / `Ensure-Administrator` | 504–540 | Self-materialize + relaunch elevated (quote tay PS5.1), strip `"` chống breakout |
| `Clear-StaleTempInstallers` | 542–548 | Dọn copy `%TEMP%` >7 ngày |
| `Enter/Exit-InstallerMutex` | 554–584 | Mutex `Global\SEDG-Installer`, re-entrant qua `$MutexDepth` |
| `Start/Stop-OpTranscript` | 586–609 | Transcript ProgramData, rotate 10 file |
| `Test-Platform` | 611–625 | x64-only (chặn ARM64), Win10 build ≥17134 |

## 4. Manifest trust chain (627–768)

`Get-ManifestProperty/String` (null-safe) → `Assert-ManifestComponents` (đủ field, https) →
`Test-DownloadUrl` (https, http chỉ loopback CI) → `Get-AssetDownloadBase` (`SEDG_ASSET_BASE_URL` seam) →
`Get-ReleaseAssetUrl` (allow-list repo + tag/asset regex, URL direct tránh API rate-limit) →
`Get-ApprovedManifest` (2 URI + embedded fallback, validate schema=1/policy=approved-only/version, cache).

## 5. Integrity & download (770–863)

`Verify-Sha256` (stream, validate 64-hex) → `Download-File` (curl retry ×3 → IWR fallback) →
`Expand-Zip` → `Find-File`.

## 6. Services & driver (881–1087)

`Stop-AllServices` (log port-53 owner, poll ≤15s, throw nếu treo) →
`Get-WinDivertImagePath`/`Normalize-WinDivertPath`/`Remove-OwnWinDivertDriver` (ownership check, schedule reboot-delete) →
`Schedule-DeleteOnReboot/Tree` (MoveFileEx) → `Start-AllServices` (rotate log >20MB, verify Running, throw kèm nssm status + log tail).
`Invoke-Nssm` (2437), `Remove-Services` (nssm→sc.exe fallback), `Create-Services` (NSSM config log/recovery/ACL LocalService SID).

## 7. DNS primitives (1089–1578)

`Set-AdapterDnsFamily/Static/Both` (CIM + netsh fallback, giữ family còn lại) →
`Get-AdapterDnsSnapshot`/`Restore-AdapterDnsSnapshot`/`Reset-DnsToDhcp` →
`Backup-DnsSettings` (live + registry, 2 bản, skip safe-copy nếu tainted) →
`Restore-DnsSettings` (match GUID→name, filter tainted, cờ `DnsRestoreIncomplete`) →
`Set-LocalDns` (127.0.0.1/::1, rollback giữa chừng) → `Set-InstallerBootstrapDns` (DNS tạm 1.1.1.1/8.8.8.8).
`Set-SystemDns` (1972, nhập tay), `Get-NetworkAdapters`, `Get-StaticDnsServers`, `Log-Port53Owner`, `Set-SecureAcl`, `Get-OurProcesses`, `Exit-Installer` (chỉ exit khi `$PSCommandPath`).

## 8. Stage → Commit (1580–1844)

`Install-StageComponents`: manifest → tải dnsproxy/zapret/nssm (mirror fallback) → verify SHA → validate 6 file → hashtable staged.
`Install-CommitComponents`: backup live → copy staged → WinDivert lock thì đòi reboot → preserve blacklist/args/driver → rollback khi lỗi.

## 9. Config & upstream (1846–2122)

`Get-ConfiguredUpstream` (YAML→state→default) → `Test-DnsUpstream` →
`Write-OriginalConfigTemplate` / `Test-ConfigValid` / `Ensure-Config` (.bak + rewrite) →
`Repair-CacheKey` (migrate `cache_max_ttl`) → `Set-UpstreamInConfig` (thay đúng 1 block, giữ newline) →
`Set-Upstream` (menu/param, stop→ghi→restart, lỗi vẫn restart rồi rethrow) → `Set-Language`, `Get-StateReleases`, `Restart-DnsProxyService`.

## 10. Watchdog (2259–2435)

`Write-WatchdogFile` sinh script độc lập (health-check `Resolve-DnsName`, 3-strikes → DHCP trừ fail-closed) →
`Install-Watchdog` (Scheduled Task SYSTEM, AtStartup + mỗi phút) + `Clear-WatchdogState`/`Set-GatewayEnabled`.
`Write-Blacklist`/`Get-DefaultWinwsArgs`/`Get-WinwsParameters`/`Write-WinwsArgs` (user files, only-if-missing).

## 11. Manager self-update (2573–2780)

`Get-ManagerSourceContent` (memory→self→download hash-pinned) → `Write-Manager` (manager.ps1 + .bat) →
`Update-ManagerFromDist` (so version, hash verify, nhả mutex/transcript, thoát process nếu `-File`) +
`Test-OwnsProcessInvocation`, `Wait-HandoffClosePrompt`, `Write-State`, `Remove-InstallDirectoryCleanly`.

## 12. Actions (2782–3180)

`Install-All` (preflight→self-update→stage→preserve→swap→commit→services→verify; đã cài thì route `Update-All`) →
`Update-All` (early-skip khi manifest khớp, skipCommit khi version trùng, rollback = restart binary cũ) →
`Pause/Resume/Restart-All` → `Uninstall-All` (giữ backup nếu restore dở, `-Purge` dọn logs/lang/backup).

## 13. Status/Menu/dispatcher (3182–3640)

`Show-Status`/`Show-ServiceTests`/`Get-MenuStatusPanel` → `Get-IPLocation`/`Resolve-CdnIPv4`/`Test-CDNOptimization` (benchmark 9 CDN) →
`Show-InstallSummary` → `Show-MainMenu`/`Select-EntryLanguage`/`Show-Menu` (loop 0–11) →
top-level `switch ($Action)` (3600–3612) + restore host prefs + self-delete temp copy.

## Rủi ro ghi nhận (từ 5 lanes, chưa fix)

1. Manifest remote được tin hoàn toàn — sha pinning nằm trong chính manifest (734-747); chỉ allow-list repo hạn chế swap.
2. `$FailClosed/$DnsOnly/$Clean` là top-level params nhưng dùng ở function sâu qua dynamic scope (2416, 2513, 2793) — chạy đúng, dễ vỡ khi refactor.
3. `Set-Upstream` menu: thứ tự `Hashtable.Keys` không guarantee (2097) — số thứ tự preset có thể lệch giữa lần chạy.
4. Restore backup rỗng → reset TOÀN BỘ physical adapter về DHCP (1409-1411), kể cả adapter ngoài backup.
5. Ghi baseline tainted lần đầu khi chưa có bản safe (1333-1334) — trái comment "never overwritten with tainted".
6. Cleanup `Remove-Item TempPath` trong try Install (2913-2914) — throw thật sẽ trigger rollback gỡ service vừa cài xong.
7. `Test-ConfigValid`/`Get-ConfiguredUpstream` parse YAML bằng regex thô — comment/flow-style làm sai lệch im lặng.
8. Watchdog template hardcode tên service (2275-2276), drift nếu đổi `$script:WinwsService`.
9. `Clear-StaleTempInstallers` ngoài try/catch dispatcher (3596) — ném thì host prefs không được restore.
10. `Invoke-WebRequest` manifest không timeout (737); log `SEDG:` nhiều chỗ bị truncate instrumentation.

## Trạng thái fix (2026-10-11, suite 94/94 xanh, smoke admin không chạy)

| R | Trạng thái |
|---|---|
| R1 | FIXED Opt C — warn khi remote cũ hơn baseline (warn-only, vẫn dùng remote) + document trust model ở SECURITY.md + 1 It mocked |
| R2 | FIXED — param tường minh `[switch]$FailClosed/$DnsOnly/$Clean` + forward đầy đủ call chain, L531-534 giữ nguyên |
| R3 | WONTFIX (báo sai) — `OptionalUpstreams` là `[ordered]`, order giữ nguyên; đã thêm 1 It pin regression |
| R4 | FIXED — replay baseline DHCP tính là success; global reset chỉ khi có file backup, không thì skip + warn |
| R5 | FIXED — safe baseline chỉ ghi khi `-not $tainted`; tainted lần đầu skip + warn (chung 1 patch với R4) |
| R6 | FIXED — cleanup TempPath bọc try/catch non-rethrow, catch Install chỉ còn cho lỗi commit/service thật |
| R7 | FIXED (hẹp) — skip comment + strip trailing comment + nhánh flow-style; write-path giữ block-style + 3 Its |
| R8 | FIXED — template dùng `%%WINWSSERVICE%%`/`%%DNSPROXYSERVICE%%` + `.Replace()` với `$script:` vars; output byte-identical + 1 It |
| R9 | FIXED — `Clear-StaleTempInstallers` vào trong `try`, `finally` restore prefs luôn chạy |
| R10 | FIXED — `-TimeoutSec 30` cho IWR manifest; giữ 2-URI + embedded fallback |
