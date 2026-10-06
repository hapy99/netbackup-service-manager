# NetBackup Service Manager

Comprehensive shell script for automated NetBackup service management on Linux systems.

## 🎯 Features

This single script handles the **complete workflow** in one execution:

1. ✅ **CHECK** - Display current NetBackup process status
2. ✅ **STOP** - Gracefully shut down all NetBackup services
3. ✅ **FORCE KILL** - Terminate stubborn processes (nbrb, nbaudit, bpdbm, bpjobd, etc.)
4. ✅ **RESTART** - Restart all NetBackup services
5. ✅ **VERIFY** - Confirm final status and service health

## 📋 Requirements

- **Linux system** with NetBackup installed
- **Root access** (required to manage services)
- Standard NetBackup installation paths:
  - `/usr/openv/netbackup/bin/`
  - `/cron/Restartservices.sh`

## 🚀 Quick Start

### 1. Make script executable:
```bash
chmod +x netbackup-service-manager.sh
```

### 2. Run the script:
```bash
sudo ./netbackup-service-manager.sh
```

Or if already root:
```bash
./netbackup-service-manager.sh
```

### 3. Monitor the output:
```
[STEP 1/5] CHECKING Current NetBackup Processes
----------------------------------------
[STEP 2/5] STOPPING NetBackup Services (Standard)
----------------------------------------
[STEP 3/5] FORCE KILLING Stubborn Processes
----------------------------------------
[STEP 4/5] RESTARTING NetBackup Services
----------------------------------------
[STEP 5/5] VERIFYING Final Status
----------------------------------------
COMPLETION SUMMARY
```

## 📊 What Each Phase Does

### Phase 1: CHECK
- Runs `bpps -x` to list all running NetBackup daemons
- Shows current process status before any changes

### Phase 2: STOP
- Executes `bp.kill_all` to gracefully shut down services
- Auto-answers prompts with "y" for non-interactive operation
- Waits 5 seconds for graceful termination

### Phase 3: FORCE KILL
Handles **stubborn processes** that don't terminate gracefully:
- Detects: `nbrb`, `nbaudit`, `bpdbm`, `bpjobd`, `nbemm`, `spoold`, `spad`, `mtstrmd`
- First sends `SIGTERM` (graceful)
- Then sends `SIGKILL` if still running
- Verifies termination for each process

### Phase 4: RESTART
- Executes `/cron/Restartservices.sh` to start all services
- Waits 20 seconds for services to initialize

### Phase 5: VERIFY
- Runs `bpps -x` again to confirm services are running
- Shows final process status

## 📝 Logging

All operations are logged to:
```bash
/var/log/netbackup_service_manager_YYYYMMDD_HHMMSS.log
```

View logs:
```bash
tail -f /var/log/netbackup_service_manager_*.log
```

## 🔧 Customization

Edit the script to change:

**Log directory:**
```bash
LOG_DIR="/var/log"
```

**Restart script path:**
```bash
RESTART_SCRIPT="/cron/Restartservices.sh"
```

**Stubborn processes list:**
```bash
local STUBBORN_PROCS=("nbrb" "nbaudit" "bpdbm" "bpjobd" ...)
```

**Initialization wait time:**
```bash
sleep 20  # Adjust as needed
```

## ❌ Troubleshooting

### Script says "bp.kill_all not found"
Verify NetBackup installation:
```bash
ls /usr/openv/netbackup/bin/bp.kill_all
which bp.kill_all
```

### Process still running after force kill
Check if it's a parent-child process:
```bash
ps aux | grep netbackup
ps -ef --forest | grep nbrb
```

### Restart script fails
Verify restart script exists and is executable:
```bash
ls -la /cron/Restartservices.sh
```

### Permission denied
Run with sudo or as root:
```bash
sudo ./netbackup-service-manager.sh
```

## 📌 Example Output

```
2026-10-06 22:45:00 - ========================================
2026-10-06 22:45:00 - NetBackup Service Manager
2026-10-06 22:45:00 - Complete Check-Stop-Restart Workflow
2026-10-06 22:45:00 - ========================================

2026-10-06 22:45:00 - [STEP 1/5] CHECKING Current NetBackup Processes
2026-10-06 22:45:00 - ----------------------------------------
2026-10-06 22:45:02 - ✓ SUCCESS: Process check completed

2026-10-06 22:45:02 - [STEP 2/5] STOPPING NetBackup Services (Standard)
2026-10-06 22:45:07 - ✓ SUCCESS: Standard stop completed (waiting 5 seconds)

2026-10-06 22:45:12 - [STEP 3/5] FORCE KILLING Stubborn Processes
2026-10-06 22:45:12 - Found stubborn process: nbrb (PIDs: 61248)
2026-10-06 22:45:12 - ✓ SUCCESS: nbrb terminated

2026-10-06 22:45:14 - [STEP 4/5] RESTARTING NetBackup Services
2026-10-06 22:45:34 - ✓ SUCCESS: Restart script completed

2026-10-06 22:45:34 - [STEP 5/5] VERIFYING Final Status
2026-10-06 22:45:34 - ✓ SUCCESS: Final verification completed

2026-10-06 22:45:34 - ========================================
2026-10-06 22:45:34 - COMPLETION SUMMARY
2026-10-06 22:45:34 - ========================================
```

## 🛡️ Safety Features

✅ Root-only execution (prevents accidental user runs)  
✅ Graceful termination first (SIGTERM before SIGKILL)  
✅ Comprehensive logging  
✅ Each phase waits appropriate time for operations  
✅ Error handling and validation  
✅ Non-blocking execution (won't hang on stuck processes)  

## 📞 Support

For issues:
1. Check the log file at `/var/log/netbackup_service_manager_*.log`
2. Verify NetBackup installation: `bpps -x`
3. Check process status manually: `ps aux | grep netbackup`
4. Review NetBackup documentation for daemon-specific issues

## 📄 License

MIT
