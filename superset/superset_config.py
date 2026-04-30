import os

# ================= 0. 核心安全配置 (必须显式声明) =================
# 读取我们在 .env 中配置的密钥，这在 Superset 4.0 中是启动的绝对前提
SECRET_KEY = os.environ.get("SUPERSET_SECRET_KEY", "fallback_secret_key_if_missing_12345")
SQLALCHEMY_DATABASE_URI = os.environ.get("SQLALCHEMY_DATABASE_URI")

# ================= 1. 角色与匿名访问 =================
# 用于允许未登录用户（如通过 Astro 网站访问）查看公开的看板
AUTH_ROLE_PUBLIC = "Public"
PUBLIC_ROLE_LIKE = "Gamma"

# ================= 2. 特性开关 (Feature Flags) =================
FEATURE_FLAGS = {
    "ALERT_REPORTS": True,
    "DATASET_FOLDERS": True,
    "DASHBOARD_RBAC": True,
    "ENABLE_JAVASCRIPT_CONTROLS": True,
    "EMBEDDED_SUPERSET": True,
}

# ================= 3. 第三方集成 =================
# 安全升级：不要在这里写死密钥，从系统环境变量中读取
MAPBOX_API_KEY = os.environ.get("MAPBOX_API_KEY", "")

# ================= 4. 安全与展示 =================
# 注意：关闭这些选项会降低安全性，但这对于嵌入式 JS 控件通常是必须的
HTML_SANITIZATION = False
TALISMAN_ENABLED = False

# ================= 5. 警报与 SQL Lab =================
ALERT_REPORTS_NOTIFICATION_DRY_RUN = True
SQLLAB_CTAS_NO_LIMIT = True