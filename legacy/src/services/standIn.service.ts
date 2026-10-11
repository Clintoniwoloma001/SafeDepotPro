import { supabase } from '@/lib/supabaseClient'
import type { StandIn } from '@/types/entities'
import type { StandInStatus } from '@/types/enums'

export async function listStandIns(options: { userId?: string; status?: StandInStatus } = {}) {
  let q = supabase.from('stand_ins').select('*').order('start_date', { ascending: false })
  if (options.userId) q = q.eq('user_id', options.userId)
  if (options.status) q = q.eq('status', options.status)
  const { data, error } = await q
  if (error) throw error
  return data as StandIn[]
}

export async function createStandIn(input: Partial<StandIn>) {
  const { data, error } = await supabase
    .from('stand_ins')
    .insert({
      user_id: input.user_id!,
      covering_depot_id: input.covering_depot_id!,
      requested_by_user_id: input.requested_by_user_id ?? null,
      requested_by_name: input.requested_by_name ?? null,
      start_date: input.start_date!,
      end_date: input.end_date!,
      reason: input.reason ?? null,
      status: input.status ?? 'PENDING',
    })
    .select()
    .single()
  if (error) throw error
  return data as StandIn
}

export async function setStandInStatus(id: string, status: StandInStatus) {
  const { data, error } = await supabase.from('stand_ins').update({ status }).eq('id', id).select().single()
  if (error) throw error
  return data as StandIn
}

export async function deleteStandIn(id: string) {
  const { error } = await supabase.from('stand_ins').delete().eq('id', id)
  if (error) throw error
}

/** Returns the active covering depot for a user if today falls within an ACTIVE stand-in range. */
export async function activeCoverDepot(userId: string): Promise<{ covering_depot_id: string } | null> {
  const today = new Date().toISOString().slice(0, 10)
  const { data } = await supabase
    .from('stand_ins')
    .select('covering_depot_id')
    .eq('user_id', userId)
    .eq('status', 'ACTIVE')
    .lte('start_date', today)
    .gte('end_date', today)
    .maybeSingle()
  return data ?? null
}