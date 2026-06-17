#!/usr/bin/env bash
# SigmaLoop EC2 bootstrap — Ubuntu 24.04 LTS, x86_64 (t3.small).
#
# Run as a normal sudo user (e.g. `ubuntu`). Re-runnable / idempotent.
# Judge0 needs cgroup v1, which requires a one-time GRUB change + reboot;
# this script detects the cgroup version and walks you through both phases:
#
#   PHASE 1 (cgroup v2 active):  installs packages + swap, flips kernel to
#                                cgroup v1, then asks you to reboot.
#   PHASE 2 (after reboot):      clones the repos and prints the next steps.
set -euo pipefail

REPO_ROOT_URL="${REPO_ROOT_URL:-https://github.com/sigma-loop/SigmaLoop.git}"
REPO_BACKEND_URL="${REPO_BACKEND_URL:-https://github.com/sigma-loop/Backend.git}"
APP_DIR="${APP_DIR:-$HOME/SigmaLoop}"

echo "==> Installing base packages (docker, nginx, certbot, git)…"
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl git nginx
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
  echo "    (log out/in once for docker group to apply, or use sudo docker)"
fi
sudo snap install --classic certbot 2>/dev/null || sudo apt-get install -y certbot python3-certbot-nginx
sudo ln -sf /snap/bin/certbot /usr/bin/certbot 2>/dev/null || true

echo "==> Ensuring a 4 GB swap file (headroom on a 2 GB box)…"
if ! sudo swapon --show | grep -q '/swapfile'; then
  sudo fallocate -l 4G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
  sudo sysctl -w vm.swappiness=10
  echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf >/dev/null
fi

echo "==> Checking cgroup version (Judge0 needs v1)…"
if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
  echo "    cgroup v2 is active — switching the kernel to cgroup v1…"
  if ! grep -q 'unified_cgroup_hierarchy=0' /etc/default/grub; then
    sudo sed -i 's/^GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 systemd.unified_cgroup_hierarchy=0 cgroup_enable=memory swapaccount=1"/' /etc/default/grub
    sudo update-grub
  fi
  echo
  echo "================================================================"
  echo "  REBOOT REQUIRED:   sudo reboot"
  echo "  After it comes back, re-run this script to finish (phase 2)."
  echo "================================================================"
  exit 0
fi
echo "    cgroup v1 OK."

echo "==> Cloning / updating repos…"
if [ ! -d "$APP_DIR/.git" ]; then
  git clone "$REPO_ROOT_URL" "$APP_DIR"
fi
if [ ! -d "$APP_DIR/Backend/.git" ]; then
  git clone "$REPO_BACKEND_URL" "$APP_DIR/Backend"
fi

echo
echo "Base setup complete. Next steps:"
echo "  1) cd $APP_DIR/deploy && cp .env.prod.example .env.prod && nano .env.prod"
echo "  2) docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build"
echo "  3) sudo cp nginx-api.conf /etc/nginx/sites-available/sigmaloop-api"
echo "     sudo ln -s /etc/nginx/sites-available/sigmaloop-api /etc/nginx/sites-enabled/"
echo "     sudo nginx -t && sudo systemctl reload nginx"
echo "  4) sudo certbot --nginx -d api.sigmaloop.dpdns.org   # free TLS + auto-renew"
echo "  (see deploy/README.md for the full runbook)"
