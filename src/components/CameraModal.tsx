import { useCallback, useEffect, useRef, useState } from 'react'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Camera, ImagePlus, X } from 'lucide-react'
import { cn } from '@/lib/utils'
import { enqueueAndUpload } from '@/components/OfflineUploadQueue'
import { toast } from 'sonner'

export type CapturedPhoto = { dataUrl: string; storagePath: string | null }

interface CameraModalProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  /** Required for uploading. Provide current user id. */
  userId: string
  bucket?: 'images' | 'attachments'
  multiple?: boolean
  onCaptured: (photos: CapturedPhoto[]) => void
}

/**
 * In-app camera capture via getUserMedia, plus gallery multi-select.
 * All capture flows are offline-safe: data URLs feed the upload queue.
 */
export default function CameraModal({ open, onOpenChange, userId, bucket = 'images', multiple = true, onCaptured }: CameraModalProps) {
  const videoRef = useRef<HTMLVideoElement | null>(null)
  const streamRef = useRef<MediaStream | null>(null)
  const [mode, setMode] = useState<'camera' | 'gallery'>('camera')
  const [error, setError] = useState<string | null>(null)
  const [captured, setCaptured] = useState<CapturedPhoto[]>([])
  const [uploading, setUploading] = useState(false)

  const stopStream = useCallback(() => {
    streamRef.current?.getTracks().forEach((t) => t.stop())
    streamRef.current = null
  }, [])

  useEffect(() => {
    return () => stopStream()
  }, [stopStream])

  useEffect(() => {
    if (!open) return
    setMode('camera')
    setError(null)
    setCaptured([])
  }, [open])

  const startCamera = useCallback(async () => {
    setError(null)
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' }, audio: false })
      streamRef.current = stream
      if (videoRef.current) {
        videoRef.current.srcObject = stream
        await videoRef.current.play().catch(() => undefined)
      }
    } catch {
      setError('Unable to access the camera. Grant permission or use gallery upload instead.')
    }
  }, [])

  useEffect(() => {
    if (open && mode === 'camera') void startCamera()
    else stopStream()
  }, [open, mode, startCamera, stopStream])

  const snap = () => {
    const video = videoRef.current
    if (!video) return
    const canvas = document.createElement('canvas')
    canvas.width = video.videoWidth || 1280
    canvas.height = video.videoHeight || 720
    canvas.getContext('2d')!.drawImage(video, 0, 0)
    setCaptured((prev) => [...prev, { dataUrl: canvas.toDataURL('image/jpeg', 0.82), storagePath: null }])
  }

  const onPickFiles = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files ?? [])
    Promise.all(
      files.map(
        (f) =>
          new Promise<CapturedPhoto>((resolve) => {
            const reader = new FileReader()
            reader.onload = () => resolve({ dataUrl: String(reader.result), storagePath: null })
            reader.readAsDataURL(f)
          }),
      ),
    ).then((photos) => setCaptured((prev) => (multiple ? [...prev, ...photos] : photos.slice(-1))))
  }

  const uploadEngine = async (photos: CapturedPhoto[]) => {
    const done: CapturedPhoto[] = []
    for (const p of photos) {
      if (p.storagePath) {
        done.push(p)
        continue
      }
      const ext = p.dataUrl.includes('image/png') ? 'png' : 'jpg'
      try {
        const path = await enqueueAndUpload({
          bucket,
          userId,
          filename: `capture_${Date.now()}.${ext}`,
          dataUrl: p.dataUrl,
        })
        done.push({ ...p, storagePath: path })
      } catch {
        toast.error('Upload failed — queued for offline retry.')
        done.push(p)
      }
    }
    return done
  }

  const confirm = async () => {
    if (captured.length === 0) return
    setUploading(true)
    const result = await uploadEngine(captured)
    onCaptured(result)
    setUploading(false)
    onOpenChange(false)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>Capture photos</DialogTitle>
        </DialogHeader>
        <div className="flex gap-2">
          <Button size="sm" variant={mode === 'camera' ? 'default' : 'outline'} onClick={() => setMode('camera')}>
            <Camera className="mr-1 h-4 w-4" /> Camera
          </Button>
          <Button size="sm" variant={mode === 'gallery' ? 'default' : 'outline'} onClick={() => setMode('gallery')}>
            <ImagePlus className="mr-1 h-4 w-4" /> Gallery
          </Button>
        </div>

        {mode === 'camera' ? (
          <div className="space-y-2">
            <div className="relative overflow-hidden rounded-md bg-black">
              <video ref={videoRef} playsInline muted className="aspect-video w-full object-cover" />
              {captured.length > 0 && <div className="absolute right-2 top-2 rounded bg-black/60 px-2 py-1 text-xs text-white">{captured.length} shot</div>}
            </div>
            {error && <div className="text-sm text-red-600">{error}</div>}
            <div className="flex items-center justify-center gap-3">
              <Button type="button" onClick={snap} disabled={Boolean(error)}>
                Take photo
              </Button>
              {captured.length > 0 && (
                <Button type="button" variant="outline" onClick={() => setCaptured((p) => p.slice(0, -1))}>
                  Undo
                </Button>
              )}
            </div>
          </div>
        ) : (
          <div className="space-y-2">
            <label className="flex cursor-pointer items-center justify-center gap-2 rounded-md border border-dashed py-6 text-sm text-muted-foreground hover:bg-muted">
              <ImagePlus className="h-5 w-5" />
              Select images
              <input type="file" accept="image/*" multiple={multiple} className="hidden" onChange={onPickFiles} />
            </label>
          </div>
        )}

        {captured.length > 0 && (
          <div className={cn('grid gap-2', multiple ? 'grid-cols-3' : 'grid-cols-1')}>
            {captured.map((p, i) => (
              <div key={i} className="relative overflow-hidden rounded-md border">
                <img src={p.dataUrl} alt={`capture ${i + 1}`} className="aspect-square w-full object-cover" />
                <button
                  className="absolute right-1 top-1 rounded-full bg-black/70 p-1 text-white"
                  onClick={() => setCaptured((prev) => prev.filter((_, idx) => idx !== i))}
                >
                  <X className="h-3 w-3" />
                </button>
              </div>
            ))}
          </div>
        )}

        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button onClick={confirm} disabled={captured.length === 0 || uploading}>
            {uploading ? 'Uploading…' : `Use ${captured.length} photo${captured.length === 1 ? '' : 's'}`}
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  )
}