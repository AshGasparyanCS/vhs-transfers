<#
.SYNOPSIS
  Uploads a finished customer order to Nextcloud and returns a download link
  that stops working after 14 days.

.DESCRIPTION
  Creates a dated folder for the customer, uploads everything from a local
  folder, then makes a read-only public share with an expiry date. Prints the
  link to send to the customer.

  Config lives in %USERPROFILE%\.vhs-delivery.json and looks like this:

    {
      "User":      "Memory Archives",
      "AppPass":   "xxxxx-xxxxx-xxxxx-xxxxx-xxxxx",
      "LanUrl":    "http://192.168.4.125:30027",
      "PublicUrl": "https://cloud.173842069.xyz"
    }

  AppPass is a Nextcloud app password, not the account password. Generate it at
  Personal settings > Security > Devices & sessions.

.PARAMETER Customer
  Customer name. Used for the folder name, so keep it simple.

.PARAMETER Path
  Local folder holding the finished MP4s.

.PARAMETER Days
  How long the link stays alive. Default 14.

.PARAMETER Password
  Optional password on the link. Worth using for anything sensitive.

.PARAMETER Remote
  Upload over the public URL instead of the LAN address. Slower and goes through
  the Cloudflare tunnel, so only use it when away from home.

.EXAMPLE
  .\New-Delivery.ps1 -Customer "Sarkisian" -Path "D:\Captures\Sarkisian"

.EXAMPLE
  .\New-Delivery.ps1 -Customer "Petrosyan" -Path "D:\Captures\Petrosyan" -Days 21 -Password "1234"

.EXAMPLE
  # Show every delivery currently on the server and when each link dies
  .\New-Delivery.ps1 -List

.EXAMPLE
  # Delete delivery folders whose links have already expired
  .\New-Delivery.ps1 -Cleanup
#>

[CmdletBinding(DefaultParameterSetName = 'Upload')]
param(
  [Parameter(Mandatory = $true, ParameterSetName = 'Upload', Position = 0)]
  [string] $Customer,

  [Parameter(Mandatory = $true, ParameterSetName = 'Upload', Position = 1)]
  [string] $Path,

  [Parameter(ParameterSetName = 'Upload')]
  [ValidateRange(1, 365)]
  [int] $Days = 14,

  [Parameter(ParameterSetName = 'Upload')]
  [string] $Password,

  [Parameter(ParameterSetName = 'Upload')]
  [switch] $Remote,

  [Parameter(Mandatory = $true, ParameterSetName = 'List')]
  [switch] $List,

  [Parameter(Mandatory = $true, ParameterSetName = 'Cleanup')]
  [switch] $Cleanup
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Say  { param($m) Write-Host "`n>>> $m" -ForegroundColor Cyan }
function Info { param($m) Write-Host "    $m" -ForegroundColor Gray }
function Good { param($m) Write-Host "    $m" -ForegroundColor Green }
function Bad  { param($m) Write-Host "    $m" -ForegroundColor Red }

# ------------------------------------------------------------------- config
$cfgPath = Join-Path $env:USERPROFILE '.vhs-delivery.json'
if (-not (Test-Path $cfgPath)) {
  Bad "No config at $cfgPath"
  Info 'Create it with your Nextcloud details. See the help at the top of this file.'
  exit 1
}
$cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
foreach ($k in 'User', 'AppPass', 'LanUrl', 'PublicUrl') {
  if (-not $cfg.$k) { Bad "Config is missing '$k'"; exit 1 }
}

$uploadBase = if ($Remote) { $cfg.PublicUrl.TrimEnd('/') } else { $cfg.LanUrl.TrimEnd('/') }
$publicBase = $cfg.PublicUrl.TrimEnd('/')

# The account name contains a space, so it must be encoded for the DAV path.
$userEnc = [Uri]::EscapeDataString($cfg.User)
$davRoot = "$uploadBase/remote.php/dav/files/$userEnc"
$ocsBase = "$uploadBase/ocs/v2.php/apps/files_sharing/api/v1/shares"

$authRaw    = "$($cfg.User):$($cfg.AppPass)"
$authHeader = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($authRaw))
$ocsHeaders = @{ 'OCS-APIRequest' = 'true'; 'Authorization' = $authHeader; 'Accept' = 'application/json' }

