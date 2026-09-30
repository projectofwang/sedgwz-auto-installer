# Pester tests for pure installer logic (no admin, no network, no services).
# Requires Pester 5.2+. Run: Invoke-Pester ./tests
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.2.0' }
$installerPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'installer.ps1'
$global:SEDGInstallerPath = $installerPath

function Import-InstallerFunction([string]$Name) {
    # M9: AST extraction instead of fragile regex.
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($global:SEDGInstallerPath, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) { throw "installer.ps1 has $($errors.Count) parse errors" }
    $fn = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name }, $true)
    if (-not $fn) { throw "installer function not found: $Name" }
    Invoke-Expression (($fn.Extent.Text) -replace '^function ', 'function global:')
}

# Stubs/globals the extracted functions expect (global for scoping).
function global:T([string]$Key) { return $Key }
function global:Get-ViInfo([string]$Text) { return $Text }
function global:Write-Step([string]$Text) { }
function global:Write-Done([string]$Text) { }
$script:Lang = 'EN'
$script:InfoVI = @{}
$script:AllowedReleaseRepos = @('AdguardTeam/dnsproxy', 'bol-van/zapret')
$script:DefaultWinwsArgsTemplate = '--wf-tcp=80,443 --wf-udp=443 --hostlist="{0}" --dpi-desync=fake,disorder2 --dpi-desync-fooling=badseq --dpi-desync-repeats=6'

Import-InstallerFunction 'Test-DnsUpstream'
Import-InstallerFunction 'Get-ReleaseAssetUrl'
Import-InstallerFunction 'Get-ManifestProperty'
Import-InstallerFunction 'Get-ManifestString'
Import-InstallerFunction 'Assert-ManifestComponents'
Import-InstallerFunction 'Normalize-WinDivertPath'
Import-InstallerFunction 'Test-ConfigValid'
Import-InstallerFunction 'Repair-CacheKey'
Import-InstallerFunction 'Get-DefaultWinwsArgs'
Import-InstallerFunction 'Get-WinwsParameters'
Import-InstallerFunction 'Write-Step'
Import-InstallerFunction 'Write-Done'
Import-InstallerFunction 'Enter-InstallerMutex'
Import-InstallerFunction 'Exit-InstallerMutex'
Import-InstallerFunction 'Get-OurProcesses'
Import-InstallerFunction 'Get-StaticDnsServers'

Describe 'Test-DnsUpstream' {
    It 'accepts https/tls/h3/quic URLs' {
        (Test-DnsUpstream 'https://dns.example/dns-query') | Should -Be $true
        (Test-DnsUpstream 'tls://dns.example') | Should -Be $true
        (Test-DnsUpstream 'h3://dns.example/dns-query') | Should -Be $true
        (Test-DnsUpstream 'quic://dns.example') | Should -Be $true
    }
    It 'rejects bad input' {
        (Test-DnsUpstream '') | Should -Be $false
        (Test-DnsUpstream 'not-a-url') | Should -Be $false
        (Test-DnsUpstream 'http://dns.example/x') | Should -Be $false
        (Test-DnsUpstream "https://dns.example/x`nupstream:`n  - evil") | Should -Be $false
    }
}

Describe 'Get-ReleaseAssetUrl' {
    It 'builds pinned download URLs' {
        $script:AllowedReleaseRepos = @('AdguardTeam/dnsproxy', 'bol-van/zapret')
        (Get-ReleaseAssetUrl 'AdguardTeam/dnsproxy' 'v0.85.0' 'a.zip') | Should -Be 'https://github.com/AdguardTeam/dnsproxy/releases/download/v0.85.0/a.zip'
    }
    It 'rejects unlisted repos, tags and asset names' {
        $script:AllowedReleaseRepos = @('AdguardTeam/dnsproxy', 'bol-van/zapret')
        { Get-ReleaseAssetUrl 'evil/repo' 'v1' 'a.zip' } | Should -Throw
        { Get-ReleaseAssetUrl 'AdguardTeam/dnsproxy' 'v1;evil' 'a.zip' } | Should -Throw
        { Get-ReleaseAssetUrl 'AdguardTeam/dnsproxy' 'v1' '../a.zip' } | Should -Throw
        { Get-ReleaseAssetUrl 'AdguardTeam/dnsproxy' '' 'a.zip' } | Should -Throw
    }
}

