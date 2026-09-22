import { useEffect, useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Clock, Plus, Download } from 'lucide-react'
import { toast } from 'sonner'
import ExcelJS from 'exceljs'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { CardContent } from '@/components/ui/card'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { PageHeader, EmptyState, SectionCard, KPICard } from '@/components/shared'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { useDepotFilter } from '@/hooks/useDepotFilter'
import { listManHours, upsertManHours, deleteManHours, safetyRates } from '@/services/manHours.service'
import { listDepots } from '@/services/depots.service'
import { formatDate } from '@/lib/utils'
import type { ManHourRecord } from '@/types/entities'

function currentPeriod(): { start: string; end: string } {
  const now = new Date()
  if (now.getDate() >= 20) {
    const end = new Date(now.getFullYear(), now.getMonth() + 1, 19)
    return { start: now.toISOString().slice(0, 10), end: end.toISOString().slice(0, 10) }
  }
  const start = new Date(now.getFullYear(), now.getMonth() - 1, 20)
  return { start: start.toISOString().slice(0, 10), end: now.toISOString().slice(0, 10) }
}

const FIELD_ORDER: { key: keyof ManHourRecord; label: string }[] = [
  { key: 'employees_scheduled', label: 'Scheduled' },
  { key: 'employees_present', label: 'Present' },
  { key: 'hours_worked', label: 'Hours worked' },
  { key: 'overtime_hours', label: 'Overtime hrs' },
  { key: 'lost_time_injuries', label: 'LTI' },
  { key: 'first_aid_cases', label: 'First aid' },
  { key: 'medical_treatment_cases', label: 'MT cases' },
  { key: 'near_misses', label: 'Near misses' },
  { key: 'recordable_incidents', label: 'Recordables' },
  { key: 'days_lost', label: 'Days lost' },
]

