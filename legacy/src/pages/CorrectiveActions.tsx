import { useEffect, useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Wrench, Plus, CheckCircle2, Camera } from 'lucide-react'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { CardContent } from '@/components/ui/card'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { PageHeader, EmptyState, SectionCard, StatusBadge, PriorityBadge, KPICard } from '@/components/shared'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { useDepotFilter } from '@/hooks/useDepotFilter'
import CameraModal, { type CapturedPhoto } from '@/components/CameraModal'
import SignaturePad from '@/components/SignaturePad'
import { listCapas, createCapa, completeCapaRecord, nextCapaNumber } from '@/services/capa.service'
import { listPersonnel } from '@/services/personnel.service'
import { listDepots } from '@/services/depots.service'
import { storage } from '@/services/storage.service'
import { formatDate, todayIso } from '@/lib/utils'
import { PRIORITY_LABELS } from '@/lib/labels'
import type { CapaRecord } from '@/types/entities'
import type { Priority, SourceType } from '@/types/enums'

const SOURCES: { value: SourceType; label: string }[] = [
  { value: 'STANDALONE', label: 'Standalone' },
  { value: 'INCIDENT', label: 'Incident' },
  { value: 'INSPECTION', label: 'Inspection' },
  { value: 'HAZARD', label: 'Hazard' },
]

