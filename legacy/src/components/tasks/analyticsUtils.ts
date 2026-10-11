import type { TaskHistory } from '@/types/entities'

/** Simple named aggregation. */
export function push(items: { name: string; value: number }[]) {
  return items
}

export function pushBy(history: TaskHistory[], keyFn: (h: TaskHistory) => string | null): { name: string; value: number }[] {
  const map = new Map<string, number>()
  for (const h of history) {
    const key = keyFn(h)
    if (!key) continue
    map.set(key, (map.get(key) ?? 0) + h.occurrences)
  }
  return Array.from(map.entries())
    .map(([name, value]) => ({ name, value }))
    .sort((a, b) => b.value - a.value)
}

export function pushByDepot(history: TaskHistory[]): { name: string; value: number }[] {
  return pushBy(history, (h) => (h.depot_id ? `Depot ${h.depot_id.slice(0, 8)}` : null))
}

export function pushByUser(history: TaskHistory[]): { name: string; value: number }[] {
  return pushBy(history, (h) => h.actor_name ?? h.user_id)
}

export function pushByTask(history: TaskHistory[]): { name: string; value: number }[] {
  return pushBy(history, (h) => h.task_id)
}