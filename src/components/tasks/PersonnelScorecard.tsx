import { useMemo } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { scorecardRating } from '@/lib/constants'
import { relativeTime } from '@/lib/utils'
import type { TaskHistory } from '@/types/entities'
import { RAG_THRESHOLDS } from '@/lib/constants'
import { cn } from '@/lib/utils'

export interface ScorecardRow {
  actorName: string
  completions: number
  uniqueTasks: number
  lastActive: string | null
}

const SCORE_NAMES = ['Needs Improvement', 'Fair', 'Good', 'Excellent']

/**
 * Per-user scorecard — completions, unique tasks, last active, RAG rating.
 * Score: completions + uniqueTasks (weighted 2x). Thresholds via scorecardRating.
 */
export function buildScorecard(history: TaskHistory[]): ScorecardRow[] {
  const byUser = new Map<string, ScorecardRow>()
  for (const h of history) {
    const key = h.actor_name ?? h.user_id ?? 'Unknown'
    const row = byUser.get(key)
    if (row) {
      row.completions += 1
      byUser.set(key, {
        ...row,
        lastActive: h.completed_at,
      })
    } else {
      byUser.set(key, { actorName: key, completions: 1, uniqueTasks: 0, lastActive: h.completed_at })
    }
  }
  // unique tasks
  const unique = new Map<string, Set<string>>()
  for (const h of history) {
    const key = h.actor_name ?? h.user_id ?? 'Unknown'
    if (!unique.has(key)) unique.set(key, new Set())
    unique.get(key)!.add(h.task_id)
  }
  for (const [key, tasks] of unique) {
    const row = byUser.get(key)!
    byUser.set(key, { ...row, uniqueTasks: tasks.size })
  }
  return Array.from(byUser.values()).sort((a, b) => b.completions - a.completions)
}

export function PersonnelScorecard({ history, maxRows = 12 }: { history: TaskHistory[]; maxRows?: number }) {
  const rows = useMemo(() => buildScorecard(history).slice(0, maxRows), [history, maxRows])

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Personnel scorecard</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        {rows.length === 0 && <p className="text-sm text-muted-foreground">No completions recorded yet.</p>}
        {rows.map((row) => {
          const total = row.completions + row.uniqueTasks * 2
          const rating = scorecardRating(total)
          const ratio = Math.min(1, total / 25)
          return (
            <div key={row.actorName} className="rounded-md border p-2">
              <div className="flex items-center justify-between text-sm">
                <span className="font-medium">{row.actorName}</span>
                <span className={cn('text-xs font-semibold', rating.color)}>{rating.label}</span>
              </div>
              <div className="mt-1 text-xs text-muted-foreground">
                {row.completions} completions · {row.uniqueTasks} unique tasks · {row.lastActive ? `last active ${relativeTime(row.lastActive)}` : 'never active'}
              </div>
              <div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-muted">
                <div
                  className={cn(
                    'h-full rounded-full',
                    total >= 20 ? 'bg-rag-good' : total >= 10 ? 'bg-blue-500' : total >= 5 ? 'bg-rag-warn' : 'bg-rag-bad',
                  )}
                  style={{ width: `${ratio * 100}%` }}
                />
              </div>
            </div>
          )
        })}
      </CardContent>
    </Card>
  )
}

export { RAG_THRESHOLDS, SCORE_NAMES }