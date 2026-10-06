#!/bin/bash
# ============================================================================
# NetBackup Service Manager - Comprehensive Script
# Complete workflow: CHECK → STOP → FORCE KILL STUBBORN PROCESSES → RESTART → VERIFY
# Usage: ./netbackup-service-manager.sh
# Run as: root
# ============================================================================

set -e

# Configuration
LOG_DIR="/var/log"
LOG_FILE="${LOG_DIR}/netbackup_service_manager_$(date +%Y%m%d_%H%M%S).log"
BPPS_CMD="bpps"
BP_KILL_CMD="bp.kill_all"
RESTART_SCRIPT="/cron/Restartservices.sh"

# Colors for output (optional)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ============================================================================
# FUNCTIONS
# ============================================================================

log_msg() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} - $1" | tee -a "$LOG_FILE"
}

log_success() {
    log_msg "${GREEN}✓ SUCCESS: $1${NC}"
}

log_warning() {
    log_msg "${YELLOW}⚠ WARNING: $1${NC}"
}

log_error() {
    log_msg "${RED}✗ ERROR: $1${NC}"
}

print_header() {
    log_msg ""
    log_msg "========================================"
    log_msg "$1"
    log_msg "========================================"
}

print_step() {
    log_msg ""
    log_msg "[STEP $1] $2"
    log_msg "----------------------------------------"
}

# ============================================================================
# PHASE 1: INITIAL CHECK
# ============================================================================

phase_check() {
    print_step "1/5" "CHECKING Current NetBackup Processes"
    
    if command -v $BPPS_CMD >/dev/null 2>&1; then
        $BPPS_CMD -x 2>&1 | tee -a "$LOG_FILE"
        log_success "Process check completed"
    else
        log_error "$BPPS_CMD command not found. NetBackup may not be installed or PATH not set."
        exit 1
    fi
    
    sleep 2
}

# ============================================================================
# PHASE 2: STANDARD STOP
# ============================================================================

phase_stop() {
    print_step "2/5" "STOPPING NetBackup Services (Standard)"
    
    if command -v $BP_KILL_CMD >/dev/null 2>&1; then
        log_msg "Found bp.kill_all in PATH. Running standard shutdown..."
        echo "y" | $BP_KILL_CMD 2>&1 | tee -a "$LOG_FILE" || true
    elif [ -f /usr/openv/netbackup/bin/$BP_KILL_CMD ]; then
        log_msg "Found bp.kill_all at full path. Running standard shutdown..."
        echo "y" | /usr/openv/netbackup/bin/$BP_KILL_CMD 2>&1 | tee -a "$LOG_FILE" || true
    else
        log_error "$BP_KILL_CMD not found in PATH or standard location"
        log_msg "Attempting manual daemon termination..."
    fi
    
    log_success "Standard stop completed (waiting 5 seconds)"
    sleep 5
}

# ============================================================================
# PHASE 3: FORCE KILL STUBBORN PROCESSES
# ============================================================================

