import { supabase } from '@/lib/supabaseClient'
import type { Hazard } from '@/types/entities'

export async function listHazards(options: { depotId?: string; status?: Hazard['status'] } = {}) {
  let q = supabase.from('hazards').select('*').order('created_at', { ascending: false })
  if (options.depotId) q = q.eq('depot_id', options.depotId)
  if (options.status) q = q.eq('status', options.status)
  const { data, error } = await q
  if (error) throw error
  return data as Hazard[]
}

export async function getHazard(id: string) {
  const { data, error } = await supabase.from('hazards').select('*').eq('id', id).single()
  if (error) throw error
  return data as Hazard
}

export async function createHazard(input: Partial<Hazard>) {
  const { data, error } = await supabase
    .from('hazards')
    .insert({
      depot_id: input.depot_id!,
      location: input.location ?? null,
      description: input.description!,
      hazard_type: input.hazard_type ?? null,
      likelihood: input.likelihood ?? 3,
      severity: input.severity ?? 'MEDIUM',
      risk_score: input.risk_score ?? null,
      risk_rating: input.risk_rating ?? null,
      reported_by: input.reported_by ?? null,
      reported_by_name: input.reported_by_name ?? null,
      photo_paths: input.photo_paths ?? [],
      corrective_action: input.corrective_action ?? null,
      controlled_confirmed: input.controlled_confirmed ?? false,
      status: input.status ?? 'OPEN',
    })
    .select()
    .single()
  if (error) throw error
  return data as Hazard
}

export async function updateHazard(id: string, input: Partial<Hazard>) {
  const { data, error } = await supabase.from('hazards').update(input).eq('id', id).select().single()
  if (error) throw error
  return data as Hazard
}

export async function deleteHazard(id: string) {
  const { error } = await supabase.from('hazards').delete().eq('id', id)
  if (error) throw error
}