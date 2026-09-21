import { useEffect, useRef, useState, type Ref } from 'react'
import { Button } from '@/components/ui/button'
import { Eraser, PenLine } from 'lucide-react'
import { uploadFileWithRetry } from '@/services/storage.service'

interface SignaturePadProps {
  userId: string
  onSignature: (path: string | null) => void
  defaultValue?: string | null
}

/** Canvas signature pad. Outputs a storage path (or null when cleared). */
export default function SignaturePad({ userId, onSignature, defaultValue }: SignaturePadProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null)
  const [drawing, setDrawing] = useState(false)
  const [saved, setSaved] = useState<string | null>(defaultValue ?? null)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const dpr = window.devicePixelRatio || 1
    const rect = canvas.getBoundingClientRect()
    canvas.width = rect.width * dpr
    canvas.height = rect.height * dpr
    const ctx = canvas.getContext('2d')!
    ctx.scale(dpr, dpr)
    ctx.lineWidth = 2
    ctx.lineCap = 'round'
    ctx.lineJoin = 'round'
    ctx.strokeStyle = '#1a1a1a'
  }, [])

  const pos = (e: React.PointerEvent) => {
    const rect = canvasRef.current!.getBoundingClientRect()
    return { x: e.clientX - rect.left, y: e.clientY - rect.top }
  }

  const start = (e: React.PointerEvent) => {
    setDrawing(true)
    canvasRef.current?.setPointerCapture(e.pointerId)
    const { x, y } = pos(e)
    const ctx = canvasRef.current!.getContext('2d')!
    ctx.beginPath()
    ctx.moveTo(x, y)
  }

  const move = (e: React.PointerEvent) => {
    if (!drawing) return
    const { x, y } = pos(e)
    const ctx = canvasRef.current!.getContext('2d')!
    ctx.lineTo(x, y)
    ctx.stroke()
  }

  const end = () => setDrawing(false)

  const clear = () => {
    const ctx = canvasRef.current!.getContext('2d')!
    ctx.clearRect(0, 0, canvasRef.current!.width, canvasRef.current!.height)
    setSaved(null)
    onSignature(null)
  }

  const save = async () => {
    if (!canvasRef.current) return
    setSaving(true)
    setError(null)
    try {
      const blob = await new Promise<Blob | null>((resolve) =>
        canvasRef.current!.toBlob((b) => resolve(b), 'image/png'),
      )
      if (!blob) {
        setError('Could not read signature from canvas.')
        setSaving(false)
        return
      }
      const path = await uploadFileWithRetry('signatures', userId, blob, `sig_${Date.now()}.png`)
      setSaved(path)
      onSignature(path)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Upload failed')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="space-y-2">
      <div className="relative rounded-md border">
        <canvas
          ref={canvasRef as Ref<HTMLCanvasElement>}
          className="h-32 w-full touch-none"
          onPointerDown={start}
          onPointerMove={move}
          onPointerUp={end}
          onPointerLeave={end}
        />
        <PenLine className="pointer-events-none absolute left-2 top-2 h-4 w-4 text-muted-foreground/60" />
      </div>
      <div className="flex items-center gap-2">
        <Button type="button" size="sm" variant="outline" onClick={save} disabled={saving}>
          {saving ? 'Saving…' : 'Save signature'}
        </Button>
        <Button type="button" size="sm" variant="ghost" onClick={clear}>
          <Eraser className="mr-1 h-4 w-4" /> Clear
        </Button>
        {saved && <span className="text-xs text-green-600">Signature saved</span>}
        {error && <span className="text-xs text-red-600">{error}</span>}
      </div>
    </div>
  )
}