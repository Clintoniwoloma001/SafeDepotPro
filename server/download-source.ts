/**
 * download-source — local dev server guarding /download-source with a SUPERADMIN check.
 * Zips the project source (excluding node_modules, dist, .git, env files) via archiver.
 *
 * Run: npm run server
 * The Vite dev server proxies /download-source here (see vite.config server.proxy).
 */
import { execSync } from 'node:child_process'
import { existsSync, readdirSync, createReadStream } from 'node:fs'
import path from 'node:path'
import * as archiverNs from 'archiver'
import type { Archiver } from 'archiver'
import express from 'express'
import { createClient } from '@supabase/supabase-js'

const PORT = Number(process.env.PORT ?? 8787)
const ROOT = path.resolve(import.meta.dirname, '..')
try {
  process.loadEnvFile(path.join(ROOT, '.env'))
} catch {
  // no .env present — dev server relies on ambient variables
}
const SUPABASE_URL = process.env.VITE_SUPABASE_URL ?? ''
const ANON_KEY = process.env.VITE_SUPABASE_ANON_KEY ?? ''

const app = express()
app.use(express.json())

const paranoiaRoutes = ['node_modules', 'dist', '.git', '.env', '.env.local', 'supabase/.temp']
const includedDirs = (dir: string): string[] =>
  readdirSync(dir, { withFileTypes: true })
    .filter((e) => e.isDirectory())
    .map((e) => e.name)
    .filter((n) => !n.startsWith('.') && n !== 'node_modules' && n !== 'dist')

async function isSuperadmin(req: express.Request): Promise<{ ok: boolean; name?: string; reason?: string }> {
  const auth = req.headers.authorization ?? ''
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : extractCookie(req.headers.cookie, '_sb_access_token')
  if (!token) return { ok: false, reason: 'Missing session. Sign in as SUPERADMIN and retry.' }
  if (!SUPABASE_URL || !ANON_KEY) return { ok: false, reason: 'Server env VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY missing.' }

  const supabase = createClient(SUPABASE_URL, ANON_KEY)
  const { data, error } = await supabase.auth.getUser(token)
  if (error || !data.user) return { ok: false, reason: 'Session invalid or expired.' }

  const { data: profile } = await supabase
    .from('profiles')
    .select('role, full_name, is_active')
    .eq('id', data.user.id)
    .maybeSingle()
  if (profile?.role !== 'SUPERADMIN' || profile.is_active === false) {
    return { ok: false, reason: 'SUPERADMIN role required.' }
  }
  return { ok: true, name: profile.full_name ?? data.user.email ?? '' }
}

function extractCookie(header: string | undefined, name: string): string | undefined {
  return header?.split(';').map((c) => c.trim()).find((c) => c.startsWith(`${name}=`))?.split('=').slice(1).join('=').replace(/^\s*|\s*$/g, '')
}

app.get('/health', (_req, res) => res.json({ ok: true }))

function makeZip(): Archiver {
  const create = (archiverNs as unknown as { default: (format: string, opts?: object) => Archiver }).default
  return create('zip', { zlib: { level: 9 } })
}

app.get('/download-source', async (req, res) => {
  const guard = await isSuperadmin(req)
  if (!guard.ok) {
    res.status(401).json({ error: guard.reason ?? 'Unauthorized' })
    return
  }

  const commit = (() => {
    try {
      return execSync('git rev-parse HEAD').toString().trim()
    } catch {
      return 'HEAD'
    }
  })()

  const zip = makeZip()
  res.setHeader('Content-Type', 'application/zip')
  res.setHeader('Content-Disposition', `attachment; filename="safedepotpro-source-${commit}.zip"`)

  zip.on('warning', (err: Error) => console.warn(err.message))
  zip.on('error', (err: unknown) => {
    console.error(err)
    if (!res.headersSent) res.status(500).json({ error: 'Failed to build archive.' })
    else res.end()
  })

  zip.pipe(res)
  for (const dir of includedDirs(ROOT)) {
    if (paranoiaRoutes.includes(dir)) continue
    zip.glob('**/*', { cwd: path.join(ROOT, dir), ignore: paranoiaRoutes.map((p) => `${dir.replace(/\/+$/, '')}/${p}`) }, { prefix: dir })
  }
  for (const f of ['package.json', 'package-lock.json', 'tsconfig.json', '.gitignore', 'README.md', 'LICENSE']) {
    if (existsSync(path.join(ROOT, f))) zip.append(createReadStream(path.join(ROOT, f)), { name: f })
  }
  await zip.finalize()
})

app.listen(PORT, () => {
  console.log(`[download-source] serving on http://localhost:${PORT} (source guard: SUPERADMIN)`)
})