# ------------------------------------------------------------------- helpers
function Invoke-Dav {
  param([string]$Method, [string]$Url, [string]$InFile)
  $req = [Net.HttpWebRequest]::Create($Url)
  $req.Method = $Method
  $req.Headers.Add('Authorization', $authHeader)
  $req.Timeout = 900000
  $req.ReadWriteTimeout = 900000
  $req.AllowWriteStreamBuffering = $false      # stream, do not buffer multi-GB files in RAM

  if ($InFile) {
    $fi = Get-Item -LiteralPath $InFile
    $req.ContentLength = $fi.Length
    $in  = [IO.File]::OpenRead($fi.FullName)
    $out = $req.GetRequestStream()
    try {
      $buf = New-Object byte[] 4194304          # 4MB chunks
      while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) { $out.Write($buf, 0, $n) }
    } finally { $out.Close(); $in.Close() }
  }

  try {
    $resp = $req.GetResponse()
    $code = [int]$resp.StatusCode
    $resp.Close()
    return $code
  } catch [Net.WebException] {
    if ($_.Exception.Response) { return [int]$_.Exception.Response.StatusCode }
    throw
  }
}

function Get-Shares {
  $r = Invoke-RestMethod -Uri "$ocsBase`?format=json" -Headers $ocsHeaders -Method Get -TimeoutSec 60
  return @($r.ocs.data)
}

# ------------------------------------------------------------------- -List
if ($List) {
  Say 'Deliveries currently on the server'
  $shares = Get-Shares | Where-Object { $_.share_type -eq 3 }
  if (-not $shares) { Info 'None.'; exit 0 }
  $now = Get-Date
  foreach ($s in $shares) {
    $exp = if ($s.expiration) { [datetime]$s.expiration } else { $null }
    $left = if ($exp) { [int]($exp - $now).TotalDays } else { $null }
    $state = if (-not $exp) { 'no expiry' }
             elseif ($left -lt 0) { "EXPIRED $([math]::Abs($left))d ago" }
             else { "$left days left" }
    $colour = if ($left -ne $null -and $left -lt 0) { 'Red' } elseif ($left -ne $null -and $left -le 3) { 'Yellow' } else { 'Gray' }
    Write-Host ("    {0,-38} {1}" -f $s.path, $state) -ForegroundColor $colour
  }
  exit 0
}

# ------------------------------------------------------------------- -Cleanup
if ($Cleanup) {
  Say 'Removing deliveries whose links have expired'
  $now = Get-Date
  $shares = Get-Shares | Where-Object { $_.share_type -eq 3 -and $_.expiration }
  $dead = $shares | Where-Object { ([datetime]$_.expiration) -lt $now }

  if (-not $dead) { Good 'Nothing expired. Nothing to do.'; exit 0 }

  foreach ($s in $dead) { Info "expired: $($s.path)" }
  Write-Host ''
  $ans = Read-Host "    Delete these $($dead.Count) folder(s) and their files? Type YES"
  if ($ans -ne 'YES') { Info 'Cancelled.'; exit 1 }

  foreach ($s in $dead) {
    $segs = ($s.path.Trim('/') -split '/') | ForEach-Object { [Uri]::EscapeDataString($_) }
    $code = Invoke-Dav -Method 'DELETE' -Url "$davRoot/$($segs -join '/')"
    if ($code -in 204, 200, 404) { Good "deleted $($s.path)" } else { Bad "failed $($s.path) ($code)" }
  }
  exit 0
}

# ------------------------------------------------------------------- upload
if (-not (Test-Path -LiteralPath $Path)) { Bad "Local folder not found: $Path"; exit 1 }

$files = Get-ChildItem -LiteralPath $Path -File -Recurse
if (-not $files) { Bad "No files in $Path"; exit 1 }

$totalBytes = ($files | Measure-Object -Property Length -Sum).Sum
$safe   = ($Customer -replace '[^\w\s\-]', '').Trim() -replace '\s+', '-'
$folder = "{0}-{1}" -f $safe, (Get-Date -Format 'yyyy-MM-dd')
$expiry = (Get-Date).AddDays($Days).ToString('yyyy-MM-dd')

Say "Delivery for $Customer"
Info "files   : $($files.Count)"
Info ("size    : {0:N1} GB" -f ($totalBytes / 1GB))
Info "folder  : /$folder"
Info "link    : expires $expiry ($Days days)"
Info "via     : $uploadBase"

