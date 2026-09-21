import { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Search, X } from 'lucide-react'
import { Input } from '@/components/ui/input'
import { Dialog, DialogContent } from '@/components/ui/dialog'
import { EmptyState } from '@/components/shared'
import { listInspections, listTruckInspections } from '@/services/inspections.service'
import { storage } from '@/services/storage.service'
import { formatDate, pathFromUrl } from '@/lib/utils'

export interface GalleryPhoto {
  id: string
  url: string
  sourceType: 'HSE_INSPECTION' | 'TRUCK_INSPECTION'
  sourceId: string
  questionText: string | null
  note: string | null
  depotId: string
  date: string
}

function resolveUrl(path: string): string {
  return storage.publicUrl('images', pathFromUrl(path) ?? path)
}

/**
 * Photo Evidence Gallery — aggregates every failed-item photo across
 * HSE + truck inspections, searchable, with a lightbox.
 */
export function PhotoGallery() {
  const [search, setSearch] = useState('')
  const [lightbox, setLightbox] = useState<string | null>(null)

  const inspections = useQuery({
    queryKey: ['inspections', 'all'],
    queryFn: () => listInspections(),
  })
  const truck = useQuery({
    queryKey: ['truck-inspections', 'all'],
    queryFn: () => listTruckInspections(),
  })

  const photos = useMemo<GalleryPhoto[]>(() => {
    const fromInspections: GalleryPhoto[] = (inspections.data ?? []).flatMap((ins) =>
      (ins.answers ?? [])
        .filter((a) => a.photo_paths && a.photo_paths.length > 0)
        .flatMap((a) =>
          a.photo_paths.map((p, idx) => ({
            id: `${ins.id}-${a.question_id}-${idx}`,
            url: resolveUrl(p),
            sourceType: 'HSE_INSPECTION' as const,
            sourceId: ins.id,
            questionText: a.note ?? null,
            note: a.corrective_action ?? null,
            depotId: ins.depot_id,
            date: ins.inspection_date,
          })),
        ),
    )
    const fromTruck: GalleryPhoto[] = (truck.data ?? []).flatMap((ti) =>
      (ti.answers ?? [])
        .filter((a) => a.photo_paths && a.photo_paths.length > 0)
        .flatMap((a) =>
          a.photo_paths.map((p, idx) => ({
            id: `${ti.id}-${a.question_id}-${idx}`,
            url: resolveUrl(p),
            sourceType: 'TRUCK_INSPECTION' as const,
            sourceId: ti.id,
            questionText: a.note ?? null,
            note: a.corrective_action ?? null,
            depotId: ti.depot_id,
            date: ti.inspection_date,
          })),
        ),
    )
    return [...fromInspections, ...fromTruck]
  }, [inspections.data, truck.data])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return photos
    return photos.filter(
      (p) =>
        (p.questionText ?? '').toLowerCase().includes(q) ||
        (p.note ?? '').toLowerCase().includes(q) ||
        p.date.toLowerCase().includes(q),
    )
  }, [photos, search])

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <div className="relative flex-1 max-w-sm">
          <Search className="absolute left-2.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search evidence (item, action, date)…" className="pl-8" />
        </div>
        <span className="text-sm text-muted-foreground">{filtered.length} photo{filtered.length === 1 ? '' : 's'}</span>
      </div>

      {filtered.length === 0 ? (
        <EmptyState title="No photo evidence yet" description="Photos attached to failed inspection items will appear here." />
      ) : (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
          {filtered.map((p) => (
            <button
              key={p.id}
              onClick={() => setLightbox(p.url)}
              className="group overflow-hidden rounded-lg border text-left"
            >
              <div className="relative aspect-square overflow-hidden bg-muted">
                <img src={p.url} alt="" className="h-full w-full object-cover transition-transform group-hover:scale-105" />
              </div>
              <div className="p-2">
                <div className="line-clamp-1 text-xs font-medium">{p.questionText ?? p.note ?? 'Failed item'}</div>
                <div className="text-[11px] text-muted-foreground">
                  {p.sourceType === 'TRUCK_INSPECTION' ? 'Truck inspection' : 'HSE inspection'} · {formatDate(p.date)}
                </div>
              </div>
            </button>
          ))}
        </div>
      )}

      <Dialog open={Boolean(lightbox)} onOpenChange={() => setLightbox(null)}>
        <DialogContent className="max-w-3xl border-0 bg-black/90 p-0">
          <button className="absolute right-3 top-3 z-10 rounded-full bg-black/60 p-1.5 text-white" onClick={() => setLightbox(null)}>
            <X className="h-5 w-5" />
          </button>
          {lightbox && <img src={lightbox} alt="" className="max-h-[80vh] w-full object-contain" />}
        </DialogContent>
      </Dialog>
    </div>
  )
}