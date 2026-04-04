# Win11 Performance Max

A comprehensive, single-script Windows 11 maintenance toolkit that automates 23 system health checks, cleanups, and optimizations. Run it monthly to keep your PC in top shape.

## What It Does

| # | Task | Type |
|---|------|------|
| 1 | **System File Checker** (`sfc /scannow`) | Repair |
| 2 | **DISM RestoreHealth** | Repair |
| 3 | **Check Disk** (scheduled for next reboot) | Repair |
| 4 | **Disk Cleanup** (old updates, temp files, error dumps) | Cleanup |
| 5 | **Windows Update Cache** clear | Cleanup |
| 6 | **Temp Folders** clear | Cleanup |
| 7 | **DNS Cache** flush | Network |
| 8 | **Disk Health Report** (SSD/HDD status) | Diagnostics |
| 9 | **Startup Programs** listing | Diagnostics |
| 10 | **CPU Temperature** check | Diagnostics |
| 11 | **Windows Update** check | Diagnostics |
| 12 | **Event Log Errors** (last 7 days) | Diagnostics |
| 13 | **Power Plan** check | Diagnostics |
| 14 | **RAM Speed / XMP** check | Diagnostics |
| 15 | **Winget Update All** installed apps | Updates |
| 16 | **Network Reset** (Winsock, TCP/IP, IP renew) | Network |
| 17 | **SSD TRIM / HDD Defrag** (auto-detects drive type) | Optimization |
| 18 | **Reliability Monitor** summary (crashes, failures) | Diagnostics |
| 19 | **Scheduled Tasks** audit (non-Microsoft) | Security |
| 20 | **Windows Defender Quick Scan** | Security |
| 21 | **Browser Cache Cleanup** (Chrome, Edge, Firefox) | Cleanup |
| 22 | **Old Log Cleanup** (maintenance logs older than 30 days) | Cleanup |
| 23 | **Disk Space Report** with low-space warnings | Diagnostics |

## Requirements

