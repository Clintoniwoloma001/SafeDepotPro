import { supabase } from '@/lib/supabaseClient'
import type { Incident } from '@/types/entities'

export async function listIncidents(options: { depotId?: string; status?: Incident['status'] } = {}) {
  let q = supabase.from('incidents').select('*').order('occurred_at', { ascending: false })
  if (options.depotId) q = q.eq('depot_id', options.depotId)
  if (options.status) q = q.eq('status', options.status)
  const { data, error } = await q
  if (error) throw error
  return data as Incident[]
}

export async function getIncident(id: string) {
  const { data, error } = await supabase.from('incidents').select('*').eq('id', id).single()
  if (error) throw error
  return data as Incident
}

export async function nextIncidentNumber(): Promise<string> {
  const { data } = await supabase.from('incidents').select('incident_number').order('created_at', { ascending: false }).limit(1)
  const num = data?.[0]?.incident_number ? parseInt(data[0].incident_number.replace(/^\D+/g, ''), 10) + 1 : 1
  return `INC-${String(num).padStart(4, '0')}`
}

export async function createIncident(input: Partial<Incident>) {
  const { data, error } = await supabase
    .from('incidents')
    .insert({
      depot_id: input.depot_id!,
      incident_number: input.incident_number!,
      occurred_at: input.occurred_at ?? new Date().toISOString(),
      incident_type: input.incident_type ?? null,
      severity: input.severity ?? 'MEDIUM',
      description: input.description!,
      root_cause: input.root_cause ?? null,
      actions_taken: input.actions_taken ?? null,
      involved_personnel: input.involved_personnel ?? [],
      photo_paths: input.photo_paths ?? [],
      status: input.status ?? 'OPEN',
      reported_by: input.reported_by ?? null,
      reported_by_name: input.reported_by_name ?? null,
    })
    .select()
    .single()
  if (error) throw error
  return data as Incident
}

export async function updateIncident(id: string, input: Partial<Incident>) {
  const { data, error } = await supabase.from('incidents').update(input).eq('id', id).select().single()
  if (error) throw error
  return data as Incident
}

export async function deleteIncident(id: string) {
  const { error } = await supabase.from('incidents').delete().eq('id', id)
  if (error) throw error
}