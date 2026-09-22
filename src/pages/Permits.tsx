import { useEffect, useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { FileCheck, Plus, Camera, CheckCircle2 } from 'lucide-react'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { CardContent } from '@/components/ui/card'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { PageHeader, EmptyState, SectionCard, StatusBadge, KPICard } from '@/components/shared'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { useDepotFilter } from '@/hooks/useDepotFilter'
import CameraModal, { type CapturedPhoto } from '@/components/CameraModal'
import SignaturePad from '@/components/SignaturePad'
import PermitApprovalReview from '@/components/permits/PermitApprovalReview'
import { RiskMatrix } from '@/components/permits/RiskMatrix'
import { listPermits, createPermit, updatePermit, getPermit, nextPermitNumber } from '@/services/permits.service'
import { listDepots } from '@/services/depots.service'
import { storage } from '@/services/storage.service'
import { riskRating } from '@/lib/constants'
import type { HazardAssessmentRow, Permit } from '@/types/entities'
import type { PermitStatus } from '@/types/enums'

const PERMIT_TYPES = ['HOT WORK', 'WORK AT HEIGHT', 'CONFINED SPACE', 'ELECTRICAL', 'EXCAVATION', 'LIFTING', 'DEMOLITION', 'COLD WORK', 'GENERAL'] as const
const PPE_OPTIONS = ['Safety helmet', 'Safety glasses', 'High-vis vest', 'Safety boots', 'Gloves', 'Respirator', 'Ear protection', 'Harness', 'Face shield', 'Welding mask'] as const

export default function Permits() {
  const user = useCurrentUser()
  const { depotId } = useDepotFilter()
  const queryClient = useQueryClient()
  const [creating, setCreating] = useState(false)
  const [editing, setEditing] = useState<Permit | null>(null)
  const [review, setReview] = useState<Permit | null>(null)

  const { data: permits = [] } = useQuery({ queryKey: ['permits', depotId ?? 'all'], queryFn: () => listPermits(depotId ? { depotId } : {}) })
  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const depotName = (id: string | null) => depots.find((d) => d.id === id)?.name ?? '—'

  const scoped = useMemo(
    () => (user.isCountryHead ? permits : permits.filter((p) => p.depot_id === user.effectiveDepotId)),
    [permits, user],
  )
  const active = scoped.filter((p) => p.status === 'APPROVED').length
  const submitted = scoped.filter((p) => p.status === 'SUBMITTED').length

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['permits'] })
  const setOpen = (v: boolean) => {
    if (!v) {
      setCreating(false)
      setEditing(null)
      setReview(null)
    }
  }

  const save = useMutation({
    mutationFn: async (input: Partial<Permit>) => {
      if (editing) return updatePermit(editing.id, input)
      return createPermit({ ...input, permit_number: input.permit_number ?? (await nextPermitNumber()) })
    },
    onSuccess: (p) => {
      toast.success(editing ? 'Permit updated' : 'Permit created')
      setCreating(false)
      setEditing(null)
      invalidate()
      if (p?.id) void queryClient.prefetchQuery({ queryKey: ['permit', p.id], queryFn: () => getPermit(p.id) })
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not save permit'),
  })

  const changeStatus = useMutation({
    mutationFn: ({ id, status, extra }: { id: string; status: PermitStatus; extra?: Partial<Permit> }) =>
      updatePermit(id, { ...extra, status, approved_at: status === 'APPROVED' ? new Date().toISOString() : undefined }),
    onSuccess: () => {
      toast.success('Permit status updated')
      setReview(null)
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not update permit'),
  })

  const openReview = async (p: Permit) => {
    const fresh = await getPermit(p.id).catch(() => p)
    setReview(fresh)
  }

  return (
    <div className="space-y-8">
      <PageHeader
        title="Permit to Work"
        subtitle={`${active} active · ${submitted} pending approval`}
        actions={<Button onClick={() => setCreating(true)}><Plus className="mr-1 h-4 w-4" /> New permit</Button>}
      />

      <div className="grid grid-cols-1 gap-6 sm:grid-cols-3">
        <KPICard icon={<FileCheck className="h-4 w-4" />} iconHue="blue" label="Active permits" value={active} />
        <KPICard icon={<FileCheck className="h-4 w-4" />} iconHue="amber" label="Awaiting approval" value={submitted} />
        <KPICard icon={<FileCheck className="h-4 w-4" />} iconHue="slate" label="Total" value={scoped.length} />
      </div>

      {scoped.length === 0 ? (
        <EmptyState title="No permits" description="Raise a Permit to Work for high-risk jobs — hot work, height, confined space and more." />
      ) : (
        <SectionCard title="Permit register">
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-28">Number</TableHead>
                  <TableHead>Job</TableHead>
                  <TableHead>Type</TableHead>
                  <TableHead className="hidden md:table-cell">Depot</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="w-24">{/* actions */}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {scoped.map((p) => (
                  <TableRow key={p.id}>
                    <TableCell className="font-mono text-xs font-medium">{p.permit_number}</TableCell>
                    <TableCell>
                      <div className="line-clamp-1 max-w-[16rem] font-medium">{p.job_title}</div>
                      <div className="text-xs text-muted-foreground">{p.location ?? '—'}</div>
                    </TableCell>
                    <TableCell>{p.permit_type ?? '—'}</TableCell>
                    <TableCell className="hidden md:table-cell">{depotName(p.depot_id)}</TableCell>
                    <TableCell><StatusBadge status={p.status} /></TableCell>
                    <TableCell>
                      <Button size="sm" variant="outline" className="h-7 text-xs" onClick={() => {
                        if (p.status === 'SUBMITTED') void openReview(p)
                        else setEditing(p)
                      }}>
                        {p.status === 'SUBMITTED' && user.isManagement ? 'Review' : p.status === 'DRAFT' ? 'Edit' : 'View'}
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </SectionCard>
      )}

      <PermitForm
        open={creating || editing !== null}
        onOpenChange={setOpen}
        permit={editing}
        userId={user.userId ?? 'anon'}
        defaultDepotId={user.effectiveDepotId ?? undefined}
        depotName={depotName}
        onSave={(input) => save.mutate(input)}
        saving={save.isPending}
      />

      <Dialog open={Boolean(review)} onOpenChange={(v) => { if (!v) setReview(null) }}>
        <DialogContent className="max-w-3xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>Permit review — {review?.permit_number}</DialogTitle>
          </DialogHeader>
          {review && (
            <PermitApprovalReview
              permit={review}
              canApprove={user.isManagement}
              onApprove={async () => {
                await changeStatus.mutateAsync({ id: review.id, status: 'APPROVED' })
              }}
              onReject={async (reason) => {
                await changeStatus.mutateAsync({ id: review.id, status: 'REJECTED', extra: { rejection_reason: reason } })
              }}
              onBackToDraft={async () => {
                await changeStatus.mutateAsync({ id: review.id, status: 'DRAFT' })
              }}
              onSave={async () => void 0}
            />
          )}
        </DialogContent>
      </Dialog>
    </div>
  )
}

function PermitForm({
  open,
  onOpenChange,
  permit,
  userId,
  defaultDepotId,
  depotName,
  onSave,
  saving,
}: {
  open: boolean
  onOpenChange: (v: boolean) => void
  permit: Permit | null
  userId: string
  defaultDepotId?: string
  depotName: (id: string | null) => string
  onSave: (input: Partial<Permit>) => void
  saving: boolean
}) {
  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const [depotId, setDepotId] = useState(defaultDepotId ?? '')
  const [permitType, setPermitType] = useState('')
  const [jobTitle, setJobTitle] = useState('')
  const [jobDescription, setJobDescription] = useState('')
  const [tasks, setTasks] = useState('')
  const [location, setLocation] = useState('')
  const [startDt, setStartDt] = useState('')
  const [endDt, setEndDt] = useState('')
  const [hazards, setHazards] = useState<HazardAssessmentRow[]>([])
  const [ppe, setPpe] = useState<string[]>([])
  const [isolation, setIsolation] = useState('')
  const [certificates, setCertificates] = useState('')
  const [attachments, setAttachments] = useState<CapturedPhoto[]>([])
  const [signature, setSignature] = useState<string | null>(null)
  const [cameraOpen, setCameraOpen] = useState(false)

  useEffect(() => {
    if (!open) return
    setDepotId(permit?.depot_id ?? defaultDepotId ?? '')
    setPermitType(permit?.permit_type ?? '')
    setJobTitle(permit?.job_title ?? '')
    setJobDescription(permit?.job_description ?? '')
    setTasks((permit?.tasks ?? []).join(', '))
    setLocation(permit?.location ?? '')
    setStartDt(permit?.start_datetime?.slice(0, 16) ?? new Date().toISOString().slice(0, 16))
    setEndDt(permit?.end_datetime?.slice(0, 16) ?? '')
    setHazards(permit?.hazard_assessment ?? [])
    setPpe(permit?.ppe ?? [])
    setIsolation(permit?.isolation_loto ?? '')
    setCertificates((permit?.certificates ?? []).join(', '))
    setAttachments((permit?.attachment_paths ?? []).map((p) => ({ dataUrl: storage.publicUrl('attachments', p), storagePath: p })))
    setSignature(permit?.signature_applicant ?? null)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, permit])

  const togglePpe = (opt: string) => setPpe((prev) => (prev.includes(opt) ? prev.filter((p) => p !== opt) : [...prev, opt]))

  const addHazard = () =>
    setHazards((prev) => [
      ...prev,
      { hazard: '', consequence: '', existing_controls: '', additional_controls: '', initial_risk: 0, residual_risk: 0, risk_rating: 'LOW' },
    ])

  const patchHazard = (i: number, patch: Partial<HazardAssessmentRow>) =>
    setHazards((prev) => prev.map((h, idx) => (idx === i ? { ...h, ...patch, risk_rating: patch.initial_risk ? riskRating(patch.initial_risk) : h.risk_rating } : h)))

  const remainingHazards = hazards.filter((h) => !h.hazard?.trim() && !h.initial_risk)
  const submitAndSubmitForApproval = (submitMode: 'DRAFT' | 'SUBMITTED') => {
    if (!depotId) return toast.error('Depot is required.')
    if (!jobTitle.trim()) return toast.error('Job title is required.')
    if (submitMode === 'SUBMITTED' && remainingHazards.length > 0) return toast.error('Complete every hazard row before submitting for approval.')
    if (submitMode === 'SUBMITTED' && ppe.length === 0) return toast.error('Select required PPE before submitting for approval.')
    onSave({
      depot_id: depotId,
      permit_type: permitType || null,
      job_title: jobTitle.trim(),
      job_description: jobDescription || null,
      tasks: tasks.split(',').map((t) => t.trim()).filter(Boolean),
      location: location || null,
      start_datetime: startDt ? new Date(startDt).toISOString() : null,
      end_datetime: endDt ? new Date(endDt).toISOString() : null,
      hazard_assessment: hazards,
      ppe,
      isolation_loto: isolation || null,
      certificates: certificates.split(',').map((c) => c.trim()).filter(Boolean),
      attachment_paths: attachments.map((a) => a.storagePath ?? a.dataUrl),
      signature_applicant: signature,
      created_by: permit?.created_by ?? userId,
      status: submitMode as PermitStatus,
    })
  }

  const saveDraft = () => submitAndSubmitForApproval('DRAFT')
  const saveSubmitted = () => submitAndSubmitForApproval('SUBMITTED')

  return (
    <>
      <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="max-w-3xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>{permit ? `Edit ${permit.permit_number}` : 'New permit to work'}</DialogTitle>
          </DialogHeader>
          <form onSubmit={(e) => { e.preventDefault(); saveDraft() }} className="space-y-5">
            <FieldSet title="Job details">
              <div className="grid gap-3 sm:grid-cols-2">
                <Field label="Depot *">
                  <Select value={depotId} onValueChange={setDepotId}>
                    <SelectTrigger><SelectValue placeholder={depotName(depotId) || 'Select'} /></SelectTrigger>
                    <SelectContent>{depots.map((d) => <SelectItem key={d.id} value={d.id}>{d.name} ({d.code})</SelectItem>)}</SelectContent>
                  </Select>
                </Field>
                <Field label="Permit type">
                  <Select value={permitType} onValueChange={setPermitType}>
                    <SelectTrigger><SelectValue placeholder="Select type" /></SelectTrigger>
                    <SelectContent>{PERMIT_TYPES.map((t) => <SelectItem key={t} value={t}>{t}</SelectItem>)}</SelectContent>
                  </Select>
                </Field>
                <Field label="Job title *"><Input value={jobTitle} onChange={(e) => setJobTitle(e.target.value)} /></Field>
                <Field label="Location"><Input value={location} onChange={(e) => setLocation(e.target.value)} /></Field>
                <Field label="Start"><Input type="datetime-local" value={startDt} onChange={(e) => setStartDt(e.target.value)} /></Field>
                <Field label="End"><Input type="datetime-local" value={endDt} onChange={(e) => setEndDt(e.target.value)} /></Field>
              </div>
              <Field label="Job description"><Textarea rows={2} value={jobDescription} onChange={(e) => setJobDescription(e.target.value)} /></Field>
              <Field label="Tasks (comma separated)"><Input value={tasks} onChange={(e) => setTasks(e.target.value)} /></Field>
            </FieldSet>

            <FieldSet title={`Hazard assessment (${hazards.length})`}>
              <div className="space-y-3">
                {hazards.map((h, i) => (
                  <div key={i} className="space-y-2 rounded-lg border border-gray-100 p-3">
                    <div className="flex items-center justify-between">
                      <span className="text-sm font-medium">Hazard {i + 1}</span>
                      <Button type="button" size="sm" variant="ghost" className="h-6 text-xs text-rag-bad" onClick={() => setHazards((prev) => prev.filter((_, idx) => idx !== i))}>
                        Remove
                      </Button>
                    </div>
                    <div className="grid gap-2 sm:grid-cols-2">
                      <Input placeholder="Hazard" value={h.hazard} onChange={(e) => patchHazard(i, { hazard: e.target.value })} />
                      <Input placeholder="Consequence" value={h.consequence} onChange={(e) => patchHazard(i, { consequence: e.target.value })} />
                    </div>
                    <div className="grid gap-2 sm:grid-cols-2">
                      <Input placeholder="Existing controls" value={h.existing_controls} onChange={(e) => patchHazard(i, { existing_controls: e.target.value })} />
                      <Input placeholder="Additional controls" value={h.additional_controls} onChange={(e) => patchHazard(i, { additional_controls: e.target.value })} />
                    </div>
                    <div className="grid gap-2 sm:grid-cols-2">
                      <Input type="number" min={0} placeholder="Initial risk (likelihood × severity)" value={h.initial_risk || ''} onChange={(e) => patchHazard(i, { initial_risk: Number(e.target.value) || 0 })} />
                      <Input type="number" min={0} placeholder="Residual risk" value={h.residual_risk || ''} onChange={(e) => patchHazard(i, { residual_risk: Number(e.target.value) || 0 })} />
                    </div>
                  </div>
                ))}
                <Button type="button" variant="outline" size="sm" onClick={addHazard}>+ Add hazard</Button>
                {hazards.length > 0 && <RiskMatrix initialScore={hazards[0].initial_risk || null} residualScore={hazards[0].residual_risk || null} />}
              </div>
            </FieldSet>

            <FieldSet title="PPE">
              <div className="flex flex-wrap gap-2">
                {PPE_OPTIONS.map((opt) => (
                  <button
                    key={opt}
                    type="button"
                    onClick={() => togglePpe(opt)}
                    className={`rounded-full border px-3 py-1 text-xs transition-colors ${ppe.includes(opt) ? 'border-brand bg-brand text-white' : 'border-gray-200 bg-white text-muted-foreground'}`}
                  >
                    {opt}
                  </button>
                ))}
              </div>
            </FieldSet>

            <FieldSet title="Isolation / LOTO">
              <Textarea rows={2} value={isolation} onChange={(e) => setIsolation(e.target.value)} placeholder="Isolation points, lock-out/tag-out details…" />
            </FieldSet>

            <FieldSet title="Certificates">
              <Input value={certificates} onChange={(e) => setCertificates(e.target.value)} placeholder="e.g. Confined space cert, lifting supervisor cert" />
            </FieldSet>

            <FieldSet title="Attachments & signature">
              <div className="flex flex-wrap items-center gap-3">
                <Button type="button" variant="outline" size="sm" onClick={() => setCameraOpen(true)}>
                  <Camera className="mr-1 h-4 w-4" /> {attachments.length > 0 ? `${attachments.length} file${attachments.length === 1 ? '' : 's'}` : 'Add attachments'}
                </Button>
                {attachments.length > 0 && (
                  <div className="flex gap-2">
                    {attachments.map((a, i) => <img key={i} src={a.dataUrl} alt="attachment" className="h-14 w-14 rounded-md border object-cover" />)}
                  </div>
                )}
              </div>
              <div className="mt-3">
                <Label className="mb-1 block text-sm font-medium text-muted-foreground">Applicant signature</Label>
                <SignaturePad userId={userId} onSignature={setSignature} defaultValue={signature} />
              </div>
            </FieldSet>

            <DialogFooter className="flex-wrap gap-2">
              <Button type="button" variant="ghost" onClick={() => onOpenChange(false)}>Cancel</Button>
              <Button type="button" variant="outline" disabled={saving} onClick={saveDraft}>
                Save draft
              </Button>
              <Button type="button" disabled={saving} onClick={saveSubmitted}>
                <CheckCircle2 className="mr-1 h-4 w-4" /> Submit for approval
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
      <CameraModal open={cameraOpen} onOpenChange={setCameraOpen} userId={userId} bucket="attachments" multiple onCaptured={(files) => setAttachments(files)} />
    </>
  )
}

function FieldSet({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="space-y-3">
      <h3 className="text-base font-semibold text-inherit">{title}</h3>
      <div className="space-y-3">{children}</div>
    </div>
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