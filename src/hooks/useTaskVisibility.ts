import { useMemo } from 'react'
import { startOfDayISO, todayIso } from '@/lib/utils'
import type { RoutineTask, TaskHistory } from '@/types/entities'
import type { CurrentUser } from './useCurrentUser'
import { addMonths, isSameDay } from 'date-fns'

export interface DueContext {
  truckInspectionsToday: number
  permitsActiveToday: number
  equipmentCount: number
  personnelCount: number
}

// ---------------------------------------------------------------------------
// Visibility — identical logic shared between Dashboard, Tasks lists and analytics.
// OR semantics, never AND.
// ---------------------------------------------------------------------------

export function taskIsVisibleToUser(task: RoutineTask, user: Pick<CurrentUser, 'userId' | 'effectiveDepotId'>): boolean {
  if (task.all_depots) return true
  const noAssignmentData =
    (!task.assigned_depot_ids || task.assigned_depot_ids.length === 0) &&
    (!task.assigned_user_ids || task.assigned_user_ids.length === 0)
  // Defensive fallback: tasks with zero assignment data must never be silently hidden.
  if (noAssignmentData) return true
  if (user.effectiveDepotId && task.assigned_depot_ids.includes(user.effectiveDepotId)) return true
  if (user.userId && task.assigned_user_ids.includes(user.userId)) return true
  return false
}

// ---------------------------------------------------------------------------
// Recurrence — "due today" is computed from the rule, not a static count.
// ---------------------------------------------------------------------------

export function taskDueOn(task: RoutineTask, date: string): boolean {
  const target = new Date(`${date}T00:00:00`)
  if (isNaN(target.getTime())) return false
  if (task.start_date && date < task.start_date) return false
  if (task.end_date && date > task.end_date) return false

  const start = task.start_date ? new Date(`${task.start_date}T00:00:00`) : target
  const dow = target.getDay() // 0=Sun

  switch (task.frequency) {
    case 'DAILY':
      return true
    case 'WEEKLY':
      // weekdays only
      return dow >= 1 && dow <= 5
    case 'MONTHLY': {
      const dates = task.monthly_dates && task.monthly_dates.length > 0 ? task.monthly_dates : [1]
      return dates.some((d) => d === target.getDate())
    }
    case 'QUARTERLY': {
      const diff = monthsBetween(start, target)
      return diff >= 0 && diff % 3 === 0 && isSameDay(start, addMonths(target, 0))
    }
    case 'BIANNUAL': {
      const diff = monthsBetween(start, target)
      return diff >= 0 && diff % 6 === 0
    }
    case 'ANNUAL': {
      const diff = monthsBetween(start, target)
      return diff >= 0 && diff % 12 === 0
    }
    default:
      return false
  }
}

function monthsBetween(a: Date, b: Date): number {
  return (b.getFullYear() - a.getFullYear()) * 12 + (b.getMonth() - a.getMonth())
}

export function isTaskDueToday(task: RoutineTask): boolean {
  return taskDueOn(task, todayIso())
}

// ---------------------------------------------------------------------------
// Expected occurrences by completion method.
// ---------------------------------------------------------------------------

export function expectedOccurrencesFor(task: RoutineTask, context: DueContext): number {
  switch (task.task_type) {
    case 'VEHICLE':
      return Math.max(1, context.truckInspectionsToday)
    case 'PERMIT':
      return Math.max(1, context.permitsActiveToday)
    case 'EQUIPMENT':
      return Math.max(1, context.equipmentCount)
    case 'PERSONNEL':
      return Math.max(1, context.personnelCount)
    case 'COUNT':
      return Math.max(1, task.expected_occurrences ?? 1)
    default:
      return 1
  }
}

const today = (): string => todayIso()

export function completionsToday(taskId: string, history: TaskHistory[]): TaskHistory[] {
  const t = today()
  return history.filter((h) => h.task_id === taskId && h.completed_at.slice(0, 10) === t)
}

// ---------------------------------------------------------------------------
// Prerequisite gating — Toolbox tasks require a same-day toolbox talk;
// Housekeeping tasks require a same-day housekeeping inspection.
// ---------------------------------------------------------------------------

export function prerequisiteBlockedFor(
  task: RoutineTask,
  date: string,
  deps: { toolboxTalksMatch: (date: string) => boolean; housekeepingInspectionMatch: (date: string) => boolean },
): string | null {
  if (task.linked_module === 'TOOLBOX' && !deps.toolboxTalksMatch(date)) {
    return `This toolbox task is blocked: no Toolbox Talk record exists for ${date}. Record the toolbox talk first.`
  }
  if (task.linked_module === 'HOUSEKEEPING' && !deps.housekeepingInspectionMatch(date)) {
    return `This housekeeping task is blocked: no Housekeeping Inspection record exists for ${date}. Complete the inspection first.`
  }
  return null
}

/**
 * Alias kept for page/component ergonomics.
 */
export type TaskContext = DueContext

// ---------------------------------------------------------------------------
// Hook — per-task status for today's view.
// ---------------------------------------------------------------------------

export interface TaskStatusView {
  task: RoutineTask
  visible: boolean
  dueToday: boolean
  completedToday: boolean
  occurrencesReported: number
  occurrencesExpected: number
  blockedReason: string | null
  nextOccurrenceDate: string | null
}

export function useTaskVisibility(
  tasks: RoutineTask[],
  history: TaskHistory[],
  user: Pick<CurrentUser, 'userId' | 'effectiveDepotId'>,
  context: DueContext,
  prerequisiteDeps: { toolboxTalksMatch: (date: string) => boolean; housekeepingInspectionMatch: (date: string) => boolean },
): TaskStatusView[] {
  return useMemo(
    () =>
      tasks.map((task) => {
        const visible = taskIsVisibleToUser(task, user)
        const dueToday = visible && taskDueOn(task, todayIso())
        const done = completionsToday(task.id, history)
        const occurrencesReported = done.reduce((sum, h) => sum + h.occurrences, 0)
        const occurrencesExpected = dueToday ? expectedOccurrencesFor(task, context) : 0
        const blockedReason = dueToday && !done.length ? prerequisiteBlockedFor(task, todayIso(), prerequisiteDeps) : null
        return {
          task,
          visible,
          dueToday,
          completedToday: occurrencesReported >= Math.max(1, occurrencesExpected),
          occurrencesReported,
          occurrencesExpected,
          blockedReason,
          nextOccurrenceDate: nextOccurrence(task),
        }
      }),
    [tasks, history, user, context, prerequisiteDeps],
  )
}

export function nextOccurrence(task: RoutineTask): string | null {
  let cursor = new Date(startOfDayISO())
  cursor.setDate(cursor.getDate() + 1)
  if (task.end_date && startOfDayISO() > task.end_date) return null
  for (let i = 0; i < 366; i++) {
    const iso = startOfDayISO(cursor)
    if (taskDueOn(task, iso)) return iso
    cursor.setDate(cursor.getDate() + 1)
  }
  return null
}