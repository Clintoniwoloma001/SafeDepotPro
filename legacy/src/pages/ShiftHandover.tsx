import { useEffect, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeftRight, Plus, Camera } from 'lucide-react'
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
import CameraModal, { type CapturedPhoto } from '@/components/CameraModal'
import SignaturePad from '@/components/SignaturePad'
import { listShiftHandovers, createShiftHandover, updateShiftHandover } from '@/services/shiftHandover.service'
import { listDepots } from '@/services/depots.service'
import { formatDate } from '@/lib/utils'
import type { ShiftHandover } from '@/types/entities'
import type { ShiftStatus } from '@/types/enums'

const CHECKLIST_ITEMS = [
  'Fuel/stock levels recorded',
  'Equipment damage noted',
  'Security locked down',
  'HSE incidents passed over',
  'PTW in progress handed over',
] as const

export default function ShiftHandover() {
  const user = useCurrentUser()
  const { depotId } = useDepotFilter()
  const queryClient = useQueryClient()
  const [creating, setCreating] = useState(false)

  const { data: handovers = [] } = useQuery({ queryKey: ['shift-handovers', depotId ?? 'all'], queryFn: () => listShiftHandovers(depotId ? { depotId } : {}) })
  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const depotName = (id: string | null) => depots.find((d) => d.id === id)?.name ?? '—'

  const scoped = user.isCountryHead ? handovers : handovers.filter((h) => h.depot_id === user.effectiveDepotId)
  const pending = scoped.filter((h) => h.status === 'PENDING' || h.status === 'COMPLETED').length

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['shift-handovers'] })

  const save = useMutation({
    mutationFn: createShiftHandover,
    onSuccess: () => {
      toast.success('Shift handover recorded')
      setCreating(false)
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not save handover'),
  })

  const setStatus = useMutation({
    mutationFn: ({ id, status }: { id: string; status: ShiftStatus }) => updateShiftHandover(id, { status }),
    onSuccess: () => {
      toast.success('Status updated')
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not update status'),
  })

  return (
    <div className="space-y-8">
      <PageHeader
        title="Shift Handover"
        subtitle={`${pending} pending handovers`}
        actions={<Button onClick={() => setCreating(true)}><Plus className="mr-1 h-4 w-4" /> New handover</Button>}
      />

      <div className="grid grid-cols-1 gap-6 sm:grid-cols-3">
        <KPICard icon={<ArrowLeftRight className="h-4 w-4" />} iconHue="blue" label="Total" value={scoped.length} />
        <KPICard icon={<ArrowLeftRight className="h-4 w-4" />} iconHue="amber" label="Pending" value={pending} />
        <KPICard icon={<ArrowLeftRight className="h-4 w-4" />} iconHue="green" label="Confirmed" value={scoped.filter((h) => h.status === 'CONFIRMED').length} />
      </div>

      {scoped.length === 0 ? (
        <EmptyState title="No handovers" description="Formal handover at shift change keeps day and night crews in the loop." />
      ) : (
        <SectionCard title="Handover register">
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Date</TableHead>
                  <TableHead>Shift</TableHead>
                  <TableHead className="hidden sm:table-cell">Outgoing</TableHead>
                  <TableHead className="hidden md:table-cell">Incoming</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="w-24">{/* actions */}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {scoped.map((h) => (
                  <TableRow key={h.id}>
                    <TableCell>{formatDate(h.shift_date)}</TableCell>
                    <TableCell>{h.shift === 'NIGHT' ? 'Night' : 'Day'}</TableCell>
                    <TableCell className="hidden sm:table-cell">{h.outgoing_name ?? '—'}</TableCell>
                    <TableCell className="hidden md:table-cell">{h.incoming_name ?? '—'}</TableCell>
                    <TableCell><StatusBadge status={h.status} /></TableCell>
                    <TableCell>
                      {h.status === 'PENDING' && (
                        <Button size="sm" variant="outline" className="h-7 text-xs" onClick={() => setStatus.mutate({ id: h.id, status: 'COMPLETED' })}>
                          Complete
                        </Button>
                      )}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </SectionCard>
      )}

      <HandoverForm
        open={creating}
        onOpenChange={setCreating}
        userId={user.userId ?? 'anon'}
        userName={user.fullName}
        defaultDepotId={user.effectiveDepotId ?? undefined}
        depotName={depotName}
        onSave={(input) => save.mutate(input)}
      />
    </div>
  )
}

function HandoverForm({
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
  onSave: (input: Partial<ShiftHandover>) => void
}) {
  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const [depotId, setDepotId] = useState(defaultDepotId ?? '')
  const [shiftDate, setShiftDate] = useState(new Date().toISOString().slice(0, 10))
  const [shift, setShift] = useState('DAY')
  const [incomingName, setIncomingName] = useState('')
  const [summary, setSummary] = useState('')
  const [checklist, setChecklist] = useState<Record<string, boolean>>({})
  const [openIssues, setOpenIssues] = useState('')
  const [followUps, setFollowUps] = useState('')
  const [photos, setPhotos] = useState<CapturedPhoto[]>([])
  const [outSig, setOutSig] = useState<string | null>(null)
  const [inSig, setInSig] = useState<string | null>(null)
  const [cameraOpen, setCameraOpen] = useState(false)

  useEffect(() => {
    if (!open) return
    setDepotId(defaultDepotId ?? '')
    setShiftDate(new Date().toISOString().slice(0, 10))
    setShift('DAY')
    setIncomingName('')
    setSummary('')
    setChecklist({})
    setOpenIssues('')
    setFollowUps('')
    setPhotos([])
    setOutSig(null)
    setInSig(null)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open])

  const submit = () => {
    if (!depotId) return toast.error('Depot is required.')
    if (!incomingName.trim()) return toast.error('Incoming crew name is required.')
    onSave({
      depot_id: depotId,
      shift_date: shiftDate,
      shift,
      incoming_user_id: userId,
      incoming_name: incomingName.trim(),
      outgoing_name: userName,
      status: 'PENDING',
      summary: summary || null,
      checklist: { ...checklist },
      open_issues: openIssues || null,
      follow_up_actions: followUps || null,
      photo_paths: photos.map((p) => p.storagePath ?? p.dataUrl),
      outgoing_signature_path: outSig,
      incoming_signature_path: inSig,
    })
  }

  return (
    <>
      <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="max-h-[92vh] overflow-y-auto">
          <DialogHeader><DialogTitle>New shift handover</DialogTitle></DialogHeader>
          <div className="space-y-4">
            <div className="grid gap-3 sm:grid-cols-2">
              <Field label="Depot *">
                <Select value={depotId} onValueChange={setDepotId}>
                  <SelectTrigger><SelectValue placeholder={depotName(depotId) || 'Select'} /></SelectTrigger>
                  <SelectContent>{depots.map((d) => <SelectItem key={d.id} value={d.id}>{d.name} ({d.code})</SelectItem>)}</SelectContent>
                </Select>
              </Field>
              <Field label="Date"><Input type="date" value={shiftDate} onChange={(e) => setShiftDate(e.target.value)} /></Field>
              <Field label="Shift">
                <Select value={shift} onValueChange={setShift}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="DAY">Day</SelectItem>
                    <SelectItem value="NIGHT">Night</SelectItem>
                  </SelectContent>
                </Select>
              </Field>
              <Field label="Incoming crew / name *"><Input value={incomingName} onChange={(e) => setIncomingName(e.target.value)} /></Field>
            </div>

            <Field label="Handover summary"><Textarea rows={3} value={summary} onChange={(e) => setSummary(e.target.value)} /></Field>

            <div className="space-y-2">
              <Label className="text-sm font-medium text-muted-foreground">Checklist</Label>
              <div className="space-y-2">
                {CHECKLIST_ITEMS.map((item) => (
                  <label key={item} className="flex items-center gap-2 text-sm">
                    <input
                      type="checkbox"
                      checked={Boolean(checklist[item])}
                      onChange={(e) => setChecklist((prev) => ({ ...prev, [item]: e.target.checked }))}
                      className="rounded border-gray-300"
                    />
                    {item}
                  </label>
                ))}
              </div>
            </div>

            <Field label="Open issues"><Textarea rows={2} value={openIssues} onChange={(e) => setOpenIssues(e.target.value)} /></Field>
            <Field label="Follow-up actions"><Textarea rows={2} value={followUps} onChange={(e) => setFollowUps(e.target.value)} /></Field>

            <div className="space-y-2">
              <Label className="text-sm font-medium text-muted-foreground">Photos</Label>
              <div className="flex flex-wrap items-center gap-3">
                <Button type="button" variant="outline" size="sm" onClick={() => setCameraOpen(true)}>
                  <Camera className="mr-1 h-4 w-4" /> {photos.length > 0 ? `${photos.length} photo${photos.length === 1 ? '' : 's'}` : 'Add photos'}
                </Button>
                {photos.map((p, i) => <img key={i} src={p.dataUrl} alt="" className="h-14 w-14 rounded-md border object-cover" />)}
              </div>
            </div>

            <div className="grid gap-4 sm:grid-cols-2">
              <div>
                <Label className="mb-1 block text-sm font-medium text-muted-foreground">Outgoing signature ({userName})</Label>
                <SignaturePad userId={userId} onSignature={setOutSig} defaultValue={outSig} />
              </div>
              <div>
                <Label className="mb-1 block text-sm font-medium text-muted-foreground">Incoming signature</Label>
                <SignaturePad userId={userId} onSignature={setInSig} defaultValue={inSig} />
              </div>
            </div>

            <div className="flex justify-end gap-2">
              <Button variant="ghost" onClick={() => onOpenChange(false)}>Cancel</Button>
              <Button onClick={submit}>Record handover</Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
      <CameraModal open={cameraOpen} onOpenChange={setCameraOpen} userId={userId} bucket="images" multiple onCaptured={(files) => setPhotos((prev) => [...prev, ...files])} />
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