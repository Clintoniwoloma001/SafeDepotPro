import { useEffect, useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Plus, Pencil, Trash2, Camera } from 'lucide-react'
import { format } from 'date-fns'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { CardContent } from '@/components/ui/card'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { PageHeader, EmptyState, SectionCard, StatusBadge, RiskBadge } from '@/components/shared'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { useDepotFilter } from '@/hooks/useDepotFilter'
import CameraModal, { type CapturedPhoto } from '@/components/CameraModal'
import { listIncidents, createIncident, updateIncident, deleteIncident, nextIncidentNumber } from '@/services/incidents.service'
import { listDepots } from '@/services/depots.service'
import { storage } from '@/services/storage.service'
import { SEVERITY_LABELS } from '@/lib/labels'
import { formatDateTime } from '@/lib/utils'
import type { Incident } from '@/types/entities'
import type { Severity } from '@/types/enums'

export default function Incidents() {
  const user = useCurrentUser()
  const { depotId } = useDepotFilter()
  const queryClient = useQueryClient()
  const [editing, setEditing] = useState<Incident | null>(null)
  const [creating, setCreating] = useState(false)

  const { data: incidents = [] } = useQuery({ queryKey: ['incidents', depotId ?? 'all'], queryFn: () => listIncidents(depotId ? { depotId } : {}) })
  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const depotName = (id: string | null) => depots.find((d) => d.id === id)?.name ?? '—'

  const scoped = useMemo(
    () => (user.isCountryHead ? incidents : incidents.filter((i) => i.depot_id === user.effectiveDepotId)),
    [incidents, user.isCountryHead, user.effectiveDepotId],
  )

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['incidents'] })
  const setOpen = (v: boolean) => {
    if (!v) {
      setCreating(false)
      setEditing(null)
    }
  }

  const save = useMutation({
    mutationFn: async (input: Partial<Incident>) => {
      if (editing) return updateIncident(editing.id, input)
      return createIncident({ ...input, incident_number: input.incident_number ?? (await nextIncidentNumber()) })
    },
    onSuccess: () => {
      toast.success(editing ? 'Incident updated' : 'Incident recorded')
      setOpen(false)
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not save incident'),
  })

  const remove = useMutation({
    mutationFn: (id: string) => deleteIncident(id),
    onSuccess: () => {
      toast.success('Incident removed')
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not remove incident'),
  })

  const openIncidents = scoped.filter((i) => !['CLOSED', 'WITHDRAWN'].includes(i.status))

  return (
    <div className="space-y-8">
      <PageHeader
        title="Incidents"
        subtitle={`${openIncidents.length} open · ${scoped.length} on record`}
        actions={
          <Button onClick={() => setCreating(true)}>
            <Plus className="mr-1 h-4 w-4" /> Record incident
          </Button>
        }
      />

      {scoped.length === 0 ? (
        <EmptyState title="No incidents recorded" description="Log unsafe events, injuries and near hits with photographic evidence." />
      ) : (
        <SectionCard title="Incident register">
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-28">Number</TableHead>
                  <TableHead>Occurred</TableHead>
                  <TableHead>Type / severity</TableHead>
                  <TableHead className="hidden md:table-cell">Depot</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="w-20" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {scoped.map((i) => (
                  <TableRow key={i.id}>
                    <TableCell className="font-mono text-xs font-medium">{i.incident_number}</TableCell>
                    <TableCell>{formatDateTime(i.occurred_at)}</TableCell>
                    <TableCell>
                      <div className="truncate max-w-[14rem] text-sm">{i.incident_type ?? '—'}</div>
                      <RiskBadge risk={i.severity} className="mt-1" />
                    </TableCell>
                    <TableCell className="hidden md:table-cell">{depotName(i.depot_id)}</TableCell>
                    <TableCell><StatusBadge status={i.status} /></TableCell>
                    <TableCell>
                      <div className="flex items-center gap-1">
                        <Button variant="ghost" size="icon" onClick={() => setEditing(i)} aria-label="Edit incident"><Pencil className="h-4 w-4" /></Button>
                        <Button variant="ghost" size="icon" className="text-rag-bad" disabled={remove.isPending} onClick={() => remove.mutate(i.id)} aria-label="Delete incident"><Trash2 className="h-4 w-4" /></Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </SectionCard>
      )}

      <IncidentForm
        open={creating || editing !== null}
        onOpenChange={setOpen}
        incident={editing}
        userId={user.userId ?? 'anon'}
        defaultDepotId={user.effectiveDepotId ?? undefined}
        depotName={depotName}
        onSave={(input) => save.mutate(input)}
        saving={save.isPending}
      />
    </div>
  )
}

function IncidentForm({
  open,
  onOpenChange,
  incident,
  userId,
  defaultDepotId,
  depotName,
  onSave,
  saving,
}: {
  open: boolean
  onOpenChange: (v: boolean) => void
  incident: Incident | null
  userId: string
  defaultDepotId?: string
  depotName: (id: string | null) => string
  onSave: (input: Partial<Incident>) => void
  saving: boolean
}) {
  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const [depotId, setDepotId] = useState(defaultDepotId ?? '')
  const [occurredAt, setOccurredAt] = useState(new Date().toISOString().slice(0, 16))
  const [incidentType, setIncidentType] = useState('')
  const [severity, setSeverity] = useState<Severity>('MEDIUM')
  const [description, setDescription] = useState('')
  const [rootCause, setRootCause] = useState('')
  const [actionsTaken, setActionsTaken] = useState('')
  const [involvedPersonnel, setInvolvedPersonnel] = useState('')
  const [photos, setPhotos] = useState<CapturedPhoto[]>([])
  const [cameraOpen, setCameraOpen] = useState(false)
  const [status, setStatus] = useState(incident?.status ?? 'OPEN')

  useEffect(() => {
    if (!open) return
    setDepotId(incident?.depot_id ?? defaultDepotId ?? '')
    setOccurredAt(incident?.occurred_at?.slice(0, 16) ?? new Date().toISOString().slice(0, 16))
    setIncidentType(incident?.incident_type ?? '')
    setSeverity(incident?.severity ?? 'MEDIUM')
    setDescription(incident?.description ?? '')
    setRootCause(incident?.root_cause ?? '')
    setActionsTaken(incident?.actions_taken ?? '')
    setInvolvedPersonnel((incident?.involved_personnel ?? []).join(', '))
    setPhotos((incident?.photo_paths ?? []).map((p) => ({ dataUrl: storage.publicUrl('images', p), storagePath: p })))
    setStatus(incident?.status ?? 'OPEN')
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, incident])

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!depotId) return toast.error('Depot is required.')
    if (!description.trim()) return toast.error('Incident description is required.')
    const occurred = occurredAt ? new Date(occurredAt) : new Date()
    onSave({
      depot_id: depotId,
      incident_type: incidentType || null,
      severity,
      description: description.trim(),
      root_cause: rootCause || null,
      actions_taken: actionsTaken || null,
      involved_personnel: involvedPersonnel.split(',').map((p) => p.trim()).filter(Boolean),
      photo_paths: photos.map((p) => p.storagePath ?? p.dataUrl),
      reported_by: incident?.reported_by,
      reported_by_name: incident?.reported_by_name,
      status: status as Incident['status'],
      occurred_at: format(occurred, "yyyy-MM-dd'T'HH:mm:ssXXX"),
    })
  }

  return (
    <>
      <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="max-w-lg max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>{incident ? `Edit ${incident.incident_number}` : 'Record incident'}</DialogTitle>
          </DialogHeader>
          <form onSubmit={submit} className="space-y-3">
            <div className="grid gap-3 sm:grid-cols-2">
              <Field label="Depot *">
                <Select value={depotId} onValueChange={setDepotId}>
                  <SelectTrigger><SelectValue placeholder={depotName(depotId) || 'Select depot'} /></SelectTrigger>
                  <SelectContent>{depots.map((d) => <SelectItem key={d.id} value={d.id}>{d.name} ({d.code})</SelectItem>)}</SelectContent>
                </Select>
              </Field>
              <Field label="Type"><Input value={incidentType} onChange={(e) => setIncidentType(e.target.value)} placeholder="Fire / First aid / Theft" /></Field>
              <Field label="Occurred at *"><Input type="datetime-local" value={occurredAt} onChange={(e) => setOccurredAt(e.target.value)} /></Field>
              <Field label="Severity">
                <Select value={severity} onValueChange={(v) => setSeverity(v as Severity)}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>{SEVERITY_LABELS.map((l) => <SelectItem key={l.value} value={l.value}>{l.label}</SelectItem>)}</SelectContent>
                </Select>
              </Field>
            </div>
            <Field label="Description *"><Textarea rows={3} value={description} onChange={(e) => setDescription(e.target.value)} /></Field>
            <Field label="Root cause"><Textarea rows={2} value={rootCause} onChange={(e) => setRootCause(e.target.value)} /></Field>
            <Field label="Actions taken"><Textarea rows={2} value={actionsTaken} onChange={(e) => setActionsTaken(e.target.value)} /></Field>
            <Field label="Involved personnel (comma separated)"><Input value={involvedPersonnel} onChange={(e) => setInvolvedPersonnel(e.target.value)} /></Field>
            <div className="space-y-1.5">
              <Label className="text-sm font-medium text-muted-foreground">Photo evidence</Label>
              <Button type="button" variant="outline" size="sm" onClick={() => setCameraOpen(true)}>
                <Camera className="mr-1 h-4 w-4" /> {photos.length > 0 ? `${photos.length} photo${photos.length === 1 ? '' : 's'}` : 'Add photos'}
              </Button>
              {photos.length > 0 && (
                <div className="grid grid-cols-4 gap-2">
                  {photos.map((p, i) => (
                    <img key={i} src={p.dataUrl} alt="evidence" className="aspect-square w-full rounded-md border object-cover" />
                  ))}
                </div>
              )}
            </div>
            <CardContent className="hidden" />
            <DialogFooter>
              <Button type="button" variant="ghost" onClick={() => onOpenChange(false)}>Cancel</Button>
              <Button type="submit" disabled={saving}>{saving ? 'Saving…' : incident ? 'Save changes' : 'Record incident'}</Button>
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