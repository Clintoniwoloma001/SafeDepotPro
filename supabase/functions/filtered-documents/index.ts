// filtered-documents — minimal RAG retrieval: keyword search over assistant_documents.
// No external AI dependency; scores documents so callers can assemble a grounded answer.

import { createClient } from 'jsr:@supabase/supabase-js@2'
import { corsHandler, json, error, corsHeaders } from '../_shared/cors.ts'

Deno.serve(async (req) => {
  const cors = await corsHandler(req)
  if (cors) return cors

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } },
    )

    const { data: authUser, error: authErr } = await supabase.auth.getUser()
    if (authErr || !authUser.user) return error('Unauthorized', 401)

    const body = await req.json().catch(() => ({}))
    const query = String(body?.query ?? '').trim()
    if (!query) return json({ matches: [] })

    const { data: docs, error: dbErr } = await supabase
      .from('assistant_documents')
      .select('id, title, filename, source_type, url, active')
      .eq('active', true)
    if (dbErr) throw dbErr

    const terms = query.toLowerCase().split(/[^a-z0-9]+/).filter(Boolean)
    const matches = (docs ?? [])
      .map((d) => {
        const hay = [d.title, d.filename, d.source_type].join(' ').toLowerCase()
        const score = terms.reduce((acc, t) => acc + (hay.includes(t) ? 1 : 0), 0)
        return { ...d, score }
      })
      .filter((d) => d.score > 0)
      .sort((a, b) => b.score - a.score)
      .slice(0, 8)
      .map(({ id, title, filename, source_type, url, score }) => ({ id, title, filename, source_type, url, snippet: `Score ${score} — keyword match for "${query}"` }))

    return json({ matches })
  } catch (e) {
    return error(e instanceof Error ? e.message : 'Failed to search documents', 500)
  }
})

export const config = { ...corsHeaders }