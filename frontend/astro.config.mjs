// @ts-check
import { defineConfig } from 'astro/config';

// https://astro.build/config
export default defineConfig({
  server: {
    host: true,
    port: 4321,
  },
  vite: {
    server: {
      headers: {
        "Content-Security-Policy":
          "default-src * 'unsafe-inline' 'unsafe-eval' data: blob:; frame-src 'self' http://localhost:8088 http://127.0.0.1:8088;",
      },
    },
  },
});
