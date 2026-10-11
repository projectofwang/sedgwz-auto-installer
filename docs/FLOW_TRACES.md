# Flow traces — installer.ps1 (post R1–R10, ~3685 dòng)

Traced từ code thật qua 4 lanes song song (số dòng grep 2026-10-11; R-lanes đã shift lines).

## Entry

- Script tail `try { Clear-StaleTempInstallers (3644); switch ($Action) (3645) }` → Install/Update/Pause/Resume/Restart/Uninstall/Status/SetUpstream/SetDns/Menu; `default` throw. `catch` → ExitCode=1; `finally` restore host prefs; pause nếu không phải Menu; self-delete copy TEMP; `Exit-Installer` nếu ExitCode≠0.
- Menu `Show-Menu` (3605): elevate 1 lần → language → loop 0–11, mỗi action try/catch + release mutex/transcript giữa actions.

## INSTALL (Install-All 2826–2974)

1. Preflight: Ensure-Administrator (510, RunAs re-exec + exit) → Test-Platform (611) → mutex Global (554) → transcript ProgramData (586).
2. Backup-DnsSettings (2836) TRƯỚC mọi chạm DNS (safe baseline chỉ khi untainted — R5).
3. Đã cài + không `-Clean` → thả mutex/transcript → route Update-All (2838-2844).
4. Update-ManagerFromDist (2846): version.json mới + sha hợp lệ → download → verify → copy manager.ps1 → bump in-memory → thoát process (script-file) hoặc return $true (iex) = dừng flow; exception → bỏ qua, cài tiếp.
5. Set-InstallerBootstrapDns (1543): resolve OK → không đụng adapter; fail → DNS tạm 1.1.1.1/8.8.8.8 + snapshot/rollback → vẫn fail → throw.
6. Install-StageComponents (1611, chỉ TEMP): manifest → tải dnsproxy/zapret/nssm (mirror fallback) → Verify-Sha256 từng zip → validate (đúng 1 dir windows-x86_64, đủ 6 file) → hashtable staged. Fail → Restore-DnsSettings + rethrow (chưa đụng services).
7. Preserve config/blacklist/args vào TempPath\preserve.
8. Stop-AllServices (903, poll ≤15s, throw nếu treo) → Remove-OwnWinDivertDriver (KHÔNG schedule reboot ở đây — locked → throw Reboot) → rename InstallPath→-old (locked → start lại service cũ + restore DNS + throw) → dọn -old/obsolete.
9. New-Item + Set-SecureAcl → Reset-DnsToDhcp → Install-CommitComponents (1754: rollback snapshot, driver-locked + hash khác → throw Reboot, preserve whitelist, rollback khi lỗi).
10. Restore preserved → Ensure-Config (.bak + template / giữ + Repair-CacheKey) → Write-Blacklist/WinwsArgs (only-if-missing) → log rotate.
11. Create-Services (gọi Remove-Services trước; winws DEMAND khi -DnsOnly; dnsproxy AUTO; LocalService; AppExit+sc recovery) → Write-Manager → Install-Watchdog (task SYSTEM AtStartup + mỗi phút; -FailClosed sticky) → gateway-enabled.
12. Start-AllServices → Test-DnsProxyListeners (poll 10s :53, IPv6 chỉ warn) → Set-LocalDns (snapshot + rollback giữa vòng) → Write-State → dọn -old/Temp → Show-InstallSummary (+CDN opt-in).
13. Teardown lỗi: staging fail → chỉ restore DNS; lỗi trong try lớn → Stop + Remove-Services + Restore-DNS + rethrow (không service nửa vời).

## UPDATE (Update-All 2976–3096)

1. Chưa cài → thả mutex/transcript → route Install-All. Manager self-update (2993) có thể dừng flow như Install.
2. Backup-DnsSettings (3000) → EARLY-SKIP nếu `-not ForceUpdate` ∧ state==manifest (2 tag) ∧ đủ 6 file → `$staged=$null`, không bootstrap DNS, không stage.
3. Không early → stage (fail → restore DNS + throw); skipCommit nếu state==staged ∧ đủ file (binaries không thay nhưng vẫn rebuild + Write-State); ForceUpdate → luôn commit.
4. Stop + Set-SecureAcl → Reset-DnsToDhcp → commit có điều kiện (locked driver → throw) → rebuild config/services/manager/watchdog → Start + Set-LocalDns → Write-State LUÔN (kể cả skip) → dọn Temp.
5. Catch: stop → start lại binary cũ → restore DNS → throw orig + `[recovery: …]` (không mask); bỏ qua Write-State. Finally đóng transcript/mutex.

## UNINSTALL (3155–3226) + Pause/Resume/Restart

1. Preflight + mutex/transcript; chưa cài → return (không mutate).
2. Stop-AllServices → Restore-DnsSettings (never-throw; incomplete → GIỮ backup + warn, complete → xóa).
3. gateway-enabled gone → Clear-WatchdogState (flag/count, task còn) → Remove-Services (nssm→sc fallback, timeout 10s throw → abort; unregister task chỉ warn).
4. Remove-OwnWinDivertDriver -ScheduleIfLocked (foreign path → throw; locked → reboot-delete).
5. Remove-Item InstallPath (fail → DeleteTreeOnReboot: files trước, dirs deepest-first) → -Purge dọn logs/lang/touched/staging + DnsBackupDir nếu rỗng (transcript đang mở thường sót logs; backup incomplete giữ cả dir).
6. Pause: stop + DHCP (không backup) + flag off (services còn đăng ký). Resume: clear state → start → Set-LocalDns (fail → stop+DHCP+rethrow) → flag on + tests. Restart: stop/start/DNS, không đụng flag/task/backup.
7. Failure patterns: A(Update: append recovery, không mask) / B(Install: teardown full) / C(Pause-Resume-Restart: stop+DHCP+rethrow) / D(Uninstall: warn-only) / E(điểm yếu: throw chặn sau mutex mở, chỉ finally đóng, không rollback).

## WATCHDOG + ELEVATION

- Watchdog generated (2301-2436, chạy SYSTEM): guard gateway-enabled → guard in-use/failedOver → self-heal services (Automatic only) → health-check Resolve-DnsName qua 127.0.0.1 (upstream ∪ dns.google/one.one.one.one) → healthy: reset counter (+re-apply DNS nếu failed-over) / unhealthy: count+1, ≥3 strikes → DHCP fallback trừ khi fail-closed marker → luôn exit 0.
- Task: AtStartup + lặp 1 phút ×3650d, Highest, timeout 5 phút, disable→enable lại.
- Elevation: irm|iex → SelfPath TEMP-GUID + SelfContent snapshot → Ensure-Administrator materialize + RunAs re-exec (quote tay, strip `"` -Upstream, forward switches) + exit; UAC từ chối → throw. Menu elevate 1 lần/session.
