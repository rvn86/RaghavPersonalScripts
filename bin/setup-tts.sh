#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./setup.sh <HUGGINGFACE_TOKEN> [--with-vllm] [--activate|--only-activate]
#
# Examples:
#   ./setup.sh <token>                 # install only
#   ./setup.sh <token> --activate      # install + start services
#   ./setup.sh <token> --only-activate # skip install, just start services
#   ./setup.sh <token> --with-vllm --activate  # install + start + vLLM

# --- Parse args ---
TOKEN=${1:-""}
WITH_VLLM=""
ACTIVATE=false
ONLY_ACTIVATE=false

for arg in "$@"; do
  case $arg in
    --with-vllm)
      WITH_VLLM="--with-vllm"
      ;;
    --activate)
      ACTIVATE=true
      ;;
    --only-activate)
      ONLY_ACTIVATE=true
      ;;
  esac
done

if [[ -z "$TOKEN" ]]; then
  echo "❌ Missing Hugging Face token"
  echo "Usage: $0 <HUGGINGFACE_TOKEN> [--with-vllm] [--activate|--only-activate]"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$(dirname "$SCRIPT_DIR")"

# --- PATH setup ---
if ! grep -q 'RaghavPersonalScripts/bin' "$HOME/.bashrc"; then
    echo 'export PATH="/RaghavPersonalScripts/bin:$PATH"' >> "$HOME/.bashrc"
fi

PATH="/root/.local/bin:$PATH"

#############################################
# INSTALLATION PHASE (skipped if --only-activate)
#############################################
if ! $ONLY_ACTIVATE; then
    echo "🔧 Installing dependencies and setting up environments..."

    curl -LsSf https://astral.sh/uv/install.sh | sh
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
        sed -i 's/^TTS_GPU_MEMORY_UTILIZATION=.*/TTS_GPU_MEMORY_UTILIZATION=0.5/' .env || echo 'TTS_GPU_MEMORY_UTILIZATION=0.5' >> .env
    else
        sed -i 's/^TTS_GPU_MEMORY_UTILIZATION=.*/TTS_GPU_MEMORY_UTILIZATION=0.9/' .env || echo 'TTS_GPU_MEMORY_UTILIZATION=0.9' >> .env
    fi

    huggingface-cli login --token "$TOKEN"
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
    git apply $BASE/patch/audiobook-creator/0001-Add-Chapters.patch || echo "Patch may already be applied."
    uv venv --python 3.12
    source .venv/bin/activate
    uv pip install pip==24.0
    uv pip install -r requirements_gpu.txt
    uv pip install --upgrade six==1.17.0

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

    deactivate
fi

#############################################
# ACTIVATION PHASE (only if --activate or --only-activate)
#############################################
if $ACTIVATE || $ONLY_ACTIVATE; then
    echo "🚀 Starting services..."

    $BASE/runOrpheus.sh

    if [[ "$WITH_VLLM" == "--with-vllm" ]]; then
        $BASE/runVllm.sh
    fi

    $BASE/runAudiobook.sh

    echo "✅ All servers started as daemons:"
    echo "   - Orpheus TTS -> /var/log/orpheus.log"
    if [[ "$WITH_VLLM" == "--with-vllm" ]]; then
        echo "   - vLLM        -> /var/log/vllm.log"
    fi
    echo "   - Audiobook   -> /var/log/audiobook.log"
else
    echo "✅ Installation completed. (Services not started — use --activate to start them.)"
fi