export default function ManHours() {
  const user = useCurrentUser()
  const { depotId } = useDepotFilter()
  const queryClient = useQueryClient()
  const [creating, setCreating] = useState(false)
  const [editing, setEditing] = useState<ManHourRecord | null>(null)

  const { data: records = [] } = useQuery({ queryKey: ['man-hours', depotId ?? 'all'], queryFn: () => listManHours(depotId ? { depotId } : {}) })
  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const depotName = (id: string | null) => depots.find((d) => d.id === id)?.name ?? '—'

  const scoped = user.isCountryHead ? records : records.filter((r) => r.depot_id === user.effectiveDepotId)
  const totalHours = scoped.reduce((acc, r) => acc + (Number(r.hours_worked) || 0), 0)
  const recInc = scoped.reduce((acc, r) => acc + (Number(r.recordable_incidents) || 0), 0)
  const lti = scoped.reduce((acc, r) => acc + (Number(r.lost_time_injuries) || 0), 0)
  const { trir, ltifr } = useMemo(
    () => safetyRates({ hours_worked: totalHours, recordable_incidents: recInc, lost_time_injuries: lti }),
    [totalHours, recInc, lti],
  )

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['man-hours'] })

  const save = useMutation({
    mutationFn: upsertManHours,
    onSuccess: () => {
      toast.success(editing ? 'Record updated' : 'Man-hours recorded')
      setCreating(false)
      setEditing(null)
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not save record'),
  })

  const del = useMutation({
    mutationFn: deleteManHours,
    onSuccess: () => {
      toast.success('Record deleted')
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not delete record'),
  })

  const exportExcel = async () => {
    const wb = new ExcelJS.Workbook()
    wb.creator = 'SafeDepot Pro'
    const ws = wb.addWorksheet('Man-hours')
    ws.columns = [{ header: 'Depot', key: 'depot' }, ...FIELD_ORDER.map((f) => ({ header: f.label, key: f.key as string })), { header: 'Period start', key: 'ps' }, { header: 'Period end', key: 'pe' }]
    scoped.forEach((r) =>
      ws.addRow({
        depot: depotName(r.depot_id),
        ...Object.fromEntries(FIELD_ORDER.map((f) => [f.key, r[f.key] ?? 0])),
        ps: r.period_start,
        pe: r.period_end,
      }),
    )
    ws.getRow(1).font = { bold: true }
    ws.columns.forEach((c, i) => {
      ws.getColumn(i + 1).width = Math.min(18, Math.max(10, String(c.header ?? '').length + 4))
    })
    const buf = Buffer.from(await wb.xlsx.writeBuffer())
    const url = URL.createObjectURL(new Blob([buf]))
    const a = document.createElement('a')
    a.href = url
    a.download = 'man_hours_export.xlsx'
    a.click()
    URL.revokeObjectURL(url)
  }

  const setOpen = (v: boolean) => {
    if (!v) {
      setCreating(false)
      setEditing(null)
    }
  }

  return (
    <div className="space-y-8">
      <PageHeader
        title="Man Hours & Safety Rates"
        subtitle={`${totalHours.toLocaleString()} exposure hours tracked`}
        actions={
          <>
            <Button variant="outline" onClick={() => void exportExcel()}><Download className="mr-1 h-4 w-4" /> Export</Button>
            <Button onClick={() => setCreating(true)}><Plus className="mr-1 h-4 w-4" /> Record man-hours</Button>
          </>
        }
      />

      <div className="grid grid-cols-1 gap-6 sm:grid-cols-3">
        <KPICard icon={<Clock className="h-4 w-4" />} iconHue="blue" label="Exposure hours" value={totalHours.toLocaleString()} />
        <KPICard icon={<Clock className="h-4 w-4" />} iconHue="amber" label="TRIR" value={trir.toFixed(2)} />
        <KPICard icon={<Clock className="h-4 w-4" />} iconHue="red" label="LTIFR" value={ltifr.toFixed(2)} />
      </div>

      {scoped.length === 0 ? (
        <EmptyState title="No man-hour records" description="Record monthly man-hours to keep TRIR and LTIFR accurate." />
      ) : (
        <SectionCard title="Monthly records">
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Depot</TableHead>
                  <TableHead className="hidden md:table-cell">Period</TableHead>
                  <TableHead>{FIELD_ORDER[0].label}</TableHead>
                  <TableHead>{FIELD_ORDER[2].label}</TableHead>
                  <TableHead>{FIELD_ORDER[4].label}</TableHead>
                  <TableHead>{FIELD_ORDER[8].label}</TableHead>
                  <TableHead className="w-24">{/* actions */}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {scoped.map((r) => {
                  const rates = safetyRates(r)
                  return (
                    <TableRow key={r.id} onClick={() => setEditing(r)} className="cursor-pointer">
                      <TableCell className="font-medium">{depotName(r.depot_id)}</TableCell>
                      <TableCell className="hidden md:table-cell text-xs">{formatDate(r.period_start)} → {formatDate(r.period_end)}</TableCell>
                      <TableCell>{r.employees_scheduled}</TableCell>
                      <TableCell>{Number(r.hours_worked).toLocaleString()}</TableCell>
                      <TableCell>{r.lost_time_injuries}</TableCell>
                      <TableCell>{r.recordable_incidents}</TableCell>
                      <TableCell className="text-right">
                        <div className="flex justify-end gap-1">
                          <span className="text-[11px] text-muted-foreground">TRIR {rates.trir.toFixed(1)}</span>
                          <Button size="sm" variant="ghost" className="h-7 px-2 text-rag-bad" onClick={(e) => { e.stopPropagation(); del.mutate(r.id) }}>
                            ×
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  )
                })}
              </TableBody>
            </Table>
          </CardContent>
        </SectionCard>
      )}

      <ManHourForm
        open={creating || editing !== null}
        onOpenChange={setOpen}
        record={editing}
        userId={user.userId ?? 'anon'}
        defaultDepotId={user.effectiveDepotId ?? undefined}
        depotName={depotName}
        onSave={(input) => save.mutate(input)}
      />
    </div>
  )
}

function ManHourForm({
  open,
  onOpenChange,
  record,
  userId,
  defaultDepotId,
  depotName,
  onSave,
}: {
  open: boolean
  onOpenChange: (v: boolean) => void
  record: ManHourRecord | null
  userId: string
  defaultDepotId?: string
  depotName: (id: string | null) => string
  onSave: (input: Partial<ManHourRecord>) => void
}) {
  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const period = currentPeriod()
  const [depotId, setDepotId] = useState(defaultDepotId ?? '')
  const [start, setStart] = useState(period.start)
  const [end, setEnd] = useState(period.end)
  const [values, setValues] = useState<Record<string, number>>({})

  useEffect(() => {
    if (!open) return
    setDepotId(record?.depot_id ?? defaultDepotId ?? '')
    setStart(record?.period_start ?? period.start)
    setEnd(record?.period_end ?? period.end)
    setValues(Object.fromEntries(FIELD_ORDER.map((f) => [f.key, Number(record?.[f.key]) || 0])))
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, record])

  const submit = () => {
    if (!depotId) return toast.error('Depot is required.')
    if (!start || !end) return toast.error('Period dates are required.')
    onSave({
      depot_id: depotId,
      period_start: start,
      period_end: end,
      created_by: record?.created_by ?? userId,
      ...Object.fromEntries(FIELD_ORDER.map((f) => [f.key, values[f.key] ?? 0])),
    })
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[92vh] overflow-y-auto">
        <DialogHeader><DialogTitle>{record ? 'Edit man-hour record' : 'Record man-hours'}</DialogTitle></DialogHeader>
        <div className="space-y-4">
          <div className="grid gap-3 sm:grid-cols-3">
            <Field label="Depot *">
              <Select value={depotId} onValueChange={setDepotId}>
                <SelectTrigger><SelectValue placeholder={depotName(depotId) || 'Select'} /></SelectTrigger>
                <SelectContent>{depots.map((d) => <SelectItem key={d.id} value={d.id}>{d.name}</SelectItem>)}</SelectContent>
              </Select>
            </Field>
            <Field label="Period start"><Input type="date" value={start} onChange={(e) => setStart(e.target.value)} /></Field>
            <Field label="Period end"><Input type="date" value={end} onChange={(e) => setEnd(e.target.value)} /></Field>
          </div>
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
            {FIELD_ORDER.map((f) => (
              <Field key={f.key} label={f.label}>
                <Input type="number" min={0} value={values[f.key] ?? 0} onChange={(e) => setValues((prev) => ({ ...prev, [f.key]: Number(e.target.value) || 0 }))} />
              </Field>
            ))}
          </div>
          <DialogFooter>
            <Button variant="ghost" onClick={() => onOpenChange(false)}>Cancel</Button>
            <Button onClick={submit}>{record ? 'Save changes' : 'Save record'}</Button>
          </DialogFooter>
        </div>
      </DialogContent>
    </Dialog>
  )
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="space-y-1.5">
      <Label className="text-sm font-medium text-muted-foreground">{label}</Label>
      {children}
    </div>
  )
}