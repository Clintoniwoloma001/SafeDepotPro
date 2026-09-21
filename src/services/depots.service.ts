import { supabase } from '@/lib/supabaseClient'
import type { Depot, DepotZone } from '@/types/entities'

export async function listDepots(depotIds?: string[]) {
  let q = supabase.from('depots').select('*').order('name', { ascending: true })
  if (depotIds && depotIds.length > 0) q = q.in('id', depotIds)
  const { data, error } = await q
  if (error) throw error
  return data as Depot[]
}

export async function getDepot(id: string) {
  const { data, error } = await supabase.from('depots').select('*').eq('id', id).single()
  if (error) throw error
  return data as Depot
}

export async function depotExists(code: string): Promise<boolean> {
  const { data } = await supabase.from('depots').select('id').eq('code', code).maybeSingle()
  return Boolean(data)
}

/** Derive a short unique code from a depot name, e.g. "Akure Depot" → "AKR". */
export function deriveDepotCode(name: string): string {
  const words = name
    .replace(/depot$/i, '')
    .trim()
    .split(/[\s\-]+/)
    .filter(Boolean)
  if (words.length === 0) return ''
  let code = ''
  if (words.length >= 3) code = words.map((w) => w[0]).join('')
  else if (words.length === 2) code = words[0][0] + words[1][0]
  else code = words[0].slice(0, 3)
  return code.toUpperCase()
}

export async function createDepot(input: Partial<Depot>) {
  const { data, error } = await supabase
    .from('depots')
    .insert({
      name: input.name!,
      code: input.code!,
      address: input.address ?? null,
      latitude: input.latitude ?? null,
      longitude: input.longitude ?? null,
      is_active: input.is_active ?? true,
    })
    .select()
    .single()
  if (error) throw error
  return data as Depot
}

export async function updateDepot(id: string, input: Partial<Depot>) {
  const { data, error } = await supabase.from('depots').update(input).eq('id', id).select().single()
  if (error) throw error
  return data as Depot
}

export async function deleteDepot(id: string) {
  const { error } = await supabase.from('depots').delete().eq('id', id)
  if (error) throw error
}

// Depot zones
export async function listZones(depotId: string) {
  const { data, error } = await supabase.from('depot_zones').select('*').eq('depot_id', depotId).order('name', { ascending: true })
  if (error) throw error
  return data as DepotZone[]
}

export async function createZone(depotId: string, name: string) {
  const { data, error } = await supabase.from('depot_zones').insert({ depot_id: depotId, name }).select().single()
  if (error) throw error
  return data as DepotZone
}

export async function deleteZone(id: string) {
  const { error } = await supabase.from('depot_zones').delete().eq('id', id)
  if (error) throw error
}