# --- create the remote folder
$code = Invoke-Dav -Method 'MKCOL' -Url "$davRoot/$([Uri]::EscapeDataString($folder))"
switch ($code) {
  201     { Good "created /$folder" }
  405     { Info  "/$folder already exists, adding to it" }
  401     { Bad 'Auth failed. Check User and AppPass in the config.'; exit 1 }
  default { Bad "Could not create /$folder (HTTP $code)"; exit 1 }
}

# --- upload
Say 'Uploading'
$sw = [Diagnostics.Stopwatch]::StartNew()
$done = 0L
$failed = @()

foreach ($f in $files) {
  $rel = $f.FullName.Substring((Resolve-Path -LiteralPath $Path).Path.Length).TrimStart('\', '/')
  $segs = ($rel -split '[\\/]') | ForEach-Object { [Uri]::EscapeDataString($_) }

  # make any intermediate subfolders
  if ($segs.Count -gt 1) {
    for ($i = 0; $i -lt $segs.Count - 1; $i++) {
      $sub = ($segs[0..$i] -join '/')
      Invoke-Dav -Method 'MKCOL' -Url "$davRoot/$([Uri]::EscapeDataString($folder))/$sub" | Out-Null
    }
  }

  $url = "$davRoot/$([Uri]::EscapeDataString($folder))/$($segs -join '/')"
  $code = Invoke-Dav -Method 'PUT' -Url $url -InFile $f.FullName

  if ($code -in 201, 204) {
    $done += $f.Length
    $pct = [int](100 * $done / $totalBytes)
    $mbps = if ($sw.Elapsed.TotalSeconds -gt 0) { ($done * 8 / 1e6) / $sw.Elapsed.TotalSeconds } else { 0 }
    Write-Host ("`r    {0,3}%  {1:N1} / {2:N1} GB   {3:N0} Mbps   {4}" -f `
      $pct, ($done/1GB), ($totalBytes/1GB), $mbps, $f.Name.PadRight(40).Substring(0, 40)) -NoNewline
  } else {
    $failed += "$rel (HTTP $code)"
  }
}
Write-Host ''

if ($failed) {
  Bad "$($failed.Count) file(s) failed:"
  $failed | Select-Object -First 10 | ForEach-Object { Bad "  $_" }
  Bad 'Not creating a link for an incomplete upload. Fix and re-run.'
  exit 1
}
Good ("uploaded {0:N1} GB in {1:N0}s" -f ($totalBytes/1GB), $sw.Elapsed.TotalSeconds)

# --- share link
Say 'Creating the download link'
$body = @{
  path        = "/$folder"
  shareType   = 3          # public link
  permissions = 1          # read only
  expireDate  = $expiry
}
if ($Password) { $body.password = $Password }

try {
  $r = Invoke-RestMethod -Uri "$ocsBase`?format=json" -Headers $ocsHeaders -Method Post -Body $body -TimeoutSec 60
} catch {
  Bad "Share creation failed: $($_.Exception.Message)"; exit 1
}

if ($r.ocs.meta.status -ne 'ok') {
  Bad "Share failed: $($r.ocs.meta.statuscode) $($r.ocs.meta.message)"; exit 1
}

# Nextcloud builds the URL from whichever host the request came in on, so over
# LAN it hands back a 192.168.x.x link that is useless to a customer. The token
# is the same either way, so rebuild the URL against the public domain.
$token = ($r.ocs.data.url -split '/s/')[-1]
$link  = "$publicBase/s/$token"

Write-Host ''
Write-Host '  ================================================================' -ForegroundColor Green
Write-Host '   READY' -ForegroundColor Green
Write-Host ''
Write-Host "   $link" -ForegroundColor White
Write-Host ''
Write-Host "   Expires $expiry, $Days days from now." -ForegroundColor Green
if ($Password) { Write-Host "   Password: $Password" -ForegroundColor Yellow }
Write-Host '  ================================================================' -ForegroundColor Green
Write-Host ''

try { Set-Clipboard -Value $link; Info 'Link copied to clipboard.' } catch { }

Info 'Suggested message to the customer:'
Write-Host ''
Write-Host "    Hi $Customer, your videos are ready." -ForegroundColor White
Write-Host "    Download them here: $link" -ForegroundColor White
if ($Password) { Write-Host "    Password: $Password" -ForegroundColor White }
Write-Host "    Please save them to your computer within $Days days." -ForegroundColor White
Write-Host "    After that the link stops working and the files are deleted." -ForegroundColor White
Write-Host ''
