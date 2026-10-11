import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { AlertTriangle, CheckCircle2, ClipboardCheck, ShieldAlert, Wrench } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Progress } from '@/components/ui/progress'
import { toast } from 'sonner'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { useAppData } from '@/hooks/useAppData'
import { useTaskVisibility } from '@/hooks/useTaskVisibility'
import CompletionDialog, { type CompletionInput } from '@/components/tasks/CompletionDialog'
import { expectedOccurrencesFor } from '@/hooks/useTaskVisibility'
import { recordTaskCompletion } from '@/services/routineTasks.service'
import { listToolboxTalks } from '@/services/toolboxTalks.service'
import { listTruckInspections } from '@/services/inspections.service'
import { listAssets } from '@/services/assets.service'
import { listPersonnel } from '@/services/personnel.service'
import { listPermits } from '@/services/permits.service'
import { PageHeader, SectionCard, KPICard } from '@/components/shared'
import type { RoutineTask } from '@/types/entities'
import { todayIso, formatDate } from '@/lib/utils'
import { RAG_THRESHOLDS } from '@/lib/constants'

export default function Dashboard() {
  const user = useCurrentUser()
  const app = useAppData()
  const queryClient = useQueryClient()
  const [completing, setCompleting] = useState<RoutineTask | null>(null)

  const { data: toolboxTalks = [] } = useQuery({ queryKey: ['toolbox-talks', user.effectiveDepotId], queryFn: () => listToolboxTalks({ depotId: user.effectiveDepotId ?? undefined }) })
  const { data: truckInspections = [] } = useQuery({ queryKey: ['truck-inspections', user.effectiveDepotId], queryFn: () => listTruckInspections({ depotId: user.effectiveDepotId ?? undefined }) })
  const { data: assets = [] } = useQuery({ queryKey: ['assets', user.effectiveDepotId], queryFn: () => listAssets({ depotId: user.effectiveDepotId ?? undefined }) })
  const { data: personnel = [] } = useQuery({ queryKey: ['personnel', user.effectiveDepotId], queryFn: () => listPersonnel({ depotId: user.effectiveDepotId ?? undefined }) })
  const { data: permits = [] } = useQuery({ queryKey: ['permits', user.effectiveDepotId], queryFn: () => listPermits({ depotId: user.effectiveDepotId ?? undefined }) })

  const context = useMemo(
    () => ({
      truckInspectionsToday: truckInspections.filter((t) => t.inspection_date === todayIso()).length,
      permitsActiveToday: permits.filter((p) => p.status === 'APPROVED').length,
      equipmentCount: assets.length,
      personnelCount: personnel.length,
    }),
    [truckInspections, permits, assets, personnel],
  )

  const prerequisiteDeps = useMemo(
    () => ({
      toolboxTalksMatch: (date: string) => toolboxTalks.some((t) => t.talk_date === date),
      housekeepingInspectionMatch: (date: string) =>
        (app.inspections ?? []).some((i) => i.inspection_date === date && (i.title ?? '').toLowerCase().includes('housekeeping')),
    }),
    [toolboxTalks, app.inspections],
  )

  const views = useTaskVisibility(app.tasks ?? [], app.taskHistory ?? [], user, context, prerequisiteDeps)
  const dueToday = views.filter((v) => v.dueToday && v.visible)
  const doneToday = dueToday.filter((v) => v.completedToday).length
  const compliance = dueToday.length === 0 ? 0 : Math.round((doneToday / dueToday.length) * 100)

  const completeMutation = useMutation({
    mutationFn: (input: CompletionInput) =>
      recordTaskCompletion({
        task_id: input.task.id,
        user_id: user.userId ?? undefined,
        actor_name: user.fullName,
        depot_id: user.effectiveDepotId ?? undefined,
        occurrences: input.occurrences,
        expected_occurrences: expectedOccurrencesFor(input.task, context),
        comment: input.comment || null,
        photo_paths: input.photos,
        signature_path: input.signature,
        attendance_count: input.task.linked_module === 'TOOLBOX' ? input.attendance : null,
        ai_verified: input.aiVerified,
        completed_at: new Date().toISOString(),
      }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['task-history'] }),
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not record completion'),
  })

  const depotName = (app.depots ?? []).find((d) => d.id === user.effectiveDepotId)?.name

  const openIncidents = (app.incidents ?? []).filter((i) => !['CLOSED', 'WITHDRAWN'].includes(i.status))
  const openHazards = (app.hazards ?? []).filter((h) => !['CLOSED', 'CANCELLED'].includes(h.status))
  const openCapas = (app.capas ?? []).filter((c) => !['CLOSED', 'CANCELLED'].includes(c.status))
  const activePermits = (app.permits ?? []).filter((p) => p.status === 'APPROVED')

  const today = todayIso()
  const overdueCapas = (app.capas ?? []).filter((c) => c.due_date && c.due_date < today && !['CLOSED', 'CANCELLED'].includes(c.status))

  return (
    <div className="space-y-6">
      <PageHeader
        title="Dashboard"
        subtitle={`${formatDate(todayIso())}${depotName ? ` · ${depotName}` : ''}`}
      />

      {user.isCountryHead ? (
        <>
          <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
            <Link to="/incidents">
              <KPICard icon={<AlertTriangle className="h-5 w-5" />} iconHue="amber" label="Open incidents" value={openIncidents.length} tone={openIncidents.length > 0 ? 'warn' : 'good'} />
            </Link>
            <Link to="/hazards">
              <KPICard icon={<ShieldAlert className="h-5 w-5" />} iconHue="amber" label="Open hazards" value={openHazards.length} tone={openHazards.length > 0 ? 'warn' : 'good'} />
            </Link>
            <Link to="/capa">
              <KPICard icon={<Wrench className="h-5 w-5" />} iconHue="red" label="Open CAPA" value={openCapas.length} tone={overdueCapas.length > 0 ? 'bad' : 'warn'} />
            </Link>
            <Link to="/permits">
              <KPICard icon={<ClipboardCheck className="h-5 w-5" />} iconHue="blue" label="Active permits" value={activePermits.length} />
            </Link>
          </div>

          <div className="grid gap-4 md:grid-cols-2">
            <SectionCard title="Safety posture" description="Live portfolio snapshot">
              <div className="grid grid-cols-2 gap-3 text-sm md:grid-cols-3">
                <Stat label="Total incidents" value={(app.incidents ?? []).length} />
                <Stat label="Total hazards" value={(app.hazards ?? []).length} />
                <Stat label="Total CAPA records" value={(app.capas ?? []).length} />
                <Stat label="Overdue CAPA" value={overdueCapas.length} />
                <Stat label="Inspections recorded" value={(app.inspections ?? []).length} />
                <Stat label="Personnel on file" value={(app.personnel ?? []).length} />
              </div>
            </SectionCard>

            <SectionCard title="Today&apos;s compliance" description="Routine task completion against due targets">
              <div className="mb-1 flex items-center justify-between text-sm">
                <span>{doneToday}/{dueToday.length} due tasks completed</span>
                <span className="font-bold">{compliance}%</span>
              </div>
              <Progress value={compliance} className={compliance >= 80 ? '[&>div]:bg-rag-good' : compliance >= 60 ? '[&>div]:bg-rag-warn' : '[&>div]:bg-rag-bad'} />
              <Link to="/tasks" className="mt-3 inline-block text-sm text-brand hover:underline">
                Open task analytics →
              </Link>
            </SectionCard>
          </div>

          <Card>
            <CardHeader>
              <CardTitle className="text-base font-semibold">Depot overview ({RAG_THRESHOLDS.GOOD * 100}%+ / {RAG_THRESHOLDS.WARN * 100}% targets)</CardTitle>
            </CardHeader>
            <CardContent className="text-sm text-muted-foreground">
              Track per-depot task compliance in Routine Tasks analytics.
            </CardContent>
          </Card>
        </>
      ) : (
        <>
          <Card>
            <CardContent className="pt-6">
              <div className="mb-1 flex items-center justify-between text-sm">
                <span className="font-medium">Today&apos;s compliance</span>
                <span className="font-bold">{compliance}%</span>
              </div>
              <Progress value={compliance} className={compliance >= 80 ? '[&>div]:bg-rag-good' : compliance >= 60 ? '[&>div]:bg-rag-warn' : '[&>div]:bg-rag-bad'} />
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex-row items-center justify-between space-y-0">
              <CardTitle className="text-base font-semibold">Due today</CardTitle>
              {dueToday.length > 0 && <Badge variant="outline">{doneToday}/{dueToday.length}</Badge>}
            </CardHeader>
            <CardContent className="space-y-2">
              {dueToday.length === 0 && <p className="py-6 text-center text-sm text-muted-foreground">Nothing due today. Great work!</p>}
              {dueToday.map(({ task, completedToday, blockedReason }) => (
                <div key={task.id} className="flex items-center gap-3 rounded-xl border p-3">
                  <div className="flex-1">
                    <span className="font-medium">{task.title}</span>
                    {blockedReason && !completedToday && <div className="text-xs text-amber-700">{blockedReason}</div>}
                  </div>
                  {completedToday ? (
                    <span className="flex items-center gap-1 text-sm font-medium text-rag-good">
                      <CheckCircle2 className="h-4 w-4" /> Done
                    </span>
                  ) : (
                    <Button size="sm" variant={blockedReason ? 'secondary' : 'default'} disabled={Boolean(blockedReason)} onClick={() => setCompleting(task)}>
                      Complete
                    </Button>
                  )}
                </div>
              ))}
            </CardContent>
          </Card>
        </>
      )}

      <CompletionDialog
        open={Boolean(completing)}
        onOpenChange={(o) => { if (!o) setCompleting(null) }}
        task={completing}
        userId={user.userId ?? 'anon'}
        currentUserName={user.fullName}
        context={context}
        onConfirm={async (input) => {
          if (!completing) return
          await completeMutation.mutateAsync(input)
          setCompleting(null)
        }}
      />
    </div>
  )
}

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <div className="flex items-center justify-between rounded-xl border px-3 py-2">
      <span className="text-muted-foreground">{label}</span>
      <b>{value}</b>
    </div>
  )
}