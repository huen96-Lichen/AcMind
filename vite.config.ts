import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import electron from 'vite-plugin-electron'
import renderer from 'vite-plugin-electron-renderer'
import path from 'path'

export default defineConfig({
  root: 'src/renderer',
  plugins: [
    react(),
    electron([
      {
        entry: path.resolve(__dirname, 'src/main/index.ts'),
        onstart(args) {
          args.startup()
        },
        vite: {
          build: {
            outDir: path.resolve(__dirname, 'dist-electron/main'),
            rollupOptions: {
              external: ['better-sqlite3', 'electron-log']
            }
          }
        }
      },
      {
        entry: path.resolve(__dirname, 'src/preload/index.ts'),
        onstart(args) {
          args.reload()
        },
        vite: {
          build: {
            outDir: path.resolve(__dirname, 'dist-electron/preload')
          }
        }
      }
    ]),
    renderer()
  ],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'src'),
      '@shared': path.resolve(__dirname, 'src/shared')
    }
  },
  build: {
    outDir: path.resolve(__dirname, 'dist'),
    emptyOutDir: true
  }
})