Describe 'Manifest shape' {
    It 'treats a missing optional mirror as empty' {
        $component = [pscustomobject]@{
            version = '2.24'
            asset = 'nssm-2.24.zip'
            url = 'https://nssm.cc/release/nssm-2.24.zip'
            sha256 = '727d1e42275c605e0f04aba98095c38a8e1e46def453cdffce42869428aa6743'
        }
        (Get-ManifestString $component 'mirror') | Should -Be ''
        (Get-ManifestString $null 'mirror') | Should -Be ''
    }
    It 'accepts the checked-in manifest and rejects incomplete components' {
        $manifestPath = Join-Path (Split-Path -Parent $global:SEDGInstallerPath) 'approved-releases.json'
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        { Assert-ManifestComponents $manifest } | Should -Not -Throw
        $badManifest = [pscustomobject]@{
            components = [pscustomobject]@{
                dnsproxy = [pscustomobject]@{
                    repository = 'AdguardTeam/dnsproxy'
                    tag = 'v0.85.0'
                    asset = 'dnsproxy-windows-amd64-v0.85.0.zip'
                    sha256 = '5b7b57b77169f6748618ed2bc2a35060f774fe2bac14a0e54352b1d502fe61eb'
                }
                zapret = [pscustomobject]@{
                    repository = 'bol-van/zapret'
                    tag = 'v72.13'
                    asset = 'zapret-v72.13.zip'
                    sha256 = 'c493e33a0dc4eba23a8686efdaba55f59755ad6ade3564aebd9d13f4c65e2e0c'
                }
                nssm = [pscustomobject]@{
                    version = '2.24'
                    asset = 'nssm-2.24.zip'
                    url = 'https://nssm.cc/release/nssm-2.24.zip'
                }
            }
        }
        { Assert-ManifestComponents $badManifest } | Should -Throw
    }
    It 'rejects non-https nssm urls' {
        $m = Get-Content -LiteralPath (Join-Path (Split-Path -Parent $global:SEDGInstallerPath) 'approved-releases.json') -Raw | ConvertFrom-Json
        $m.components.nssm.url = 'http://nssm.cc/release/nssm-2.24.zip'
        { Assert-ManifestComponents $m } | Should -Throw
    }
    It 'embedded manifest matches approved-releases.json components' {
        $manifest = Get-Content -LiteralPath (Join-Path (Split-Path -Parent $global:SEDGInstallerPath) 'approved-releases.json') -Raw | ConvertFrom-Json
        $src = Get-Content -LiteralPath $global:SEDGInstallerPath -Raw
        foreach ($pair in @(@('dnsproxy', $manifest.components.dnsproxy.tag, $manifest.components.dnsproxy.sha256), @('zapret', $manifest.components.zapret.tag, $manifest.components.zapret.sha256))) {
            $src | Should -Match ([regex]::Escape($pair[1]))
            $src | Should -Match ([regex]::Escape($pair[2]))
        }
    }
}

Describe 'Normalize-WinDivertPath' {
    It 'strips NT prefixes' {
        (Normalize-WinDivertPath '\??\C:\x\WinDivert64.sys') | Should -Be 'C:\x\WinDivert64.sys'
        (Normalize-WinDivertPath '"C:\x\WinDivert64.sys"') | Should -Be 'C:\x\WinDivert64.sys'
    }
    It 'returns null for empty input' {
        (Normalize-WinDivertPath '') | Should -BeNullOrEmpty
    }
}

Describe 'Repair-CacheKey' {
    It 'rewrites the legacy key keeping the value' {
        $script:ConfigFile = Join-Path $TestDrive 'config.yaml'
        "cache: true`ncache_max_ttl: 7200`n" | Set-Content -LiteralPath $script:ConfigFile -Encoding UTF8 -NoNewline
        Repair-CacheKey
        (Get-Content -LiteralPath $script:ConfigFile -Raw) | Should -Match 'cache-max-ttl: 7200'
    }
    It 'drops the legacy key when the new one exists' {
        $script:ConfigFile = Join-Path $TestDrive 'config2.yaml'
        "cache-max-ttl: 100`ncache_max_ttl: 7200`n" | Set-Content -LiteralPath $script:ConfigFile -Encoding UTF8 -NoNewline
        Repair-CacheKey
        $raw = Get-Content -LiteralPath $script:ConfigFile -Raw
        $raw | Should -Match 'cache-max-ttl: 100'
        ($raw -match 'cache_max_ttl') | Should -Be $false
    }
    It 'leaves modern configs untouched' {
        $script:ConfigFile = Join-Path $TestDrive 'config3.yaml'
        "cache: true`ncache-max-ttl: 3600`n" | Set-Content -LiteralPath $script:ConfigFile -Encoding UTF8 -NoNewline
        $before = Get-Content -LiteralPath $script:ConfigFile -Raw
        Repair-CacheKey
        (Get-Content -LiteralPath $script:ConfigFile -Raw) | Should -Be $before
    }
}

Describe 'Test-ConfigValid' {
    It 'accepts a minimal valid config and rejects junk' {
        $script:ConfigFile = Join-Path $TestDrive 'ok.yaml'
        "listen-ports:`n  - 53`nupstream:`n  - https://x/dns-query`n" | Set-Content -LiteralPath $script:ConfigFile -Encoding UTF8 -NoNewline
        (Test-ConfigValid) | Should -Be $true
        "hello`n" | Set-Content -LiteralPath $script:ConfigFile -Encoding UTF8 -NoNewline
        (Test-ConfigValid) | Should -Be $false
    }
}

