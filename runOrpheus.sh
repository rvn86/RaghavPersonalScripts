cd /Orpheus-TTS-FastAPI

source .venv/bin/activate
setsid uvicorn fastapi_app:app --host 0.0.0.0 --port 8880 > /var/log/orpheus.log 2>&1 < /dev/null &

deactivate
