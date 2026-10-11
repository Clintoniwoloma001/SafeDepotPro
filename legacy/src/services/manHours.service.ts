import { supabase } from '@/lib/supabaseClient'
import type { ManHourRecord } from '@/types/entities'

export async function listManHours(options: { depotId?: string; from?: string; to?: string } = {}) {
  let q = supabase.from('man_hours').select('*').order('period_start', { ascending: false })
  if (options.depotId) q = q.eq('depot_id', options.depotId)
  if (options.from) q = q.gte('period_start', options.from)
  if (options.to) q = q.lte('period_end', options.to)
  const { data, error } = await q
  if (error) throw error
  return data as ManHourRecord[]
}

export async function upsertManHours(input: Partial<ManHourRecord>) {
  const { data, error } = await supabase
    .from('man_hours')
    .upsert(
      {
        depot_id: input.depot_id!,
        period_start: input.period_start!,
        period_end: input.period_end!,
        report_date: input.report_date ?? new Date().toISOString().slice(0, 10),
        employees_scheduled: input.employees_scheduled ?? 0,
        employees_present: input.employees_present ?? 0,
        hours_worked: input.hours_worked ?? 0,
        overtime_hours: input.overtime_hours ?? 0,
        lost_time_injuries: input.lost_time_injuries ?? 0,
        first_aid_cases: input.first_aid_cases ?? 0,
        medical_treatment_cases: input.medical_treatment_cases ?? 0,
        near_misses: input.near_misses ?? 0,
        recordable_incidents: input.recordable_incidents ?? 0,
        days_lost: input.days_lost ?? 0,
        created_by: input.created_by ?? null,
      },
      { onConflict: 'depot_id,period_start' },
    )
    .select()
    .single()
  if (error) throw error
  return data as ManHourRecord
}

export async function updateManHours(id: string, input: Partial<ManHourRecord>) {
  const { data, error } = await supabase.from('man_hours').update(input).eq('id', id).select().single()
  if (error) throw error
  return data as ManHourRecord
}

export async function deleteManHours(id: string) {
  const { error } = await supabase.from('man_hours').delete().eq('id', id)
  if (error) throw error
}

/** TRIR / LTIFR (per 200,000 exposure hours). */
export function safetyRates(r: Pick<ManHourRecord, 'recordable_incidents' | 'lost_time_injuries' | 'hours_worked'>) {
  const hours = Number(r.hours_worked) || 0
  const base = 200000
  return {
    trir: hours > 0 && Number(r.recordable_incidents) > 0 ? (Number(r.recordable_incidents) * base) / hours : 0,
    ltifr: hours > 0 && Number(r.lost_time_injuries) > 0 ? (Number(r.lost_time_injuries) * base) / hours : 0,
  }
}