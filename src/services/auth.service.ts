import { supabase } from '@/lib/supabaseClient'
import type { User, Session } from '@supabase/supabase-js'
import type { UserRole } from '@/types/enums'

export interface SignupInput {
  email: string
  password: string
  fullName: string
  depotId: string
  initialRole?: UserRole
}

/** Email/password signup with required depot selection. New users always start as USER. */
export async function signUpWithDepot(input: SignupInput) {
  const { data, error } = await supabase.auth.signUp({
    email: input.email,
    password: input.password,
    options: {
      data: {
        full_name: input.fullName,
        depot_id: input.depotId,
        initial_role: input.initialRole ?? 'USER',
        must_change_password: true,
      },
    },
  })
  if (error) throw error
  return data
}

export async function signIn(email: string, password: string) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password })
  if (error) throw error
  return data
}

export async function signInWithGoogle(redirectTo?: string) {
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: { redirectTo: redirectTo ?? `${window.location.origin}/auth/callback` },
  })
  if (error) throw error
  return data
}

export async function signOut() {
  const { error } = await supabase.auth.signOut()
  if (error) throw error
}

export async function requestPasswordReset(email: string, redirectTo?: string) {
  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: redirectTo ?? `${window.location.origin}/auth/reset-password`,
  })
  if (error) throw error
}

export async function updatePassword(newPassword: string) {
  const { data, error } = await supabase.auth.updateUser({ password: newPassword })
  if (error) throw error
  const { error: profileError } = await supabase
    .from('profiles')
    .update({ must_change_password: false })
    .eq('id', data.user.id)
  if (profileError) throw profileError
  return data
}

export async function getSession(): Promise<Session | null> {
  const { data } = await supabase.auth.getSession()
  return data.session
}

export function onAuthStateChange(callback: (session: Session | null, user: User | null) => void) {
  return supabase.auth.onAuthStateChange((_event, session) => {
    callback(session, session?.user ?? null)
  })
}

/** Record the depot selected during signup on the profile row. */
export async function finalizeSignupProfile(userId: string, fullName: string, depotId: string) {
  const { error } = await supabase
    .from('profiles')
    .update({ full_name: fullName, depot_id: depotId })
    .eq('id', userId)
  return { error }
}

export async function fetchProfile(userId: string) {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .single()
  if (error) throw error
  return data
}