import { useMemo, useState } from 'react'
import { Camera, Check, FileSignature, Gauge, Save } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Badge } from '@/components/ui/badge'
import { toast } from 'sonner'
import type { RoutineTask } from '@/types/entities'
import { expectedOccurrencesFor, type TaskContext } from '@/hooks/useTaskVisibility'
import { useGPS } from '@/hooks/useGPS'
import CameraModal from '@/components/CameraModal'
import SignaturePad from '@/components/SignaturePad'

export type CompletionInput = {
  task: RoutineTask
  taskId: string
  occurrences: number
  comment: string
  photos: string[]
  signature: string | null
  attendance: number | null
  aiVerified: boolean
}

type Props = {
  open: boolean
  onOpenChange: (open: boolean) => void
  task: RoutineTask | null
  userId: string
  currentUserName: string
  context: TaskContext
  onConfirm: (input: CompletionInput) => Promise<void>
}

export default function CompletionDialog({ open, onOpenChange, task, userId, currentUserName, context, onConfirm }: Props) {
  const [comment, setComment] = useState('')
  const [photos, setPhotos] = useState<string[]>([])
  const [signature, setSignature] = useState<string | null>(null)
  const [occurrences, setOccurrences] = useState(1)
  const [attendance, setAttendance] = useState('')
  const [cameraOpen, setCameraOpen] = useState(false)
  const [saving, setSaving] = useState(false)

  const { position, ready, error: gpsError, loading: gpsLoading, requestGpsFix } = useGPSView()
  const accuracy = position?.accuracy

  const expected = useMemo(() => (task ? expectedOccurrencesFor(task, context) : 1), [task, context])

  if (!task) return null

  const targets = {
    VEHICLE: context.truckInspectionsToday,
    PERMIT: context.permitsActiveToday,
    EQUIPMENT: context.equipmentCount,
    PERSONNEL: context.personnelCount,
  } as const

  const autoTarget = targets[task.task_type as keyof typeof targets]

  const submit = async () => {
    if (task.linked_module === 'TOOLBOX') {
      const n = Number(attendance)
      if (Number.isNaN(n) || n <= 0) {
        toast.error('Enter attendee count.')
        return
      }
    }
    if (task.task_type === 'COUNT' && occurrences < 1) {
      toast.error('Enter a count of at least 1.')
      return
    }
    if (task.requires_photo_on_completion && photos.length === 0) {
      toast.warning('This task requires photographic evidence. Add at least one photo.')
      return
    }
    if (!ready) {
      toast.error('GPS accuracy not ready. Wait for a GPS fix or check your connection.')
      return
    }
    if (accuracy && accuracy > 200) {
      toast.warning('GPS accuracy is low; fix may still be recorded.')
    }
    setSaving(true)
    try {
      await onConfirm({
        task,
        taskId: task.id,
        occurrences,
        comment,
        photos,
        signature,
        attendance: task.linked_module === 'TOOLBOX' ? Number(attendance) : null,
        aiVerified: task.task_type === 'AI_VERIFIED',
      })
      toast.success('Completion recorded.')
      setComment('')
      setPhotos([])
      setSignature(null)
      setAttendance('')
      setOccurrences(1)
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Failed to record completion')
    } finally {
      setSaving(false)
    }
  }

  return (
    <>
      <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle>Complete: {task.title}</DialogTitle>
            <DialogDescription>
              {task.task_type.replace(/_/g, ' ')} ·{' '}
              {expected > 1 && `${expected} occurrence${expected > 1 ? 's' : ''} expected today`}
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-3">
            <Tabs defaultValue="form">
              <TabsList className="w-full">
                <TabsTrigger value="form" className="flex-1">
                  <Check className="mr-1 h-3.5 w-3.5" /> Form
                </TabsTrigger>
                <TabsTrigger value="photo" className="flex-1">
                  <Camera className="mr-1 h-3.5 w-3.5" /> Photos
                </TabsTrigger>
                <TabsTrigger value="sign" className="flex-1">
                  <FileSignature className="mr-1 h-3.5 w-3.5" /> Signature
                </TabsTrigger>
                {task.linked_module !== 'TOOLBOX' && (
                  <TabsTrigger value="count" className="flex-1">
                    <Gauge className="mr-1 h-3.5 w-3.5" /> Count
                  </TabsTrigger>
                )}
              </TabsList>

              <TabsContent value="form" className="space-y-3 pt-2">
                {(task.task_type === 'VEHICLE' || task.task_type === 'PERMIT' || task.task_type === 'EQUIPMENT' || task.task_type === 'PERSONNEL') && (
                  <div className="rounded-md bg-muted px-3 py-2 text-sm">
                    Auto-detected today: <b>{autoTarget}</b>. Linked-module records are reused for this task.
                  </div>
                )}
                <div className="space-y-1.5">
                  <Label>Comment / remarks</Label>
                  <Textarea rows={3} value={comment} onChange={(e) => setComment(e.target.value)} placeholder="Notes (optional for most methods)" />
                </div>
                <div className="flex items-center justify-between rounded-md border px-3 py-2 text-sm">
                  <span className="flex items-center gap-1.5">
                    <Gauge className="h-4 w-4 text-muted-foreground" /> GPS
                    {ready ? <Badge variant="outline" className="text-rag-good">Fix acquired</Badge> : <Badge variant="outline" className="text-rag-warn">{gpsLoading ? 'Locating…' : 'Waiting…'}</Badge>}
                    {accuracy ? <span className="text-xs text-muted-foreground">±{Math.round(accuracy)} m</span> : null}
                  </span>
                  <Button size="sm" variant="ghost" onClick={() => void requestGpsFix()}>
                    Retry fix
                  </Button>
                </div>
                {gpsError && <p className="text-xs text-red-600">{gpsError}</p>}
                {task.linked_module === 'TOOLBOX' && (
                  <div className="space-y-1.5">
                    <Label htmlFor="attendance">Attendee count (required)</Label>
                    <Input id="attendance" type="number" min={1} value={attendance} onChange={(e) => setAttendance(e.target.value)} placeholder="e.g. 8" />
                  </div>
                )}
                {task.task_type === 'COUNT' && (
                  <div className="space-y-1.5">
                    <Label htmlFor="occurrences">Occurrences completed</Label>
                    <Input id="occurrences" type="number" min={1} value={occurrences} onChange={(e) => setOccurrences(Math.max(1, Number(e.target.value) || 1))} />
                  </div>
                )}
                {task.task_type === 'AI_VERIFIED' && (
                  <div className="flex items-center justify-between rounded-md bg-amber-50 px-3 py-2 text-sm text-amber-800">
                    <span className="flex items-center gap-1.5">
                      <Check className="h-4 w-4" /> AI-verified pass
                    </span>
                    <Badge className="bg-amber-accent text-white">AI</Badge>
                  </div>
                )}
              </TabsContent>

              <TabsContent value="photo" className="space-y-3 pt-2">
                <div className="flex items-center justify-between">
                  <span className="text-sm text-muted-foreground">
                    {photos.length} photo{photos.length !== 1 ? 's' : ''} attached
                    {task.requires_photo_on_completion && ' · required on completion'}
                  </span>
                  <Button size="sm" variant="outline" onClick={() => setCameraOpen(true)}>
                    <Camera className="mr-1 h-4 w-4" /> Capture
                  </Button>
                </div>
                {photos.length > 0 && (
                  <div className="grid grid-cols-3 gap-2">
                    {photos.map((url) => (
                      <img key={url} src={url} alt="" className="h-20 w-full rounded-md object-cover" />
                    ))}
                  </div>
                )}
              </TabsContent>

              <TabsContent value="sign" className="space-y-3 pt-2">
                {signature ? (
                  <div className="flex flex-col items-center gap-2">
                    <span className="text-sm text-rag-good">Signature saved</span>
                    <Button size="sm" variant="ghost" onClick={() => setSignature(null)}>
                      Clear signature
                    </Button>
                  </div>
                ) : (
                  <>
                    <SignaturePad userId={userId} onSignature={setSignature} />
                    <p className="text-xs text-muted-foreground">Recording completion as {currentUserName}</p>
                  </>
                )}
              </TabsContent>

              {task.linked_module !== 'TOOLBOX' && (
                <TabsContent value="count" className="space-y-3 pt-2">
                  <div className="space-y-1.5">
                    <Label>Occurrences completed today</Label>
                    <Input type="number" min={1} max={expected} value={occurrences} onChange={(e) => setOccurrences(Math.max(1, Number(e.target.value) || 1))} />
                    <p className="text-xs text-muted-foreground">
                      Auto-derived from linked modules where possible. {expected} expected today.
                    </p>
                  </div>
                </TabsContent>
              )}
            </Tabs>

            <Button className="w-full" onClick={submit} disabled={saving}>
              <Save className="mr-1 h-4 w-4" /> {saving ? 'Saving…' : 'Record completion'}
            </Button>
          </div>
        </DialogContent>
      </Dialog>

      <CameraModal
        open={cameraOpen}
        onOpenChange={setCameraOpen}
        userId={userId}
        onCaptured={(items) => setPhotos((p) => [...p, ...items.map((i) => i.storagePath ?? i.dataUrl)])}
      />
    </>
  )
}

// --- GPS view helper: exposes ready/position and a retry trigger -------------

function useGPSView() {
  const { position, error, loading, request } = useGPS()
  return {
    position: position as { latitude: number; longitude: number; accuracy?: number } | null,
    ready: Boolean(position),
    error,
    loading,
    requestGpsFix: () => void request(),
  }
}