<#
.SYNOPSIS
  Checks that a USB flash drive really holds as much as it claims, and that
  what you write to it reads back identical.

.DESCRIPTION
  Counterfeit flash drives report a large capacity to Windows but physically
  hold far less. They accept everything you write, report success, then silently
  discard or overwrite the earlier data. You do not find out until someone tries
  to open a file months later.

  This fills the drive with random data, recording a SHA256 for each chunk, then
  reads it all back and compares. Any mismatch means the drive is lying about
  its size or is failing.

  Run this ONCE per drive when a new pack arrives. Not per customer.

.PARAMETER DriveLetter
  The drive to test, e.g. E or E:

.PARAMETER ChunkMB
  Size of each test file in MB. Default 256.

.PARAMETER KeepFiles
  Leave the test files in place afterward. Default is to delete them.

.EXAMPLE
  .\Verify-Drive.ps1 -DriveLetter E

.NOTES
  DESTRUCTIVE. This fills the drive. Anything already on it should be considered
  gone. Only run it on blank drives straight out of the packet.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string] $DriveLetter,

  [ValidateRange(16, 2048)]
  [int] $ChunkMB = 256,

  [switch] $KeepFiles
)

$ErrorActionPreference = 'Stop'

function Write-Step { param($m) Write-Host "`n>>> $m" -ForegroundColor Cyan }
function Write-Ok   { param($m) Write-Host "    $m" -ForegroundColor Green }
function Write-Bad  { param($m) Write-Host "    $m" -ForegroundColor Red }
function Write-Info { param($m) Write-Host "    $m" -ForegroundColor Gray }