export default function CorrectiveActions() {
  const user = useCurrentUser()
  const { depotId } = useDepotFilter()
  const queryClient = useQueryClient()
  const [creating, setCreating] = useState(false)
  const [completing, setCompleting] = useState<CapaRecord | null>(null)

  const { data: capas = [] } = useQuery({ queryKey: ['capa', depotId ?? 'all'], queryFn: () => listCapas(depotId ? { depotId } : {}) })

  const scoped = useMemo(
    () => (user.isCountryHead ? capas : capas.filter((c) => c.depot_id === user.effectiveDepotId || c.responsible_user_id === user.userId)),
    [capas, user],
  )
  const openCount = scoped.filter((c) => !['CLOSED', 'CANCELLED'].includes(c.status)).length
  const overdue = scoped.filter((c) => c.due_date && c.due_date < todayIso() && !['CLOSED', 'CANCELLED'].includes(c.status)).length
  const completionRate = scoped.length === 0 ? 0 : Math.round((scoped.filter((c) => c.status === 'CLOSED').length / scoped.length) * 100)

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['capa'] })

  const save = useMutation({
    mutationFn: async (input: Partial<CapaRecord>) => createCapa({ ...input, capa_number: input.capa_number ?? (await nextCapaNumber()) }),
    onSuccess: () => {
      toast.success('CAPA created')
      setCreating(false)
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not create CAPA'),
  })

  const completeMut = useMutation({
    mutationFn: (v: { id: string; proof_paths: string[]; signature_path: string | null }) => completeCapaRecord(v.id, v),
    onSuccess: () => {
      toast.success('CAPA completed')
      setCompleting(null)
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not complete CAPA'),
  })

  const canComplete = (c: CapaRecord) => c.responsible_user_id === user.userId || user.isManagement

  return (
    <div className="space-y-8">
      <PageHeader
        title="Corrective Actions (CAPA)"
        subtitle={`${openCount} open · ${overdue} overdue`}
        actions={
          user.isCountryHead ? (
            <Button onClick={() => setCreating(true)}><Plus className="mr-1 h-4 w-4" /> New CAPA</Button>
          ) : undefined
        }
      />

      <div className="grid grid-cols-1 gap-6 sm:grid-cols-3">
        <KPICard icon={<Wrench className="h-4 w-4" />} iconHue="purple" label="Open CAPA" value={openCount} tone={openCount > 0 ? 'warn' : 'good'} />
        <KPICard icon={<Wrench className="h-4 w-4" />} iconHue="red" label="Overdue" value={overdue} tone={overdue > 0 ? 'bad' : 'good'} />
        <KPICard icon={<CheckCircle2 className="h-4 w-4" />} iconHue="green" label="Completion rate" value={`${completionRate}%`} tone={completionRate >= 80 ? 'good' : completionRate >= 60 ? 'warn' : 'bad'} />
      </div>

      {scoped.length === 0 ? (
        <EmptyState title="No CAPA records" description="Corrective and preventive actions close out incidents, hazards and inspection findings." />
      ) : (
        <SectionCard title="CAPA register">
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-28">Number</TableHead>
                  <TableHead>Title</TableHead>
                  <TableHead>Source</TableHead>
                  <TableHead>Priority</TableHead>
                  <TableHead className="hidden md:table-cell">Responsible</TableHead>
                  <TableHead className="hidden lg:table-cell">Due</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="w-24">{/* action */}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {scoped.map((c) => (
                  <TableRow key={c.id}>
                    <TableCell className="font-mono text-xs font-medium">{c.capa_number}</TableCell>
                    <TableCell>
                      <div className="line-clamp-1 max-w-[16rem] font-medium">{c.title}</div>
                      {c.due_date && c.due_date < todayIso() && c.status !== 'CLOSED' && <div className="text-xs text-rag-bad">Overdue</div>}
                    </TableCell>
                    <TableCell><StatusBadge status={c.source_type} /></TableCell>
                    <TableCell><PriorityBadge priority={c.priority} /></TableCell>
                    <TableCell className="hidden md:table-cell">{c.responsible_name ?? '—'}</TableCell>
                    <TableCell className="hidden lg:table-cell">{c.due_date ? formatDate(c.due_date) : '—'}</TableCell>
                    <TableCell><StatusBadge status={c.status} /></TableCell>
                    <TableCell>
                      {c.status !== 'CLOSED' && canComplete(c) ? (
                        <Button size="sm" variant="outline" className="h-7 text-xs" onClick={() => setCompleting(c)}>
                          Complete
                        </Button>
                      ) : null}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </SectionCard>
      )}

      <CapaForm
        open={creating}
        onOpenChange={setCreating}
        userId={user.userId ?? 'anon'}
        userName={user.fullName}
        defaultDepotId={user.effectiveDepotId ?? undefined}
        onSave={(input) => save.mutate(input)}
        saving={save.isPending}
      />

      <CompleteDialog
        capa={completing}
        userId={user.userId ?? 'anon'}
        onOpenChange={(v) => {
          if (!v) setCompleting(null)
        }}
        onComplete={(proofs, signature) => {
          if (completing) completeMut.mutate({ id: completing.id, proof_paths: proofs, signature_path: signature })
        }}
        saving={completeMut.isPending}
      />
    </div>
  )
}

function CapaForm({
  open,
  onOpenChange,
  userId,
  userName,
  defaultDepotId,
  onSave,
  saving,
}: {
  open: boolean
  onOpenChange: (v: boolean) => void
  userId: string
  userName: string
  defaultDepotId?: string
  onSave: (input: Partial<CapaRecord>) => void
  saving: boolean
}) {
  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const { data: personnel = [] } = useQuery({ queryKey: ['personnel', 'active'], queryFn: () => listPersonnel() })
  const [depotId, setDepotId] = useState(defaultDepotId ?? '')
  const [title, setTitle] = useState('')
  const [source, setSource] = useState<SourceType>('STANDALONE')
  const [description, setDescription] = useState('')
  const [rootCause, setRootCause] = useState('')
  const [correctiveAction, setCorrectiveAction] = useState('')
  const [responsible, setResponsible] = useState('')
  const [priority, setPriority] = useState<Priority>('MEDIUM')
  const [dueDate, setDueDate] = useState('')

  useEffect(() => {
    if (open) {
      setDepotId(defaultDepotId ?? '')
      setTitle('')
      setSource('STANDALONE')
      setDescription('')
      setRootCause('')
      setCorrectiveAction('')
      setResponsible('')
      setPriority('MEDIUM')
      setDueDate('')
    }
  }, [open, defaultDepotId])

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!depotId) return toast.error('Depot is required.')
    if (!title.trim()) return toast.error('Title is required.')
    if (!correctiveAction.trim()) return toast.error('Corrective action is required.')
    const person = personnel.find((p) => p.id === responsible)
    onSave({
      depot_id: depotId,
      title: title.trim(),
      source_type: source,
      description: description || null,
      root_cause: rootCause || null,
      corrective_action: correctiveAction.trim(),
      responsible_user_id: person?.user_id ?? null,
      responsible_name: person ? `${person.first_name} ${person.last_name}`.trim() : null,
      assigner_user_id: userId,
      assigner_name: userName,
      priority,
      due_date: dueDate || null,
      status: 'OPEN',
    })
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-lg max-h-[90vh] overflow-y-auto">
        <DialogHeader><DialogTitle>New CAPA</DialogTitle></DialogHeader>
        <form onSubmit={submit} className="space-y-3">
          <Field label="Depot *">
            <Select value={depotId} onValueChange={setDepotId}>
              <SelectTrigger><SelectValue /></SelectTrigger>
              <SelectContent>{depots.map((d) => <SelectItem key={d.id} value={d.id}>{d.name} ({d.code})</SelectItem>)}</SelectContent>
            </Select>
          </Field>
          <div className="grid gap-3 sm:grid-cols-2">
            <Field label="Source">
              <Select value={source} onValueChange={(v) => setSource(v as SourceType)}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>{SOURCES.map((s) => <SelectItem key={s.value} value={s.value}>{s.label}</SelectItem>)}</SelectContent>
              </Select>
            </Field>
            <Field label="Priority">
              <Select value={priority} onValueChange={(v) => setPriority(v as Priority)}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>{PRIORITY_LABELS.map((l) => <SelectItem key={l.value} value={l.value}>{l.label}</SelectItem>)}</SelectContent>
              </Select>
            </Field>
          </div>
          <Field label="Title *"><Input value={title} onChange={(e) => setTitle(e.target.value)} /></Field>
          <Field label="Description"><Textarea rows={2} value={description} onChange={(e) => setDescription(e.target.value)} /></Field>
          <Field label="Root cause"><Textarea rows={2} value={rootCause} onChange={(e) => setRootCause(e.target.value)} /></Field>
          <Field label="Corrective action *"><Textarea rows={2} value={correctiveAction} onChange={(e) => setCorrectiveAction(e.target.value)} /></Field>
          <div className="grid gap-3 sm:grid-cols-2">
            <Field label="Responsible">
              <Select value={responsible} onValueChange={setResponsible}>
                <SelectTrigger><SelectValue placeholder="Select person" /></SelectTrigger>
                <SelectContent>
                  {personnel.map((p) => <SelectItem key={p.id} value={p.id}>{p.first_name} {p.last_name}</SelectItem>)}
                </SelectContent>
              </Select>
            </Field>
            <Field label="Due date"><Input type="date" value={dueDate} onChange={(e) => setDueDate(e.target.value)} /></Field>
          </div>
          <DialogFooter>
            <Button type="button" variant="ghost" onClick={() => onOpenChange(false)}>Cancel</Button>
            <Button type="submit" disabled={saving}>{saving ? 'Creating…' : 'Create CAPA'}</Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function CompleteDialog({
  capa,
  userId,
  onOpenChange,
  onComplete,
  saving,
}: {
  capa: CapaRecord | null
  userId: string
  onOpenChange: (v: boolean) => void
  onComplete: (proofs: string[], signature: string | null) => void
  saving: boolean
}) {
  const [photos, setPhotos] = useState<CapturedPhoto[]>([])
  const [signature, setSignature] = useState<string | null>(null)
  const [cameraOpen, setCameraOpen] = useState(false)

  useEffect(() => {
    if (capa) {
      setPhotos((capa.proof_paths ?? []).map((p) => ({ dataUrl: storage.publicUrl('images', p), storagePath: p })))
      setSignature(capa.signature_path ?? null)
    }
  }, [capa])

  return (
    <>
      <Dialog open={Boolean(capa)} onOpenChange={onOpenChange}>
        <DialogContent className="max-w-lg max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>Complete {capa?.capa_number ?? 'CAPA'}</DialogTitle>
          </DialogHeader>
          <div className="space-y-4 text-sm">
            <div className="rounded-lg bg-gray-50 px-3 py-2">{capa?.title}</div>
            <div className="space-y-1.5">
              <Label className="text-sm font-medium text-muted-foreground">Proof of completion</Label>
              <Button type="button" variant="outline" size="sm" onClick={() => setCameraOpen(true)}>
                <Camera className="mr-1 h-4 w-4" /> {photos.length > 0 ? `${photos.length} photo${photos.length === 1 ? '' : 's'}` : 'Upload proof'}
              </Button>
              {photos.length > 0 && (
                <div className="grid grid-cols-4 gap-2">
                  {photos.map((p, i) => <img key={i} src={p.dataUrl} alt="proof" className="aspect-square w-full rounded-md border object-cover" />)}
                </div>
              )}
            </div>
            <div className="space-y-1.5">
              <Label className="text-sm font-medium text-muted-foreground">Completion signature</Label>
              <SignaturePad userId={userId} onSignature={setSignature} defaultValue={signature} />
            </div>
            <DialogFooter>
              <Button variant="ghost" onClick={() => onOpenChange(false)}>Cancel</Button>
              <Button disabled={saving || photos.length === 0} onClick={() => onComplete(photos.map((p) => p.storagePath ?? p.dataUrl), signature)}>
                {saving ? 'Submitting…' : 'Confirm completion'}
              </Button>
            </DialogFooter>
          </div>
        </DialogContent>
      </Dialog>
      <CameraModal open={cameraOpen} onOpenChange={setCameraOpen} userId={userId} bucket="images" multiple onCaptured={(photos) => setPhotos(photos)} />
    </>
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