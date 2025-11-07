#!/bin/bash
#
# run_and_log.sh (v4.3 - App Readiness, Cleaned Status Files):
# - Outputs formatted session info
# - Detects app readiness via generic and custom signals
# - Cleans up .status and .ready flags on completion or failure
#

SESSION_ID=$(date +%Y-%m-%d_%H:%M:%S)
echo "SESSION_ID ($SESSION_ID) :" >&2
echo "$SESSION_ID"

STATUS_FILE="reports/.session_${SESSION_ID}.status"
INIT_FLAG="reports/.session_${SESSION_ID}.ready"
echo "STARTING" > "$STATUS_FILE"
rm -f "$INIT_FLAG"

cleanup() {
    rm -f "$STATUS_FILE" "$INIT_FLAG"
}
trap cleanup EXIT

(
    LOG_FILE="reports/run.log"
    PID_FILE="reports/flutter.pid"
    DEVICE_ID="emulator-5554"

    log_with_date() {
        echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" | tee -a "$LOG_FILE"
    }

    echo "--- Autonomous Validation Session ID: $SESSION_ID ---" > "$LOG_FILE"
    echo "--- Started at: $(date -u +%Y-%m-%dT%H:%M:%SZ) ---" >> "$LOG_FILE"

    log_with_date "[SETUP] Building TypeScript assets..."
    npm run build >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        log_with_date "[FATAL] NPM BUILD FAILED."
        echo "FAILED" > "$STATUS_FILE"
        exit 1
    fi
    log_with_date "[SETUP] TypeScript build successful."
    echo "BUILD_COMPLETE" > "$STATUS_FILE"

    log_with_date "[SETUP] Launching Flutter App on device '$DEVICE_ID'..."
    stdbuf -oL flutter run -d "$DEVICE_ID" 2>&1 | while IFS= read -r line; do
        echo "$line" | stdbuf -oL grep -E \
            -e "flutter:" \
            -e "\[(Engine|AI Studio|Observer) LOG\]" \
            -e "\[(WebView CONSOLE|AiWebviewScreen)\]" \
            -e "\[(JavaScriptBridge|ConversationProvider)\]" \
            -e "A Dart VM Service on" \
            -e "\\[AI_HUB_READY\\]" \
            -e "Lost connection" \
            -e "Error|error|ERROR" \
            -e "Failed|failed|FAILED" \
            -e "Exception|exception" \
            -e "extract|Extract|EXTRACT" \
            -e "Starting extraction|Finalized turn|Edit button|Extracted.*chars|Exited edit mode" \
            -e "extractFinalResponse|extractAndReturnToHub" \
            -e "AUTOMATION_FAILED|automation.*fail" \
            -e "ConversationProvider|conversation.*provider" >> "$LOG_FILE" 2>&1

        # Signal when Dart VM or custom app log indicate readiness
        if echo "$line" | grep -Eq "A Dart VM Service on|\\[AI_HUB_READY\\]"; then
            touch "$INIT_FLAG"
            log_with_date "[READY] App or Dart VM Service initialized - app is running"
        fi
    done

    echo "COMPLETED" > "$STATUS_FILE"

    # Extra safety: clean up at the end of the background subshell
    rm -f "$STATUS_FILE" "$INIT_FLAG"

) &

FLUTTER_PID=$!
echo "$FLUTTER_PID" > "reports/flutter.pid"

TIMEOUT=60
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ] && [ ! -f "$INIT_FLAG" ]; do
    sleep 1
    ELAPSED=$((ELAPSED + 1))
done

if [ $ELAPSED -lt 10 ]; then
    sleep $((10 - ELAPSED))
fi

sleep 2

# At script exit, the trap will remove the files if they still exist
