import { useEffect, useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ClipboardCheck, Plus, Eye } from 'lucide-react'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { CardContent } from '@/components/ui/card'
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { PageHeader, EmptyState, SectionCard, KPICard, StatusBadge } from '@/components/shared'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { useDepotFilter } from '@/hooks/useDepotFilter'
import ChecklistRenderer, { type CheckedAnswers } from '@/components/inspections/ChecklistRenderer'
import { listChecklistTemplates, listInspections, createInspection, computeCompliance } from '@/services/inspections.service'
import { listDepots } from '@/services/depots.service'
import { formatDate, cn } from '@/lib/utils'
import type { ChecklistTemplate, Inspection, InspectionAnswer } from '@/types/entities'

export default function Inspections() {
  const user = useCurrentUser()
  const { depotId } = useDepotFilter()
  const queryClient = useQueryClient()
  const [creating, setCreating] = useState(false)
  const [viewing, setViewing] = useState<Inspection | null>(null)

  const { data: inspections = [] } = useQuery({ queryKey: ['inspections', depotId ?? 'all'], queryFn: () => listInspections(depotId ? { depotId } : {}) })
  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const depotName = (id: string | null) => depots.find((d) => d.id === id)?.name ?? '—'

  const scoped = useMemo(
    () => (user.isCountryHead ? inspections : inspections.filter((i) => i.depot_id === user.effectiveDepotId)),
    [inspections, user],
  )
  const done = scoped.filter((i) => i.status === 'SUBMITTED' || i.status === 'APPROVED' || i.status === 'CLOSED').length
  const avg = scoped.length === 0 ? 0 : Math.round(scoped.reduce((acc, i) => acc + (i.compliance_percentage ?? 0), 0) / scoped.length)

  const save = useMutation({
    mutationFn: createInspection,
    onSuccess: () => {
      toast.success('Inspection saved')
      queryClient.invalidateQueries({ queryKey: ['inspections'] })
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not save inspection'),
  })

  return (
    <div className="space-y-8">
      <PageHeader
        title="Inspections"
        subtitle={`${scoped.length} inspections · ${avg}% average compliance`}
        actions={<Button onClick={() => setCreating(true)}><Plus className="mr-1 h-4 w-4" /> New inspection</Button>}
      />

      <div className="grid grid-cols-1 gap-6 sm:grid-cols-3">
        <KPICard icon={<ClipboardCheck className="h-4 w-4" />} iconHue="green" label="Completed" value={done} />
        <KPICard icon={<ClipboardCheck className="h-4 w-4" />} iconHue="blue" label="Average compliance" value={`${avg}%`} />
        <KPICard icon={<ClipboardCheck className="h-4 w-4" />} iconHue="slate" label="Total" value={scoped.length} />
      </div>

      {scoped.length === 0 ? (
        <EmptyState title="No inspections" description="Create a site inspection from a checklist template and capture evidence as you go." />
      ) : (
        <SectionCard title="Inspection register">
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Date</TableHead>
                  <TableHead>Title</TableHead>
                  <TableHead className="hidden md:table-cell">Depot</TableHead>
                  <TableHead>Compliance</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="w-20">{/* actions */}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {scoped.map((i) => (
                  <TableRow key={i.id}>
                    <TableCell>{formatDate(i.inspection_date)}</TableCell>
                    <TableCell className="max-w-[14rem]"><span className="line-clamp-1 font-medium">{i.title ?? 'Inspection'}</span></TableCell>
                    <TableCell className="hidden md:table-cell">{depotName(i.depot_id)}</TableCell>
                    <TableCell>
                      <ComplianceCell value={i.compliance_percentage ?? 0} />
                    </TableCell>
                    <TableCell><StatusBadge status={i.status} /></TableCell>
                    <TableCell>
                      <Button size="sm" variant="outline" className="h-7 text-xs" onClick={() => setViewing(i)}>
                        <Eye className="mr-1 h-3.5 w-3.5" /> View
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </SectionCard>
      )}

      <InspectionForm
        open={creating}
        onOpenChange={setOpen}
        userId={user.userId ?? 'anon'}
        userName={user.fullName}
        defaultDepotId={user.effectiveDepotId ?? undefined}
        depotName={depotName}
        onSave={(input) => save.mutateAsync(input)}
      />

      <InspectionDetail inspection={viewing} onClose={() => setViewing(null)} />
    </div>
  )

  function setOpen(v: boolean) {
    setCreating(v)
  }
}

function InspectionForm({
  open,
  onOpenChange,
  userId,
  userName,
  defaultDepotId,
  depotName,
  onSave,
}: {
  open: boolean
  onOpenChange: (v: boolean) => void
  userId: string
  userName: string
  defaultDepotId?: string
  depotName: (id: string | null) => string
  onSave: (input: Partial<Inspection>) => Promise<unknown>
}) {
  const { data: templates = [] } = useQuery({ queryKey: ['templates-HSE'], queryFn: () => listChecklistTemplates('HSE') })
  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const [depotId, setDepotId] = useState(defaultDepotId ?? '')
  const [templateId, setTemplateId] = useState('')
  const [title, setTitle] = useState('')
  const [inspectionDate, setInspectionDate] = useState(new Date().toISOString().slice(0, 10))
  const [answers, setAnswers] = useState<CheckedAnswers>({})
  const [overallNote, setOverallNote] = useState('')
  const [busy, setBusy] = useState(false)

  const template = templates.find((t) => t.id === templateId) as ChecklistTemplate | undefined

  useEffect(() => {
    if (!open) return
    setDepotId(defaultDepotId ?? '')
    setTemplateId('')
    setTitle('')
    setInspectionDate(new Date().toISOString().slice(0, 10))
    setAnswers({})
    setOverallNote('')
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open])

  const submit = async (status: Inspection['status']) => {
    if (!depotId) return toast.error('Depot is required.')
    if (!template) return toast.error('Choose a checklist template.')
    const answersArr = Object.values(answers).map((a) => a as InspectionAnswer)
    const compliance = computeCompliance(answersArr)
    setBusy(true)
    try {
      await onSave({
        template_id: template.id,
        depot_id: depotId,
        title: title.trim() || template.title,
        inspection_date: inspectionDate,
        inspector_user_id: userId,
        inspector_name: userName,
        status,
        answers: answersArr,
        compliance_percentage: compliance,
        overall_note: overallNote || null,
      })
      onOpenChange(false)
    } catch {
      // toast handled by parent mutation
    } finally {
      setBusy(false)
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-3xl max-h-[92vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>New inspection</DialogTitle>
        </DialogHeader>
        <div className="space-y-4">
          <div className="grid gap-3 sm:grid-cols-3">
            <div className="space-y-1.5">
              <Label className="text-sm font-medium text-muted-foreground">Depot *</Label>
              <Select value={depotId} onValueChange={setDepotId}>
                <SelectTrigger><SelectValue placeholder={depotName(depotId) || 'Select'} /></SelectTrigger>
                <SelectContent>{depots.map((d) => <SelectItem key={d.id} value={d.id}>{d.name} ({d.code})</SelectItem>)}</SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label className="text-sm font-medium text-muted-foreground">Template *</Label>
              <Select value={templateId} onValueChange={(v) => { setTemplateId(v); setAnswers({}) }}>
                <SelectTrigger><SelectValue placeholder="Choose template" /></SelectTrigger>
                <SelectContent>{templates.map((t) => <SelectItem key={t.id} value={t.id}>{t.title}</SelectItem>)}</SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label className="text-sm font-medium text-muted-foreground">Date</Label>
              <Input type="date" value={inspectionDate} onChange={(e) => setInspectionDate(e.target.value)} />
            </div>
          </div>
          <div className="space-y-1.5">
            <Label className="text-sm font-medium text-muted-foreground">Title</Label>
            <Input value={title} onChange={(e) => setTitle(e.target.value)} placeholder={template?.title ?? 'Inspection title'} />
          </div>

          {template ? (
            <>
              <ChecklistRenderer sections={template.sections} answers={answers} onChange={setAnswers} />
              <div className="space-y-1.5">
                <Label className="text-sm font-medium text-muted-foreground">Overall note</Label>
                <Textarea rows={2} value={overallNote} onChange={(e) => setOverallNote(e.target.value)} />
              </div>
              <div className="flex justify-end gap-2">
                <Button variant="ghost" onClick={() => onOpenChange(false)}>Cancel</Button>
                <Button variant="outline" disabled={busy} onClick={() => void submit('DRAFT')}>Save draft</Button>
                <Button disabled={busy} onClick={() => void submit('SUBMITTED')}>Submit inspection</Button>
              </div>
            </>
          ) : (
            <p className="text-sm text-muted-foreground">Choose a template to begin the checklist.</p>
          )}
        </div>
      </DialogContent>
    </Dialog>
  )
}

function InspectionDetail({ inspection, onClose }: { inspection: Inspection | null; onClose: () => void }) {
  const [answers, setAnswers] = useState<CheckedAnswers>({})
  const { data: templates = [] } = useQuery({ queryKey: ['templates-HSE'], queryFn: () => listChecklistTemplates('HSE') })
  const template = templates.find((t) => t.id === inspection?.template_id)

  useEffect(() => {
    setAnswers((inspection?.answers ?? []).reduce<CheckedAnswers>((acc, a) => {
      acc[a.question_id] = a
      return acc
    }, {}))
  }, [inspection])

  return (
    <Dialog open={Boolean(inspection)} onOpenChange={(v) => { if (!v) onClose() }}>
      <DialogContent className="max-w-3xl max-h-[92vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{inspection?.title ?? 'Inspection'}</DialogTitle>
        </DialogHeader>
        {inspection && (
          <div className="space-y-4">
            <div className="flex items-center justify-between text-sm text-muted-foreground">
              <span>{formatDate(inspection.inspection_date)} · {inspection.inspector_name ?? '—'}</span>
              <StatusBadge status={inspection.status} />
            </div>
            {template && <ChecklistRenderer sections={template.sections} answers={answers} onChange={setAnswers} readOnly />}
          </div>
        )}
      </DialogContent>
    </Dialog>
  )
}

function ComplianceCell({ value }: { value: number }) {
  return (
    <div className="flex items-center gap-2">
      <div className="h-2 w-16 overflow-hidden rounded-full bg-muted">
        <div className={cn('h-full rounded-full', value >= 85 ? 'bg-rag-good' : value >= 70 ? 'bg-rag-warn' : 'bg-rag-bad')} style={{ width: `${Math.min(100, value)}%` }} />
      </div>
      <span className="text-xs font-medium">{value}%</span>
    </div>
  )
}