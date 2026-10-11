import { useEffect, useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { FileText, Users, Plus, Camera, Download, Trash2 } from 'lucide-react'
import { toast } from 'sonner'
import JSZip from 'jszip'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { CardContent } from '@/components/ui/card'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { PageHeader, EmptyState, SectionCard, KPICard } from '@/components/shared'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { useDepotFilter } from '@/hooks/useDepotFilter'
import CameraModal, { type CapturedPhoto } from '@/components/CameraModal'
import SignaturePad from '@/components/SignaturePad'
import { getSettings } from '@/services/settings.service'
import { buildToolboxTalkPdf } from '@/components/pdf/pdfUtils'
import { listToolboxTalks, createToolboxTalk, updateToolboxTalk, replaceAttendees, listAttendees, deleteToolboxTalk } from '@/services/toolboxTalks.service'
import { listDepots } from '@/services/depots.service'
import { storage } from '@/services/storage.service'
import { formatDate, cn } from '@/lib/utils'
import type { ToolboxTalk, ToolboxAttendee } from '@/types/entities'

export default function ToolboxTalks() {
  const user = useCurrentUser()
  const { depotId } = useDepotFilter()
  const queryClient = useQueryClient()
  const [creating, setCreating] = useState(false)
  const [editing, setEditing] = useState<ToolboxTalk | null>(null)
  const [viewing, setViewing] = useState<ToolboxTalk | null>(null)
  const [q, setQ] = useState('')

  const { data: talks = [] } = useQuery({
    queryKey: ['toolbox-talks', depotId ?? 'all'],
    queryFn: () => listToolboxTalks(depotId ? { depotId } : {}),
  })
  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const depotName = (id: string | null) => depots.find((d) => d.id === id)?.name ?? '—'

  const scoped = useMemo(
    () => (user.isCountryHead ? talks : talks.filter((t) => t.depot_id === user.effectiveDepotId)),
    [talks, user],
  )
  const qNorm = q.trim().toLowerCase()
  const filtered = qNorm ? scoped.filter((t) => t.topic.toLowerCase().includes(qNorm) || t.facilitator.toLowerCase().includes(qNorm)) : scoped

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['toolbox-talks'] })

  const del = useMutation({
    mutationFn: deleteToolboxTalk,
    onSuccess: () => {
      toast.success('Toolbox talk deleted')
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not delete'),
  })

  const setOpen = (v: boolean) => {
    if (!v) {
      setCreating(false)
      setEditing(null)
    }
  }

  const save = useMutation({
    mutationFn: async ({ input, attendees }: { input: Partial<ToolboxTalk>; attendees: Omit<ToolboxAttendee, 'id' | 'toolbox_talk_id' | 'created_at'>[] }) => {
      const talk = editing ? await updateToolboxTalk(editing.id, input) : await createToolboxTalk(input)
      await replaceAttendees(talk.id, attendees)
      return talk
    },
    onSuccess: () => {
      toast.success(editing ? 'Toolbox talk updated' : 'Toolbox talk created')
      setCreating(false)
      setEditing(null)
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not save toolbox talk'),
  })

  return (
    <div className="space-y-8">
      <PageHeader
        title="Toolbox Talks"
        subtitle={`${scoped.length} talks on record`}
        actions={<Button onClick={() => setCreating(true)}><Plus className="mr-1 h-4 w-4" /> New talk</Button>}
      />

      <div className="grid grid-cols-1 gap-6 sm:grid-cols-3">
        <KPICard icon={<FileText className="h-4 w-4" />} iconHue="red" label="All talks" value={scoped.length} />
        <KPICard icon={<Users className="h-4 w-4" />} iconHue="blue" label="This month" value={scoped.filter((t) => t.talk_date?.slice(0, 7) === new Date().toISOString().slice(0, 7)).length} />
      </div>

      {filtered.length === 0 ? (
        <EmptyState title="No toolbox talks" description="Run your first toolbox talk with attendees signed off and photographic evidence." />
      ) : (
        <SectionCard title="Talk register">
          <CardContent className="p-0">
            <div className="p-4">
              <Input placeholder="Search topic or facilitator…" value={q} onChange={(e) => setQ(e.target.value)} className="max-w-sm" />
            </div>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Date</TableHead>
                  <TableHead>Topic</TableHead>
                  <TableHead className="hidden sm:table-cell">Facilitator</TableHead>
                  <TableHead className="hidden md:table-cell">Depot</TableHead>
                  <TableHead className="w-24">{/* actions */}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filtered.map((t) => (
                  <TableRow key={t.id}>
                    <TableCell>{formatDate(t.talk_date)}</TableCell>
                    <TableCell className="max-w-[14rem]"><span className="line-clamp-1 font-medium">{t.topic}</span></TableCell>
                    <TableCell className="hidden sm:table-cell">{t.facilitator}</TableCell>
                    <TableCell className="hidden md:table-cell">{depotName(t.depot_id)}</TableCell>
                    <TableCell className="text-right">
                      <div className="flex justify-end gap-2">
                        <Button size="sm" variant="outline" className="h-7 text-xs" onClick={() => setViewing(t)}>View</Button>
                        <Button size="sm" variant="ghost" className="h-7 px-2 text-rag-bad" onClick={() => del.mutate(t.id)}>
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </SectionCard>
      )}

      <TalkForm
        open={creating || editing !== null}
        onOpenChange={setOpen}
        talk={editing}
        userId={user.userId ?? 'anon'}
        defaultDepotId={user.effectiveDepotId ?? undefined}
        depotName={depotName}
        onSave={(input, attendees) => save.mutate({ input, attendees })}
        saving={save.isPending}
      />

      <TalkDetail
        talk={viewing}
        onClose={() => setViewing(null)}
        onEdit={(t) => {
          setViewing(null)
          setEditing(t)
        }}
      />
    </div>
  )
}

function TalkForm({
  open,
  onOpenChange,
  talk,
  userId,
  defaultDepotId,
  depotName,
  onSave,
  saving,
}: {
  open: boolean
  onOpenChange: (v: boolean) => void
  talk: ToolboxTalk | null
  userId: string
  defaultDepotId?: string
  depotName: (id: string | null) => string
  onSave: (input: Partial<ToolboxTalk>, attendees: Omit<ToolboxAttendee, 'id' | 'toolbox_talk_id' | 'created_at'>[]) => void
  saving: boolean
}) {
  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const [depotId, setDepotId] = useState(defaultDepotId ?? '')
  const [talkDate, setTalkDate] = useState(new Date().toISOString().slice(0, 10))
  const [facilitator, setFacilitator] = useState('')
  const [topic, setTopic] = useState('')
  const [discussion, setDiscussion] = useState('')
  const [takeaways, setTakeaways] = useState('')
  const [actions, setActions] = useState('')
  const [photos, setPhotos] = useState<CapturedPhoto[]>([])
  const [attendees, setAttendees] = useState<{ name: string; signature: string | null; signing: boolean }[]>([])
  const [cameraOpen, setCameraOpen] = useState(false)

  useEffect(() => {
    if (!open) return
    setDepotId(talk?.depot_id ?? defaultDepotId ?? '')
    setTalkDate(talk?.talk_date ?? new Date().toISOString().slice(0, 10))
    setFacilitator(talk?.facilitator ?? '')
    setTopic(talk?.topic ?? '')
    setDiscussion(talk?.discussion_points ?? '')
    setTakeaways(talk?.takeaways ?? '')
    setActions(talk?.action_items ?? '')
    setPhotos((talk?.photo_paths ?? []).map((p) => ({ dataUrl: storage.publicUrl('images', p), storagePath: p })))
    setAttendees([])
    if (talk) {
      void listAttendees(talk.id).then((list) =>
        setAttendees(list.map((a) => ({ name: a.full_name, signature: a.signature_path, signing: false }))),
      )
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, talk, defaultDepotId])

  const addAttendee = () => setAttendees((prev) => [...prev, { name: '', signature: null, signing: false }])

  const submit = () => {
    if (!depotId) return toast.error('Depot is required.')
    if (!facilitator.trim()) return toast.error('Facilitator is required.')
    if (!topic.trim()) return toast.error('Topic is required.')
    const valid = attendees.filter((a) => a.name.trim())
    if (valid.length === 0) return toast.error('Add at least one attendee.')
    onSave(
      {
        depot_id: depotId,
        talk_date: talkDate,
        facilitator: facilitator.trim(),
        topic: topic.trim(),
        discussion_points: discussion || null,
        takeaways: takeaways || null,
        action_items: actions || null,
        photo_paths: photos.map((p) => p.storagePath ?? p.dataUrl),
        created_by: talk?.created_by ?? userId,
      },
      valid.map((a) => ({ full_name: a.name.trim(), signature_path: a.signature })),
    )
  }

  return (
    <>
      <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="max-h-[92vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>{talk ? 'Edit toolbox talk' : 'New toolbox talk'}</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <div className="grid gap-3 sm:grid-cols-2">
              <Field label="Depot *">
                <Select value={depotId} onValueChange={setDepotId}>
                  <SelectTrigger><SelectValue placeholder={depotName(depotId) || 'Select'} /></SelectTrigger>
                  <SelectContent>{depots.map((d) => <SelectItem key={d.id} value={d.id}>{d.name} ({d.code})</SelectItem>)}</SelectContent>
                </Select>
              </Field>
              <Field label="Date"><Input type="date" value={talkDate} onChange={(e) => setTalkDate(e.target.value)} /></Field>
              <Field label="Facilitator *"><Input value={facilitator} onChange={(e) => setFacilitator(e.target.value)} /></Field>
              <Field label="Topic *"><Input value={topic} onChange={(e) => setTopic(e.target.value)} /></Field>
            </div>
            <Field label="Discussion points"><Textarea rows={3} value={discussion} onChange={(e) => setDiscussion(e.target.value)} /></Field>
            <Field label="Takeaways"><Textarea rows={2} value={takeaways} onChange={(e) => setTakeaways(e.target.value)} /></Field>
            <Field label="Action items"><Textarea rows={2} value={actions} onChange={(e) => setActions(e.target.value)} /></Field>

            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <Label className="text-sm font-medium text-muted-foreground">Attendees *</Label>
                <Button type="button" size="sm" variant="outline" onClick={addAttendee}>+ Add</Button>
              </div>
              {attendees.length === 0 && <p className="text-sm text-muted-foreground">No attendees yet.</p>}
              <div className="space-y-3">
                {attendees.map((a, i) => (
                  <div key={i} className="rounded-lg border p-3">
                    <div className="flex items-center gap-2">
                      <Input placeholder={`Attendee ${i + 1} name`} value={a.name} onChange={(e) => setAttendees((prev) => prev.map((x, idx) => (idx === i ? { ...x, name: e.target.value } : x)))} />
                      <Button
                        type="button"
                        size="sm"
                        variant="ghost"
                        className="h-8 px-2 text-rag-bad"
                        onClick={() => setAttendees((prev) => prev.filter((_, idx) => idx !== i))}
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </div>
                    <div className="mt-2 flex items-center gap-2">
                      <Button type="button" size="sm" variant={a.signature ? 'ghost' : 'outline'} className="text-xs" onClick={() => setAttendees((prev) => prev.map((x, idx) => (idx === i ? { ...x, signing: !x.signing } : x)))}>
                        {a.signature ? 'Re-sign' : 'Sign'}
                      </Button>
                      {a.signature ? <span className="text-xs text-green-600">Signed ✓</span> : <span className="text-xs text-muted-foreground">Pending</span>}
                    </div>
                    {a.signing && (
                      <div className="mt-2">
                        <SignaturePad userId={userId} defaultValue={a.signature} onSignature={(path) => {
                          setAttendees((prev) => prev.map((x, idx) => (idx === i ? { name: x.name, signature: path, signing: false } : x)))
                        }} />
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </div>

            <div className="space-y-2">
              <Label className="text-sm font-medium text-muted-foreground">Photo evidence</Label>
              <div className="flex flex-wrap items-center gap-3">
                <Button type="button" variant="outline" size="sm" onClick={() => setCameraOpen(true)}>
                  <Camera className="mr-1 h-4 w-4" /> {photos.length > 0 ? `${photos.length} photo${photos.length === 1 ? '' : 's'}` : 'Add photos'}
                </Button>
                {photos.map((p, i) => (
                  <button key={i} type="button" onClick={() => setPhotos((prev) => prev.filter((_, idx) => idx !== i))} className="group relative">
                    <img src={p.dataUrl} alt={`photo ${i + 1}`} className="h-14 w-14 rounded-md border object-cover" />
                    <span className="absolute -right-1 -top-1 hidden h-4 w-4 items-center justify-center rounded-full bg-rag-bad text-[10px] text-white group-hover:flex">×</span>
                  </button>
                ))}
              </div>
            </div>

            <DialogFooter>
              <Button type="button" variant="ghost" onClick={() => onOpenChange(false)}>Cancel</Button>
              <Button type="button" disabled={saving} onClick={submit}>{saving ? 'Saving…' : talk ? 'Save changes' : 'Create talk'}</Button>
            </DialogFooter>
          </div>
        </DialogContent>
      </Dialog>
      <CameraModal open={cameraOpen} onOpenChange={setCameraOpen} userId={userId} bucket="images" multiple onCaptured={(files) => setPhotos((prev) => [...prev, ...files])} />
    </>
  )
}

function TalkDetail({ talk, onClose, onEdit }: { talk: ToolboxTalk | null; onClose: () => void; onEdit: (t: ToolboxTalk) => void }) {
  const [attendees, setAttendees] = useState<ToolboxAttendee[]>([])
  const [lightbox, setLightbox] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const { data: settings } = useQuery({ queryKey: ['settings'], queryFn: () => getSettings() })

  useEffect(() => {
    if (!talk) return
    setAttendees([])
    setLightbox(null)
    void listAttendees(talk.id).then(setAttendees).catch(() => void 0)
  }, [talk])

  const photoUrls = talk?.photo_paths.map((p) => storage.publicUrl('images', p)) ?? []

  const downloadImages = async () => {
    if (!talk) return
    setBusy(true)
    try {
      if (photoUrls.length === 0) return
      if (photoUrls.length === 1) {
        const blob = await storage.download('images', talk.photo_paths[0])
        const url = URL.createObjectURL(blob)
        const a = document.createElement('a')
        a.href = url
        a.download = `toolbox_${talk.talk_date}.jpg`
        a.click()
        URL.revokeObjectURL(url)
      } else {
        const zip = new JSZip()
        for (const path of talk.photo_paths) {
          const blob = await storage.download('images', path)
          zip.file(path.split('/').pop() ?? 'photo.jpg', blob)
        }
        const blob = await zip.generateAsync({ type: 'blob' })
        const url = URL.createObjectURL(blob)
        const a = document.createElement('a')
        a.href = url
        a.download = `toolbox_${talk.talk_date}_photos.zip`
        a.click()
        URL.revokeObjectURL(url)
      }
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Download failed')
    } finally {
      setBusy(false)
    }
  }

  const downloadPdf = async () => {
    if (!talk || !settings) return
    const doc = buildToolboxTalkPdf(talk, attendees, settings)
    doc.save(`toolbox_${talk.talk_date}.pdf`)
  }

  return (
    <Dialog open={Boolean(talk)} onOpenChange={(v) => { if (!v) onClose() }}>
      <DialogContent className="max-w-2xl max-h-[92vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Toolbox talk — {talk?.topic}</DialogTitle>
        </DialogHeader>
        {talk && (
          <div className="space-y-5">
            <div className="grid gap-1 text-sm sm:grid-cols-2">
              <span>Date: <strong>{formatDate(talk.talk_date)}</strong></span>
              <span>Facilitator: <strong>{talk.facilitator}</strong></span>
            </div>
            {(talk.discussion_points || talk.takeaways || talk.action_items) && (
              <div className="space-y-3 text-sm">
                {talk.discussion_points && <p><strong>Discussion:</strong> {talk.discussion_points}</p>}
                {talk.takeaways && <p><strong>Takeaways:</strong> {talk.takeaways}</p>}
                {talk.action_items && <p><strong>Actions:</strong> {talk.action_items}</p>}
              </div>
            )}

            <SectionCard title={`Attendees (${attendees.length})`}>
              <CardContent className="space-y-2">
                {attendees.map((a) => (
                  <div key={a.id} className="flex items-center justify-between rounded-lg border p-2">
                    <span className="text-sm font-medium">{a.full_name}</span>
                    <span className={cn('text-xs', a.signature_path ? 'text-green-600' : 'text-muted-foreground')}>
                      {a.signature_path ? 'Signed ✓' : 'No signature'}
                    </span>
                  </div>
                ))}
                {attendees.length === 0 && <p className="text-sm text-muted-foreground">No attendees.</p>}
              </CardContent>
            </SectionCard>

            {photoUrls.length > 0 && (
              <div className="grid grid-cols-3 gap-2">
                {photoUrls.map((u, i) => (
                  <button key={i} onClick={() => setLightbox(u)} className="group relative">
                    <img src={u} alt={`photo ${i + 1}`} className="aspect-square w-full rounded-lg object-cover" />
                  </button>
                ))}
              </div>
            )}

            <div className="flex flex-wrap gap-2">
              <Button size="sm" variant="outline" onClick={downloadImages} disabled={busy || photoUrls.length === 0}>
                <Download className="mr-1 h-4 w-4" /> {photoUrls.length > 1 ? 'Download images (zip)' : 'Download image'}
              </Button>
              <Button size="sm" variant="outline" onClick={downloadPdf} disabled={!settings}>
                <FileText className="mr-1 h-4 w-4" /> Generate PDF
              </Button>
              <Button size="sm" variant="ghost" onClick={() => onEdit(talk)}>Edit</Button>
            </div>
          </div>
        )}
      </DialogContent>
      <Dialog open={Boolean(lightbox)} onOpenChange={(v) => { if (!v) setLightbox(null) }}>
        <DialogContent className="max-w-2xl">
          {lightbox && <img src={lightbox} alt="lightbox" className="w-full rounded-lg" />}
        </DialogContent>
      </Dialog>
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