#Requires -RunAsAdministrator
# =============================================================
# Windows Maintenance Script
# Run as Administrator: Right-click > Run as Administrator
# =============================================================

param(
    [switch]$SkipReboot
)

$ErrorActionPreference = "Continue"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$logFile = "$env:USERPROFILE\Documents\maintenance_log_$timestamp.txt"

function Log {
    param([string]$Message)
    $entry = "[$(Get-Date -Format 'HH:mm:ss')] $Message"
    Write-Host $entry
    Add-Content -Path $logFile -Value $entry
}

Log "=== Windows Maintenance Script Started ==="
Log ""

# ----------------------------------------------------------
# 1. System File Checker
# ----------------------------------------------------------
Log "--- Running System File Checker (sfc /scannow) ---"
Log "This may take several minutes..."
sfc /scannow | Out-File "$env:USERPROFILE\Documents\sfc_results_$timestamp.txt" -Encoding utf8
Log "SFC complete. Results saved to sfc_results_$timestamp.txt"
Log ""

# ----------------------------------------------------------
# 2. DISM Health Restore
# ----------------------------------------------------------
Log "--- Running DISM RestoreHealth ---"
Log "This may take several minutes..."
DISM /Online /Cleanup-Image /RestoreHealth | Out-File "$env:USERPROFILE\Documents\dism_results_$timestamp.txt" -Encoding utf8
Log "DISM complete. Results saved to dism_results_$timestamp.txt"
Log ""

# ----------------------------------------------------------
# 3. Check Disk (schedule for next reboot on boot drive)
# ----------------------------------------------------------
Log "--- Scheduling chkdsk on C: for next reboot ---"
$chkdskOutput = echo Y | chkdsk C: /F /R /X 2>&1
if ($chkdskOutput -match "cannot lock") {
    Log "chkdsk will run on next reboot (drive is in use)."
} else {
    Log "chkdsk completed or scheduled."
}
Log ""

# ----------------------------------------------------------
# 4. Disk Cleanup - remove old Windows Update files, temp, etc.
# ----------------------------------------------------------
Log "--- Running Disk Cleanup (automated) ---"
# Set registry keys for automated cleanup selections
$cleanupKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
$categories = @(
    "Active Setup Temp Folders",
    "Downloaded Program Files",
    "Internet Cache Files",
    "Old ChkDsk Files",
    "Previous Installations",
    "Recycle Bin",
    "Setup Log Files",
    "System error memory dump files",
    "System error minidump files",
    "Temporary Files",
    "Temporary Setup Files",
    "Update Cleanup",
    "Windows Error Reporting Files",
    "Windows Upgrade Log Files"
)
foreach ($cat in $categories) {
    $path = "$cleanupKey\$cat"
    if (Test-Path $path) {
        Set-ItemProperty -Path $path -Name "StateFlags0100" -Value 2 -Type DWord -ErrorAction SilentlyContinue
    }
}
Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:100" -Wait
Log "Disk Cleanup complete."
Log ""

# ----------------------------------------------------------
# 5. Clear Windows Update Cache
# ----------------------------------------------------------
Log "--- Clearing Windows Update Cache ---"
Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
Start-Service -Name wuauserv -ErrorAction SilentlyContinue
Log "Windows Update cache cleared."
Log ""

# ----------------------------------------------------------
# 6. Clear temp folders
# ----------------------------------------------------------
Log "--- Clearing temp folders ---"
$tempPaths = @(
    "$env:TEMP\*",
    "$env:LOCALAPPDATA\Temp\*",
    "C:\Windows\Temp\*"
)
foreach ($p in $tempPaths) {
    Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue
}
Log "Temp folders cleared."
Log ""

# ----------------------------------------------------------
# 7. Flush DNS Cache
# ----------------------------------------------------------
Log "--- Flushing DNS cache ---"
ipconfig /flushdns | Out-Null
Log "DNS cache flushed."
Log ""

