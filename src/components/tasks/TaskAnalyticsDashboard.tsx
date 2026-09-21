import { useMemo, useState } from 'react'
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Line,
  LineChart,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { StatusBadge } from '@/components/shared'
import { taskIsVisibleToUser } from '@/hooks/useTaskVisibility'
import type { CurrentUser } from '@/hooks/useCurrentUser'
import type { RoutineTask, TaskHistory } from '@/types/entities'
import CompletionDetailModal from './CompletionDetailModal'
import { PersonnelScorecard } from './PersonnelScorecard'
import { startOfDayISO } from '@/lib/utils'
import { subDays } from 'date-fns'
import { pushByDepot, pushByUser } from './analyticsUtils'

type Period = '30D' | '90D' | '12M'

interface TaskAnalyticsDashboardProps {
  tasks: RoutineTask[]
  history: TaskHistory[]
  user: Pick<CurrentUser, 'userId' | 'effectiveDepotId' | 'role'>
  depotId: string | null
}

export default function TaskAnalyticsDashboard({ tasks, history, user, depotId: _depotId }: TaskAnalyticsDashboardProps) {
  const [period, setPeriod] = useState<Period>('30D')
  const [detail, setDetail] = useState<TaskHistory | null>(null)

  const filtered = useMemo(() => {
    const dayCut = period === '30D' ? subDays(new Date(), 30) : period === '90D' ? subDays(new Date(), 90) : subDays(new Date(), 365)
    const cut = startOfDayISO(dayCut)
    return history.filter((h) => h.completed_at.slice(0, 10) >= cut)
  }, [history, period])

  const visibleTasks = useMemo(
    () => tasks.filter((t) => taskIsVisibleToUser(t, user)),
    [tasks, user],
  )

  const byDepot = useMemo(() => pushByDepot(filtered), [filtered])
  const byUser = useMemo(() => pushByUser(filtered), [filtered])
  const byDay = useMemo(() => {
    const map = new Map<string, number>()
    for (const h of filtered) {
      const d = h.completed_at.slice(0, 10)
      map.set(d, (map.get(d) ?? 0) + h.occurrences)
    }
    return Array.from(map.entries())
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([date, count]) => ({ date, count }))
  }, [filtered])

  const taskRates = useMemo(
    () =>
      visibleTasks.map((t) => {
        const done = filtered.filter((h) => h.task_id === t.id)
        const count = t.task_type === 'MANUAL' || t.task_type === 'FORM' ? 0 : t.expected_occurrences ?? 1
        const expected = count + done.length > 0 ? done.length + 1 : 1
        return {
          id: t.id,
          title: t.title,
          completions: done.length,
          expected: expected,
        }
      }),
    [visibleTasks, filtered],
  )

  const compliance = useMemo(() => {
    const total = taskRates.reduce((a, r) => a + r.expected, 0)
    const done = taskRates.reduce((a, r) => a + r.completions, 0)
    return total === 0 ? 0 : Math.round((done / total) * 100)
  }, [taskRates])

  const completed = filtered.length
  const overdue = visibleTasks.filter((t) => t.is_active && new Date(t.start_date) <= new Date()).length
  const pending = Math.max(0, taskRates.reduce((a, r) => a + Math.max(0, r.expected - r.completions), 0))

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex gap-1 rounded-md border">
          {(['30D', '90D', '12M'] as Period[]).map((p) => (
            <Button key={p} size="sm" variant={period === p ? 'default' : 'ghost'} onClick={() => setPeriod(p)}>
              {p}
            </Button>
          ))}
        </div>
        <div className="flex items-center gap-2 text-sm">
          <span className="font-semibold">{compliance}%</span> compliance
        </div>
      </div>

      <Tabs defaultValue="completion" className="w-full">
        <TabsList className="flex-wrap">
          <TabsTrigger value="completion">Completion</TabsTrigger>
          <TabsTrigger value="breakdown">Breakdown</TabsTrigger>
          <TabsTrigger value="trend">Trend</TabsTrigger>
          <TabsTrigger value="scorecard">Scorecards</TabsTrigger>
          <TabsTrigger value="recent">Recent completions</TabsTrigger>
        </TabsList>

        <TabsContent value="completion" className="space-y-4">
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
            <Card><CardContent className="pt-6 text-center"><div className="text-3xl font-bold text-rag-good">{completed}</div><div className="text-sm text-muted-foreground">Completed</div></CardContent></Card>
            <Card><CardContent className="pt-6 text-center"><div className="text-3xl font-bold text-amber-accent">{pending}</div><div className="text-sm text-muted-foreground">Pending</div></CardContent></Card>
            <Card><CardContent className="pt-6 text-center"><div className="text-3xl font-bold text-rag-bad">{overdue}</div><div className="text-sm text-muted-foreground">Overdue</div></CardContent></Card>
          </div>
          <Card>
            <CardHeader><CardTitle className="text-base">Completion by task</CardTitle></CardHeader>
            <CardContent className="h-64">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={taskRates}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="title" hide />
                  <Tooltip />
                  <Legend />
                  <Bar dataKey="completions" fill="#22c55e" name="Completed" />
                  <Bar dataKey="expected" fill="#e5e7eb" name="Expected" />
                </BarChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="breakdown" className="grid grid-cols-1 gap-4 lg:grid-cols-2">
          <Card>
            <CardHeader><CardTitle className="text-base">By person</CardTitle></CardHeader>
            <CardContent className="h-64">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie data={byUser} dataKey="value" nameKey="name" cx="50%" cy="50%" outerRadius={90} label>
                    {byUser.map((_, i) => <Cell key={i} fill={['#cc0000', '#f59e0b', '#22c55e', '#3b82f6', '#a855f7', '#64748b'][i % 6]} />)}
                  </Pie>
                  <Tooltip />
                </PieChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
          <Card>
            <CardHeader><CardTitle className="text-base">By depot</CardTitle></CardHeader>
            <CardContent className="h-64">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={byDepot}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="name" />
                  <YAxis allowDecimals={false} />
                  <Tooltip />
                  <Bar dataKey="value" fill="#cc0000" name="Completions" />
                </BarChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="trend">
          <Card>
            <CardHeader><CardTitle className="text-base">Completions over time</CardTitle></CardHeader>
            <CardContent className="h-72">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={byDay}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="date" />
                  <YAxis allowDecimals={false} />
                  <Tooltip />
                  <Line type="monotone" dataKey="count" stroke="#cc0000" dot={false} name="Completions" />
                </LineChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="scorecard">
          <PersonnelScorecard history={filtered} />
        </TabsContent>

        <TabsContent value="recent">
          <Card>
            <CardHeader><CardTitle className="text-base">Recent completions</CardTitle></CardHeader>
            <CardContent>
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Task</TableHead>
                    <TableHead>User</TableHead>
                    <TableHead>Time</TableHead>
                    <TableHead>Occurrences</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filtered.slice(0, 50).map((h) => {
                    const task = visibleTasks.find((t) => t.id === h.task_id)
                    return (
                      <TableRow key={h.id} className="cursor-pointer" onClick={() => setDetail(h)}>
                        <TableCell className="font-medium">{task?.title ?? h.task_id.slice(0, 8)}</TableCell>
                        <TableCell>{h.actor_name ?? '—'}</TableCell>
                        <TableCell>{h.completed_at.slice(0, 16).replace('T', ' ')}</TableCell>
                        <TableCell><StatusBadge status="COMPLETED" /> {h.occurrences}/{h.expected_occurrences ?? h.occurrences}</TableCell>
                      </TableRow>
                    )
                  })}
                  {filtered.length === 0 && (
                    <TableRow><TableCell colSpan={4} className="text-center text-muted-foreground">No completions in this period</TableCell></TableRow>
                  )}
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>

      <CompletionDetailModal record={detail} task={detail ? visibleTasks.find((t) => t.id === detail!.task_id) ?? null : null} open={Boolean(detail)} onOpenChange={(o) => { if (!o) setDetail(null) }} />
    </div>
  )
}