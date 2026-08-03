#!/bin/bash
set -e

echo "=== Waiting for Superset metadata database ==="

python - <<'PY'
import os
import time
import psycopg2

host = "postgres"
port = 5432
dbname = "superset_db"
user = os.environ["SUPERSET_DB_USER"]
password = os.environ["SUPERSET_DB_PASSWORD"]

for attempt in range(60):
    try:
        conn = psycopg2.connect(
            host=host,
            port=port,
            dbname=dbname,
            user=user,
            password=password,
        )
        conn.close()
        print("Superset metadata database is ready.")
        break
    except Exception as exc:
        print(f"Waiting for Superset metadata database... attempt {attempt + 1}/60: {exc}")
        time.sleep(5)
else:
    raise RuntimeError("Superset metadata database was not ready after waiting.")
PY
	
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

    echo "Synchronizing virtual dataset SQL from imported dashboard assets..."

    python - <<'PY'
import os
import json
import re
import zipfile
import yaml
import psycopg2

asset_zip = "/tmp/superset_dashboard_import.zip"
color_scheme = "d3Category20c"

updates = []
with zipfile.ZipFile(asset_zip, "r") as archive:
    for name in archive.namelist():
        if "/datasets/" not in name or not name.endswith(".yaml"):
            continue

        data = yaml.safe_load(archive.read(name).decode("utf-8"))
        if not isinstance(data, dict):
            continue

        table_name = data.get("table_name")
        dataset_sql = data.get("sql")
        if table_name and dataset_sql:
            updates.append((dataset_sql, table_name))

conn = psycopg2.connect(
    host="postgres",
    port=5432,
    dbname="superset_db",
    user=os.environ["SUPERSET_DB_USER"],
    password=os.environ["SUPERSET_DB_PASSWORD"],
)

with conn:
    with conn.cursor() as cur:
        for dataset_sql, table_name in updates:
            cur.execute(
                "update tables set sql = %s where table_name = %s",
                (dataset_sql, table_name),
            )
            print(f"Synchronized SQL for dataset {table_name}: {cur.rowcount} row(s)")

        cur.execute("select id, position_json from dashboards where position_json is not null")
        for dashboard_id, position_json in cur.fetchall():
            position = json.loads(position_json)
            active_chart_ids = {
                int(node["meta"]["chartId"])
                for node in position.values()
                if isinstance(node, dict)
                and node.get("type") == "CHART"
                and node.get("meta", {}).get("chartId") is not None
            }

            if active_chart_ids:
                cur.execute(
                    """
                    delete from dashboard_slices
                    where dashboard_id = %s
                      and not (slice_id = any(%s))
                    """,
                    (dashboard_id, sorted(active_chart_ids)),
                )
                print(
                    "Removed stale dashboard chart links for dashboard "
                    f"{dashboard_id}: {cur.rowcount} row(s)"
                )

        cur.execute(
            """
            update slices
            set slice_name = regexp_replace(slice_name, '^[Pp][1-4]_', '')
            where slice_name ~ '^[Pp][1-4]_'
            """
        )
        print(f"Removed chart name prefixes: {cur.rowcount} row(s)")

        cur.execute("select id, params, query_context from slices")
        for slice_id, params, query_context in cur.fetchall():
            updated_params = params
            updated_query_context = query_context

            if updated_params:
                updated_params = re.sub(
                    r'"color_scheme"\s*:\s*"[^"]+"',
                    f'"color_scheme": "{color_scheme}"',
                    updated_params,
                )

            if updated_query_context:
                updated_query_context = re.sub(
                    r'"color_scheme"\s*:\s*"[^"]+"',
                    f'"color_scheme":"{color_scheme}"',
                    updated_query_context,
                )

            if updated_params != params or updated_query_context != query_context:
                cur.execute(
                    """
                    update slices
                    set params = %s,
                        query_context = %s
                    where id = %s
                    """,
                    (updated_params, updated_query_context, slice_id),
                )

        cur.execute(
            """
            update dashboards
            set json_metadata = regexp_replace(
                    json_metadata,
                    '"color_scheme"\\s*:\\s*"[^"]+"',
                    '"color_scheme": "d3Category20c"',
                    'g'
                )
            where json_metadata is not null
            """
        )
        print(f"Normalized dashboard color scheme: {cur.rowcount} row(s)")

conn.close()
PY

    echo "Publishing imported dashboards and granting Public/Gamma access..."

    python - <<'PY'
import os
import psycopg2

conn = psycopg2.connect(
    host="postgres",
    port=5432,
    dbname="superset_db",
    user=os.environ["SUPERSET_DB_USER"],
    password=os.environ["SUPERSET_DB_PASSWORD"],
)

with conn:
    with conn.cursor() as cur:
        cur.execute("update dashboards set published = true where published is not true")
        cur.execute(
            """
            insert into dashboard_roles (dashboard_id, role_id)
            select d.id, r.id
            from dashboards d
            cross join ab_role r
            where d.published is true
              and r.name in ('Public', 'Gamma')
            on conflict do nothing
            """
        )

conn.close()
PY

else
    echo "No dashboard asset zip found. Skipping dashboard import."
fi

echo "=== 5. Fix project_db database URI after dashboard import ==="

superset set-database-uri \
    -d project_db \
    -u "postgresql+psycopg2://${PROJECT_DB_USER}:${PROJECT_DB_PASSWORD}@postgres:5432/${PROJECT_DB_NAME}" \
    || echo "Database project_db not found or set-database-uri failed. Continuing..."

echo "=== Superset initialization completed ==="
