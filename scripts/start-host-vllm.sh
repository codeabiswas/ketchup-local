#!/usr/bin/env sh
set -eu

MODEL="${1:-${VLLM_MODEL_HF_ID:-Qwen/Qwen3-4B-Instruct-2507}}"
HOST="${VLLM_HOST:-0.0.0.0}"
PORT="${VLLM_PORT:-8080}"
API_KEY="${VLLM_API_KEY:-EMPTY}"
MAX_MODEL_LEN="${VLLM_MAX_MODEL_LEN:-4096}"
MAX_NUM_SEQS="${VLLM_MAX_NUM_SEQS:-4}"
ENABLE_AUTO_TOOL_CHOICE="${VLLM_ENABLE_AUTO_TOOL_CHOICE:-true}"
TOOL_CALL_PARSER="${VLLM_TOOL_CALL_PARSER:-hermes}"
CHAT_TEMPLATE="${VLLM_CHAT_TEMPLATE:-}"
VLLM_BIN=""

if command -v vllm >/dev/null 2>&1; then
  VLLM_BIN="vllm"
elif command -v python3 >/dev/null 2>&1 && python3 -c "import vllm" >/dev/null 2>&1; then
  VLLM_BIN="python3 -m vllm.entrypoints.openai.api_server"
fi

if [ -z "${VLLM_BIN}" ]; then
  echo "vLLM not found on host (no 'vllm' CLI and no importable Python module)." >&2
  echo "Install host vLLM first (Apple Silicon recommended: vllm-metal installer)," >&2
  echo "then rerun this script." >&2
  echo "Alternatively run any OpenAI-compatible server on ${HOST}:${PORT}." >&2
  exit 1
fi

echo "Starting host-local vLLM:"
echo "  model=${MODEL}"
echo "  host=${HOST}"
echo "  port=${PORT}"
echo "  auto_tool_choice=${ENABLE_AUTO_TOOL_CHOICE}"
if [ "${ENABLE_AUTO_TOOL_CHOICE}" = "true" ]; then
  echo "  tool_call_parser=${TOOL_CALL_PARSER}"
fi

set -- \
  --host "${HOST}" \
  --port "${PORT}" \
  --api-key "${API_KEY}" \
  --max-model-len "${MAX_MODEL_LEN}" \
  --max-num-seqs "${MAX_NUM_SEQS}"

if [ "${ENABLE_AUTO_TOOL_CHOICE}" = "true" ]; then
  set -- "$@" --enable-auto-tool-choice --tool-call-parser "${TOOL_CALL_PARSER}"
fi

if [ -n "${CHAT_TEMPLATE}" ]; then
  echo "  chat_template=${CHAT_TEMPLATE}"
  set -- "$@" --chat-template "${CHAT_TEMPLATE}"
fi

if [ "${VLLM_BIN}" = "vllm" ]; then
  exec vllm serve "${MODEL}" "$@"
fi

exec python3 -m vllm.entrypoints.openai.api_server \
  --model "${MODEL}" \
  "$@"
