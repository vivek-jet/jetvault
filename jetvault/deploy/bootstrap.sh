#!/bin/bash
# One-time server setup for JetVault on Ubuntu 24.04 (Lightsail/EC2), run as root:
#
#   JETVAULT_HOSTNAME=vault.example.com ACME_EMAIL=it@example.com bash bootstrap.sh
#
# Set JETVAULT_IMAGE to use a different image than ghcr.io/vivek-jet/jetvault:latest.
#
# Installs Docker, lays out /opt/jetvault, generates an admin token, starts the stack and
# schedules nightly backups. Safe to re-run: existing .env and data are kept.
set -euo pipefail

: "${JETVAULT_HOSTNAME:?set JETVAULT_HOSTNAME, e.g. vault.example.com}"
: "${ACME_EMAIL:?set ACME_EMAIL for the HTTPS certificate}"
ROOT=/opt/jetvault
SRC="$(cd "$(dirname "$0")" && pwd)"

if ! command -v docker >/dev/null; then
    curl -fsSL https://get.docker.com | sh
fi
systemctl enable --now docker

# Small instances: add swap so image pulls and upgrades never OOM
if ! swapon --show | grep -q /swapfile; then
    fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

install -d -m 700 "${ROOT}" "${ROOT}/data" "${ROOT}/backups"
install -m 644 "${SRC}/compose.yml" "${SRC}/Caddyfile" "${ROOT}/"
install -m 755 "${SRC}/backup.sh" "${ROOT}/backup.sh"

if [ ! -f "${ROOT}/.env" ]; then
    ADMIN_PLAIN="$(openssl rand -base64 36 | tr -d '\n')"
    ADMIN_HASH="$(docker run --rm -i docker.io/library/python:3.12-slim sh -c \
        'pip install -q argon2-cffi >/dev/null 2>&1 && python -c "import sys,argon2; print(argon2.PasswordHasher(time_cost=3, memory_cost=65540, parallelism=4).hash(sys.stdin.read().strip()))"' \
        <<< "${ADMIN_PLAIN}")"
    sed -e "s|^JETVAULT_HOSTNAME=.*|JETVAULT_HOSTNAME=${JETVAULT_HOSTNAME}|" \
        -e "s|^ACME_EMAIL=.*|ACME_EMAIL=${ACME_EMAIL}|" \
        -e "s|^ADMIN_TOKEN=.*|ADMIN_TOKEN='${ADMIN_HASH}'|" \
        "${SRC}/env.example" > "${ROOT}/.env"
    chmod 600 "${ROOT}/.env"
    install -m 600 /dev/null "${ROOT}/admin-token.txt"
    echo "${ADMIN_PLAIN}" > "${ROOT}/admin-token.txt"
    echo "Admin token saved to ${ROOT}/admin-token.txt (root only). Store it in a safe place, then delete the file."
fi

# Optional image override, e.g. an image loaded with `docker load` instead of pulled from GHCR
if [ -n "${JETVAULT_IMAGE:-}" ]; then
    sed -i '/^JETVAULT_IMAGE=/d' "${ROOT}/.env"
    echo "JETVAULT_IMAGE=${JETVAULT_IMAGE}" >> "${ROOT}/.env"
fi

cd "${ROOT}"
docker compose --env-file .env pull --ignore-pull-failures
docker compose --env-file .env up -d

echo "17 2 * * * root ${ROOT}/backup.sh >> /var/log/jetvault-backup.log 2>&1" > /etc/cron.d/jetvault-backup
echo "JetVault is starting at https://${JETVAULT_HOSTNAME}"
