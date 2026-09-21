import { supabase } from '@/lib/supabaseClient'
import type { RoutineTask, TaskHistory } from '@/types/entities'

export async function listRoutineTasks(options: { includeInactive?: boolean } = {}) {
  let q = supabase.from('routine_tasks').select('*').order('sequence_order', { ascending: true })
  if (!options.includeInactive) q = q.eq('is_active', true)
  const { data, error } = await q
  if (error) throw error
  return data as RoutineTask[]
}

export async function getRoutineTask(id: string) {
  const { data, error } = await supabase.from('routine_tasks').select('*').eq('id', id).single()
  if (error) throw error
  return data as RoutineTask
}

export async function createRoutineTask(input: Partial<RoutineTask>) {
  const { data, error } = await supabase
    .from('routine_tasks')
    .insert({
      title: input.title,
      description: input.description,
      task_type: input.task_type ?? 'MANUAL',
      category: input.category,
      all_depots: input.all_depots ?? false,
      assigned_depot_ids: input.all_depots ? [] : input.assigned_depot_ids ?? [],
      assigned_user_ids: input.all_depots ? [] : input.assigned_user_ids ?? [],
      frequency: input.frequency ?? 'DAILY',
      monthly_dates: input.monthly_dates ?? [1],
      start_date: input.start_date,
      end_date: input.end_date,
      expected_occurrences: input.expected_occurrences,
      linked_module: input.linked_module,
      ai_prompt: input.ai_prompt,
      sequence_order: input.sequence_order ?? 0,
    })
    .select()
    .single()
  if (error) throw error
  return data as RoutineTask
}

export async function updateRoutineTask(id: string, input: Partial<RoutineTask>) {
  const { data, error } = await supabase
    .from('routine_tasks')
    .update({
      title: input.title,
      description: input.description,
      task_type: input.task_type,
      category: input.category,
      all_depots: input.all_depots,
      assigned_depot_ids: input.all_depots ? [] : input.assigned_depot_ids,
      assigned_user_ids: input.all_depots ? [] : input.assigned_user_ids,
      frequency: input.frequency,
      monthly_dates: input.monthly_dates,
      start_date: input.start_date,
      end_date: input.end_date,
      expected_occurrences: input.expected_occurrences,
      linked_module: input.linked_module,
      ai_prompt: input.ai_prompt,
      is_active: input.is_active,
      sequence_order: input.sequence_order,
    })
    .eq('id', id)
    .select()
    .single()
  if (error) throw error
  return data as RoutineTask
}

export async function deleteRoutineTask(id: string) {
  const { error } = await supabase.from('routine_tasks').delete().eq('id', id)
  if (error) throw error
}

export async function listTaskHistory(options: {
  taskId?: string
  depotId?: string
  userId?: string
  from?: string
  to?: string
} = {}) {
  let q = supabase.from('task_history').select('*').order('completed_at', { ascending: false })
  if (options.taskId) q = q.eq('task_id', options.taskId)
  if (options.depotId) q = q.eq('depot_id', options.depotId)
  if (options.userId) q = q.eq('user_id', options.userId)
  if (options.from) q = q.gte('completed_at', options.from)
  if (options.to) q = q.lte('completed_at', options.to)
  const { data, error } = await q
  if (error) throw error
  return data as TaskHistory[]
}

export async function recordTaskCompletion(input: Partial<TaskHistory>) {
  const { data, error } = await supabase
    .from('task_history')
    .insert({
      task_id: input.task_id!,
      user_id: input.user_id,
      actor_name: input.actor_name,
      depot_id: input.depot_id,
      completed_at: input.completed_at ?? new Date().toISOString(),
      occurrences: input.occurrences ?? 1,
      expected_occurrences: input.expected_occurrences,
      comment: input.comment,
      photo_paths: input.photo_paths ?? [],
      signature_path: input.signature_path,
      latitude: input.latitude,
      longitude: input.longitude,
      ai_verified: input.ai_verified ?? false,
      form_answers: input.form_answers ?? null,
      attendance_count: input.attendance_count,
    })
    .select()
    .single()
  if (error) throw error
  return data as TaskHistory
}

export async function deleteTaskHistory(id: string) {
  const { error } = await supabase.from('task_history').delete().eq('id', id)
  if (error) throw error
}