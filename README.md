# Ketchup Local

Docker Compose setup for local development.

Services:
- `db` (PostgreSQL)
- `backend` (FastAPI)
- `frontend` (Next.js)
- optional vLLM profiles

Assumes sibling directories:
- `ketchup-local`
- `ketchup-backend`
- `ketchup-frontend`

## Start

```bash
cd ketchup-local
cp env.example .env
# edit .env
```

Base stack:

```bash
docker compose up --build
```

With local vLLM:

```bash
docker compose --profile llm-apple up --build
# or
docker compose --profile llm-nvidia up --build
# or
docker compose --profile llm-rocm up --build
```

## Endpoints

- Frontend: `http://localhost:3001`
- Backend: `http://localhost:8000`
- Backend docs: `http://localhost:8000/docs`
- Postgres: `localhost:5433`
- vLLM: `http://localhost:8080/v1` (when LLM profile is running)

## vLLM Configuration

Important env vars:
- `VLLM_BASE_URL`
- `VLLM_MODEL`
- `VLLM_API_KEY`
- `VLLM_MODEL_HF_ID`
- `VLLM_MAX_MODEL_LEN`
- `VLLM_MAX_NUM_SEQS`
- `VLLM_ENABLE_AUTO_TOOL_CHOICE`
- `VLLM_TOOL_CALL_PARSER`
- `HF_TOKEN` (for gated/private models)

Planner behavior controls:
- `PLANNER_NOVELTY_TARGET_GENERATE`
- `PLANNER_NOVELTY_TARGET_REFINE`
- `PLANNER_FALLBACK_ENABLED`

Tool keys:
- `GOOGLE_MAPS_API_KEY`
- `TAVILY_API_KEY`

## Apple Profile

`llm-apple` expects host-local vLLM on port `8080`, then bridges from Compose network.

Start host vLLM:

```bash
cd ketchup-local
./scripts/start-host-vllm.sh
```

Then run Compose in another shell:

```bash
cd ketchup-local
docker compose --profile llm-apple up --build
```

## Useful Commands

```bash
docker compose logs -f backend
docker compose logs -f frontend
docker compose logs -f vllm-apple-bridge
docker compose logs -f vllm-nvidia
docker compose logs -f vllm-rocm
docker compose restart backend
docker compose down
docker compose down -v
```

## Quick Checks

vLLM health:

```bash
curl http://localhost:8080/health
curl http://localhost:8080/v1/models
```

Tavily smoke test:

```bash
cat >/tmp/tavily_test.py <<'PY'
import asyncio, json
import agents.planning as planning

out = asyncio.run(
    planning._web_search(
        query="group activities for friends",
        location="Boston, MA",
        max_results=3,
    )
)
print("ERROR:", out.get("error"))
print("RESULT_COUNT:", len(out.get("results", [])))
print(json.dumps(out.get("results", [])[:2], indent=2))
PY

docker compose exec -T backend env PYTHONPATH=/app python /dev/stdin < /tmp/tavily_test.py
```

## Troubleshooting

If plan generation returns `502`:
- check backend logs for planner/tool errors
- check active vLLM service logs for startup/model issues
- verify `GOOGLE_MAPS_API_KEY` for maps grounding
- verify `TAVILY_API_KEY` for web fallback
