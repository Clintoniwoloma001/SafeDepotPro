import { useMemo } from 'react'
import { useQuery } from '@tanstack/react-query'
import { useAuth } from '@/contexts/AuthContext'
import { activeCoverDepot } from '@/services/standIn.service'
import { ROLE_LABELS, ROLE_RANK } from '@/types/enums'
import type { UserRole } from '@/types/enums'

export interface CurrentUser {
  userId: string | null
  fullName: string
  email: string
  role: UserRole
  rank: number
  depotId: string | null
  /** Effective depot — swaps to the cover depot while this user is an ACTIVE stand-in. */
  effectiveDepotId: string | null
  coverDepotId: string | null
  isAuthenticated: boolean
  isSuperadmin: boolean
  isCountryHead: boolean
  isAdmin: boolean
  canViewAllDepots: boolean
  roleLabel: string
  /** True for COUNTRY_HEAD, ADMIN and SUPERADMIN. */
  isManagement: boolean
  mustChangePassword: boolean
  isLoading: boolean
}

export function useCurrentUser(): CurrentUser {
  const { user, profile, loading } = useAuth()

  const { data: cover } = useQuery({
    queryKey: ['stand-in-cover', profile?.id],
    queryFn: () => (profile?.id ? activeCoverDepot(profile.id) : null),
    enabled: Boolean(profile?.id),
    staleTime: 60_000,
  })

  return useMemo<CurrentUser>(() => {
    if (!user || !profile || !profile.is_active) {
      return {
        userId: user?.id ?? null,
        fullName: profile?.full_name ?? user?.user_metadata?.full_name ?? '',
        email: profile?.email ?? user?.email ?? '',
        role: (profile?.role as UserRole) ?? 'USER',
        rank: ROLE_RANK[(profile?.role as UserRole) ?? 'USER'],
        depotId: profile?.depot_id ?? null,
        effectiveDepotId: profile?.depot_id ?? null,
        coverDepotId: null,
        isAuthenticated: false,
        isSuperadmin: false,
        isCountryHead: false,
        isAdmin: false,
        canViewAllDepots: false,
        roleLabel: ROLE_LABELS.USER,
        isManagement: false,
        mustChangePassword: profile?.must_change_password ?? false,
        isLoading: loading,
      }
    }

    const role = profile.role as UserRole
    const coverDepotId = cover?.covering_depot_id ?? null
    const effectiveDepotId = coverDepotId ?? profile.depot_id
    const isCountryHead = role === 'COUNTRY_HEAD' || role === 'ADMIN' || role === 'SUPERADMIN'
    const isAdmin = role === 'ADMIN'
    const isSuperadmin = role === 'SUPERADMIN'

    return {
      userId: user.id,
      fullName: profile.full_name || ((user.user_metadata?.full_name as string) ?? user.email ?? ''),
      email: profile.email || (user.email ?? ''),
      role,
      rank: ROLE_RANK[role],
      depotId: profile.depot_id,
      effectiveDepotId,
      coverDepotId,
      isAuthenticated: true,
      isSuperadmin,
      isCountryHead,
      isAdmin,
      canViewAllDepots: isCountryHead,
      roleLabel: ROLE_LABELS[role],
      isManagement: isCountryHead,
      mustChangePassword: profile.must_change_password,
      isLoading: loading,
    }
  }, [user, profile, cover, loading])
}