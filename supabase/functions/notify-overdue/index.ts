// notify-overdue — scheduled (pg_cron / cron.schedule) check for overdue routine tasks
// and due-permit renewals. Composes a digest when org reminders are enabled and logs
// each trigger to the audit log so the source-download endpoint can trace automation.

import { createClient } from 'jsr:@supabase/supabase-js@2'
import { corsHandler, json, error } from '../_shared/cors.ts'

Deno.serve(async (req) => {
  const cors = await corsHandler(req)
  if (cors) return cors

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { persistSession: false } },
    )

    const { data: settings } = await supabase
      .from('app_settings')
      .select('enable_ai_reminders, ai_reminder_window_days, reminder_frequency, reminder_time, reminder_message')
      .limit(1)
      .single()

    if (!settings?.enable_ai_reminders) {
      return json({ checked: false, reason: 'reminders disabled' })
    }

    const windowDays = settings.ai_reminder_window_days ?? 7
    const horizon = new Date(Date.now() + windowDays * 86400_000).toISOString()

    const { data: tasks } = await supabase
      .from('routine_tasks')
      .select('id, title, frequency, start_date, end_date, assigned_depot_ids, assigned_user_ids, is_active')
      .eq('is_active', true)
    if (!tasks) throw new Error('Failed to load routine tasks')

    const { data: history } = await supabase
      .from('task_history')
      .select('task_id, completed_at, depot_id')
    const counts = new Map<string, number>()
    for (const h of history ?? []) {
      const key = h.depot_id ? `${h.task_id}:${h.depot_id}` : h.task_id
      counts.set(key, (counts.get(key) ?? 0) + 1)
    }

    const overdue: string[] = []
    for (const t of tasks) {
      if (t.end_date && new Date(t.end_date).getTime() < Date.now()) continue
      const depotKeys = (t.assigned_depot_ids ?? []).map((d) => `${t.id}:${d}`)
      const doneCount = Math.max(0, ...depotKeys.map((k) => counts.get(k) ?? 0), counts.get(t.id) ?? 0)
      const due = nextDue(t.frequency, t.start_date, doneCount)
      if (due && new Date(due) < new Date(horizon)) {
        overdue.push(`${t.title} — due target ${due}`)
      }
    }

    const digest = overdue.join('\n')
    if (digest) {
      await supabase.from('audit_log').insert({
        actor_name: 'system',
        action: 'notify-overdue',
        target: 'routine_tasks',
        meta: { message: settings.reminder_message ?? 'Overdue tasks pending', body: digest, count: overdue.length },
      })
    }

    return json({ checked: true, horizon, overdueCount: overdue.length, overdue })
  } catch (e) {
    return error(e instanceof Error ? e.message : 'Overdue check failed', 500)
  }
})

function nextDue(frequency: string, start: string, completed: number): string | null {
  const startDate = new Date(start)
  const { add } = {
    DAILY: () => startDate.setDate(startDate.getDate() + 1 * completed),
    WEEKLY: () => startDate.setDate(startDate.getDate() + 7 * completed),
    MONTHLY: () => startDate.setMonth(startDate.getMonth() + completed),
    QUARTERLY: () => startDate.setMonth(startDate.getMonth() + 3 * completed),
    BIANNUAL: () => startDate.setMonth(startDate.getMonth() + 6 * completed),
    ANNUAL: () => startDate.setFullYear(startDate.getFullYear() + completed),
  }
  add[frequency as keyof typeof add]?.()
  return startDate.toISOString()
}