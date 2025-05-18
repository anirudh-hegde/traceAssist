#!/usr/bin/env bash
set -euo pipefail

# ─── Ensure we're in the repo root ─────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ─── Load AI-Agent .env if present ─────────────────────────────────────────────
if [ -f ai-agent/.env ]; then
  echo "🔑 Loading environment variables from ai-agent/.env"
  set -o allexport
  source ai-agent/.env
  set +o allexport
fi

# Check that OPENAI_API_KEY is now set
if [ -z "${OPENAI_API_KEY-}" ]; then
  echo "❌ Missing OPENAI_API_KEY. Please add it to ai-agent/.env as:"
  echo "    OPENAI_API_KEY=sk-..."
  exit 1
fi

echo "🛠  Starting full TraceAssist setup..."

# ─── 1) Telemetry Stack ───────────────────────────────────────────────────────
echo "🔧  1) Launching telemetry stack..."
docker network inspect telemetry >/dev/null 2>&1 || docker network create telemetry
cd telemetry
docker-compose up -d
cd ..

# ─── 2) Backend API ────────────────────────────────────────────────────────────
echo "🔧  2) Setting up Backend..."
if [ ! -d backend/venv ]; then
  python3 -m venv backend/venv
fi
backend/venv/bin/pip install --upgrade pip
backend/venv/bin/pip install -r backend/requirements.txt

echo "🚀  Starting Backend on http://localhost:8000 ..."
nohup backend/venv/bin/uvicorn backend.main:app \
  --host 0.0.0.0 --port 8000 \
  > backend.log 2>&1 &

# ─── 3) AI-Agent Service ──────────────────────────────────────────────────────
echo "🔧  3) Setting up AI-Agent..."
if [ ! -d ai-agent/venv ]; then
  python3 -m venv ai-agent/venv
fi
ai-agent/venv/bin/pip install --upgrade pip
ai-agent/venv/bin/pip install -r ai-agent/requirements.txt

echo "🚀  Starting AI-Agent on http://localhost:8200 ..."
nohup ai-agent/venv/bin/uvicorn ai-agent.main:app \
  --host 0.0.0.0 --port 8200 \
  > ai-agent.log 2>&1 &

# ─── 4) Frontend UI ────────────────────────────────────────────────────────────
echo "🔧  4) Setting up Frontend..."
cd frontend
npm install
echo "🚀  Starting Frontend on http://localhost:5173 ..."
nohup npm run dev > frontend.log 2>&1 &
cd ..

# ─── Done ──────────────────────────────────────────────────────────────────────
echo
echo "✅  Setup complete!"
echo
echo "  • Frontend UI:     http://localhost:5173"
echo "  • Backend API:     http://localhost:8000/docs"
echo "  • AI-Agent API:    http://localhost:8200/docs"
echo "  • Grafana:         http://localhost:3000  (admin/admin)"
echo "  • Prometheus:      http://localhost:9090"
echo "  • Jaeger UI:       http://localhost:16686"
echo "  • Loki UI:         http://localhost:3100"
echo
echo "Logs are in: backend.log, ai-agent.log, frontend.log"
