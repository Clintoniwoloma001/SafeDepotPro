import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { supabase } from '@/lib/supabaseClient'
import type { Profile } from '@/types/entities'
import { fetchProfile } from '@/services/auth.service'

interface AuthContextValue {
  user: import('@supabase/supabase-js').User | null
  profile: Profile | null
  loading: boolean
  refreshProfile: () => Promise<void>
  setProfile: (p: Profile) => void
}

const AuthContext = createContext<AuthContextValue | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<import('@supabase/supabase-js').User | null>(null)
  const [profile, setProfileState] = useState<Profile | null>(null)
  const [loading, setLoading] = useState(true)

  const refreshProfile = useCallback(async () => {
    const { data } = await supabase.auth.getSession()
    const uid = data.session?.user.id
    if (!uid) {
      setProfileState(null)
      return
    }
    try {
      const p = await fetchProfile(uid)
      setProfileState(p)
    } catch {
      setProfileState(null)
    }
  }, [])

  useEffect(() => {
    let mounted = true
    const { data: unsub } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null)
    })
    supabase.auth.getSession().then(async ({ data }) => {
      if (!mounted) return
      setUser(data.session?.user ?? null)
      if (data.session?.user.id) {
        try {
          const p = await fetchProfile(data.session.user.id)
          if (mounted) setProfileState(p)
        } catch {
          if (mounted) setProfileState(null)
        }
      }
      if (mounted) setLoading(false)
    })
    return () => {
      mounted = false
      unsub.subscription.unsubscribe()
    }
  }, [])

  const value = useMemo<AuthContextValue>(
    () => ({ user, profile, loading, refreshProfile, setProfile: setProfileState }),
    [user, profile, loading, refreshProfile],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}