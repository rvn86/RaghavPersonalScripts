#!/usr/bin/env bash
set -euo pipefail

# Ensure it's in ~/.bashrc (only add if not already present)
if ! grep -q 'RaghavPersonalScripts/bin' "$HOME/.bashrc"; then
    echo 'export PATH="/RaghavPersonalScripts/bin:$PATH"' >> "$HOME/.bashrc"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$(dirname "$SCRIPT_DIR")"
TOKEN=$1
WITH_VLLM=${2:-""}   # optional flag: pass "--with-vllm"

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

if [[ "$WITH_VLLM" == "--with-vllm" ]]; then
    # If using vLLM → set GPU utilization lower
    if grep -q '^TTS_GPU_MEMORY_UTILIZATION=' .env; then
        sed -i 's/^TTS_GPU_MEMORY_UTILIZATION=.*/TTS_GPU_MEMORY_UTILIZATION=0.5/' .env
    else
        echo 'TTS_GPU_MEMORY_UTILIZATION=0.5' >> .env
    fi
else
    # If NOT using vLLM → set GPU utilization higher
    if grep -q '^TTS_GPU_MEMORY_UTILIZATION=' .env; then
        sed -i 's/^TTS_GPU_MEMORY_UTILIZATION=.*/TTS_GPU_MEMORY_UTILIZATION=0.9/' .env
    else
        echo 'TTS_GPU_MEMORY_UTILIZATION=0.9' >> .env
    fi
fi

huggingface-cli login --token "$TOKEN"

# Run Orpheus TTS server on port 8880 (daemonized)
$BASE/runOrpheus.sh

deactivate

#############################################
# Setup vLLM server (only if specified)
#############################################
if [[ "$WITH_VLLM" == "--with-vllm" ]]; then
    mkdir -p /vllm-workspace
    cd /vllm-workspace
    uv venv --python 3.12 --seed
    source .venv/bin/activate
    uv pip install vllm --torch-backend=auto

    # Run vLLM server on port 1234 (daemonized)
    $BASE/runVllm.sh

    deactivate
fi

#############################################
# Setup Audiobook-Creator
#############################################
cd /
if [ ! -d "audiobook-creator" ]; then
    git clone https://github.com/prakharsr/audiobook-creator.git
fi
cd audiobook-creator

git pull
git apply $BASE/patch/audiobook-creator/0001-Add-Chapters.patch
uv venv --python 3.12
source .venv/bin/activate
uv pip install pip==24.0
uv pip install -r requirements_gpu.txt
uv pip install --upgrade six==1.17.0

# Write .env file properly (non-interactive)
cat > .env <<EOF
# No quotes in values
OPENAI_BASE_URL=http://localhost:1234/v1
OPENAI_API_KEY=lm-studio
OPENAI_MODEL_NAME=Qwen/Qwen3-4B
LLM_MAX_PARALLEL_REQUESTS_BATCH_SIZE=40
TTS_BASE_URL=http://localhost:8880/v1
TTS_API_KEY=dummy-key
TTS_MODEL=orpheus
NO_THINK_MODE=false
TTS_MAX_PARALLEL_REQUESTS_BATCH_SIZE=$( [[ "$WITH_VLLM" == "--with-vllm" ]] && echo 8 || echo 64 )
EOF

# Run Audiobook Creator server on port 8000 (daemonized)
$BASE/runAudiobook.sh

deactivate

echo "✅ All servers started as daemons:"
echo "   - Orpheus TTS -> /var/log/orpheus.log"
if [[ "$WITH_VLLM" == "--with-vllm" ]]; then
    echo "   - vLLM        -> /var/log/vllm.log"
fi
echo "   - Audiobook   -> /var/log/audiobook.log"

