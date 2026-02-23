# Ketchup Local

Local Docker Compose setup for the full Ketchup stack:
- `db` (PostgreSQL)
- `backend` (FastAPI)
- `frontend` (Next.js)
- optional `local-llm` profile (llama.cpp OpenAI-compatible server)

This folder assumes `ketchup-local`, `ketchup-backend`, and `ketchup-frontend` are sibling folders.

## What It Runs

`docker compose up` starts:
- Frontend: `http://localhost:3001`
- Backend API: `http://localhost:8000`
- Backend docs: `http://localhost:8000/docs`
- Postgres host port: `localhost:5433`

`docker compose --profile llm up` additionally starts:
- one-shot model init/downloader (`llm-model-init`)
- Local LLM endpoint: `http://localhost:8080/v1`

## Prerequisites

- Docker Desktop (Compose v2)
- Google OAuth web credentials (used by frontend sign-in)
- `AUTH_SECRET` for Auth.js
- Optional for tool-grounded planning:
  - `GOOGLE_MAPS_API_KEY` with:
    - Places API (New)
    - Routes API
  - Optional web fallback:
    - `TAVILY_API_KEY` (Tavily API key)

## Setup

```bash
cd ketchup-local
cp env.example .env
# Fill required values in .env (OAuth + AUTH_SECRET at minimum)
```

Start base stack:

```bash
docker compose up --build
```

## Optional: Local LLM Profile

The llm profile now auto-manages model bootstrap:
- checks `./models/${LLM_HF_FILENAME}`
- downloads from `${LLM_HF_REPO}` only if missing
- creates/updates symlink `./models/${LLM_LOCAL_MODEL_LINK}`

Then run:

```bash
docker compose --profile llm up --build
```

Quick checks:

```bash
curl http://localhost:8080/health
curl http://localhost:8080/v1/models
```

If you want a different model file/repo, override in `.env`:

```bash
LLM_HF_REPO=<hf-repo>
LLM_HF_FILENAME=<file.gguf>
LLM_LOCAL_MODEL_LINK=<symlink-name.gguf>
```

## Useful Commands

```bash
docker compose up -d
docker compose logs -f backend
docker compose logs -f frontend
docker compose logs -f local-llm
docker compose restart backend
docker compose down
docker compose down -v
```

## Notes About Planning Runtime

- Backend points to `VLLM_BASE_URL=http://local-llm:8080/v1`.
- If local LLM is unavailable, plan generation may fail or rely on fallback behavior depending on `PLANNER_FALLBACK_ENABLED`.
- If `GOOGLE_MAPS_API_KEY` is missing, planner runs without tool grounding.
- If `TAVILY_API_KEY` is set, planner enables web fallback when maps search returns no venues.
- `web_search` is fallback-only. If maps already returns usable venues, planner may not call Tavily in that run.
- If Maps key exists but APIs are not enabled, generation can still fail on tool calls.

## Verify Tavily Integration

1. Restart backend after updating `.env`:

```bash
docker compose restart backend
```

2. Smoke-test web tool directly in backend container:

```bash
cat > /tmp/tavily_test.py <<'PY'
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

3. End-to-end plan generation and tool summary logs:

```bash
docker compose logs backend --since=15m | rg "Planner tool summary|web_calls|web_results|web-grounded fallback|Planner invoking tool 'web_search'"
```

## Common Issues

`network ... not found` while bringing stack up:

```bash
docker compose down --remove-orphans
docker compose --profile llm up --build --force-recreate
```

`POST /generate-plans` returns 502:
- Check backend logs and local-llm logs.
- Check `llm-model-init` logs to confirm download/symlink.
- Verify Maps key and API enablement if using tool grounding.
