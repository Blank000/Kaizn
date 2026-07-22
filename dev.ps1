# dev.ps1 — hot-reload-capable dev session for this project on iQOO/Vivo.
#
# WHY THIS EXISTS: Funtouch OS suppresses/masks the "Dart VM service is
# listening on http://..." logcat line that `flutter run` parses to attach.
# Result: the tool hangs at "Waiting for VM Service port to be available...",
# never prints the key-commands banner, and r/R never work. This script
# bypasses discovery: launch with a FIXED, tokenless VM-service port, then
# `flutter attach` to the known URL. The attach session is fully interactive
# (r = hot reload, R = hot restart, q = quit).
#
# Usage:  .\dev.ps1              (auto-picks the first connected device)
#         .\dev.ps1 -Device 192.168.0.128:35125

param(
  [string]$Device = "",
  [int]$Port = 39321
)

$ErrorActionPreference = "Stop"

if (-not $Device) {
  $line = adb devices | Select-String "\sdevice$" | Select-Object -First 1
  if (-not $line) {
    Write-Host "No device connected. Check 'adb devices' / wireless debugging." -ForegroundColor Red
    exit 1
  }
  $Device = ($line.ToString() -split "\s+")[0]
}

Write-Host "[dev] Device: $Device  VM-service port: $Port" -ForegroundColor Green
Write-Host "[dev] Step 1/3: building & launching (the tool WILL hang at" -ForegroundColor Green
Write-Host "      'Waiting for VM Service port' - that's expected; we detach there)." -ForegroundColor Green

$job = Start-Job -ScriptBlock {
  param($d, $p, $proj)
  Set-Location $proj
  flutter run -d $d --device-vmservice-port $p --disable-service-auth-codes 2>&1
} -ArgumentList $Device, $Port, $PSScriptRoot

$deadline = (Get-Date).AddMinutes(12)
$launched = $false
$printed = 0
while ((Get-Date) -lt $deadline) {
  $out = (Receive-Job $job -Keep | Out-String)
  # Relay build progress lines we haven't shown yet.
  $lines = $out -split "`n"
  for ($i = $printed; $i -lt $lines.Count; $i++) {
    $l = $lines[$i].Trim()
    if ($l -match "Running Gradle|Built build|Installing") { Write-Host "      $l" }
  }
  $printed = $lines.Count
  if ($out -match "Waiting for VM Service port") { $launched = $true; break }
  if ($out -match "Gradle task assembleDebug failed|Error launching|No supported devices") {
    Write-Host $out; Stop-Job $job; Remove-Job $job -Force; exit 1
  }
  Start-Sleep -Seconds 3
}

Stop-Job $job; Remove-Job $job -Force
if (-not $launched) {
  Write-Host "[dev] Launch didn't reach the VM-service phase in time. Run 'flutter run -v' to inspect." -ForegroundColor Red
  exit 1
}

Write-Host "[dev] Step 2/3: forwarding tcp:$Port" -ForegroundColor Green
adb -s $Device forward tcp:$Port tcp:$Port | Out-Null

Write-Host "[dev] Step 3/3: attaching - r / R / q work in THIS window once connected." -ForegroundColor Green
flutter attach -d $Device --debug-url="http://127.0.0.1:$Port/"
