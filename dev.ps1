# dev.ps1 — hot-reload-capable dev session for this project on iQOO/Vivo.
#
# WHY THIS EXISTS: Funtouch OS suppresses/masks the "Dart VM service is
# listening on http://..." logcat line that `flutter run` parses to attach.
# Result: the tool never attaches, never prints the key-commands banner, and
# r/R never work. This script bypasses logcat discovery entirely:
#   1. build + install + launch via flutter run (then detach)
#   2. cold-start the app with a FIXED, tokenless VM-service port
#      (verified working via --ei vm-service-port + legacy observatory-port)
#   3. wait for the device socket to actually LISTEN, forward it, and
#      `flutter attach --debug-url` — fully interactive: r / R / q work.
#
# Usage:  .\dev.ps1              (auto-picks the first connected device)
#         .\dev.ps1 -Device 192.168.0.128:34227

param(
  [string]$Device = "",
  [int]$Port = 39321
)

$ErrorActionPreference = "Stop"
$App = "com.alokraj.habit_reward_tracker"
$PortHex = ('{0:X4}' -f $Port)

if (-not $Device) {
  $line = adb devices | Select-String "\sdevice$" | Select-Object -First 1
  if (-not $line) {
    Write-Host "[dev] No device connected. On the phone: Developer options -> Wireless debugging, then 'adb connect IP:PORT'." -ForegroundColor Red
    exit 1
  }
  $Device = ($line.ToString() -split "\s+")[0]
}

function Test-VmSocket {
  $out = adb -s $Device shell "grep -i ':$PortHex ' /proc/net/tcp /proc/net/tcp6 2>/dev/null"
  return [bool]($out -match ':')
}

Write-Host "[dev] Device: $Device  VM-service port: $Port" -ForegroundColor Green
Write-Host "[dev] Step 1/3: build + install + launch (progress below)..." -ForegroundColor Green

$job = Start-Job -ScriptBlock {
  param($d, $p, $proj)
  Set-Location $proj
  flutter run -d $d --device-vmservice-port $p --disable-service-auth-codes 2>&1
} -ArgumentList $Device, $Port, $PSScriptRoot

$deadline = (Get-Date).AddMinutes(12)
$printed = 0
$appUp = $false
$lastBeat = Get-Date
while ((Get-Date) -lt $deadline) {
  # Relay meaningful tool output so this never looks hung.
  $lines = @(Receive-Job $job -Keep | Out-String) -split "`n"
  for ($i = $printed; $i -lt $lines.Count; $i++) {
    $l = $lines[$i].Trim()
    if ($l -match "Gradle|Built |Installing|Launching|[Ee]rror|Exception|fail") {
      Write-Host "      $l"
    }
  }
  $printed = $lines.Count

  if ($job.State -ne 'Running') {
    Write-Host "[dev] flutter run exited early:" -ForegroundColor Red
    Receive-Job $job | Select-Object -Last 15 | ForEach-Object { Write-Host "      $_" }
    Remove-Job $job -Force; exit 1
  }

  # The app process appearing = install + launch done. That's our signal
  # (the 'Waiting for VM Service' line only exists in verbose mode).
  $pid2 = (adb -s $Device shell pidof $App 2>$null | Out-String).Trim()
  if ($pid2) { $appUp = $true; break }

  if (((Get-Date) - $lastBeat).TotalSeconds -ge 20) {
    Write-Host "      ...still building/installing" -ForegroundColor DarkGray
    $lastBeat = Get-Date
  }
  Start-Sleep -Seconds 3
}

Stop-Job $job -ErrorAction SilentlyContinue
Remove-Job $job -Force -ErrorAction SilentlyContinue
if (-not $appUp) {
  Write-Host "[dev] App never appeared on the device. Run 'flutter run -v' to inspect." -ForegroundColor Red
  exit 1
}

Write-Host "[dev] Step 2/3: cold-starting with fixed VM-service port..." -ForegroundColor Green
if (-not (Test-VmSocket)) {
  adb -s $Device shell am force-stop $App | Out-Null
  Start-Sleep -Seconds 1
  adb -s $Device shell am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -f 0x20000000 --ez enable-dart-profiling true --ez enable-checked-mode true --ez verify-entry-points true --ei vm-service-port $Port --ei observatory-port $Port --ez disable-service-auth-codes true "$App/.MainActivity" | Out-Null
}

$sockDeadline = (Get-Date).AddSeconds(45)
while (-not (Test-VmSocket)) {
  if ((Get-Date) -gt $sockDeadline) {
    Write-Host "[dev] VM service never opened port $Port on the device." -ForegroundColor Red
    exit 1
  }
  Start-Sleep -Seconds 2
}
Write-Host "      device socket 127.0.0.1:$Port is LISTENING" -ForegroundColor DarkGray

Write-Host "[dev] Step 3/3: forward + attach (r / R / q work below once connected)" -ForegroundColor Green
# cmd /c isolates adb's stderr — under EAP=Stop, PowerShell 5.1 turns a
# harmless "listener not found" stderr line into a script-killing error.
cmd /c "adb -s $Device forward --remove tcp:$Port >nul 2>&1"
adb -s $Device forward "tcp:$Port" "tcp:$Port" | Out-Null
flutter attach -d $Device --debug-url="http://127.0.0.1:$Port/"
