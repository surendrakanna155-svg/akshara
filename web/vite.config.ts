/// <reference types="vitest" />
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'node:path';

// Akshara Unified Web Platform — Vite config.
// Path alias `@/` → src, matching the Flutter package-style imports.
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: {
    port: 5173,
    host: true,
  },
  // Same-origin dev/preview proxy to the live backend. Build with
  // VITE_API_BASE_URL=/api-proxy so the browser talks to this origin (no CORS);
  // vite forwards server-side. Target overridable via API_PROXY_TARGET.
  preview: {
    proxy: {
      '/api-proxy': {
        target: process.env.API_PROXY_TARGET || 'https://akshara.veloraunisexsalon.com',
        changeOrigin: true,
        secure: true,
        rewrite: (p) => p.replace(/^\/api-proxy/, '/functions/v1/api'),
      },
    },
  },
  build: {
    chunkSizeWarningLimit: 900,
    rollupOptions: {
      output: {
        manualChunks: {
          // Eagerly-used vendors → stable cached chunks. recharts is intentionally
          // NOT listed: it's dynamically imported (lazy charts) so it stays in its
          // own async chunk, out of the initial critical path.
          react: ['react', 'react-dom', 'react-router-dom'],
          motion: ['framer-motion'],
          query: ['@tanstack/react-query'],
        },
      },
    },
  },
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    css: false,
  },
});
