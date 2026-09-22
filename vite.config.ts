import { execSync } from 'node:child_process'
import { fileURLToPath, URL } from 'node:url'

import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'
import { VitePWA } from 'vite-plugin-pwa'

const gitCommitHash = (() => {
  try {
    return execSync('git rev-parse HEAD').toString().trim()
  } catch {
    return 'unknown'
  }
})()

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['favicon.svg', 'logo.svg', 'logo.png', 'logos.png', 'apple-touch-icon.png'],
      manifest: {
        name: 'SafeDepot Pro',
        short_name: 'SafeDepot',
        description: 'HSE Management — Depot & Warehouse Operations',
        theme_color: '#cc0000',
        background_color: '#1a1a1a',
        display: 'standalone',
        start_url: '/',
        icons: [
          { src: 'icon-192.png', sizes: '192x192', type: 'image/png' },
          { src: 'icon-512.png', sizes: '512x512', type: 'image/png' },
          { src: 'icon-512-maskable.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
        ],
      },
      workbox: {
        runtimeCaching: [
          {
            urlPattern: ({ url }) => url.pathname.startsWith('/rest/') || url.pathname.startsWith('/auth/') || url.pathname.startsWith('/storage/v1/'),
            handler: 'NetworkOnly',
          },
        ],
      },
    }),
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  define: {
    // Tied to a verifiable git commit; fingerprint also appears in the bundle banner.
    __BUILD_HASH__: JSON.stringify(gitCommitHash),
  },
  build: {
    rollupOptions: {
      output: {
        banner: `/*! SafeDepot Pro — © ${new Date().getFullYear()} Clinton Iwoloma, Flatra Tech Ltd. All rights reserved. Build: ${gitCommitHash} */`,
      },
    },
  },
})