import { useMemo, useState } from 'react'
import { useCurrentUser } from './useCurrentUser'
import { useQuery } from '@tanstack/react-query'
import { listDepots } from '@/services/depots.service'
import type { Depot } from '@/types/entities'

export interface DepotFilter {
  /** The selected depot id. null means "all depots the user can see". */
  depotId: string | null
  setDepotId: (id: string | null) => void
  depots: Depot[]
  /** Effective depot id when the user is scoped to a single depot (USER). */
  scopedDepotId: string | null
  /** All depots visible to the user. */
  visibleDepots: Depot[]
}

export function useDepotFilter(): DepotFilter {
  const { effectiveDepotId, canViewAllDepots } = useCurrentUser()
  const { data: depots = [] } = useQuery({
    queryKey: ['depots'],
    queryFn: () => listDepots(),
    staleTime: 5 * 60_000,
  })
  const [selected, setSelected] = useState<string | null>(null)

  const visibleDepots = useMemo(() => (canViewAllDepots ? depots : depots.filter((d) => d.id === effectiveDepotId)), [canViewAllDepots, depots, effectiveDepotId])

  const depotId = useMemo(() => {
    if (!canViewAllDepots) return effectiveDepotId
    if (selected && visibleDepots.some((d) => d.id === selected)) return selected
    return null
  }, [canViewAllDepots, selected, visibleDepots, effectiveDepotId])

  return {
    depotId,
    setDepotId: setSelected,
    depots,
    scopedDepotId: effectiveDepotId,
    visibleDepots,
  }
}