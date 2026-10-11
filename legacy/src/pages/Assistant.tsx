import { useEffect, useRef, useState } from 'react'
import { Bot, Send, Sparkles } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { PageHeader } from '@/components/shared'
import { supabase } from '@/lib/supabaseClient'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { cn } from '@/lib/utils'
import type { AssistDoc } from '@/types/assistant'

interface Message {
  id: string
  role: 'user' | 'assistant'
  content: string
  sources?: AssistDoc[]
}

const SUGGESTIONS = [
  'How is our RAG compliance tracking?',
  'Summarise outstanding CAPAs in my depot',
  'What man-hours were reported this month?',
  'Walk me through raising a hot work permit',
]

export default function Assistant() {
  const user = useCurrentUser()
  const [messages, setMessages] = useState<Message[]>([])
  const [input, setInput] = useState('')
  const [busy, setBusy] = useState(false)
  const [mode, setMode] = useState<'rag' | 'fallback'>('rag')
  const endRef = useRef<HTMLDivElement | null>(null)

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  const askRag = async (q: string) => {
    const { data, error } = await supabase.functions.invoke('assistant', { body: { question: q } })
    if (error) throw error
    const answer = data?.answer ?? data?.completion ?? 'No answer returned.'
    return { answer, sources: data?.sources as AssistDoc[] | undefined }
  }

  const askFallback = async (q: string) => {
    const { data, error } = await supabase.functions.invoke('filtered-documents', { body: { query: q } })
    if (error) throw error
    const text = joinDocs(data?.matches ?? [])
    return { answer: text || fallbackAnswer(q), sources: [] as AssistDoc[] }
  }

  const send = async (raw?: string) => {
    const q = (raw ?? input).trim()
    if (!q || busy) return
    setInput('')
    const id = crypto.randomUUID()
    setMessages((prev) => [...prev, { id, role: 'user', content: q }])
    setBusy(true)
    try {
      let result: { answer: string; sources?: AssistDoc[] }
      try {
        result = await askRag(q)
        setMode('rag')
      } catch {
        result = await askFallback(q)
        setMode('fallback')
      }
      setMessages((prev) => [...prev, { id: crypto.randomUUID(), role: 'assistant', content: result.answer, sources: result.sources ?? [] }])
    } catch (e) {
      setMessages((prev) => [
        ...prev,
        {
          id: crypto.randomUUID(),
          role: 'assistant',
          content: `Sorry, I couldn't reach the knowledge base right now. ${e instanceof Error ? e.message : 'Try again shortly.'}`,
        },
      ])
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="flex h-[calc(100vh-11rem)] flex-col space-y-4">
      <PageHeader
        title="AI Copilot"
        subtitle="Ask questions across your HSE knowledge base and records"
        actions={
          <span className={cn('rounded-full px-2 py-0.5 text-xs font-medium', mode === 'rag' ? 'bg-green-50 text-green-700' : 'bg-amber-50 text-amber-700')}>
            {mode === 'rag' ? 'RAG indexed' : 'Keyword fallback'}
          </span>
        }
      />

      <div className="flex-1 space-y-4 overflow-y-auto rounded-xl border bg-muted/20 p-4">
        {messages.length === 0 && (
          <div className="flex h-full flex-col items-center justify-center gap-3 text-center">
            <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-brand text-white">
              <Bot className="h-6 w-6" />
            </div>
            <p className="max-w-sm text-sm text-muted-foreground">
              Your RAG copilot answers from indexed safety documents, permits and records. Start with one of these:
            </p>
            <div className="flex flex-wrap justify-center gap-2">
              {SUGGESTIONS.map((s) => (
                <button key={s} onClick={() => void send(s)} className="rounded-full border bg-white px-3 py-1.5 text-xs text-muted-foreground transition-colors hover:border-brand hover:text-brand">
                  {s}
                </button>
              ))}
            </div>
          </div>
        )}
        {messages.map((m) => (
          <div key={m.id} className={cn('flex gap-3', m.role === 'user' && 'justify-end')}>
            {m.role === 'assistant' && (
              <div className="mt-1 flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-brand/10 text-brand">
                <Bot className="h-4 w-4" />
              </div>
            )}
            <div className={cn('max-w-[85%] space-y-2', m.role === 'user' ? 'order-first' : '')}>
              <div className={cn('rounded-2xl px-4 py-3 text-sm', m.role === 'assistant' ? 'border bg-white' : 'bg-brand text-white')}>
                <div className="whitespace-pre-wrap leading-relaxed">{m.content}</div>
              </div>
              {m.role === 'assistant' && m.sources && m.sources.length > 0 && (
                <div className="space-y-1">
                  {m.sources.map((s, i) => (
                    <div key={i} className="flex items-start gap-2 rounded-xl border bg-white px-3 py-2 text-xs">
                      <Sparkles className="mt-0.5 h-3.5 w-3.5 shrink-0 text-brand" />
                      <div>
                        <div className="font-medium">{s.title ?? s.filename}</div>
                        <div className="text-muted-foreground">{s.snippet}</div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        ))}
        {busy && (
          <div className="flex gap-3">
            <div className="mt-1 flex h-8 w-8 items-center justify-center rounded-lg bg-brand/10 text-brand">
              <Bot className="h-4 w-4" />
            </div>
            <div className="rounded-2xl border bg-white px-4 py-3 text-sm text-muted-foreground">
              <span className="inline-flex gap-1">
                <span className="h-1.5 w-1.5 animate-bounce rounded-full bg-brand" />
                <span className="h-1.5 w-1.5 animate-bounce rounded-full bg-brand [animation-delay:120ms]" />
                <span className="h-1.5 w-1.5 animate-bounce rounded-full bg-brand [animation-delay:240ms]" />
              </span>
              Thinking…
            </div>
          </div>
        )}
        <div ref={endRef} />
      </div>

      <form
        onSubmit={(e) => {
          e.preventDefault()
          void send()
        }}
        className="flex gap-2"
      >
        <Input value={input} onChange={(e) => setInput(e.target.value)} placeholder="Ask about compliance, records, permits, CAPAs…" disabled={busy} className="bg-white" />
        <Button type="submit" disabled={busy || !input.trim()}>
          <Send className="mr-1 h-4 w-4" /> Send
        </Button>
      </form>
      <p className="text-xs text-muted-foreground">
        Answered by {user.roleLabel} within {user.effectiveDepotId || 'your organisation'}.
        Verify critical answers against the source documents.
      </p>
    </div>
  )
}

function joinDocs(matches: unknown[]): string {
  const parts = matches.map((m) => {
    const doc = m as { title?: string; filename?: string; content?: string; snippet?: string }
    return `${doc.title ?? doc.filename ?? 'Document'}: ${doc.snippet ?? doc.content ?? ''}`
  })
  return parts.length ? parts.join('\n\n') : ''
}

function fallbackAnswer(q: string): string {
  const lower = q.toLowerCase()
  const topic = lower.includes('permit')
    ? 'permits'
    : lower.includes('capa')
      ? 'corrective actions'
      : lower.includes('incident')
        ? 'incidents'
        : lower.includes('hazard')
          ? 'hazards'
          : lower.includes('man-hour') || lower.includes('man hour')
            ? 'man-hours'
            : 'HSE'
  return `I couldn't find an indexed match for “${q}” in the knowledge base. Ask an HSE lead, or check the live ${topic} register in the relevant section.`
}