# ---------------------------------------------------------------- resolve drive
$letter = $DriveLetter.TrimEnd(':', '\').ToUpper()
if ($letter -notmatch '^[A-Z]$') { throw "Give a single drive letter, e.g. -DriveLetter E" }

$root = "${letter}:\"
if (-not (Test-Path $root)) { throw "Drive ${letter}: not found. Is it plugged in?" }

$vol = Get-Volume -DriveLetter $letter
$sizeGB = [math]::Round($vol.Size / 1GB, 1)
$freeGB = [math]::Round($vol.SizeRemaining / 1GB, 1)

Write-Step "Drive ${letter}:"
Write-Info "Label      : $(if ($vol.FileSystemLabel) { $vol.FileSystemLabel } else { '(none)' })"
Write-Info "Filesystem : $($vol.FileSystem)"
Write-Info "Reports    : $sizeGB GB total, $freeGB GB free"

# FAT32 cannot hold files over 4GB, and more importantly a 128GB+ drive
# formatted FAT32 is a common counterfeit tell.
if ($vol.FileSystem -eq 'FAT32' -and $vol.Size -gt 64GB) {
  Write-Bad "WARNING: a drive this large formatted FAT32 is a classic fake-drive sign."
}

# ---------------------------------------------------------------- confirm
Write-Host ""
Write-Host "This will FILL drive ${letter}: with test data." -ForegroundColor Yellow
Write-Host "Everything currently on it should be considered lost." -ForegroundColor Yellow
$answer = Read-Host "Type YES to continue"
if ($answer -ne 'YES') { Write-Host "Cancelled."; exit 1 }

$testDir = Join-Path $root '_drivetest'
if (Test-Path $testDir) { Remove-Item $testDir -Recurse -Force }
New-Item -ItemType Directory -Path $testDir | Out-Null

$chunkBytes = $ChunkMB * 1MB
$hashes     = @{}
$written    = 0L
$index      = 0
$sw         = [System.Diagnostics.Stopwatch]::StartNew()

# ---------------------------------------------------------------- write phase
Write-Step "Writing $ChunkMB MB chunks until full"

$rng    = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$buffer = New-Object byte[] $chunkBytes

try {
  while ($true) {
    $free = (Get-Volume -DriveLetter $letter).SizeRemaining
    if ($free -lt $chunkBytes) { break }

    $rng.GetBytes($buffer)
    $name = 'chunk_{0:D5}.bin' -f $index
    $path = Join-Path $testDir $name

    try {
      [System.IO.File]::WriteAllBytes($path, $buffer)
    } catch {
      # A drive that dies mid-write is also a failure, just a louder one.
      Write-Bad "Write failed at chunk $index : $($_.Exception.Message)"
      break
    }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hashes[$name] = [BitConverter]::ToString($sha.ComputeHash($buffer)).Replace('-', '')
    $sha.Dispose()

    $written += $chunkBytes
    $index++
    Write-Host ("`r    written {0,7:N1} GB  ({1} chunks)" -f ($written / 1GB), $index) -NoNewline
  }
} finally {
  $rng.Dispose()
}

Write-Host ""
Write-Info ("Wrote {0:N1} GB in {1} chunks, {2:N0}s" -f ($written/1GB), $index, $sw.Elapsed.TotalSeconds)

if ($index -eq 0) { throw "Nothing could be written. Drive full or write protected?" }

# ---------------------------------------------------------------- flush caches
# Windows caches aggressively. If the whole test fits in RAM the verify would
# read back from memory and a fake drive would sail through. Unplugging and
# replugging is the only reliable way to guarantee reads hit the device.
Write-Step "Flush the cache before verifying"
Write-Host "    Safely eject drive ${letter}:, unplug it, plug it back in." -ForegroundColor Yellow
Write-Host "    This matters. Without it Windows may verify from RAM and a fake" -ForegroundColor Yellow
Write-Host "    drive will pass a test it should fail." -ForegroundColor Yellow
Read-Host "    Press Enter once it is plugged back in"

if (-not (Test-Path $testDir)) { throw "Cannot see $testDir. Is the drive back and still ${letter}:?" }

# ---------------------------------------------------------------- verify phase
Write-Step "Reading everything back and comparing"

$bad = @()
$checked = 0
$sw.Restart()

foreach ($name in ($hashes.Keys | Sort-Object)) {
  $path = Join-Path $testDir $name

  if (-not (Test-Path $path)) {
    $bad += "$name : MISSING after replug"
    continue
  }

  try {
    $actual = (Get-FileHash -Path $path -Algorithm SHA256).Hash
  } catch {
    $bad += "$name : unreadable, $($_.Exception.Message)"
    continue
  }

  if ($actual -ne $hashes[$name]) { $bad += "$name : CONTENTS CHANGED" }

  $checked++
  Write-Host ("`r    verified {0} / {1}" -f $checked, $hashes.Count) -NoNewline
}

Write-Host ""
Write-Info ("Verified in {0:N0}s" -f $sw.Elapsed.TotalSeconds)

# ---------------------------------------------------------------- cleanup
if (-not $KeepFiles) {
  Write-Step "Removing test files"
  Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
  Write-Info "Done"
}

# ---------------------------------------------------------------- verdict
Write-Host ""
if ($bad.Count -eq 0) {
  Write-Host "  ================================================" -ForegroundColor Green
  Write-Host "   PASS" -ForegroundColor Green
  Write-Host ("   {0:N1} GB written and read back identical." -f ($written/1GB)) -ForegroundColor Green
  Write-Host "   Safe to give to a customer." -ForegroundColor Green
  Write-Host "  ================================================" -ForegroundColor Green
  exit 0
} else {
  Write-Host "  ================================================" -ForegroundColor Red
  Write-Host "   FAIL  ($($bad.Count) of $($hashes.Count) chunks bad)" -ForegroundColor Red
  Write-Host "   DO NOT give this drive to a customer." -ForegroundColor Red
  Write-Host "  ================================================" -ForegroundColor Red
  Write-Host ""
  $bad | Select-Object -First 15 | ForEach-Object { Write-Bad $_ }
  if ($bad.Count -gt 15) { Write-Bad "... and $($bad.Count - 15) more" }
  Write-Host ""
  Write-Info "Corrupted chunks starting partway through usually means fake capacity:"
  Write-Info "the drive wrapped around and overwrote earlier data. Return it, and"
  Write-Info "treat every drive from the same pack as suspect until tested."
  exit 1
}
