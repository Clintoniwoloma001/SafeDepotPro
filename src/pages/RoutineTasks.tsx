import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { CheckCircle2, Lock, Plus, Search } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Card, CardContent } from '@/components/ui/card'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Progress } from '@/components/ui/progress'
import { Badge } from '@/components/ui/badge'
import { toast } from 'sonner'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { useTaskVisibility, expectedOccurrencesFor, type TaskContext } from '@/hooks/useTaskVisibility'
import { listRoutineTasks, listTaskHistory, recordTaskCompletion } from '@/services/routineTasks.service'
import { listToolboxTalks } from '@/services/toolboxTalks.service'
import { listInspections, listTruckInspections } from '@/services/inspections.service'
import { listPermits } from '@/services/permits.service'
import { listAssets } from '@/services/assets.service'
import { listPersonnel } from '@/services/personnel.service'
import type { RoutineTask } from '@/types/entities'
import { FREQUENCY_LABELS } from '@/lib/constants'
import { todayIso } from '@/lib/utils'
import TaskAnalyticsDashboard from '@/components/tasks/TaskAnalyticsDashboard'
import TaskFormDialog from '@/components/tasks/TaskFormDialog'
import CompletionDialog, { type CompletionInput } from '@/components/tasks/CompletionDialog'

