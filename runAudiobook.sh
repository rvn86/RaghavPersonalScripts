cd audiobook-creator
source .venv/bin/activate
setsid uvicorn app:app --host 0.0.0.0 --port 8000 > /var/log/audiobook.log 2>&1 < /dev/null &

deactivate
