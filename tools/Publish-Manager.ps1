#requires -Version 5.1
<#
.SYNOPSIS
    Publishes the SEDG Desktop Manager (app + broker) and packages the pinned asset.
.DESCRIPTION
    Mode-neutral: pass exactly one of -SelfContained or -FrameworkDependent. The
    publish mode is a parameter, never a manifest/installer value. Writes only
    under -OutDir; never edits approved-releases.json or any tracked file.
#>
param(
    [switch]$SelfContained,
    [switch]$FrameworkDependent,
    [string]$Version = '',
    [string]$OutDir = '',
    [string]$Dotnet = 'dotnet',
    [string]$RepoRoot = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($SelfContained.IsPresent -eq $FrameworkDependent.IsPresent) {
    throw 'Pass exactly one of -SelfContained or -FrameworkDependent.'
}
$selfContained = $SelfContained.IsPresent

if ([string]::IsNullOrWhiteSpace($RepoRoot)) { $RepoRoot = Split-Path -Parent $PSScriptRoot }
$RepoRoot = [IO.Path]::GetFullPath($RepoRoot)
$manifestPath = Join-Path $RepoRoot 'approved-releases.json'

if ([string]::IsNullOrWhiteSpace($Version)) {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -ErrorAction Stop | ConvertFrom-Json
    $manager = $null
    try { $manager = $manifest.components.manager } catch { $manager = $null }
    if ($null -eq $manager) { throw 'approved-releases.json has no manager component; pass -Version.' }
    $Version = ([string]$manager.tag).TrimStart('v')
}
if ($Version -notmatch '^\d+(\.\d+)*$') { throw "Invalid manager version: $Version" }

if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path ([IO.Path]::GetTempPath()) ('sedg-manager-publish-' + $Version)
}
$OutDir = [IO.Path]::GetFullPath($OutDir)
$appDir = Join-Path $OutDir 'app'
$zip = Join-Path $OutDir ('sedg-manager-win-x64-' + $Version + '.zip')
if (Test-Path -LiteralPath $appDir) { Remove-Item -LiteralPath $appDir -Recurse -Force }
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
New-Item -ItemType Directory -Path $appDir -Force | Out-Null

$selfValue = if ($selfContained) { 'true' } else { 'false' }
foreach ($project in @('src\Sedg.Desktop\Sedg.Desktop.csproj', 'src\Sedg.Broker\Sedg.Broker.csproj')) {
    $projectPath = Join-Path $RepoRoot $project
    Write-Host ("Publishing {0} (self-contained={1}) ..." -f $project, $selfValue)
    & $Dotnet publish $projectPath -c Release -r win-x64 --self-contained $selfValue -p:PublishSingleFile=false -o $appDir
    if ($LASTEXITCODE -ne 0) { throw ("dotnet publish failed for {0} with exit code {1}." -f $project, $LASTEXITCODE) }
}

[IO.File]::WriteAllText((Join-Path $appDir 'manager-version.txt'), $Version, [Text.UTF8Encoding]::new($false))
foreach ($required in @('Sedg.Desktop.exe', 'Sedg.Broker.exe', 'vi\Sedg.Desktop.resources.dll')) {
    if (-not (Test-Path -LiteralPath (Join-Path $appDir $required) -PathType Leaf)) {
        throw ("Published manager is missing {0}." -f $required)
    }
}

Compress-Archive -Path (Join-Path $appDir '*') -DestinationPath $zip -Force
$hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
$size = (Get-Item -LiteralPath $zip).Length
Write-Host ("Published: {0}" -f $zip)
Write-Host ("SHA-256:  {0}" -f $hash)
Write-Host ("Size:     {0:N0} bytes" -f $size)
