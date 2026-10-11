import { supabase } from '@/lib/supabaseClient'
import type { ShiftHandover } from '@/types/entities'

export async function listShiftHandovers(options: { depotId?: string; date?: string } = {}) {
  let q = supabase.from('shift_handovers').select('*').order('shift_date', { ascending: false })
  if (options.depotId) q = q.eq('depot_id', options.depotId)
  if (options.date) q = q.eq('shift_date', options.date)
  const { data, error } = await q
  if (error) throw error
  return data as ShiftHandover[]
}

export async function createShiftHandover(input: Partial<ShiftHandover>) {
  const { data, error } = await supabase
    .from('shift_handovers')
    .insert({
      depot_id: input.depot_id!,
      shift_date: input.shift_date ?? new Date().toISOString().slice(0, 10),
      shift: input.shift ?? 'DAY',
      outgoing_user_id: input.outgoing_user_id ?? null,
      outgoing_name: input.outgoing_name ?? null,
      incoming_user_id: input.incoming_user_id ?? null,
      incoming_name: input.incoming_name ?? null,
      status: input.status ?? 'PENDING',
      summary: input.summary ?? null,
      checklist: input.checklist ?? {},
      open_issues: input.open_issues ?? null,
      follow_up_actions: input.follow_up_actions ?? null,
      photo_paths: input.photo_paths ?? [],
      outgoing_signature_path: input.outgoing_signature_path ?? null,
      incoming_signature_path: input.incoming_signature_path ?? null,
    })
    .select()
    .single()
  if (error) throw error
  return data as ShiftHandover
}

export async function updateShiftHandover(id: string, input: Partial<ShiftHandover>) {
  const { data, error } = await supabase.from('shift_handovers').update(input).eq('id', id).select().single()
  if (error) throw error
  return data as ShiftHandover
}

export async function deleteShiftHandover(id: string) {
  const { error } = await supabase.from('shift_handovers').delete().eq('id', id)
  if (error) throw error
}