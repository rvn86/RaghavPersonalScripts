cd /vllm-workspace
source .venv/bin/activate

# Run vLLM server on port 1234 (daemonized)
setsid vllm serve Qwen/Qwen3-4B --port 1234 --host 127.0.0.1 --gpu-memory-utilization 0.35 > /var/log/vllm.log 2>&1 < /dev/null &
deactivate

