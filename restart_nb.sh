#!/bin/bash
# Restart NetBackup services
# Run as root

LOG_FILE="/var/log/netbackup_restart_$(date +%Y%m%d_%H%M%S).log"

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_msg "========================================"
log_msg "NetBackup Service Restart"
log_msg "========================================"

if [ -f /cron/Restartservices.sh ]; then
    log_msg "[STEP 1] Running restart script..."
    /cron/Restartservices.sh 2>&1 | tee -a "$LOG_FILE"
    restart_exit=$?
    
    if [ $restart_exit -ne 0 ]; then
        log_msg "WARNING: Restart script exited with code $restart_exit"
    else
        log_msg "SUCCESS: Restart script completed"
    fi
else
    log_msg "ERROR: /cron/Restartservices.sh not found."
    log_msg "Please verify the restart script path."
    exit 1
fi

log_msg ""
log_msg "[STEP 2] Waiting for services to initialize (20 seconds)..."
sleep 20

log_msg "[STEP 3] Checking current process status..."
if command -v bpps >/dev/null 2>&1; then
    bpps -x | tee -a "$LOG_FILE"
else
    log_msg "WARNING: bpps not found; cannot verify."
fi

log_msg ""
log_msg "========================================"
log_msg "Restart completed at: $(date)"
log_msg "Log saved to: $LOG_FILE"
log_msg "========================================"
