import { supabase } from '@/lib/supabaseClient'
import type { Asset } from '@/types/entities'

export async function listAssets(options: { depotId?: string; status?: Asset['status'] } = {}) {
  let q = supabase.from('assets').select('*').order('name', { ascending: true })
  if (options.depotId) q = q.eq('depot_id', options.depotId)
  if (options.status) q = q.eq('status', options.status)
  const { data, error } = await q
  if (error) throw error
  return data as Asset[]
}

export async function createAsset(input: Partial<Asset>) {
  const { data, error } = await supabase
    .from('assets')
    .insert({
      depot_id: input.depot_id!,
      asset_tag: input.asset_tag ?? null,
      name: input.name!,
      asset_type: input.asset_type ?? null,
      make_model: input.make_model ?? null,
      serial_number: input.serial_number ?? null,
      zone_id: input.zone_id ?? null,
      zone_name: input.zone_name ?? null,
      purchase_date: input.purchase_date ?? null,
      status: input.status ?? 'AVAILABLE',
      condition: input.condition ?? null,
      last_calibration_date: input.last_calibration_date ?? null,
      next_calibration_date: input.next_calibration_date ?? null,
      assigned_to_user_id: input.assigned_to_user_id ?? null,
      assigned_to_name: input.assigned_to_name ?? null,
      notes: input.notes ?? null,
    })
    .select()
    .single()
  if (error) throw error
  return data as Asset
}

export async function updateAsset(id: string, input: Partial<Asset>) {
  const { data, error } = await supabase.from('assets').update(input).eq('id', id).select().single()
  if (error) throw error
  return data as Asset
}

export async function deleteAsset(id: string) {
  const { error } = await supabase.from('assets').delete().eq('id', id)
  if (error) throw error
}