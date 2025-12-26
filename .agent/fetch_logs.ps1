# fetch_logs.ps1
# Automatically finds the latest Godot log file for Mutanic Reign and displays the last 50 lines.

$logDir = "$env:APPDATA\Godot\app_userdata\MutanicReign"
$logs = Get-ChildItem -Path $logDir -Recurse -Filter "*.log" -ErrorAction SilentlyContinue

if ($logs) {
    $latestLog = $logs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    Write-Host "Reading log file: $($latestLog.FullName)" -ForegroundColor Cyan
    Get-Content -Path $latestLog.FullName -Tail 50 -Wait
} else {
    Write-Host "No log files found in $logDir" -ForegroundColor Red
}
