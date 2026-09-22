import { useEffect, useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Plus, Pencil, Trash2, Camera, ShieldAlert } from 'lucide-react'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { CardContent } from '@/components/ui/card'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { PageHeader, EmptyState, SectionCard, StatusBadge, RiskBadge, KPICard } from '@/components/shared'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { useDepotFilter } from '@/hooks/useDepotFilter'
import CameraModal, { type CapturedPhoto } from '@/components/CameraModal'
import { listHazards, createHazard, updateHazard, deleteHazard } from '@/services/hazards.service'
import { listDepots } from '@/services/depots.service'
import { storage } from '@/services/storage.service'
import { riskRating, riskScore, SEVERITY_SCORE } from '@/lib/constants'
import { SEVERITY_LABELS, HAZARD_TYPES } from '@/lib/labels'
import { formatDate } from '@/lib/utils'
import type { Hazard } from '@/types/entities'
import type { Severity } from '@/types/enums'

export default function Hazards() {
  const user = useCurrentUser()
  const { depotId } = useDepotFilter()
  const queryClient = useQueryClient()
  const [editing, setEditing] = useState<Hazard | null>(null)
  const [creating, setCreating] = useState(false)

  const { data: hazards = [] } = useQuery({ queryKey: ['hazards', depotId ?? 'all'], queryFn: () => listHazards(depotId ? { depotId } : {}) })
  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const depotName = (id: string | null) => depots.find((d) => d.id === id)?.name ?? '—'

  const scoped = useMemo(
    () => (user.isCountryHead ? hazards : hazards.filter((h) => h.depot_id === user.effectiveDepotId)),
    [hazards, user.isCountryHead, user.effectiveDepotId],
  )
  const openCount = scoped.filter((h) => !['CLOSED', 'CANCELLED'].includes(h.status)).length
  const criticalCount = scoped.filter((h) => h.risk_rating === 'CRITICAL' && !['CLOSED', 'CANCELLED'].includes(h.status)).length

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['hazards'] })
  const setOpen = (v: boolean) => {
    if (!v) {
      setCreating(false)
      setEditing(null)
    }
  }

  const save = useMutation({
    mutationFn: (input: Partial<Hazard>) => (editing ? updateHazard(editing.id, input) : createHazard(input)),
    onSuccess: () => {
      toast.success(editing ? 'Hazard updated' : 'Hazard logged')
      setOpen(false)
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not save hazard'),
  })

  const remove = useMutation({
    mutationFn: (id: string) => deleteHazard(id),
    onSuccess: () => {
      toast.success('Hazard removed')
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not remove hazard'),
  })

  return (
    <div className="space-y-8">
      <PageHeader
        title="Hazards"
        subtitle={`${openCount} open${criticalCount > 0 ? ` · ${criticalCount} critical` : ''}`}
        actions={<Button onClick={() => setCreating(true)}><Plus className="mr-1 h-4 w-4" /> Log hazard</Button>}
      />

      <div className="grid grid-cols-1 gap-6 sm:grid-cols-3">
        <KPICard icon={<ShieldAlert className="h-4 w-4" />} iconHue="red" label="Open hazards" value={openCount} tone={openCount > 0 ? 'warn' : 'good'} />
        <KPICard icon={<ShieldAlert className="h-4 w-4" />} iconHue="red" label="Critical open" value={criticalCount} tone={criticalCount > 0 ? 'bad' : 'good'} />
        <KPICard icon={<ShieldAlert className="h-4 w-4" />} iconHue="slate" label="Total logged" value={scoped.length} />
      </div>

      {scoped.length === 0 ? (
        <EmptyState title="No hazards logged" description="Recording hazards triggers visibility for the HSE team and enables targeted control actions." />
      ) : (
        <SectionCard title="Hazard register">
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Hazard</TableHead>
                  <TableHead>Location</TableHead>
                  <TableHead className="hidden md:table-cell">Depot</TableHead>
                  <TableHead>Risk</TableHead>
                  <TableHead>Reported</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="w-20" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {scoped.map((h) => (
                  <TableRow key={h.id}>
                    <TableCell>
                      <div className="line-clamp-1 max-w-[16rem] font-medium">{h.description}</div>
                      <div className="text-xs text-muted-foreground">{h.hazard_type ?? '—'}</div>
                    </TableCell>
                    <TableCell>{h.location ?? '—'}</TableCell>
                    <TableCell className="hidden md:table-cell">{depotName(h.depot_id)}</TableCell>
                    <TableCell><RiskBadge risk={h.risk_rating ?? 'LOW'} /></TableCell>
                    <TableCell>{h.reported_by_name ?? formatDate(h.created_at)}</TableCell>
                    <TableCell><StatusBadge status={h.status} /></TableCell>
                    <TableCell>
                      <div className="flex items-center gap-1">
                        <Button variant="ghost" size="icon" onClick={() => setEditing(h)} aria-label="Edit hazard"><Pencil className="h-4 w-4" /></Button>
                        <Button variant="ghost" size="icon" className="text-rag-bad" disabled={remove.isPending} onClick={() => remove.mutate(h.id)} aria-label="Delete hazard"><Trash2 className="h-4 w-4" /></Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </SectionCard>
      )}

      <HazardForm
        open={creating || editing !== null}
        onOpenChange={setOpen}
        hazard={editing}
        userId={user.userId ?? 'anon'}
        defaultDepotId={user.effectiveDepotId ?? undefined}
        depotName={depotName}
        onSave={(input) => save.mutate(input)}
        saving={save.isPending}
      />
    </div>
  )
}

function HazardForm({
  open,
  onOpenChange,
  hazard,
  userId,
  defaultDepotId,
  depotName,
  onSave,
  saving,
}: {
  open: boolean
  onOpenChange: (v: boolean) => void
  hazard: Hazard | null
  userId: string
  defaultDepotId?: string
  depotName: (id: string | null) => string
  onSave: (input: Partial<Hazard>) => void
  saving: boolean
}) {
  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const [depotId, setDepotId] = useState(defaultDepotId ?? '')
  const [location, setLocation] = useState('')
  const [hazardType, setHazardType] = useState('')
  const [description, setDescription] = useState('')
  const [likelihood, setLikelihood] = useState(3)
  const [severity, setSeverity] = useState<Severity>('MEDIUM')
  const [correctiveAction, setCorrectiveAction] = useState('')
  const [controlled, setControlled] = useState(false)
  const [photos, setPhotos] = useState<CapturedPhoto[]>([])
  const [cameraOpen, setCameraOpen] = useState(false)
  const [status, setStatus] = useState('OPEN')

  useEffect(() => {
    if (!open) return
    setDepotId(hazard?.depot_id ?? defaultDepotId ?? '')
    setLocation(hazard?.location ?? '')
    setHazardType(hazard?.hazard_type ?? '')
    setDescription(hazard?.description ?? '')
    setLikelihood(hazard?.likelihood ?? 3)
    setSeverity(hazard?.severity ?? 'MEDIUM')
    setCorrectiveAction(hazard?.corrective_action ?? '')
    setControlled(hazard?.controlled_confirmed ?? false)
    setPhotos((hazard?.photo_paths ?? []).map((p) => ({ dataUrl: storage.publicUrl('images', p), storagePath: p })))
    setStatus(hazard?.status ?? 'OPEN')
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, hazard])

  const score = riskScore(likelihood, SEVERITY_SCORE[severity])
  const rating = riskRating(score)

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!depotId) return toast.error('Depot is required.')
    if (!description.trim()) return toast.error('Hazard description is required.')
    onSave({
      depot_id: depotId,
      location: location || null,
      hazard_type: hazardType || null,
      description: description.trim(),
      likelihood,
      severity,
      risk_score: score,
      risk_rating: rating,
      corrective_action: correctiveAction || null,
      controlled_confirmed: controlled,
      photo_paths: photos.map((p) => p.storagePath ?? p.dataUrl),
      reported_by: hazard?.reported_by,
      reported_by_name: hazard?.reported_by_name,
      status: status as Hazard['status'],
    })
  }

  return (
    <>
      <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="max-w-lg max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>{hazard ? 'Edit hazard' : 'Log hazard'}</DialogTitle>
          </DialogHeader>
          <form onSubmit={submit} className="space-y-3">
            <div className="grid gap-3 sm:grid-cols-2">
              <Field label="Depot *">
                <Select value={depotId} onValueChange={setDepotId}>
                  <SelectTrigger><SelectValue placeholder={depotName(depotId) || 'Select depot'} /></SelectTrigger>
                  <SelectContent>{depots.map((d) => <SelectItem key={d.id} value={d.id}>{d.name} ({d.code})</SelectItem>)}</SelectContent>
                </Select>
              </Field>
              <Field label="Type">
                <Select value={hazardType} onValueChange={setHazardType}>
                  <SelectTrigger><SelectValue placeholder="Select type" /></SelectTrigger>
                  <SelectContent>{HAZARD_TYPES.map((t) => <SelectItem key={t} value={t}>{t}</SelectItem>)}</SelectContent>
                </Select>
              </Field>
            </div>
            <Field label="Location"><Input value={location} onChange={(e) => setLocation(e.target.value)} placeholder="e.g. Warehouse B, aisle 3" /></Field>
            <Field label="Description *"><Textarea rows={3} value={description} onChange={(e) => setDescription(e.target.value)} /></Field>
            <div className="grid gap-3 sm:grid-cols-2">
              <Field label="Likelihood (1–5)"><Input type="number" min={1} max={5} value={likelihood} onChange={(e) => setLikelihood(Number(e.target.value) || 1)} /></Field>
              <Field label="Severity">
                <Select value={severity} onValueChange={(v) => setSeverity(v as Severity)}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>{SEVERITY_LABELS.map((l) => <SelectItem key={l.value} value={l.value}>{l.label}</SelectItem>)}</SelectContent>
                </Select>
              </Field>
            </div>
            <div className="rounded-lg bg-gray-50 px-3 py-2 text-sm">
              <span className="text-muted-foreground">Risk score {score}</span> · <RiskBadge risk={rating} />
            </div>
            <Field label="Corrective action"><Textarea rows={2} value={correctiveAction} onChange={(e) => setCorrectiveAction(e.target.value)} /></Field>
            <div className="space-y-1.5">
              <Label className="text-sm font-medium text-muted-foreground">Photo evidence</Label>
              <Button type="button" variant="outline" size="sm" onClick={() => setCameraOpen(true)}>
                <Camera className="mr-1 h-4 w-4" /> {photos.length > 0 ? `${photos.length} photo${photos.length === 1 ? '' : 's'}` : 'Add photos'}
              </Button>
              {photos.length > 0 && (
                <div className="grid grid-cols-4 gap-2">
                  {photos.map((p, i) => <img key={i} src={p.dataUrl} alt="evidence" className="aspect-square w-full rounded-md border object-cover" />)}
                </div>
              )}
            </div>
            <DialogFooter>
              <Button type="button" variant="ghost" onClick={() => onOpenChange(false)}>Cancel</Button>
              <Button type="submit" disabled={saving}>{saving ? 'Saving…' : hazard ? 'Save changes' : 'Log hazard'}</Button>
            </DialogFooter>
          </form>
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