export default function RoutineTasks() {
  const user = useCurrentUser()
  const queryClient = useQueryClient()
  const [search, setSearch] = useState('')
  const [tab, setTab] = useState<'today' | 'all'>('today')
  const [createOpen, setCreateOpen] = useState(false)
  const [completing, setCompleting] = useState<RoutineTask | null>(null)

  const { data: tasks = [] } = useQuery({ queryKey: ['tasks'], queryFn: () => listRoutineTasks() })
  const { data: history = [] } = useQuery({
    queryKey: ['task-history', user.effectiveDepotId],
    queryFn: () => listTaskHistory({ depotId: user.effectiveDepotId ?? undefined }),
    refetchInterval: 60_000,
  })

  const { data: toolboxTalks = [] } = useQuery({ queryKey: ['toolbox-talks'], queryFn: () => listToolboxTalks({ depotId: user.effectiveDepotId ?? undefined }) })
  const { data: inspections = [] } = useQuery({ queryKey: ['inspections', 'deps'], queryFn: () => listInspections({ depotId: user.effectiveDepotId ?? undefined }) })
  const { data: truckInspections = [] } = useQuery({ queryKey: ['truck-inspections', 'deps'], queryFn: () => listTruckInspections({ depotId: user.effectiveDepotId ?? undefined }) })
  const { data: permits = [] } = useQuery({ queryKey: ['permits', 'deps'], queryFn: () => listPermits({ depotId: user.effectiveDepotId ?? undefined }) })
  const { data: assets = [] } = useQuery({ queryKey: ['assets', 'deps'], queryFn: () => listAssets({ depotId: user.effectiveDepotId ?? undefined }) })
  const { data: personnel = [] } = useQuery({ queryKey: ['personnel', 'deps'], queryFn: () => listPersonnel({ depotId: user.effectiveDepotId ?? undefined }) })

  const context: TaskContext = useMemo(
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
        inspections.some((i) => i.inspection_date === date && (i.title ?? '').toLowerCase().includes('housekeeping')),
    }),
    [toolboxTalks, inspections],
  )

  const views = useTaskVisibility(tasks, history, user, context, prerequisiteDeps)

  const visibleToday = useMemo(
    () => views.filter((v) => v.visible && (tab === 'all' || v.dueToday)).filter((v) => v.task.title.toLowerCase().includes(search.toLowerCase())),
    [views, tab, search],
  )
  const visibleAll = useMemo(
    () => views.filter((v) => v.visible && v.task.title.toLowerCase().includes(search.toLowerCase())),
    [views, search],
  )

  const doneToday = views.filter((v) => v.completedToday && v.dueToday).length
  const dueTodayCount = views.filter((v) => v.dueToday).length
  const compliance = dueTodayCount === 0 ? 0 : Math.round((doneToday / dueTodayCount) * 100)

  const completeMutation = useMutation({
    mutationFn: (input: CompletionInput) =>
      recordTaskCompletion({
        task_id: input.taskId,
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
        latitude: null,
        longitude: null,
      }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['task-history'] }),
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not record completion'),
  })

  // Management view
  if (user.isCountryHead) {
    return (
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold">Routine Tasks</h1>
            <p className="text-sm text-muted-foreground">Analytics view for management</p>
          </div>
          <Button onClick={() => setCreateOpen(true)}>
            <Plus className="mr-1 h-4 w-4" /> New task
          </Button>
        </div>
        <TaskAnalyticsDashboard tasks={tasks} history={history} user={user} depotId={user.effectiveDepotId} />
        <TaskFormDialog open={createOpen} onOpenChange={setCreateOpen} />
      </div>
    )
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">Routine Tasks</h1>
          <p className="text-sm text-muted-foreground">
            {doneToday}/{dueTodayCount} due tasks completed today
          </p>
        </div>
        <div className="relative w-56">
          <Search className="absolute left-2.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search tasks…" className="pl-8" />
        </div>
      </div>

      <Card>
        <CardContent className="pt-6">
          <div className="mb-1 flex items-center justify-between text-sm">
            <span className="font-medium">Today&apos;s compliance</span>
            <span className="font-bold">{compliance}%</span>
          </div>
          <Progress value={compliance} className={compliance >= 80 ? '[&>div]:bg-rag-good' : compliance >= 60 ? '[&>div]:bg-rag-warn' : '[&>div]:bg-rag-bad'} />
        </CardContent>
      </Card>

      <Tabs value={tab} onValueChange={(v) => setTab(v as 'today' | 'all')}>
        <TabsList>
          <TabsTrigger value="today">Today</TabsTrigger>
          <TabsTrigger value="all">All</TabsTrigger>
        </TabsList>

        <TabsContent value="today" className="space-y-2">
          {visibleToday.length === 0 && (
            <p className="py-8 text-center text-sm text-muted-foreground">No tasks due today.</p>
          )}
          {visibleToday.map(({ task, completedToday, blockedReason, occurrencesReported, occurrencesExpected }) => (
            <TaskRow
              key={task.id}
              task={task}
              blockedReason={completedToday ? null : blockedReason}
              completedToday={completedToday}
              occurrencesReported={occurrencesReported}
              occurrencesExpected={occurrencesExpected}
              onComplete={() => setCompleting(task)}
            />
          ))}
        </TabsContent>

        <TabsContent value="all" className="space-y-2">
          {visibleAll.length === 0 && <p className="py-8 text-center text-sm text-muted-foreground">No tasks visible.</p>}
          {visibleAll.map(({ task, completedToday, dueToday, occurrencesReported, occurrencesExpected }) => (
            <TaskRow
              key={task.id}
              task={task}
              dueToday={dueToday}
              blockedReason={completedToday ? null : !dueToday ? null : null}
              completedToday={completedToday}
              occurrencesReported={occurrencesReported}
              occurrencesExpected={occurrencesExpected}
              onComplete={() => setCompleting(task)}
            />
          ))}
        </TabsContent>
      </Tabs>

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

function TaskRow({
  task,
  completedToday,
  blockedReason,
  occurrencesReported,
  occurrencesExpected,
  dueToday,
  onComplete,
}: {
  task: RoutineTask
  completedToday: boolean
  blockedReason?: string | null
  occurrencesReported: number
  occurrencesExpected: number
  dueToday?: boolean
  onComplete: () => void
}) {
  return (
    <div className="flex items-center gap-3 rounded-lg border bg-card p-3">
      <div className="flex-1">
        <div className="flex items-center gap-2">
          <span className="font-medium">{task.title}</span>
          <Badge variant="outline" className="bg-muted text-muted-foreground">{task.task_type.replace(/_/g, ' ')}</Badge>
          {dueToday === false && task.frequency && <Badge variant="outline">{FREQUENCY_LABELS[task.frequency]}</Badge>}
        </div>
        {blockedReason ? (
          <div className="mt-1 flex items-start gap-1.5 text-sm text-amber-700">
            <Lock className="mt-0.5 h-3.5 w-3.5 shrink-0" />
            {blockedReason}
          </div>
        ) : (
          task.description && <div className="mt-0.5 text-sm text-muted-foreground line-clamp-1">{task.description}</div>
        )}
        {occurrencesLabel(occurrencesReported, occurrencesExpected)}
      </div>
      {completedToday ? (
        <span className="flex items-center gap-1 text-sm font-medium text-rag-good">
          <CheckCircle2 className="h-4 w-4" /> Done
        </span>
      ) : (
        <Button size="sm" variant={blockedReason ? 'secondary' : 'default'} disabled={Boolean(blockedReason)} onClick={onComplete}>
          Complete
        </Button>
      )}
    </div>
  )
}

function occurrencesLabel(reported: number, expected: number) {
  if (expected > 1) {
    return <div className="mt-0.5 text-xs text-muted-foreground">{reported} of {expected} occurrences completed today</div>
  }
  return null
}