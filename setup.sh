#!/usr/bin/env bash
set -euo pipefail

# ── SigmaLoop Setup ────────────────────────────────────────────
# Clones or pulls the Frontend and Backend repositories.
#
# Usage:
#   ./setup.sh          # Clone missing repos, pull existing ones
#   ./setup.sh clone    # Force fresh clone (removes existing)
#   ./setup.sh pull     # Pull latest changes only
#   ./setup.sh install  # Clone/pull + npm install
# ────────────────────────────────────────────────────────────────

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

ORG="sigma-loop"
REPOS=(
  "Frontend"
  "Backend"
)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${CYAN}[setup]${NC} $*"; }
ok()   { echo -e "${GREEN}[setup]${NC} $*"; }
warn() { echo -e "${YELLOW}[setup]${NC} $*"; }
err()  { echo -e "${RED}[setup]${NC} $*" >&2; }

clone_repo() {
  local name="$1"
  local dir="$ROOT_DIR/$name"
  local url="https://github.com/$ORG/$name.git"

  if [[ -d "$dir" ]]; then
    warn "$name/ already exists — skipping clone (use 'pull' to update)"
    return
  fi

  log "Cloning $url ..."
  git clone "$url" "$dir"
  ok "$name cloned"
}

pull_repo() {
  local name="$1"
  local dir="$ROOT_DIR/$name"

  if [[ ! -d "$dir/.git" ]]; then
    warn "$name/ is not a git repo — run clone first"
    return 1
  fi

  log "Pulling latest for $name ..."
  git -C "$dir" pull --ff-only
  ok "$name updated"
}

install_deps() {
  local name="$1"
  local dir="$ROOT_DIR/$name"

  if [[ ! -f "$dir/package.json" ]]; then
    warn "$name/ has no package.json — skipping install"
    return
  fi

  log "Installing dependencies for $name ..."
  (cd "$dir" && npm install)
  ok "$name dependencies installed"
}

force_clone() {
  local name="$1"
  local dir="$ROOT_DIR/$name"

  if [[ -d "$dir" ]]; then
    warn "Removing existing $name/ ..."
    rm -rf "$dir"
  fi

  clone_repo "$name"
}

# ── Main ─────────────────────────────────────────────────────

ACTION="${1:-setup}"

case "$ACTION" in
  setup)
    echo ""
    log "Setting up SigmaLoop repositories..."
    echo ""
    for repo in "${REPOS[@]}"; do
      if [[ -d "$ROOT_DIR/$repo/.git" ]]; then
        pull_repo "$repo"
      else
        clone_repo "$repo"
      fi
    done
    ;;

  clone)
    echo ""
    log "Force cloning all repositories..."
    echo ""
    for repo in "${REPOS[@]}"; do
      force_clone "$repo"
    done
    ;;

  pull)
    echo ""
    log "Pulling latest changes..."
    echo ""
    for repo in "${REPOS[@]}"; do
      pull_repo "$repo"
    done
    ;;

  install)
    echo ""
    log "Setting up and installing dependencies..."
    echo ""
    for repo in "${REPOS[@]}"; do
      if [[ -d "$ROOT_DIR/$repo/.git" ]]; then
        pull_repo "$repo"
      else
        clone_repo "$repo"
      fi
      install_deps "$repo"
    done
    ;;

  *)
    err "Unknown action: $ACTION"
    echo "Usage: $0 {setup|clone|pull|install}"
    exit 1
    ;;
esac

echo ""
ok "Done!"
