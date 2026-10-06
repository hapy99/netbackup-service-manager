#!/bin/bash
# Advanced NetBackup service stop with stubborn process handling
# Handles processes that won't terminate gracefully (like nbrb)
# Run as root

set -e

LOG_FILE="/var/log/netbackup_stop_$(date +%Y%m%d_%H%M%S).log"

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_msg "========================================"
log_msg "NetBackup Service Stop - Advanced"
log_msg "========================================"

# Step 1: Check current status
log_msg "[STEP 1] Checking current NetBackup processes..."
if command -v bpps >/dev/null 2>&1; then
    bpps -x | tee -a "$LOG_FILE"
else
    log_msg "WARNING: bpps command not found"
fi

sleep 2

# Step 2: Run standard kill script with auto-yes
log_msg "[STEP 2] Running bp.kill_all (standard shutdown)..."
if command -v bp.kill_all >/dev/null 2>&1; then
    # Pipe 'y' to auto-answer prompts
    echo "y" | bp.kill_all 2>&1 | tee -a "$LOG_FILE" || true
elif [ -f /usr/openv/netbackup/bin/bp.kill_all ]; then
    echo "y" | /usr/openv/netbackup/bin/bp.kill_all 2>&1 | tee -a "$LOG_FILE" || true
else
    log_msg "WARNING: bp.kill_all not found"
fi

sleep 5

# Step 3: Force kill stubborn processes
log_msg "[STEP 3] Checking for stubborn processes (nbrb, nbaudit, etc.)..."

STUBBORN_PROCS=("nbrb" "nbaudit" "bpdbm" "bpjobd")
KILLED_PROCS=()
STILL_RUNNING=()

for proc in "${STUBBORN_PROCS[@]}"; do
    PIDS=$(pgrep -f "$proc" || true)
    if [ -n "$PIDS" ]; then
        log_msg "Found stubborn process: $proc (PIDs: $PIDS)"
        
        # Try SIGTERM first
        log_msg "  → Sending SIGTERM to $proc..."
        kill -TERM $PIDS 2>/dev/null || true
        sleep 3
        
        # Check if still running
        PIDS=$(pgrep -f "$proc" || true)
        if [ -n "$PIDS" ]; then
            log_msg "  → $proc still running, sending SIGKILL..."
            kill -9 $PIDS 2>/dev/null || true
            sleep 2
            KILLED_PROCS+=("$proc")
        else
            log_msg "  → $proc terminated successfully"
        fi
    fi
done

# Step 4: Verify final status
log_msg "[STEP 4] Final process verification..."
sleep 3

REMAINING=$(pgrep -f "/usr/openv/netbackup/bin" || true)
if [ -z "$REMAINING" ]; then
    log_msg "SUCCESS: All NetBackup processes terminated"
else
    log_msg "WARNING: Some processes still running:"
    echo "$REMAINING" | tee -a "$LOG_FILE"
fi

# Step 5: Show final status
log_msg "[STEP 5] Final status check..."
if command -v bpps >/dev/null 2>&1; then
    bpps -x | tee -a "$LOG_FILE"
fi

log_msg "========================================"
log_msg "Stop process completed at: $(date)"
log_msg "Log saved to: $LOG_FILE"
log_msg "========================================"

exit 0
