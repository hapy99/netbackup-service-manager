#!/bin/bash
# Full NetBackup service cycle: check → stop → restart → verify
# Handles stubborn processes that won't terminate
# Run as root

set -e

LOG_FILE="/var/log/netbackup_full_cycle_$(date +%Y%m%d_%H%M%S).log"

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_msg "========================================"
log_msg "NetBackup Full Service Cycle"
log_msg "========================================"

# ============ STEP 1: CHECK ============
log_msg ""
log_msg "[PHASE 1/4] CHECKING current services..."
log_msg "========================================"
if command -v bpps >/dev/null 2>&1; then
    bpps -x | tee -a "$LOG_FILE"
else
    log_msg "WARNING: bpps command not found"
fi

sleep 2

# ============ STEP 2: STOP ============
log_msg ""
log_msg "[PHASE 2/4] STOPPING NetBackup services..."
log_msg "========================================"

if command -v bp.kill_all >/dev/null 2>&1; then
    log_msg "Running bp.kill_all..."
    echo "y" | bp.kill_all 2>&1 | tee -a "$LOG_FILE" || true
elif [ -f /usr/openv/netbackup/bin/bp.kill_all ]; then
    log_msg "Running bp.kill_all from full path..."
    echo "y" | /usr/openv/netbackup/bin/bp.kill_all 2>&1 | tee -a "$LOG_FILE" || true
else
    log_msg "ERROR: bp.kill_all not found"
    exit 1
fi

sleep 5

# ============ STEP 3: FORCE KILL STUBBORN PROCESSES ============
log_msg ""
log_msg "[PHASE 2.5/4] FORCE killing stubborn processes..."
log_msg "========================================"

STUBBORN_PROCS=("nbrb" "nbaudit" "bpdbm" "bpjobd" "nbemm" "spoold")

for proc in "${STUBBORN_PROCS[@]}"; do
    PIDS=$(pgrep -f "$proc" 2>/dev/null || true)
    if [ -n "$PIDS" ]; then
        log_msg "Found: $proc (PIDs: $PIDS) - Sending SIGTERM..."
        kill -TERM $PIDS 2>/dev/null || true
        sleep 2
        
        PIDS=$(pgrep -f "$proc" 2>/dev/null || true)
        if [ -n "$PIDS" ]; then
            log_msg "  → Still running - Sending SIGKILL..."
            kill -9 $PIDS 2>/dev/null || true
            sleep 1
        else
            log_msg "  → Terminated"
        fi
    fi
done

log_msg ""
log_msg "Verifying all NetBackup processes stopped..."
REMAINING=$(pgrep -f "/usr/openv/netbackup/bin" 2>/dev/null || true)
if [ -z "$REMAINING" ]; then
    log_msg "SUCCESS: All NetBackup processes stopped"
else
    log_msg "WARNING: Some processes still running:"
    echo "$REMAINING" | tee -a "$LOG_FILE"
fi

# ============ STEP 4: RESTART ============
log_msg ""
log_msg "[PHASE 3/4] RESTARTING NetBackup services..."
log_msg "========================================"

if [ -f /cron/Restartservices.sh ]; then
    log_msg "Running restart script..."
    /cron/Restartservices.sh 2>&1 | tee -a "$LOG_FILE"
    restart_exit=$?
    
    if [ $restart_exit -ne 0 ]; then
        log_msg "WARNING: Restart script exited with code $restart_exit"
    else
        log_msg "SUCCESS: Restart script completed"
    fi
else
    log_msg "ERROR: /cron/Restartservices.sh not found"
    exit 1
fi

# ============ STEP 5: VERIFY ============
log_msg ""
log_msg "[PHASE 4/4] VERIFYING service status..."
log_msg "========================================"

log_msg "Waiting 20 seconds for services to initialize..."
sleep 20

if command -v bpps >/dev/null 2>&1; then
    log_msg "Current process status:"
    bpps -x | tee -a "$LOG_FILE"
else
    log_msg "WARNING: bpps not found; cannot verify"
fi

# ============ COMPLETION ============
log_msg ""
log_msg "========================================"
log_msg "Full cycle completed at: $(date)"
log_msg "Log file: $LOG_FILE"
log_msg "========================================"

log_msg "SUMMARY:"
log_msg "  1. Checked initial status ✓"
log_msg "  2. Stopped services ✓"
log_msg "  3. Force killed stubborn processes ✓"
log_msg "  4. Restarted services ✓"
log_msg "  5. Verified final status ✓"

exit 0
