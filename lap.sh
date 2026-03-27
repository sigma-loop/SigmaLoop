#!/usr/bin/env bash
set -euo pipefail

# ── Lambda LAP Service Manager ──────────────────────────────────
# Usage: ./lap.sh {start|stop|restart|status} [service...]
# Services: mongo, judge0, backend, frontend, all (default)
# Examples:
#   ./lap.sh start              # start everything
#   ./lap.sh stop               # stop everything
#   ./lap.sh restart backend    # restart only the backend
#   ./lap.sh status             # show what's running
# ────────────────────────────────────────────────────────────────

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$ROOT_DIR/Backend"
FRONTEND_DIR="$ROOT_DIR/Frontend"
PID_DIR="$ROOT_DIR/.pids"

# Docker compose shortcuts (separate project names to avoid orphan conflicts)
DC_MONGO="docker compose -p lap-mongo -f $BACKEND_DIR/docker-compose.yml"
DC_JUDGE0="docker compose -p lap-judge0 --env-file $BACKEND_DIR/.env.judge0 -f $BACKEND_DIR/docker-compose.judge0.yml"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log()  { echo -e "${CYAN}[LAP]${NC} $*"; }
ok()   { echo -e "${GREEN}[LAP]${NC} $*"; }
warn() { echo -e "${YELLOW}[LAP]${NC} $*"; }
err()  { echo -e "${RED}[LAP]${NC} $*" >&2; }

mkdir -p "$PID_DIR"

# ── Helpers ──────────────────────────────────────────────────────

is_running() {
    local pidfile="$PID_DIR/$1.pid"
    if [[ -f "$pidfile" ]]; then
        local pid
        pid=$(<"$pidfile")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
        rm -f "$pidfile"
    fi
    return 1
}

kill_pid() {
    local name="$1"
    local pidfile="$PID_DIR/$name.pid"
    if [[ -f "$pidfile" ]]; then
        local pid
        pid=$(<"$pidfile")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            # Wait up to 5 seconds for graceful shutdown
            for _ in $(seq 1 10); do
                kill -0 "$pid" 2>/dev/null || break
                sleep 0.5
            done
            # Force kill if still alive
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null || true
            fi
        fi
        rm -f "$pidfile"
    fi
}

# ── MongoDB ──────────────────────────────────────────────────────

start_mongo() {
    log "Starting MongoDB..."
    $DC_MONGO up -d mongo
    ok "MongoDB is up (port 27017)"
}

stop_mongo() {
    log "Stopping MongoDB..."
    $DC_MONGO stop mongo
    ok "MongoDB stopped"
}

# ── Judge0 (+ Postgres + Redis) ─────────────────────────────────

start_judge0() {
    log "Starting Judge0 (server + workers + postgres + redis)..."
    $DC_JUDGE0 up -d
    ok "Judge0 is up (port 2358)"
}

stop_judge0() {
    log "Stopping Judge0 stack..."
    $DC_JUDGE0 stop
    ok "Judge0 stopped"
}

# ── Backend (npm run dev) ────────────────────────────────────────

start_backend() {
    if is_running backend; then
        warn "Backend is already running (PID $(cat "$PID_DIR/backend.pid"))"
        return
    fi
    log "Starting Backend dev server..."
    cd "$BACKEND_DIR"
    npm run dev > "$PID_DIR/backend.log" 2>&1 &
    echo $! > "$PID_DIR/backend.pid"
    cd "$ROOT_DIR"
    ok "Backend started (PID $(<"$PID_DIR/backend.pid"), port 4000)"
    ok "  Logs: $PID_DIR/backend.log"
}

stop_backend() {
    if is_running backend; then
        log "Stopping Backend..."
        kill_pid backend
        ok "Backend stopped"
    else
        warn "Backend is not running"
    fi
}

# ── Frontend (npm run dev) ───────────────────────────────────────

start_frontend() {
    if is_running frontend; then
        warn "Frontend is already running (PID $(cat "$PID_DIR/frontend.pid"))"
        return
    fi
    log "Starting Frontend dev server..."
    cd "$FRONTEND_DIR"
    npm run dev > "$PID_DIR/frontend.log" 2>&1 &
    echo $! > "$PID_DIR/frontend.pid"
    cd "$ROOT_DIR"
    ok "Frontend started (PID $(<"$PID_DIR/frontend.pid"), port 5173)"
    ok "  Logs: $PID_DIR/frontend.log"
}

