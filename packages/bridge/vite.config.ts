import { defineConfig } from 'vite';
import { resolve } from 'path';

export default defineConfig({
  build: {
    lib: {
      entry: resolve(__dirname, 'automation_engine.ts'),
      name: 'AutomationEngine',
      formats: ['iife'],
      fileName: () => 'bridge.js',
    },
    outDir: resolve(__dirname, '../../assets/js'),
    emptyOutDir: false,
  },
});