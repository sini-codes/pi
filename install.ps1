# pi fork installer (sini-codes/pi) - installs or updates the pi Windows binary.
# Usage: irm https://raw.githubusercontent.com/sini-codes/pi/feat/pwsh-parallel-tool/install.ps1 | iex
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repo = 'sini-codes/pi'
$installDir = Join-Path $env:LOCALAPPDATA 'pi'
$arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
$assetName = "pi-windows-$arch.zip"

Write-Host "Fetching latest release of $repo..."
$release = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers @{ 'User-Agent' = 'pi-fork-installer' }
$tag = $release.tag_name
$asset = $release.assets | Where-Object { $_.name -eq $assetName }
if (-not $asset) { throw "Asset $assetName not found in release $tag" }

$currentExe = Join-Path $installDir 'pi.exe'
if (Test-Path $currentExe) {
    $currentVersion = & $currentExe --version 2>$null
    if ($currentVersion -and ($tag.TrimStart('v') -eq "$currentVersion".Trim())) {
        Write-Host "pi $tag already installed at $installDir" -ForegroundColor Green
        return
    }
}

$tempZip = Join-Path $env:TEMP "pi-install-$([guid]::NewGuid().ToString('N')).zip"
Write-Host "Downloading $assetName ($tag)..."
Invoke-WebRequest $asset.browser_download_url -OutFile $tempZip -Headers @{ 'User-Agent' = 'pi-fork-installer' }

New-Item -ItemType Directory -Force -Path $installDir | Out-Null

# Windows allows renaming a running exe but not overwriting it.
# Move current binaries aside; clean stale ones from previous updates.
Get-ChildItem $installDir -Filter '*.old' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
if (Test-Path $currentExe) {
    $stamp = Get-Date -Format 'yyyyMMddHHmmss'
    Move-Item $currentExe "$currentExe.$stamp.old" -Force
}

# Release zip is flat (pi.exe at root)
Expand-Archive $tempZip -DestinationPath $installDir -Force
Remove-Item $tempZip -Force -ErrorAction SilentlyContinue

# Add install dir to user PATH if missing
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($userPath -split ';') -notcontains $installDir) {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$installDir", 'User')
    $env:Path = "$env:Path;$installDir"
    Write-Host "Added $installDir to user PATH (restart terminals to pick it up)."
}

$installed = & (Join-Path $installDir 'pi.exe') --version
Write-Host "pi $installed installed to $installDir" -ForegroundColor Green
