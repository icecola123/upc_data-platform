#!/bin/bash
set -e

echo "=== 1. Upgrade Superset metadata database ==="
superset db upgrade

echo "=== 2. Create or reset Superset admin user ==="

if superset fab list-users | grep -q "${SUPERSET_WEB_USER:-admin}"; then
    echo "Admin user already exists. Resetting password..."
    superset fab reset-password \
        --username "${SUPERSET_WEB_USER:-admin}" \
        --password "${SUPERSET_WEB_PASSWORD:-admin_super_pass}" || true
else
    echo "Creating admin user..."
    superset fab create-admin \
        --username "${SUPERSET_WEB_USER:-admin}" \
        --firstname Admin \
        --lastname Admin \
        --email admin@example.com \
        --password "${SUPERSET_WEB_PASSWORD:-admin_super_pass}"
fi

echo "=== 3. Initialize Superset roles and permissions ==="
superset init

echo "=== Superset initialization completed ==="