Describe 'Get-WinwsParameters' {
    It 'prefers the args file and falls back to built-in defaults' {
        $script:ZapretPath = Join-Path $TestDrive 'zapret'
        New-Item -ItemType Directory -Path $script:ZapretPath -Force | Out-Null
        $script:WinwsArgsFile = Join-Path $script:ZapretPath 'winws-args.txt'
        if (Test-Path -LiteralPath $script:WinwsArgsFile) { Remove-Item -LiteralPath $script:WinwsArgsFile -Force }
        (Get-WinwsParameters) | Should -Match 'blacklist\.txt'
        '# only a comment' | Set-Content -LiteralPath $script:WinwsArgsFile -Encoding UTF8
        (Get-WinwsParameters) | Should -Match 'blacklist\.txt'
        '--wf-tcp=443 --custom=1' | Set-Content -LiteralPath $script:WinwsArgsFile -Encoding UTF8
        (Get-WinwsParameters) | Should -Be '--wf-tcp=443 --custom=1'
    }
    It 'default template is shared (no duplication drift)' {
        $script:ZapretPath = Join-Path $TestDrive 'zapret2'
        (Get-DefaultWinwsArgs) | Should -Match 'blacklist\.txt'
        (Get-DefaultWinwsArgs) | Should -Match 'dpi-desync'
    }
}

Describe 'Installer mutex' {
    It 'balances recursive acquire/release' {
        $script:InstallerMutex = $null
        $script:MutexDepth = 0
        Enter-InstallerMutex
        Enter-InstallerMutex
        Exit-InstallerMutex
        Exit-InstallerMutex
        $script:MutexDepth | Should -Be 0
    }
}

Describe 'H4 DNS backup signals' {
    It 'Get-StaticDnsServers reads registry NameServer (empty = automatic)' {
        # Missing key must yield empty, never throw.
        (Get-StaticDnsServers '{00000000-0000-0000-0000-000000000000}' 'Tcpip') | Should -BeNullOrEmpty
    }
    It 'installer no longer uses Get-NetIPInterface Dhcp as DNS signal' {
        $src = Get-Content -LiteralPath $global:SEDGInstallerPath -Raw
        $backupBlock = ([regex]::Match($src, '(?s)function Backup-DnsSettings \{(.*?)\n\}')).Groups[1].Value
        $backupBlock | Should -Not -Match 'Get-NetIPInterface'
        $src | Should -Match 'Get-StaticDnsServers'
        $src | Should -Match 'InterfaceGuid'
    }
    It 'bootstrap/tainted list covers temp DNS' {
        $src = Get-Content -LiteralPath $global:SEDGInstallerPath -Raw
        foreach ($ip in @('1\.1\.1\.1', '8\.8\.8\.8', '2606:4700:4700::1111')) {
            $src | Should -Match $ip
        }
    }
    It 'staging is admin-only under ProgramData, not TEMP' {
        $src = Get-Content -LiteralPath $global:SEDGInstallerPath -Raw
        $src | Should -Match "DnsBackupDir 'staging'"
        $src | Should -Match 'Set-SecureAcl \$script:TempPath -AdminOnly'
    }
}

Describe 'Language tables' {
    It 'keeps EN/VI keys in sync' {
        $text = Get-Content -LiteralPath $global:SEDGInstallerPath -Raw
        $en = ([regex]::Match($text, '(?s)EN = @\{(.*?)\n  \}')).Groups[1].Value
        $vi = ([regex]::Match($text, '(?s)VI = @\{(.*?)\n  \}')).Groups[1].Value
        $enKeys = [regex]::Matches($en, "([A-Za-z0-9]+)='") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
        $viKeys = [regex]::Matches($vi, "([A-Za-z0-9]+)='") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
        (Compare-Object $enKeys $viKeys | Measure-Object).Count | Should -Be 0
    }
    It 'keeps installer.ps1 pure ASCII' {
        $text = Get-Content -LiteralPath $global:SEDGInstallerPath -Raw
        ([regex]::Matches($text, '[^\x00-\x7F]').Count) | Should -Be 0
    }
    It 'every Write-Step/Write-Done literal has a VI entry' {
        $src = Get-Content -LiteralPath $global:SEDGInstallerPath -Raw
        $stepLiterals = [regex]::Matches($src, "Write-(?:Step|Done) '((?:[^']|'')+)'") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
        $m = [regex]::Match($src, '(?s)\$script:InfoVI = @{(.*)')
        $infoBlock = if ($m.Success) { $m.Groups[1].Value } else { '' }
        $missing = @($stepLiterals | Where-Object { $infoBlock -notmatch [regex]::Escape($_) -and $_ -notmatch '^\{' -and $_ -notmatch '\$' })
        # Allow T()-keyed steps (translated via $Texts, not $InfoVI).
        $missing = @($missing | Where-Object { $_ -notmatch '^\(T ' })
        $missing.Count | Should -Be 0
    }
}
