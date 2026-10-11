/// <reference types="vite/client" />

/** Injected at build time via vite.config.ts `define` (git HEAD at build). */
declare const __BUILD_HASH__: string

interface ImportMetaEnv {
  readonly VITE_SUPABASE_URL?: string
  readonly VITE_SUPABASE_ANON_KEY?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}