# ----------------------------------------------------------
# 8. Check SSD/Disk Health
# ----------------------------------------------------------
Log "--- Disk Health Report ---"
$diskHealth = Get-PhysicalDisk | Select-Object FriendlyName, MediaType, HealthStatus, OperationalStatus, Size
$diskHealth | Format-Table -AutoSize | Out-String | ForEach-Object { Log $_ }
Log ""

# ----------------------------------------------------------
# 9. Startup Programs Report
# ----------------------------------------------------------
Log "--- Startup Programs (review and disable unneeded ones) ---"
$startups = Get-CimInstance -ClassName Win32_StartupCommand | Select-Object Name, Command, Location
$startups | Format-Table -AutoSize -Wrap | Out-String | ForEach-Object { Log $_ }
Log ""

# ----------------------------------------------------------
# 10. Check Thermals (if HWiNFO/HWMonitor not available, use WMI)
# ----------------------------------------------------------
Log "--- CPU Temperature Check ---"
try {
    $temps = Get-CimInstance -Namespace "root/WMI" -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop
    foreach ($t in $temps) {
        $celsius = [math]::Round(($t.CurrentTemperature - 2732) / 10, 1)
        Log "  Thermal Zone: ${celsius}C"
    }
} catch {
    Log "  Could not read temps via WMI (normal on many systems). Use HWiNFO for detailed thermals."
}
Log ""

# ----------------------------------------------------------
# 11. Windows Update Check
# ----------------------------------------------------------
Log "--- Checking for Windows Updates ---"
try {
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $searcher = $updateSession.CreateUpdateSearcher()
    $results = $searcher.Search("IsInstalled=0")
    if ($results.Updates.Count -gt 0) {
        Log "  $($results.Updates.Count) update(s) available:"
        foreach ($update in $results.Updates) {
            Log "    - $($update.Title)"
        }
    } else {
        Log "  System is up to date."
    }
} catch {
    Log "  Could not check updates programmatically. Check Settings > Windows Update."
}
Log ""

# ----------------------------------------------------------
# 12. Event Log Errors (last 7 days)
# ----------------------------------------------------------
Log "--- Recent System Errors (last 7 days) ---"
$errors = Get-WinEvent -FilterHashtable @{LogName='System'; Level=2; StartTime=(Get-Date).AddDays(-7)} -MaxEvents 20 -ErrorAction SilentlyContinue
if ($errors) {
    foreach ($e in $errors) {
        Log "  [$($e.TimeCreated)] $($e.ProviderName): $($e.Message.Substring(0, [Math]::Min(120, $e.Message.Length)))..."
    }
} else {
    Log "  No critical system errors in the last 7 days."
}
Log ""

# ----------------------------------------------------------
# 13. Power Plan Check
# ----------------------------------------------------------
Log "--- Current Power Plan ---"
$powerPlan = powercfg /getactivescheme
Log "  $powerPlan"
Log ""

# ----------------------------------------------------------
# 14. RAM XMP Check Reminder
# ----------------------------------------------------------
Log "--- RAM Info ---"
$ram = Get-CimInstance -ClassName Win32_PhysicalMemory | Select-Object Manufacturer, Speed, Capacity
foreach ($stick in $ram) {
    $sizeGB = [math]::Round($stick.Capacity / 1GB, 1)
    Log "  $($stick.Manufacturer) - ${sizeGB}GB @ $($stick.Speed)MHz"
}
Log "  TIP: Verify XMP/DOCP is enabled in BIOS if speeds look lower than rated."
Log ""

# ----------------------------------------------------------
# 15. Winget - Update All Installed Apps
# ----------------------------------------------------------
Log "--- Updating All Apps via Winget ---"
try {
    $wingetPath = Get-Command winget -ErrorAction Stop | Select-Object -ExpandProperty Source
    Log "Checking for app updates..."
    $wingetList = winget upgrade 2>&1
    $wingetList | Out-String | ForEach-Object { Log $_ }
    Log "Running winget upgrade --all ..."
    winget upgrade --all --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-String | ForEach-Object { Log $_ }
    Log "Winget upgrade complete."
} catch {
    Log "  Winget not found. Install it from the Microsoft Store (App Installer) or winget.run"
}
Log ""

