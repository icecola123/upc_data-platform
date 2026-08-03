const DEFAULT_SUPERSET_DASHBOARD_URL =
  "http://superset:8088/superset/dashboard/upc-v0623/?standalone=true";

export const prerender = false;

export const GET = async () => {
  const dashboardUrl =
    import.meta.env.SUPERSET_DASHBOARD_URL ?? DEFAULT_SUPERSET_DASHBOARD_URL;

  try {
    const response = await fetch(dashboardUrl, {
      headers: {
        Accept: "text/html",
      },
    });

    if (!response.ok) {
      return new Response(`Erreur Superset: ${response.status}`, {
        status: 502,
      });
    }

    const html = await response.text();

    return new Response(html, {
      headers: {
        "Content-Type": "text/html; charset=utf-8",
      },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(message, { status: 500 });
  }
};
