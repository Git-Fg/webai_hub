#!/bin/bash
#
# terminate_run.sh (Final): Safely terminates the background Flutter process
# using the stored PID, with timestamped logging.
#

PID_FILE="reports/flutter.pid"

# Helper function for timestamped logging
log_with_date() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1"
}

log_with_date "[CLEANUP] Terminate script initiated."

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    log_with_date "[CLEANUP] Found PID file. Terminating process tree with PID: $PID"
    # Use 'kill' to terminate the process.
    kill $PID
    rm "$PID_FILE"
    log_with_date "[CLEANUP] Process terminated and PID file removed."
else
    log_with_date "[CLEANUP] PID file not found. No process to terminate."
fi

log_with_date "[CLEANUP] Terminate script finished."