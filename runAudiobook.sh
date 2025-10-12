#!/bin/bash
cd /audiobook-creator

LOGFILE="/var/log/audiobook.log"
UVICORN_CMD="uvicorn app:app --host 0.0.0.0 --port 8000"

echo "[$(date)] Stopping any existing audiobook creator process..." | tee -a "$LOGFILE"

# Kill existing uvicorn processes for audiobook creator
pkill -f "$UVICORN_CMD"

# Wait up to 10 seconds for old process to exit
for i in {1..10}; do
    if pgrep -f "$UVICORN_CMD" > /dev/null; then
        echo "[$(date)] Waiting for process to stop ($i/10)..." | tee -a "$LOGFILE"
        sleep 1
    else
        break
    fi
done

# Final check — if still running, force kill
if pgrep -f "$UVICORN_CMD" > /dev/null; then
    echo "[$(date)] Process still running. Forcing kill..." | tee -a "$LOGFILE"
    pkill -9 -f "$UVICORN_CMD"
    sleep 1
fi

# Verify no instance remains
if pgrep -f "$UVICORN_CMD" > /dev/null; then
    echo "[$(date)] ERROR: Could not stop existing audiobook process." | tee -a "$LOGFILE"
    exit 1
else
    echo "[$(date)] Old process stopped successfully." | tee -a "$LOGFILE"
fi

# Activate environment
source .venv/bin/activate

# Start new instance
echo "[$(date)] Starting new audiobook creator instance..." | tee -a "$LOGFILE"
setsid $UVICORN_CMD > "$LOGFILE" 2>&1 < /dev/null &

# Deactivate
deactivate

# Confirm it started
sleep 2
if pgrep -f "$UVICORN_CMD" > /dev/null; then
    echo "[$(date)] Audiobook creator started successfully." | tee -a "$LOGFILE"
else
    echo "[$(date)] ERROR: Failed to start audiobook creator." | tee -a "$LOGFILE"
    exit 1
fi

