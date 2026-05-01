import os

# ================= 0. Core Security Configuration (Must be explicitly declared) =================
# Read the secret key configured in our .env file. This is an absolute prerequisite for starting Superset 4.0.
SECRET_KEY = os.environ.get("SUPERSET_SECRET_KEY", "fallback_secret_key_if_missing_12345")
SQLALCHEMY_DATABASE_URI = os.environ.get("SQLALCHEMY_DATABASE_URI")

# ================= 1. Roles and Anonymous Access =================
# Used to allow unauthenticated users (e.g., accessing via the Astro website) to view public dashboards.
AUTH_ROLE_PUBLIC = "Public"
PUBLIC_ROLE_LIKE = "Gamma"

# ================= 2. Feature Flags =================
FEATURE_FLAGS = {
    "ALERT_REPORTS": True,
    "DATASET_FOLDERS": True,
    "DASHBOARD_RBAC": True,
    "ENABLE_JAVASCRIPT_CONTROLS": True,
    "EMBEDDED_SUPERSET": True,
}

# ================= 3. Third-Party Integrations =================
# Security upgrade: Do not hardcode the API key here; read it from system environment variables.
MAPBOX_API_KEY = os.environ.get("MAPBOX_API_KEY", "")

# ================= 4. Security and Display =================
# Note: Disabling these options reduces security, but this is usually necessary for embedded JS controls.
HTML_SANITIZATION = False
TALISMAN_ENABLED = False

# ================= 5. Alerts and SQL Lab =================
ALERT_REPORTS_NOTIFICATION_DRY_RUN = True
SQLLAB_CTAS_NO_LIMIT = True