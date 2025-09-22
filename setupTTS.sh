#!/usr/bin/env bash
set -euo pipefail

TOKEN=$1

# Install dependencies
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc
apt-get update
apt-get install -y vim ffmpeg git

#############################################
# Setup Orpheus-TTS-FastAPI
#############################################
cd /
if [ ! -d "Orpheus-TTS-FastAPI" ]; then
    git clone https://github.com/prakharsr/Orpheus-TTS-FastAPI.git
fi
cd Orpheus-TTS-FastAPI

uv venv --python 3.12
source .venv/bin/activate
uv pip install -r requirements.txt
uv pip install hf_transfer

cp .env.sample .env
huggingface-cli login --token "$TOKEN"

# Run Orpheus TTS server on port 8880 (daemonized)
setsid uvicorn fastapi_app:app --host 0.0.0.0 --port 8880 > /var/log/orpheus.log 2>&1 < /dev/null &

deactivate

#############################################
# Setup Audiobook-Creator
#############################################
cd /
if [ ! -d "audiobook-creator" ]; then
    git clone https://github.com/prakharsr/audiobook-creator.git
fi
cd audiobook-creator

uv venv --python 3.12
source .venv/bin/activate
uv pip install pip==24.0
uv pip install -r requirements_gpu.txt
uv pip install --upgrade six==1.17.0

# Write .env file properly (non-interactive)
cat > .env <<'EOF'
# No quotes in values
OPENAI_BASE_URL=http://localhost:1234/v1
OPENAI_API_KEY=lm-studio
OPENAI_MODEL_NAME=qwen3-14b
LLM_MAX_PARALLEL_REQUESTS_BATCH_SIZE=4
TTS_BASE_URL=http://localhost:8880/v1
TTS_API_KEY=dummy-key
TTS_MODEL=orpheus
NO_THINK_MODE=false
TTS_MAX_PARALLEL_REQUESTS_BATCH_SIZE=8
EOF

# Run Audiobook Creator server on port 8000 (daemonized)
setsid uvicorn app:app --host 0.0.0.0 --port 8000 > /var/log/audiobook.log 2>&1 < /dev/null &

deactivate

echo "✅ Both servers started as daemons (check /var/log/orpheus.log and /var/log/audiobook.log)"

