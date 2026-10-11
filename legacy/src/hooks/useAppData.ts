import { useQuery } from '@tanstack/react-query'
import { useCurrentUser } from './useCurrentUser'
import { useDepotFilter } from './useDepotFilter'
import { listRoutineTasks, listTaskHistory } from '@/services/routineTasks.service'
import { listHazards } from '@/services/hazards.service'
import { listCapas } from '@/services/capa.service'
import { listPermits } from '@/services/permits.service'
import { listInspections } from '@/services/inspections.service'
import { listIncidents } from '@/services/incidents.service'
import { listPersonnel } from '@/services/personnel.service'
import { listDepots } from '@/services/depots.service'
import type { RoutineTask, TaskHistory } from '@/types/entities'

/** Central fetch of all dashboard-relevant aggregates. Only one source of truth per module. */
export function useAppData() {
  const user = useCurrentUser()
  const { depotId } = useDepotFilter()

  const tasks = useQuery({
    queryKey: ['tasks', user.role, depotId ?? 'all'],
    queryFn: () => listRoutineTasks(),
    enabled: user.isAuthenticated,
    refetchInterval: 5 * 60_000,
  })
  const history = useQuery({
    queryKey: ['task-history', 'today', user.effectiveDepotId],
    queryFn: () => listTaskHistory({ depotId: user.effectiveDepotId ?? undefined }),
    enabled: user.isAuthenticated,
    refetchInterval: 5 * 60_000,
  })
  const hazards = useQuery({
    queryKey: ['hazards', depotId ?? 'all'],
    queryFn: () => listHazards(depotId ? { depotId } : {}),
    enabled: user.isAuthenticated,
    refetchInterval: 5 * 60_000,
  })
  const capas = useQuery({
    queryKey: ['capa', depotId ?? 'all'],
    queryFn: () => listCapas(depotId ? { depotId } : {}),
    enabled: user.isAuthenticated,
    refetchInterval: 5 * 60_000,
  })
  const permits = useQuery({
    queryKey: ['permits', depotId ?? 'all'],
    queryFn: () => listPermits(depotId ? { depotId } : {}),
    enabled: user.isAuthenticated,
    refetchInterval: 5 * 60_000,
  })
  const inspections = useQuery({
    queryKey: ['inspections', depotId ?? 'all'],
    queryFn: () => listInspections(depotId ? { depotId } : {}),
    enabled: user.isAuthenticated,
    refetchInterval: 5 * 60_000,
  })
  const incidents = useQuery({
    queryKey: ['incidents', depotId ?? 'all'],
    queryFn: () => listIncidents(depotId ? { depotId } : {}),
    enabled: user.isAuthenticated,
    refetchInterval: 5 * 60_000,
  })
  const personnel = useQuery({
    queryKey: ['personnel', 'all'],
    queryFn: () => listPersonnel(),
    enabled: user.isAuthenticated,
  })
  const depots = useQuery({
    queryKey: ['depots'],
    queryFn: () => listDepots(),
    enabled: user.isAuthenticated,
  })

  return {
    user,
    depotId,
    tasks: tasks.data as RoutineTask[] | undefined,
    taskHistory: history.data as TaskHistory[] | undefined,
    hazards: hazards.data,
    capas: capas.data,
    permits: permits.data,
    inspections: inspections.data,
    incidents: incidents.data,
    personnel: personnel.data,
    depots: depots.data,
    isLoading: [tasks, hazards, capas, permits, inspections, incidents].some((q) => q.isLoading),
  }
}