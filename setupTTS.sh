#!/usr/bin/env bash
set -euo pipefail

TOKEN=$1

# Install dependencies
curl -LsSf https://astral.sh/uv/install.sh | sh
PATH="/root/.local/bin:$PATH"
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

# Ensure TTS_GPU_MEMORY_UTILIZATION is set to 0.6
if grep -q '^TTS_GPU_MEMORY_UTILIZATION=' .env; then
    sed -i 's/^TTS_GPU_MEMORY_UTILIZATION=.*/TTS_GPU_MEMORY_UTILIZATION=0.6/' .env
else
    echo 'TTS_GPU_MEMORY_UTILIZATION=0.6' >> .env
fi

huggingface-cli login --token "$TOKEN"

# Run Orpheus TTS server on port 8880 (daemonized)
setsid uvicorn fastapi_app:app --host 0.0.0.0 --port 8880 > /var/log/orpheus.log 2>&1 < /dev/null &

deactivate

#############################################
# Setup vLLM server
#############################################
mkdir -p /vllm-workspace
cd /vllm-workspace
uv venv --python 3.12 --seed
source .venv/bin/activate
uv pip install vllm --torch-backend=auto

# Run vLLM server on port 1234 (daemonized)
setsid vllm serve --port 1234 --host 127.0.0.1 --gpu-memory-utilization 0.2 > /var/log/vllm.log 2>&1 < /dev/null &

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
OPENAI_MODEL_NAME=Qwen/Qwen3-0.6B
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

echo "✅ All servers started as daemons:"
echo "   - Orpheus TTS -> /var/log/orpheus.log"
echo "   - vLLM        -> /var/log/vllm.log"
echo "   - Audiobook   -> /var/log/audiobook.log"