# ----------------------------------------------------------
# 16. Network Reset & Optimization
# ----------------------------------------------------------
Log "--- Network Reset & Optimization ---"
Log "  Resetting Winsock catalog..."
netsh winsock reset 2>&1 | Out-Null
Log "  Resetting TCP/IP stack..."
netsh int ip reset 2>&1 | Out-Null
Log "  Releasing IP address..."
ipconfig /release 2>&1 | Out-Null
Log "  Renewing IP address..."
ipconfig /renew 2>&1 | Out-Null
Log "  Network reset complete. A reboot is recommended for Winsock/TCP changes to take full effect."
Log ""

# ----------------------------------------------------------
# 17. SSD TRIM / HDD Defrag
# ----------------------------------------------------------
Log "--- Drive Optimization (TRIM / Defrag) ---"
foreach ($disk in Get-PhysicalDisk) {
    $diskName = $disk.FriendlyName
    $mediaType = $disk.MediaType
    # Get partitions on this disk
    $partitions = Get-Partition -DiskNumber $disk.DeviceId -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter }
    foreach ($part in $partitions) {
        $letter = $part.DriveLetter
        if ($mediaType -eq "SSD" -or $mediaType -eq "Unspecified") {
            Log "  Running TRIM on ${letter}: ($diskName - $mediaType)..."
            try {
                Optimize-Volume -DriveLetter $letter -ReTrim -ErrorAction Stop
                Log "  TRIM complete on ${letter}:"
            } catch {
                Log "  Could not TRIM ${letter}: - $($_.Exception.Message)"
            }
        } else {
            Log "  Running Defrag on ${letter}: ($diskName - HDD)..."
            try {
                Optimize-Volume -DriveLetter $letter -Defrag -ErrorAction Stop
                Log "  Defrag complete on ${letter}:"
            } catch {
                Log "  Could not defrag ${letter}: - $($_.Exception.Message)"
            }
        }
    }
}
Log ""

# ----------------------------------------------------------
# 18. Reliability Monitor Summary
# ----------------------------------------------------------
Log "--- Reliability Monitor Summary (last 7 days) ---"
try {
    $reliability = Get-CimInstance -ClassName Win32_ReliabilityRecords -ErrorAction Stop |
        Where-Object { $_.TimeGenerated -gt (Get-Date).AddDays(-7) } |
        Select-Object -First 20 TimeGenerated, SourceName, EventIdentifier, Message
    if ($reliability) {
        foreach ($r in $reliability) {
            $msg = if ($r.Message.Length -gt 100) { $r.Message.Substring(0, 100) + "..." } else { $r.Message }
            Log "  [$($r.TimeGenerated)] $($r.SourceName): $msg"
        }
    } else {
        Log "  No reliability events in the last 7 days. System looks stable."
    }
} catch {
    Log "  Could not query reliability data."
}
Log ""

# ----------------------------------------------------------
# 19. Scheduled Tasks Cleanup Report
# ----------------------------------------------------------
Log "--- Non-Microsoft Scheduled Tasks ---"
$tasks = Get-ScheduledTask -ErrorAction SilentlyContinue |
    Where-Object { $_.TaskPath -notlike "\Microsoft\*" -and $_.TaskName -notlike "User_Feed*" } |
    Select-Object TaskName, TaskPath, State
if ($tasks) {
    $tasks | Format-Table -AutoSize | Out-String | ForEach-Object { Log $_ }
    Log "  Review these tasks and remove any you don't recognize."
} else {
    Log "  No non-Microsoft scheduled tasks found."
}
Log ""

# ----------------------------------------------------------
# 20. Windows Defender Quick Scan
# ----------------------------------------------------------
Log "--- Running Windows Defender Quick Scan ---"
Log "This may take several minutes..."
try {
    Start-MpScan -ScanType QuickScan -ErrorAction Stop
    $threatStatus = Get-MpThreatDetection -ErrorAction SilentlyContinue
    if ($threatStatus) {
        Log "  THREATS DETECTED:"
        foreach ($threat in $threatStatus) {
            Log "    - $($threat.ThreatName) (Status: $($threat.ActionSuccess))"
        }
    } else {
        Log "  No threats detected. System is clean."
    }
} catch {
    Log "  Could not run Defender scan. Check Windows Security settings."
}
Log ""

