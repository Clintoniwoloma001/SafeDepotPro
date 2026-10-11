import type { ReactNode } from 'react'
import { Navigate, useLocation } from 'react-router-dom'
import { useAuth } from '@/contexts/AuthContext'
import { Skeleton } from '@/components/ui/skeleton'

export default function ProtectedRoute({ children }: { children: ReactNode }) {
  const { user, loading, profile } = useAuth()
  const location = useLocation()

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="w-80 space-y-3">
          <Skeleton className="h-8 w-3/4" />
          <Skeleton className="h-24 w-full" />
        </div>
      </div>
    )
  }

  if (!user) {
    return <Navigate to="/auth/login" replace state={{ from: location }} />
  }

  // A logged-in user whose profile is missing or inactive must complete setup.
  if (user && !profile) {
    if (location.pathname !== '/auth/callback') {
      return <Navigate to="/auth/callback" replace />
    }
  }

  if (profile && !profile.is_active) {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <div className="max-w-md rounded-lg border p-6 text-sm text-muted-foreground">
          Your account has been deactivated. Contact your administrator.
        </div>
      </div>
    )
  }

  return <>{children}</>
}