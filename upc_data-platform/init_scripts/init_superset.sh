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


echo "=== 4. Import Superset dashboard assets if available ==="

ASSET_ZIP="/app/superset_assets/upc_dashboard.zip"
PATCHED_ASSET_ZIP="/tmp/superset_dashboard_import.zip"

if [ -f "$ASSET_ZIP" ]; then
    echo "Found dashboard asset zip: $ASSET_ZIP"
    echo "Patching database URI inside temporary import zip..."

    python - <<PY
import os
import zipfile
import yaml

src = "${ASSET_ZIP}"
dst = "${PATCHED_ASSET_ZIP}"

project_db_user = os.environ["PROJECT_DB_USER"]
project_db_password = os.environ["PROJECT_DB_PASSWORD"]
project_db_name = os.environ["PROJECT_DB_NAME"]

uri = f"postgresql+psycopg2://{project_db_user}:{project_db_password}@postgres:5432/{project_db_name}"

with zipfile.ZipFile(src, "r") as zin, zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as zout:
    for item in zin.infolist():
        content = zin.read(item.filename)

        if item.filename.endswith("/databases/project_db.yaml"):
            data = yaml.safe_load(content.decode("utf-8"))
            data["sqlalchemy_uri"] = uri
            content = yaml.safe_dump(data, sort_keys=False, allow_unicode=True).encode("utf-8")
            print(f"Patched database URI in {item.filename}")

        zout.writestr(item, content)

print(f"Created patched import zip: {dst}")
PY

    echo "Importing dashboard assets from patched zip..."

    superset import-dashboards \
        -p "$PATCHED_ASSET_ZIP" \
        -u "${SUPERSET_WEB_USER:-admin}"

else
    echo "No dashboard asset zip found. Skipping dashboard import."
fi

echo "=== 5. Fix project_db database URI after dashboard import ==="

superset set-database-uri \
    -d project_db \
    -u "postgresql+psycopg2://${PROJECT_DB_USER}:${PROJECT_DB_PASSWORD}@postgres:5432/${PROJECT_DB_NAME}" \
    || echo "Database project_db not found or set-database-uri failed. Continuing..."

echo "=== Superset initialization completed ==="