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

$tempExtract = Join-Path $env:TEMP "pi-extract-$([guid]::NewGuid().ToString('N'))"
Expand-Archive $tempZip -DestinationPath $tempExtract -Force
Remove-Item $tempZip -Force -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Force -Path $installDir | Out-Null

# Drop leftovers from previous updates (ignore any still locked by a live process).
Get-ChildItem $installDir -Recurse -Filter '*.pi-old' -Force -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

# Copy the new tree over the install dir. Windows refuses to overwrite files that are
# locked by a running process (pi.exe itself, loaded native .node addons) but allows
# renaming them, so rename-aside first and roll back if anything fails.
$stamp = Get-Date -Format 'yyyyMMddHHmmss'
$renamed = @()
try {
    foreach ($source in Get-ChildItem $tempExtract -Recurse -File -Force) {
        $relative = $source.FullName.Substring($tempExtract.Length).TrimStart('\')
        $dest = Join-Path $installDir $relative
        New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
        try {
            Copy-Item -LiteralPath $source.FullName -Destination $dest -Force
        } catch [System.UnauthorizedAccessException] {
            # Locked by the running pi (pi.exe, loaded native .node addons): renaming is
            # allowed where overwriting is not.
            $aside = "$dest.$stamp.pi-old"
            Move-Item -LiteralPath $dest -Destination $aside -Force
            $renamed += [pscustomobject]@{ Original = $dest; Aside = $aside }
            Copy-Item -LiteralPath $source.FullName -Destination $dest -Force
        }
    }
} catch {
    Write-Host "Install failed, rolling back..." -ForegroundColor Yellow
    foreach ($entry in $renamed) {
        Remove-Item -LiteralPath $entry.Original -Force -ErrorAction SilentlyContinue
        Move-Item -LiteralPath $entry.Aside -Destination $entry.Original -Force -ErrorAction SilentlyContinue
    }
    Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
    throw
}

Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

# Add install dir to user PATH if missing
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($userPath -split ';') -notcontains $installDir) {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$installDir", 'User')
    $env:Path = "$env:Path;$installDir"
    Write-Host "Added $installDir to user PATH (restart terminals to pick it up)."
}

$installed = & $currentExe --version
Write-Host "pi $installed installed to $installDir" -ForegroundColor Green
Write-Host "Leftover .pi-old files are cleaned up on the next update." -ForegroundColor DarkGray
