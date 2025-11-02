import { defineConfig } from 'vite';
import { resolve } from 'path';

export default defineConfig({
  build: {
    lib: {
      entry: resolve(__dirname, 'ts_src/automation_engine.ts'),
      name: 'AutomationEngine',
      formats: ['iife'], // Format idéal pour l'injection
      fileName: () => 'bridge.js',
    },
    outDir: 'assets/js', // Exporter directement dans les assets Flutter
    emptyOutDir: false,
  },
});