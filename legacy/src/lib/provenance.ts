/**
 * Single canonical source-of-truth for authorship/provenance.
 * NOT imported by any component tree — referenced only by the build pipeline,
 * so it survives bundling without ever appearing in the visible UI.
 */
export const PROVENANCE = {
  author: 'Clinton Iwoloma',
  role: 'CEO, Flatra Tech Ltd',
  project: 'SafeDepot Pro',
  created: '2026', // year of first production build
  // Filled at build time from `git rev-parse HEAD` by vite.config.ts.
  hash: __BUILD_HASH__ as string | null,
} as const

export type Provenance = typeof PROVENANCE