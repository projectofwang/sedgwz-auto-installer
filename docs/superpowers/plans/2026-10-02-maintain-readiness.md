# Maintain Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Đưa repo solo-dev về trạng thái maintain an toàn: onboarding tối thiểu, build/deploy tái lập được, lỗi không bị nuốt, rủi ro destructive có test mocked.

**Architecture:** 4 task độc lập theo biên file: docs → deploy tái lập → hardening PS (giữ chữ ký hàm) → test bổ sung. Mỗi task có deliverable test được riêng, CI hiện tại làm gate cuối.

**Tech Stack:** PowerShell 5.1 ASCII-only, Pester 5.2+, Node 22.21.0, wrangler 4.144.0, cf 1.0.0-beta.7, GitHub Actions (windows-latest).

**Spec:** Audit 2026-10-02 (3 explorer lanes + oracle NOT READY): coverage ~15.5% (16/103 funcs), catch rỗng, thiếu CONTRIBUTING/docs, config deploy phân mảnh, lockfile cloudflare bị ignore, thiếu `npm test`, local Pester 3.4 không chạy được suite.

## Global Constraints

- PowerShell 5.1 tương thích, `installer.ps1` giữ pure ASCII (CI check `ci.yml:31`).
- `$ErrorActionPreference='Stop'` giữ nguyên (`installer.ps1:19`).
- PSScriptAnalyzer `-Severity Error` pass, ngoại trừ `PSAvoidUsingWriteHost` (`ci.yml:38`).
- Pester 5.2+ (`tests/Installer.Logic.Tests.ps1:3` `#Requires`), chạy `Invoke-Pester ./tests`.
- Single version source `installer.ps1:65 $script:InstallerVersion='1.0.4'` mirror `approved-releases.json` + CHANGELOG (CI parity `ci.yml:61-81`).
- EN/VI key parity (`ci.yml:83-93`) không được vỡ.
- Không đổi hành vi install/uninstall/service/DNS thật; test destructive chỉ mocked, không admin, không network.
- Solo-dev: thay đổi tối thiểu, revert được, không refactor lớn monolith.

## Review Focus

- DNS mutation sai (Backup/Restore/Reset) làm mất mạng — expect mock test chứng minh không chạm registry/service thật.
- Download/verify bypass (SHA256 sai vẫn pass) — expect test vector SHA đúng/sai rõ ràng.
- Service lifecycle gọi sai thứ tự — expect test thứ tự mocked, không Start/Stop thật.
- Manifest parity vỡ (version/tag/sha) — expect CI parity vẫn xanh sau mọi sửa.
- Catch rỗng nuốt lỗi cài đặt — expect mỗi catch mới đều ghi Warning/Verbose + transcript.

---

### Task 1: Onboarding docs tối thiểu

**Files:**
- Create: `CONTRIBUTING.md`
- Modify: `CHANGELOG.md` (thêm dates + Unreleased)
- Modify: `README.md` (1 đoạn chạy test local, yêu cầu Pester 5.2+)

**Interfaces:**
- Consumes: CI jobs `ci.yml:18-130`, release flow `release.yml:8-58`, `tools/Update-Manifest.ps1`.
- Produces: Quy ước test/lint/parity mà Task 2-4 tuân thủ (không API code).

- [ ] **Step 1: Viết CONTRIBUTING.md** — test/lint/manifest parity/release, yêu cầu Windows PS 5.1 + Pester 5.2+, lệnh `Invoke-Pester ./tests`, lưu ý ASCII-only.
- [ ] **Step 2: Thêm dates vào CHANGELOG.md** — giữ Keep-a-Changelog, thêm `## [Unreleased]`, date cho 1.0.1→1.0.4.
- [ ] **Step 3: Thêm đoạn local-test vào README.md** — `Install-Module Pester -RequiredVersion 5.2.0`, `Invoke-Pester ./tests`, link CONTRIBUTING.
- [ ] **Step 4: Verify** — `git status --short`, đọc lại 3 file, `git diff --stat` chỉ 3 file docs.
- [ ] **Step 5: Commit** — `git add CONTRIBUTING.md CHANGELOG.md README.md` + `git commit -m "docs: minimal maintain onboarding"`

