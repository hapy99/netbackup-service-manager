#!/bin/bash
# Check NetBackup daemons
# Run as root

LOG_FILE="/var/log/netbackup_check_$(date +%Y%m%d_%H%M%S).log"

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_msg "========================================"
log_msg "NetBackup Process Status Check"
log_msg "========================================"
log_msg ""

if command -v bpps >/dev/null 2>&1; then
    bpps -x | tee -a "$LOG_FILE"
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_msg "WARNING: bpps exited with code $exit_code"
    fi
else
    log_msg "ERROR: bpps command not found. NetBackup may not be installed or PATH is not set."
    exit 1
fi

log_msg ""
log_msg "========================================"
log_msg "Check completed at: $(date)"
log_msg "Log saved to: $LOG_FILE"
log_msg "========================================"