stop_frontend() {
    if is_running frontend; then
        log "Stopping Frontend..."
        kill_pid frontend
        ok "Frontend stopped"
    else
        warn "Frontend is not running"
    fi
}

# ── Status ───────────────────────────────────────────────────────

show_status() {
    echo ""
    echo -e "${CYAN}═══ Lambda LAP Status ═══${NC}"
    echo ""

    # MongoDB
    if $DC_MONGO ps --status running 2>/dev/null | grep -q mongo; then
        ok "  MongoDB        : running (port 27017)"
    else
        err "  MongoDB        : stopped"
    fi

    # Judge0
    if $DC_JUDGE0 ps --status running 2>/dev/null | grep -q judge0-server; then
        ok "  Judge0 Server  : running (port 2358)"
    else
        err "  Judge0 Server  : stopped"
    fi

    if $DC_JUDGE0 ps --status running 2>/dev/null | grep -q judge0-workers; then
        ok "  Judge0 Workers : running"
    else
        err "  Judge0 Workers : stopped"
    fi

    if $DC_JUDGE0 ps --status running 2>/dev/null | grep -q judge0-db; then
        ok "  PostgreSQL     : running"
    else
        err "  PostgreSQL     : stopped"
    fi

    if $DC_JUDGE0 ps --status running 2>/dev/null | grep -q judge0-redis; then
        ok "  Redis          : running"
    else
        err "  Redis          : stopped"
    fi

    # Backend
    if is_running backend; then
        ok "  Backend        : running (PID $(<"$PID_DIR/backend.pid"), port 4000)"
    else
        err "  Backend        : stopped"
    fi

    # Frontend
    if is_running frontend; then
        ok "  Frontend       : running (PID $(<"$PID_DIR/frontend.pid"), port 5173)"
    else
        err "  Frontend       : stopped"
    fi

    echo ""
}

# ── Service dispatcher ───────────────────────────────────────────

do_start() {
    local svc="$1"
    case "$svc" in
        mongo)    start_mongo ;;
        judge0)   start_judge0 ;;
        backend)  start_backend ;;
        frontend) start_frontend ;;
        all)
            start_mongo
            start_judge0
            start_backend
            start_frontend
            ;;
        *) err "Unknown service: $svc"; exit 1 ;;
    esac
}

do_stop() {
    local svc="$1"
    case "$svc" in
        mongo)    stop_mongo ;;
        judge0)   stop_judge0 ;;
        backend)  stop_backend ;;
        frontend) stop_frontend ;;
        all)
            stop_frontend
            stop_backend
            stop_judge0
            stop_mongo
            ;;
        *) err "Unknown service: $svc"; exit 1 ;;
    esac
}

do_restart() {
    local svc="$1"
    do_stop "$svc"
    do_start "$svc"
}

# ── Main ─────────────────────────────────────────────────────────

usage() {
    echo "Usage: $0 {start|stop|restart|status} [service...]"
    echo ""
    echo "Services: mongo, judge0, backend, frontend, all (default)"
    echo ""
    echo "Examples:"
    echo "  $0 start              # start everything"
    echo "  $0 stop               # stop everything"
    echo "  $0 restart backend    # restart only the backend"
    echo "  $0 start mongo judge0 # start only databases"
    echo "  $0 status             # show what's running"
    echo "  $0 logs backend       # tail backend logs"
    echo "  $0 logs frontend      # tail frontend logs"
}

ACTION="${1:-}"
shift || true

if [[ -z "$ACTION" ]]; then
    usage
    exit 1
fi

# Special case: logs
if [[ "$ACTION" == "logs" ]]; then
    TARGET="${1:-}"
    case "$TARGET" in
        backend)  tail -f "$PID_DIR/backend.log" ;;
        frontend) tail -f "$PID_DIR/frontend.log" ;;
        judge0)   $DC_JUDGE0 logs -f ;;
        mongo)    $DC_MONGO logs -f mongo ;;
        *) err "Usage: $0 logs {backend|frontend|judge0|mongo}"; exit 1 ;;
    esac
    exit 0
fi

# Special case: status
if [[ "$ACTION" == "status" ]]; then
    show_status
    exit 0
fi

# Validate action
if [[ "$ACTION" != "start" && "$ACTION" != "stop" && "$ACTION" != "restart" ]]; then
    err "Unknown action: $ACTION"
    usage
    exit 1
fi

# Default to "all" if no services specified
SERVICES=("${@:-all}")

for svc in "${SERVICES[@]}"; do
    "do_$ACTION" "$svc"
done

echo ""
ok "Done!"
