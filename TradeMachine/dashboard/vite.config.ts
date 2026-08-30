import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { fileURLToPath, URL } from 'node:url';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  server: {
    port: 5173,
    // Bind to loopback only. The WebBridge has no authentication, so the
    // dashboard should not be reachable from the local network either.
    host: '127.0.0.1',
    strictPort: true,
  },
  build: {
    // Emitted as a plain static bundle so Flask (or any static host) can serve
    // it directly. No Node runtime required in production.
    outDir: 'dist',
    sourcemap: true,
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom', 'react-router-dom'],
          charts: ['lightweight-charts', 'recharts'],
        },
      },
    },
  },
});
