import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Badge } from '@/components/ui/badge'
import { storage } from '@/services/storage.service'
import { formatDateTime } from '@/lib/utils'
import type { RoutineTask, TaskHistory } from '@/types/entities'
import { ScrollArea } from '@/components/ui/scroll-area'

interface CompletionDetailModalProps {
  record: TaskHistory | null
  task: RoutineTask | null
  open: boolean
  onOpenChange: (open: boolean) => void
}

/** Shows photos, signature, GPS and comments. Attendance count is shown ONLY for toolbox-type tasks. */
export default function CompletionDetailModal({ record, task, open, onOpenChange }: CompletionDetailModalProps) {
  const isToolboxLike = task?.linked_module === 'TOOLBOX' || (task?.title ?? '').toLowerCase().includes('toolbox')

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-xl">
        <DialogHeader>
          <DialogTitle>Completion detail</DialogTitle>
        </DialogHeader>
        <ScrollArea className="max-h-[70vh] pr-3">
          <div className="space-y-3 text-sm">
            {task && <div className="font-medium">{task.title}</div>}
            <div className="flex flex-wrap gap-1.5">
              <Badge variant="outline">Completed {formatDateTime(record?.completed_at)}</Badge>
              <Badge variant="outline">Occurrences {record?.occurrences ?? 0}/{record?.expected_occurrences ?? record?.occurrences ?? 0}</Badge>
              <Badge variant="outline">By {record?.actor_name ?? '—'}</Badge>
              {isToolboxLike ? (
                <Badge variant="outline" className="bg-amber-50 text-amber-800">Attendance: {record?.attendance_count ?? 0}</Badge>
              ) : null}
            </div>

            {record?.comment && (
              <div className="rounded-md bg-muted p-3">
                <div className="text-xs uppercase text-muted-foreground">Comment</div>
                <div className="mt-1">{record.comment}</div>
              </div>
            )}

            {record?.form_answers && Object.keys(record.form_answers).length > 0 && (
              <div className="rounded-md border p-3">
                <div className="text-xs uppercase text-muted-foreground">Form answers</div>
                <dl className="mt-1 grid grid-cols-1 gap-1 sm:grid-cols-2">
                  {Object.entries(record.form_answers).map(([k, v]) => (
                    <div key={k}>
                      <dt className="text-xs text-muted-foreground">{k}</dt>
                      <dd className="font-medium">{String(v)}</dd>
                    </div>
                  ))}
                </dl>
              </div>
            )}

            {(record?.latitude != null || record?.longitude != null) && (
              <div className="rounded-md bg-muted p-3">
                <div className="text-xs uppercase text-muted-foreground">GPS</div>
                <div className="mt-1">
                  {record.latitude?.toFixed(5)}, {record.longitude?.toFixed(5)}
                </div>
              </div>
            )}

            {record?.signature_path && (
              <div className="rounded-md border p-3">
                <div className="text-xs uppercase text-muted-foreground">Signature</div>
                <img src={storage.publicUrl('signatures', record.signature_path)} alt="Signature" className="mt-1 h-20 object-contain" />
              </div>
            )}

            {record?.photo_paths && record.photo_paths.length > 0 && (
              <div>
                <div className="text-xs uppercase text-muted-foreground">Photos ({record.photo_paths.length})</div>
                <div className="mt-1 grid grid-cols-3 gap-2">
                  {record.photo_paths.map((p, i) => (
                    <a key={i} href={storage.publicUrl('images', p)} target="_blank" rel="noreferrer" className="block overflow-hidden rounded border">
                      <img src={storage.publicUrl('images', p)} alt="" className="aspect-square w-full object-cover" />
                    </a>
                  ))}
                </div>
              </div>
            )}

            {record?.ai_verified && <Badge className="bg-amber-accent text-white">AI verified</Badge>}
          </div>
        </ScrollArea>
      </DialogContent>
    </Dialog>
  )
}