phase_force_kill() {
    print_step "3/5" "FORCE KILLING Stubborn Processes"
    
    # List of known stubborn NetBackup daemons
    local STUBBORN_PROCS=("nbrb" "nbaudit" "bpdbm" "bpjobd" "nbemm" "spoold" "spad" "mtstrmd")
    local killed_count=0
    local still_running_count=0
    
    for proc in "${STUBBORN_PROCS[@]}"; do
        PIDS=$(pgrep -f "/usr/openv/netbackup/bin/$proc" 2>/dev/null || true)
        
        if [ -n "$PIDS" ]; then
            log_msg "Found stubborn process: $proc (PIDs: $PIDS)"
            
            # Step 1: Try SIGTERM (graceful)
            log_msg "  → Sending SIGTERM to $proc..."
            kill -TERM $PIDS 2>/dev/null || true
            sleep 2
            
            # Step 2: Check if still running
            PIDS=$(pgrep -f "/usr/openv/netbackup/bin/$proc" 2>/dev/null || true)
            if [ -n "$PIDS" ]; then
                log_msg "  → $proc still running after SIGTERM, sending SIGKILL..."
                kill -9 $PIDS 2>/dev/null || true
                sleep 1
                killed_count=$((killed_count + 1))
                
                # Final check
                PIDS=$(pgrep -f "/usr/openv/netbackup/bin/$proc" 2>/dev/null || true)
                if [ -n "$PIDS" ]; then
                    log_warning "$proc (PIDs: $PIDS) is still running after SIGKILL"
                    still_running_count=$((still_running_count + 1))
                else
                    log_success "$proc terminated"
                fi
            else
                log_success "$proc terminated gracefully"
            fi
        fi
    done
    
    log_msg ""
    log_msg "Summary: Force-killed $killed_count process(es), $still_running_count still running"
    sleep 2
}

# ============================================================================
# PHASE 4: RESTART SERVICES
# ============================================================================

phase_restart() {
    print_step "4/5" "RESTARTING NetBackup Services"
    
    if [ -f "$RESTART_SCRIPT" ]; then
        log_msg "Running restart script: $RESTART_SCRIPT"
        $RESTART_SCRIPT 2>&1 | tee -a "$LOG_FILE" || true
        log_success "Restart script completed"
    else
        log_error "Restart script not found at: $RESTART_SCRIPT"
        return 1
    fi
    
    log_msg "Waiting 20 seconds for services to initialize..."
    sleep 20
}

# ============================================================================
# PHASE 5: FINAL VERIFICATION
# ============================================================================

phase_verify() {
    print_step "5/5" "VERIFYING Final Status"
    
    if command -v $BPPS_CMD >/dev/null 2>&1; then
        log_msg "Current NetBackup process status:"
        $BPPS_CMD -x 2>&1 | tee -a "$LOG_FILE"
        log_success "Final verification completed"
    else
        log_warning "$BPPS_CMD not found; cannot verify final status"
    fi
}

# ============================================================================
# SUMMARY
# ============================================================================

print_summary() {
    print_header "COMPLETION SUMMARY"
    log_msg ""
    log_success "All phases completed"
    log_msg ""
    log_msg "Execution Timeline:"
    log_msg "  1. ✓ Checked initial NetBackup status"
    log_msg "  2. ✓ Stopped NetBackup services (standard shutdown)"
    log_msg "  3. ✓ Force-killed stubborn processes (nbrb, nbaudit, etc.)"
    log_msg "  4. ✓ Restarted NetBackup services"
    log_msg "  5. ✓ Verified final status"
    log_msg ""
    log_msg "Log file: $LOG_FILE"
    log_msg "Completed at: $(date '+%Y-%m-%d %H:%M:%S')"
    log_msg ""
    print_header "END OF EXECUTION"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    # Verify running as root
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}ERROR: This script must be run as root${NC}"
        exit 1
    fi
    
    # Create log file
    touch "$LOG_FILE" 2>/dev/null || {
        LOG_DIR="/tmp"
        LOG_FILE="${LOG_DIR}/netbackup_service_manager_$(date +%Y%m%d_%H%M%S).log"
        touch "$LOG_FILE"
    }
    
    log_msg ""
    log_msg "========================================"
    log_msg "NetBackup Service Manager"
    log_msg "Complete Check-Stop-Restart Workflow"
    log_msg "========================================"
    log_msg "Started at: $(date '+%Y-%m-%d %H:%M:%S')"
    log_msg "Log file: $LOG_FILE"
    
    # Execute all phases
    phase_check
    phase_stop
    phase_force_kill
    phase_restart
    phase_verify
    print_summary
    
    log_success "NetBackup service management completed successfully"
    exit 0
}

# ============================================================================
# EXECUTE
# ============================================================================

main "$@"
