import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  build: {
    // The TDD caps first load at 15 MB gzipped. Warn well before that so a
    // regression shows up in the build log rather than in a player's wait.
    chunkSizeWarningLimit: 1200,
    target: 'es2022',
  },
  test: {
    globals: true,
    environment: 'jsdom',
    include: ['tests/**/*.test.ts', 'tests/**/*.test.tsx'],
  },
});
