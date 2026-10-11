import type { ReactNode } from 'react'
import { Navigate, useLocation } from 'react-router-dom'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import type { UserRole } from '@/types/enums'

interface RoleGuardProps {
  /** Minimum role rank required. */
  minRank?: number
  /** Specific roles allowed. */
  roles?: UserRole[]
  children: ReactNode
}

/** UI convenience layer only — RLS remains the real security boundary. */
export default function RoleGuard({ minRank, roles, children }: RoleGuardProps) {
  const user = useCurrentUser()
  const location = useLocation()

  const allowed = roles ? roles.includes(user.role) : minRank != null ? user.rank >= minRank : true

  if (!allowed) {
    return <Navigate to="/" replace state={{ from: location }} />
  }
  return <>{children}</>
}