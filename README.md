# Ketchup Local

Local development stack for the Ketchup product.

Data pipeline orchestration (DVC/Airflow) is managed in `ketchup-backend/docker-compose.yml`.
Use this repository for app runtime (frontend, backend API, Postgres, optional local LLM profiles).

## What This Runs

- `db`: PostgreSQL
- `backend`: FastAPI API service
- `frontend`: Next.js app
- Optional LLM profiles:
  - `llm-apple` (host vLLM + bridge container)
  - `llm-nvidia` (containerized vLLM)
  - `llm-rocm` (containerized vLLM)

## Prerequisites

- Docker Desktop
- Python 3.11+ (for host vLLM on Apple profile)
- Hugging Face token if model access is gated/private

## Repository Assumptions

Sibling directories are expected:

- `ketchup-local`
- `ketchup-backend`
- `ketchup-frontend`

## Environment Setup

```bash
cd ketchup-local
cp env.example .env
# edit .env for your keys and model settings
```

If your Postgres volume was created before analytics schema changes:

```bash
docker compose exec -T db psql -U postgres -d appdb -f /docker-entrypoint-initdb.d/02_analytics.sql
```

## Start the Stack

Base stack (no local LLM profile):

```bash
docker compose up --build
```

Apple host-vLLM profile:

```bash
docker compose --profile llm-apple up --build
```

GPU profiles:

```bash
docker compose --profile llm-nvidia up --build
# or
docker compose --profile llm-rocm up --build
```

## Apple Silicon: Host vLLM Setup

`llm-apple` expects a host-local vLLM server on `0.0.0.0:8080`.

Install once:

```bash
python3 -m venv ~/.venv-vllm-metal
source ~/.venv-vllm-metal/bin/activate
pip install -U pip vllm vllm-metal huggingface_hub
hf auth login   # required for gated/private models
```

Start vLLM:

```bash
cd ketchup-local
./scripts/start-host-vllm.sh
```

Override model when needed:

```bash
VLLM_MODEL_HF_ID=<your-hf-model-id> ./scripts/start-host-vllm.sh
```

## Service Endpoints

- Frontend: `http://localhost:3001`
- Postgres: `localhost:5433`
- Host vLLM: `http://localhost:8080/v1` (when running)

Networking notes:

- Backend is internal to compose (`http://backend:8000`) and not host-published by default.
- Frontend reaches backend through `/api/*` proxy routes.

## Validation Checklist

1. Container status

```bash
docker compose ps
```

2. Backend compile sanity

```bash
docker compose exec -T backend python -m compileall /app/agents /app/analytics /app/api /app/services
```

3. vLLM health (host)

```bash
curl http://localhost:8080/health
curl http://localhost:8080/v1/models
```

4. vLLM reachability from backend container

```bash
docker compose exec -T backend python -c "import httpx; print(httpx.get('http://vllm-local:8080/health', timeout=5).status_code)"
```

5. Planner flow

- In UI, open a group and run `Generate plans` and `Refine`.
- Inspect backend logs:

```bash
docker compose logs --since=10m backend | rg "Planner tool summary|tool loop failed|deterministic grounded fallback"
```

6. Tavily tool smoke (optional)

```bash
docker compose exec -T backend env PYTHONPATH=/app python -c "import asyncio,json; import agents.planning as p; out=asyncio.run(p._web_search(query='group activities for friends', location='Boston, MA', max_results=3)); print('ERROR:', out.get('error')); print('RESULT_COUNT:', len(out.get('results', []))); print(json.dumps(out.get('results', [])[:2], indent=2))"
```

## Useful Commands

```bash
docker compose logs -f backend
docker compose logs -f frontend
docker compose restart backend
docker compose down
docker compose down -v
```

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| Planner requests time out | LLM server not reachable or too slow | verify `http://vllm-local:8080/health` from backend; check model size and timeout settings |
| `tool_choice=auto` error from backend logs | vLLM not started with tool-calling flags | restart vLLM with `--enable-auto-tool-choice --tool-call-parser ...` |
| `llm-apple` bridge cannot reach host | host vLLM not running/bound correctly | run `./scripts/start-host-vllm.sh`, ensure bind `0.0.0.0:8080` |
| Repeated fallback-only plans | missing API keys or tool parsing unsupported by model template | verify `GOOGLE_MAPS_API_KEY`, optional `TAVILY_API_KEY`, and model/tool parser compatibility |
| Compose network not found/orphan issues | stale compose state | `docker compose down --remove-orphans` then `docker compose up --build` |
