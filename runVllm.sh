cd /vllm-workspace
source .venv/bin/activate

# Run vLLM server on port 1234 (daemonized)
setsid vllm serve "mistralai/Mistral-7B-Instruct-v0.3" --port 1234 --host 127.0.0.1 --max-model-len=16000 --gpu-memory-utilization 0.45 > /var/log/vllm.log 2>&1 < /dev/null &
deactivate

