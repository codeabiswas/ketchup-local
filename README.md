# 🍅 Ketchup Local Development

This folder orchestrates the full Ketchup stack using Docker Compose, pulling from the separate frontend and backend repositories.

## Folder Structure

```
~/projects/
├── ketchup-frontend/       ← Next.js repo (must exist)
├── ketchup-backend/        ← FastAPI repo (must exist)
└── ketchup-local/          ← THIS folder
    ├── docker-compose.yml
    ├── .env.example
    ├── .env                ← your local secrets (git-ignored)
    ├── README.md
    └── db/
        └── init/
            ├── 01_schema.sql
```

## Prerequisites

- **Docker** and **Docker Compose** (v2) installed
- Both repos cloned as siblings to this folder

## Quick Start

```bash
# 1. Clone repos side by side (if you haven't already)
cd ~/projects
git clone <your-frontend-repo> ketchup-frontend
git clone <your-backend-repo> ketchup-backend

# 2. Set up this folder
cd ketchup-local
cp .env.example .env

# 3. Copy your SQL migration files into db/init/
#    (These run automatically on first database creation)
cp ../ketchup-backend/database/migrations/01_schema.sql db/init/

# 4. Start everything
docker compose up

# 5. Open the app
#    Frontend: http://localhost:3001
#    Backend API docs: http://localhost:8000/docs
#    Database: localhost:5433 (user: postgres, pass: postgres, db: appdb)
```

## Common Commands

```bash
# Start in background
docker compose up -d

# Rebuild after changing requirements.txt or package.json
docker compose up --build

# View logs for one service
docker compose logs -f backend

# Stop everything
docker compose down

# Nuclear reset (wipes database)
docker compose down -v
```

## How Networking Works

Inside Docker, services talk to each other by **service name**:
- Frontend calls backend at `http://backend:8000` (via Next.js API proxy)
- Backend calls database at `postgresql://postgres:postgres@db:5432/appdb`

From your **browser**, you access services via published ports:
- Frontend: `http://localhost:3001`
- Backend: `http://localhost:8000`

The Next.js API proxy (`/api/[...path]/route.ts`) bridges this gap — browser JS
calls `/api/something`, Next.js server-side code forwards it to `http://backend:8000/api/something`.