- Windows 10/11
- PowerShell 5.1+ (included with Windows)
- Administrator privileges
- [Winget](https://aka.ms/getwinget) (optional, for app updates)

## Quick Start

### Option 1: Right-click

1. Right-click `maintenance.ps1`
2. Select **Run with PowerShell** (as Administrator)

### Option 2: PowerShell (Admin)

```powershell
& "path\to\maintenance.ps1"
```

### Option 3: Skip reboot prompt

```powershell
& "path\to\maintenance.ps1" -SkipReboot
```

> **Tip:** Close your browsers before running for the best cache cleanup results.

## Output

The script logs everything to timestamped files in your `Documents` folder:

| File | Contents |
|------|----------|
| `maintenance_log_YYYY-MM-DD_HH-mm.txt` | Full run log with all results, diagnostics, and recommendations |
| `sfc_results_YYYY-MM-DD_HH-mm.txt` | Detailed System File Checker output |
| `dism_results_YYYY-MM-DD_HH-mm.txt` | Detailed DISM component store repair output |

Old logs are automatically cleaned up after 30 days.

## Reading the Results

Open `maintenance_log_*.txt` after a run. Here's what to look for and what to do:

### Repairs (SFC, DISM, chkdsk)

| Result | What It Means | What To Do |
|--------|---------------|------------|
| `did not find any integrity violations` | System files are healthy | Nothing — you're good |
| `found corrupt files and successfully repaired them` | SFC fixed damaged system files | Run the script again to verify the fix stuck |
| `found corrupt files but was unable to fix some of them` | SFC couldn't repair everything | Run DISM first (`DISM /Online /Cleanup-Image /RestoreHealth`), then SFC again. If it persists, consider an in-place Windows repair install |
| `The restore operation completed successfully` | DISM component store is healthy | Nothing — you're good |
| `chkdsk will run on next reboot` | Disk check is queued | Reboot when convenient. Let chkdsk finish — don't interrupt it |

### Diagnostics

| Section | What's Good | What Needs Attention |
|---------|-------------|---------------------|
| **Disk Health** | `Healthy` / `OK` | Any status other than Healthy — back up your data immediately and consider replacing the drive |
| **CPU Temperature** | Below 80C under load | Consistently above 85C — clean dust, check fans, consider reapplying thermal paste |
| **Windows Updates** | `System is up to date` | Available updates listed — install them via Settings > Windows Update |
| **Event Log Errors** | `No critical system errors` | Recurring errors from the same source — search the error message online or investigate the failing driver/service |
| **RAM Speed** | Speed matches your RAM's rated spec (printed on the stick or product page) | Running at 2133MHz when your RAM is rated higher — enable XMP/DOCP in BIOS (see [BIOS Recommendations](#bios-recommendations)) |
| **Power Plan** | `High Performance` or manufacturer equivalent | `Balanced` is fine for laptops on battery; desktops should use High Performance |
| **Disk Space** | Above 15% free | `*** LOW SPACE WARNING ***` — free up space. Windows needs room for updates, swap, and temp files |

### Security

| Section | What's Good | What Needs Attention |
|---------|-------------|---------------------|
| **Defender Scan** | `No threats detected` | `THREATS DETECTED` — review the threat names logged. Defender should auto-quarantine, but verify in Windows Security |
| **Scheduled Tasks** | Only tasks from software you recognize | Tasks from unknown publishers — search the task name online. Could be bloatware or leftover entries from uninstalled software. Disable suspicious ones via Task Scheduler (`taskschd.msc`) |
| **Startup Programs** | Only programs you want at boot | Unnecessary apps slowing boot — disable via Task Manager > Startup tab |

### Cleanup & Updates

| Section | What's Good | What Needs Attention |
|---------|-------------|---------------------|
| **Winget** | `0 upgrades available` or all updated successfully | `Installer hash does not match` — not your fault; the app publisher needs to update their winget manifest. Try updating that app manually |
| **Browser Cache** | Cache cleared with size reported | If sizes are very large (1GB+), consider running the script more often |
| **SSD TRIM** | `TRIM complete` | Errors usually mean the drive doesn't support TRIM or is busy — not critical |

### Reliability Monitor

This section shows app crashes, hangs, and hardware failures from the last 7 days. Look for:

- **Repeating crash patterns** — the same app crashing multiple times may indicate a bad install, driver conflict, or DLL injection from bloatware (e.g., Nahimic audio software is a known culprit)
- **Faulting module name** — this tells you what actually crashed. If it's a third-party DLL injecting into another app, the DLL owner is the problem, not the crashing app
- **MsiInstaller entries** — these are just install/uninstall records, not errors

## AI-Assisted Analysis

Don't want to read through the logs yourself? Copy the contents of `maintenance_log_*.txt` into any AI chat (ChatGPT, Claude, Gemini, Copilot, etc.) and ask:

> "Here's the output from my Windows maintenance script. Summarize the results and give me a list of action items for anything that still needs attention."

The AI will parse the diagnostics, flag anything abnormal, and give you a prioritized to-do list. You can also paste in `sfc_results_*.txt` or `dism_results_*.txt` for deeper analysis on specific repairs.

### Don't trust the script?

That's healthy. If you're not a developer and want to verify what this script does before running it, copy the contents of `maintenance.ps1` into any AI chat and ask:

> "Can you review this PowerShell script and tell me exactly what it does? Is it safe to run?"

The AI will walk you through every section in plain language so you can make an informed decision.

## What It Won't Touch

- Your files and documents
- Browser cookies, passwords, or bookmarks
- Installed programs (only updates them via winget)
- BIOS settings (reports only)
- System restore points

## After the Script Runs

The script prints a checklist of manual steps at the end. These are things that require your judgment:

1. **Review startup programs** — disable anything you don't need at boot (Task Manager > Startup)
2. **Review scheduled tasks** — remove tasks from software you no longer have installed
3. **Uninstall unused programs** — Settings > Apps > Installed Apps
4. **Review browser extensions** — remove ones you don't actively use
5. **Check BIOS settings** — see below
6. **Check thermals under load** — use [HWiNFO](https://www.hwinfo.com/) while gaming or running benchmarks
7. **Verify backups** — make sure important files are backed up somewhere

### Reboot

A reboot is recommended after each run because:
- **chkdsk** is scheduled to scan on next boot
- **Winsock/TCP reset** changes take full effect after reboot
- **Winget updates** may need a restart to complete

## Runtime

Expect **15-30 minutes** depending on disk size and number of app updates. The longest steps are:
- SFC scan (~1-2 min)
- DISM restore (~1-2 min)
- Disk Cleanup (~5-7 min)
- Defender Quick Scan (~2-3 min)
- Winget updates (varies)

## BIOS Recommendations

The script reports on these but can't change BIOS settings. To access BIOS, restart your PC and press **Del** or **F2** during boot (varies by motherboard).

### Enable XMP/DOCP

Your RAM has a rated speed (e.g., 3200MHz, 3600MHz) printed on the stick or its product page. Without XMP/DOCP enabled, it runs at the default 2133MHz — significantly slower.

- **Intel boards:** Look for **XMP** (Extreme Memory Profile)
- **AMD boards:** Look for **DOCP** (Direct Over Clock Profile) or **EXPO**
- Select Profile 1 and save/exit

The script's RAM Info section shows your current speed so you can tell if it's enabled.

### Enable SVM / VT-x

Required for virtualization software (VirtualBox, Hyper-V, WSL 2, Docker, Android emulators).

- **AMD:** Enable **SVM Mode** (under Advanced > CPU Configuration)
- **Intel:** Enable **Intel Virtualization Technology (VT-x)** (same area)

Without this, you'll see "Hypervisor launch failed" errors in the event log.

## License

MIT License. See [LICENSE](LICENSE) for details.
