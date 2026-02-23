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
- If Maps key exists but APIs are not enabled, generation can still fail on tool calls.

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