### Task 2: Deploy tái lập được

**Files:**
- Modify: `.gitignore:1-9` (unignore `cloudflare/package-lock.json`, thêm `.env*`, `.vscode/`, `.idea/`, `*.bak`, `*~`)
- Modify: `package.json:6-12` (thêm `"test": "pwsh -NoProfile -Command Invoke-Pester ./tests"`, `"predeploy": "npm run build:cloudflare"`, giữ `deploy:cf` chain build)
- Modify: `cloudflare/package.json` (giữ `cf 1.0.0-beta.7`, `wrangler 4.144.0` exact)
- Create: `cloudflare/package-lock.json` (tạo bằng `npm install` trong `cloudflare/`, rồi commit)
- Modify: `.github/workflows/ci.yml:113-130` (`npm ci` thay `npm install` ở cả root + cloudflare, ghim `actions/setup-node` bằng SHA như `actions/checkout`)
- Modify: `cloudflare/wrangler.toml`, `cloudflare/cloudflare.config.ts`, `cloudflare/wrangler.config.ts` — chọn 1 source of truth route/worker name (giữ `wrangler.toml:2,9` làm chuẩn, 2 file kia comment trỏ về), làm rõ `cloudflare/README.md:20` "static only — worker block chỉ là route, không có main".

**Interfaces:**
- Consumes: `cloudflare/build.sh`, `ci.yml:95-130` assertions.
- Produces: Lệnh chuẩn cho Task 4 verify: `npm test`, `npm run build:cloudflare`, `npm run deploy:cf:dry`.

- [ ] **Step 1 (RED – affordance check): Ghi lại failing evidence** — chạy `npm test` expect FAIL "missing script", `git check-ignore cloudflare/package-lock.json` expect ignored.
- [ ] **Step 2: Sửa `.gitignore` + `package.json` scripts** như Files trên, giữ ASCII, JSON valid (`node -e "require('./package.json')"`)
- [ ] **Step 3: Tạo lockfile** — `cd cloudflare && npm install && cd ..`, `git add -f cloudflare/package-lock.json`, xác nhận `git check-ignore` không còn ignore.
- [ ] **Step 4: Sửa `ci.yml`** — `npm ci` 2 nơi, pin setup-node SHA, giữ nguyên các step parse/ASCII/PSScriptAnalyzer/Pester/parity.
- [ ] **Step 5: Chuẩn hoá worker config** — 1 comment header mỗi file ghi source of truth, không đổi route thật.
- [ ] **Step 6 (GREEN): Verify** — `npm test` (lúc này vẫn đỏ do Pester local, ghi nhận), `bash cloudflare/build.sh` + assertions `ci.yml:100-105`, `npm run deploy:cf:dry` nếu có creds mock/dry-run.
- [ ] **Step 7: Commit** — `git add .gitignore package.json cloudflare/package-lock.json .github/workflows/ci.yml cloudflare/wrangler.toml cloudflare/cloudflare.config.ts cloudflare/wrangler.config.ts`

### Task 3: Hardening PS — catch + constants (giữ chữ ký)

**Files:**
- Modify: `installer.ps1` — `try/catch` rỗng tại `:42,63,395,407,518,569` (+ grep lại `catch\s*\{\s*\}` để không sót), constants `:65-99` gom vào config block có comment, dùng `$script:Sources`, `$script:InstallPath` hiện có (không đổi giá trị, chỉ thêm param override/`$env:SEDG_INSTALL_PATH` fallback).
- Modify: `tools/Update-Manifest.ps1:110` catch rỗng tương tự.

**Interfaces:**
- Consumes: `Start-OpTranscript installer.ps1:557`, `Write-Step/Write-StatusLine :410/:469`.
- Produces: Chữ ký hàm giữ nguyên cho Task 4 (không đổi tên/param/return của 16 hàm đã import ở `tests:28-43`).

