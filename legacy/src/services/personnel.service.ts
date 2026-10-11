import { supabase } from '@/lib/supabaseClient'
import type { Personnel, Profile } from '@/types/entities'
import type { UserRole } from '@/types/enums'

// ---------------------------------------------------------------------------
// Personnel (employee directory — one per user, synced bidirectionally)
// ---------------------------------------------------------------------------

export async function listPersonnel(options: { depotId?: string; includeInactive?: boolean } = {}) {
  let q = supabase.from('personnel').select('*').order('first_name', { ascending: true })
  if (options.depotId) q = q.eq('depot_id', options.depotId)
  if (!options.includeInactive) q = q.eq('is_active', true)
  const { data, error } = await q
  if (error) throw error
  return data as Personnel[]
}

export async function getPersonnel(id: string) {
  const { data, error } = await supabase.from('personnel').select('*').eq('id', id).single()
  if (error) throw error
  return data as Personnel
}

export async function createPersonnel(input: Partial<Personnel>) {
  const { data, error } = await supabase
    .from('personnel')
    .insert({
      user_id: input.user_id ?? null,
      first_name: input.first_name ?? '',
      last_name: input.last_name ?? '',
      email: input.email ?? '',
      phone: input.phone ?? null,
      position: input.position ?? null,
      depot_id: input.depot_id ?? null,
      is_active: input.is_active ?? true,
    })
    .select()
    .single()
  if (error) throw error
  return data as Personnel
}

export async function updatePersonnel(id: string, input: Partial<Personnel>) {
  const { data, error } = await supabase.from('personnel').update(input).eq('id', id).select().single()
  if (error) throw error
  return data as Personnel
}

export async function deletePersonnel(id: string) {
  const { error } = await supabase.from('personnel').delete().eq('id', id)
  if (error) throw error
}

// ---------------------------------------------------------------------------
// Profiles (auth-linking table — USER can read/update own, SUPERADMIN manages all)
// ---------------------------------------------------------------------------

export interface ProfileWithPersonnel extends Profile {
  personnel: Personnel | null
}

export async function listProfiles(): Promise<ProfileWithPersonnel[]> {
  const { data: profiles, error } = await supabase
    .from('profiles')
    .select('*')
    .order('created_at', { ascending: false })
  if (error) throw error
  const { data: personnel } = await supabase.from('personnel').select('*')
  const byUser = new Map((personnel ?? []).map((p) => [p.user_id, p]))
  return (profiles ?? []).map((prof) => ({ ...prof, personnel: byUser.get(prof.id) ?? null })) as ProfileWithPersonnel[]
}

export async function updateProfileRole(userId: string, role: UserRole) {
  const { data, error } = await supabase.from('profiles').update({ role }).eq('id', userId).select().single()
  if (error) throw error
  return data as Profile
}

export async function updateProfileDepot(userId: string, depotId: string | null) {
  const { data, error } = await supabase.from('profiles').update({ depot_id: depotId }).eq('id', userId).select().single()
  if (error) throw error
  return data as Profile
}

export async function setProfileActive(userId: string, isActive: boolean) {
  const { data, error } = await supabase.from('profiles').update({ is_active: isActive }).eq('id', userId).select().single()
  if (error) throw error
  return data as Profile
}

export async function deleteProfile(userId: string) {
  const { error } = await supabase.from('profiles').delete().eq('id', userId)
  if (error) throw error
}