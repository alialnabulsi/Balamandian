import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  workers: 2,
  reporter: 'list',
  use: {
    baseURL: 'http://127.0.0.1:5176',
    channel: 'msedge',
    reducedMotion: 'reduce',
    screenshot: 'only-on-failure',
  },
  webServer: {
    command: 'npm run dev',
    url: 'http://127.0.0.1:5176',
    reuseExistingServer: !process.env.CI,
  },
  projects: [
    { name: 'mobile-light', use: { viewport: { width: 412, height: 915 } } },
    { name: 'mobile-dark', use: { viewport: { width: 412, height: 915 } } },
    { name: 'narrow', use: { viewport: { width: 360, height: 800 } } },
    { name: 'desktop', use: { viewport: { width: 1280, height: 900 } } },
  ],
});
