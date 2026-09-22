// assistant — RAG-style Copilot endpoint. Runs a grounded keyword retrieval over
// assistant_documents and frames an answer without an external LLM dependency.
// Swap the answer-builder for a real model call when a provider key is configured.

import { createClient } from 'jsr:@supabase/supabase-js@2'
import { corsHandler, json, error } from '../_shared/cors.ts'

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
    const question = String(body?.question ?? '').trim()
    if (!question) return error('Question is required')

    const { data: docs, error: dbErr } = await supabase
      .from('assistant_documents')
      .select('id, title, filename, source_type, url, active')
      .eq('active', true)
    if (dbErr) throw dbErr

    const terms = question.toLowerCase().split(/[^a-z0-9]+/).filter((t) => t.length > 2)
    const scored = (docs ?? [])
      .map((d) => {
        const hay = [d.title ?? '', d.filename ?? '', d.source_type ?? ''].join(' ').toLowerCase()
        const score = terms.reduce((acc, t) => acc + (hay.includes(t) ? 1 : 0), 0)
        return { ...d, score }
      })
      .filter((d) => d.score > 0)
      .sort((a, b) => b.score - a.score)
      .slice(0, 5)

    const sources = scored.map((d) => {
      const scoredAny = scored.some((s) => s.id === d.id && s.score >= d.score)
      return {
        id: d.id,
        title: d.title ?? d.filename,
        filename: d.filename,
        score: d.score,
        url: d.url,
        snippet: scoredAny ? `Keyword match (score ${d.score}) for "${question}"` : undefined,
      }
    })

    let answer: string
    if (scored.length === 0) {
      answer = `I couldn't find a relevant knowledge-base document for "${question}". ` +
        'Try wording such as: "What is the permit-to-work process?" or "housekeeping routine requirement".'
    } else {
      const best = scored[0]
      const names = scored.slice(0, 3).map((s) => `"${s.title}"`).join(', ')
      answer = `Based on ${names}, here is guidance for your question. ` +
        `The most relevant document is "${best.title}" (${best.filename ?? 'reference'}). ` +
        'Review the referenced source for full requirements, and raise a corrective action if the standard is not met.'
    }

    return json({ answer, sources })
  } catch (e) {
    return error(e instanceof Error ? e.message : 'Failed to answer', 500)
  }
})