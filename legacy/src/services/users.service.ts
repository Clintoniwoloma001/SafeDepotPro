import { supabase } from '@/lib/supabaseClient'
import type { User } from '@supabase/supabase-js'
import type { Profile } from '@/types/entities'
import type { UserRole } from '@/types/enums'

/** Invite a new user (SUPERADMIN only). Initial password forces change on first login. */
export async function inviteUser(input: {
  name: string
  email: string
  role: UserRole
  depotId: string | null
  position?: string
  initialPassword: string
}) {
  const { data, error } = await supabase.auth.admin.createUser({
    email: input.email,
    password: input.initialPassword,
    email_confirm: true,
    user_metadata: {
      full_name: input.name,
      depot_id: input.depotId,
      initial_role: input.role,
      must_change_password: true,
    },
  })
  if (error) throw error
  const { error: personnelError } = await supabase.from('personnel').upsert({
    user_id: data.user.id,
    first_name: input.name.split(' ')[0] ?? input.name,
    last_name: input.name.split(' ').slice(1).join(' ') ?? '',
    email: input.email,
    position: input.position ?? null,
    depot_id: input.depotId,
    is_active: true,
  })
  if (personnelError) throw personnelError
  return data.user as User
}

/** Delete a user — cascades personnel, revokes auth access. */
export async function deleteUserAccount(userId: string) {
  const { error } = await supabase.auth.admin.deleteUser(userId)
  if (error) throw error
}

export async function listUsersWithProfiles() {
  const { data, error } = await supabase.auth.admin.listUsers({ perPage: 1000 })
  if (error) throw error
  const { data: profiles, error: pErr } = await supabase.from('profiles').select('*')
  if (pErr) throw pErr
  const profileMap = new Map<string, Profile>((profiles ?? []).map((p) => [p.id, p]))
  return data.users.map((u) => ({ user: u, profile: profileMap.get(u.id) ?? null }))
}

export async function setUserRole(userId: string, role: UserRole) {
  const { error } = await supabase.from('profiles').update({ role }).eq('id', userId)
  if (error) throw error
}