# ----------------------------------------------------------
# 21. Browser Cache Cleanup
# ----------------------------------------------------------
Log "--- Browser Cache Cleanup ---"
$cachePaths = @{
    "Chrome" = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\Cache_Data"
    "Edge"   = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\Cache_Data"
    "Firefox" = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
}
foreach ($browser in $cachePaths.Keys) {
    $path = $cachePaths[$browser]
    if ($browser -eq "Firefox") {
        # Firefox stores cache in profile subfolders
        $ffProfiles = Get-ChildItem -Path $path -Directory -ErrorAction SilentlyContinue
        foreach ($profile in $ffProfiles) {
            $ffCache = Join-Path $profile.FullName "cache2\entries"
            if (Test-Path $ffCache) {
                $sizeMB = [math]::Round((Get-ChildItem $ffCache -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB, 1)
                Remove-Item -Path "$ffCache\*" -Recurse -Force -ErrorAction SilentlyContinue
                Log "  Firefox ($($profile.Name)): Cleared ${sizeMB}MB cache"
            }
        }
    } else {
        if (Test-Path $path) {
            $sizeMB = [math]::Round((Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB, 1)
            Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
            Log "  ${browser}: Cleared ${sizeMB}MB cache"
        } else {
            Log "  ${browser}: No cache folder found (not installed or already clean)"
        }
    }
}
Log "  NOTE: Cookies, passwords, and bookmarks were NOT touched."
Log ""

# ----------------------------------------------------------
# 22. Old Maintenance Log Cleanup
# ----------------------------------------------------------
Log "--- Cleaning Old Maintenance Logs (30+ days) ---"
$oldLogs = Get-ChildItem -Path "$env:USERPROFILE\Documents" -Filter "maintenance_log_*.txt" -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }
$oldSfc = Get-ChildItem -Path "$env:USERPROFILE\Documents" -Filter "sfc_results_*.txt" -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }
$oldDism = Get-ChildItem -Path "$env:USERPROFILE\Documents" -Filter "dism_results_*.txt" -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }
$allOld = @($oldLogs) + @($oldSfc) + @($oldDism) | Where-Object { $_ }
if ($allOld.Count -gt 0) {
    foreach ($f in $allOld) {
        Remove-Item $f.FullName -Force -ErrorAction SilentlyContinue
        Log "  Deleted: $($f.Name)"
    }
} else {
    Log "  No old logs to clean up."
}
Log ""

# ----------------------------------------------------------
# 23. Disk Space Report
# ----------------------------------------------------------
Log "--- Disk Space Report ---"
$drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null }
foreach ($drive in $drives) {
    $totalGB = [math]::Round(($drive.Used + $drive.Free) / 1GB, 1)
    $freeGB = [math]::Round($drive.Free / 1GB, 1)
    $freePercent = [math]::Round(($drive.Free / ($drive.Used + $drive.Free)) * 100, 1)
    $warning = if ($freePercent -lt 15) { " *** LOW SPACE WARNING ***" } else { "" }
    Log "  $($drive.Name): ${freeGB}GB free / ${totalGB}GB total (${freePercent}% free)$warning"
}
Log ""

# ----------------------------------------------------------
# Summary
# ----------------------------------------------------------
Log "=== Maintenance Complete ==="
Log "Log saved to: $logFile"
Log ""
Log "MANUAL STEPS REMAINING:"
Log "  1. Review startup programs above and disable unneeded ones in Task Manager"
Log "  2. Review non-Microsoft scheduled tasks above and remove suspicious ones"
Log "  3. Uninstall unused programs (Settings > Apps)"
Log "  4. Review browser extensions"
Log "  5. Verify XMP/DOCP in BIOS if RAM speed looks low"
Log "  6. Check thermals under load with HWiNFO if concerned"
Log "  7. Verify you have a backup strategy in place"
if (-not $SkipReboot) {
    Log ""
    Log "A reboot is recommended (chkdsk is scheduled to run on next boot)."
}

Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