- [ ] **Step 1 (RED): Viết test chứng minh catch nuốt lỗi** — Pester test tạm gọi hàm có catch rỗng với input lỗi, expect không có Warning/Verbose (FAIL sau fix sẽ pass khi có log). Chạy `Invoke-Pester ./tests` xác nhận đỏ đúng lý do.
- [ ] **Step 2: Thêm logging tối thiểu vào mọi catch rỗng** — `Write-Warning "SEDG:<Function>:<lý do> ($($_.Exception.Message))"` + `Write-Verbose`, giữ `$ErrorActionPreference` flow, giữ ASCII (không dấu, không box-drawing mới).
- [ ] **Step 3: Centralize constants** — gom `InstallerVersion/InstallPath/Sources/NssmSha256/DoH defaults :1690-1694` vào 1 block `#region MaintainConfig`, cho phép override qua env/param, không đổi giá trị default.
- [ ] **Step 4 (GREEN): Verify** — PS parse `ParseFile` 0 errors, PSScriptAnalyzer Error-only pass, `Invoke-Pester ./tests` không vỡ test cũ, ASCII check `installer.ps1`.
- [ ] **Step 5: Commit** — `git add installer.ps1 tools/Update-Manifest.ps1`

### Task 4: Test bổ sung mocked (không chạm hệ thống)

**Files:**
- Modify: `tests/Installer.Logic.Tests.ps1` (import thêm hàm, không sửa 15 Describe cũ) HOẶC Create: `tests/Installer.Maintain.Tests.ps1` (khuyến nghị file mới để tránh conflict).
- Test: chính file trên, dùng harness `Import-InstallerFunction` + stubs `T/Get-ViInfo/Write-Step/Write-Done` hiện có.

**Interfaces:**
- Consumes: Chữ ký giữ nguyên từ Task 3: `Verify-Sha256`, `Get-ApprovedManifest`, `Get-ReleaseAssetUrl`, `Test-ConfigValid`, `Get-DefaultWinwsArgs`/`Get-WinwsParameters`, DNS backup/restore (mock registry), service lifecycle (mock Start/Stop).
- Produces: Evidence cuối cho maintain gate.

- [ ] **Step 1 (RED): Viết failing tests** — `Verify-Sha256` đúng/sai (tạo file temp, tính hash thật), `Get-ReleaseAssetUrl` 3 assets từ `approved-releases.json`, `Test-ConfigValid` valid/invalid, DNS backup/restore mocked (assert không gọi Set-Adapter), service order mocked. Chạy `Invoke-Pester ./tests` xác nhận FAIL "function not imported / assertion".
- [ ] **Step 2: Import + stub tối thiểu** — thêm `Import-InstallerFunction` cho các hàm trên, mock `Download-File` bằng file local (không network), mock service/DNS bằng global stub ghi call-order.
- [ ] **Step 3 (GREEN): Chạy suite** — `Invoke-Pester ./tests` PASS, output pristine, không admin/network.
- [ ] **Step 4: Chạy gate parity** — manifest schema/version/embedded parity (`ci.yml:61-81`), EN/VI parity (`:83-93`).
- [ ] **Step 5: Commit** — `git add tests/`

## Verification Budget (evidence path)

- Claim docs đủ onboard → owner Task 1 → evidence: 3 file tồn tại + đọc được, `git diff --stat` chỉ docs.
- Claim build/deploy tái lập → owner Task 2 → evidence: `npm test` tồn tại, `git check-ignore` không ignore lockfile, `bash cloudflare/build.sh` + assertions pass, `npm run deploy:cf:dry` (CI job `cf-path` xanh).
- Claim lỗi không bị nuốt + hằng số tập trung → owner Task 3 → evidence: grep `catch\s*\{\s*\}` còn 0 rỗng, PSScriptAnalyzer Error 0, PS parse 0 errors, ASCII check pass.
- Claim destructive được bảo vệ → owner Task 4 → evidence: `Invoke-Pester ./tests` PASS trên Pester 5.2+ (local cần `Install-Module Pester 5.2.0`; hiện local 3.4 nên CI là gate bắt buộc), parity checks xanh.
- Gate cuối (sau cả 4): `git status` sạch nghĩa lý, `git log --oneline -5`, full CI `ci.yml` xanh trên push. Tái dùng evidence cũ chỉ khi file liên quan không đổi.
