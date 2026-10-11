import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Plus } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Checkbox } from '@/components/ui/checkbox'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { toast } from 'sonner'
import type { RoutineTask } from '@/types/entities'
import type { CompletionMethod, Frequency } from '@/types/enums'
import { FREQUENCY_LABELS } from '@/lib/constants'
import { createRoutineTask, updateRoutineTask } from '@/services/routineTasks.service'
import { listDepots } from '@/services/depots.service'
import { listPersonnel } from '@/services/personnel.service'

const COMPLETION_METHODS: { value: CompletionMethod; label: string }[] = [
  { value: 'MANUAL', label: 'Manual (comment / photos / signature / GPS)' },
  { value: 'FORM', label: 'Form-based (linked checklist)' },
  { value: 'COUNT', label: 'Count-based (enter occurrences)' },
  { value: 'PERMIT', label: 'Permit-linked (auto from active permits)' },
  { value: 'VEHICLE', label: 'Vehicle-linked (auto from truck inspections)' },
  { value: 'EQUIPMENT', label: 'Equipment-linked (auto from asset count)' },
  { value: 'PERSONNEL', label: 'Personnel-linked (auto from personnel count)' },
  { value: 'AI_VERIFIED', label: 'AI-verified (photo/vision check)' },
]

const FREQUENCIES: { value: Frequency; label: string }[] = Object.entries(FREQUENCY_LABELS).map(([value, label]) => ({ value: value as Frequency, label }))

const LINKED_MODULES: { value: 'TOOLBOX' | 'HOUSEKEEPING'; label: string }[] = [
  { value: 'TOOLBOX', label: 'Toolbox talk (requires same-day talk)' },
  { value: 'HOUSEKEEPING', label: 'Housekeeping (requires same-day inspection)' },
]

type Props = {
  open: boolean
  onOpenChange: (open: boolean) => void
  task?: RoutineTask | null
}

export default function TaskFormDialog({ open, onOpenChange, task }: Props) {
  const queryClient = useQueryClient()
  const isEdit = Boolean(task)
  const [title, setTitle] = useState(task?.title ?? '')
  const [description, setDescription] = useState(task?.description ?? '')
  const [type, setType] = useState<CompletionMethod>(task?.task_type ?? 'MANUAL')
  const [frequency, setFrequency] = useState<Frequency>(task?.frequency ?? 'DAILY')
  const [linked, setLinked] = useState<'TOOLBOX' | 'HOUSEKEEPING' | ''>(task?.linked_module ?? '')
  const [allDepots, setAllDepots] = useState(task?.all_depots ?? false)
  const [depots, setDepots] = useState<string[]>(task?.assigned_depot_ids ?? [])
  const [users, setUsers] = useState<string[]>(task?.assigned_user_ids ?? [])
  const [startDate, setStartDate] = useState(task?.start_date ?? new Date().toISOString().slice(0, 10))

  const { data: depotList = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const { data: personnelList = [] } = useQuery({ queryKey: ['personnel'], queryFn: () => listPersonnel({}) })

  const mutation = useMutation({
    mutationFn: (payload: Partial<RoutineTask>) =>
      isEdit && task ? updateRoutineTask(task.id, payload) : createRoutineTask(payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tasks'] })
      toast.success(isEdit ? 'Task updated.' : 'Task created.')
      onOpenChange(false)
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Failed to save task'),
  })

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!title.trim()) {
      toast.error('Title is required.')
      return
    }
    if (!allDepots && depots.length === 0 && users.length === 0) {
      toast.error('Assign at least one depot, one user, or flag "All depots".')
      return
    }
    mutation.mutate({
      title,
      description: description || null,
      task_type: type,
      category: null,
      all_depots: allDepots,
      assigned_depot_ids: allDepots ? [] : depots,
      assigned_user_ids: allDepots ? [] : users,
      frequency,
      linked_module: linked || null,
      start_date: startDate,
      is_active: true,
    })
  }

  const toggle = (list: string[], set: (v: string[]) => void, id: string) =>
    set(list.includes(id) ? list.filter((x) => x !== id) : [...list, id])

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[90vh] max-w-lg overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{isEdit ? 'Edit task' : 'Create task'}</DialogTitle>
        </DialogHeader>
        <form onSubmit={submit} className="space-y-3">
          <div className="space-y-1.5">
            <Label htmlFor="title">Title *</Label>
            <Input id="title" value={title} onChange={(e) => setTitle(e.target.value)} placeholder="e.g. Fire extinguisher check" required />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="desc">Description</Label>
            <Textarea id="desc" value={description} onChange={(e) => setDescription(e.target.value)} rows={2} />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <Label>Completion method</Label>
              <Select value={type} onValueChange={(v) => setType(v as CompletionMethod)}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent className="max-h-60">
                  {COMPLETION_METHODS.map((m) => (
                    <SelectItem key={m.value} value={m.value}>{m.label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label>Frequency</Label>
              <Select value={frequency} onValueChange={(v) => setFrequency(v as Frequency)}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {FREQUENCIES.map((f) => (
                    <SelectItem key={f.value} value={f.value}>{f.label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>
          <div className="space-y-1.5">
            <Label>Linked module (prerequisite)</Label>
            <Select value={linked} onValueChange={(v) => setLinked(v === '__none' ? '' : (v as 'TOOLBOX' | 'HOUSEKEEPING'))}>
              <SelectTrigger>
                <SelectValue placeholder="None" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="__none">None</SelectItem>
                {LINKED_MODULES.map((m) => (
                  <SelectItem key={m.value} value={m.value}>{m.label}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="start">Start date</Label>
            <Input id="start" type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} />
          </div>

          <div className="flex items-center gap-2 rounded-md border px-3 py-2">
            <Checkbox id="alld" checked={allDepots} onCheckedChange={(c) => setAllDepots(Boolean(c))} />
            <Label htmlFor="alld">All depots (visible to every depot)</Label>
          </div>

          {!allDepots && (
            <>
              <div>
                <Label className="mb-1 block">Assigned depots</Label>
                <div className="grid max-h-40 grid-cols-2 gap-1 overflow-y-auto rounded-md border p-2">
                  {depotList.map((d) => (
                    <label key={d.id} className="flex items-center gap-1.5 text-sm">
                      <Checkbox checked={depots.includes(d.id)} onCheckedChange={() => toggle(depots, setDepots, d.id)} />
                      {d.name}
                    </label>
                  ))}
                </div>
              </div>
              <div>
                <Label className="mb-1 block">Assigned personnel</Label>
                <div className="grid max-h-40 grid-cols-2 gap-1 overflow-y-auto rounded-md border p-2">
                  {personnelList.map((p) => (
                    <label key={p.id} className="flex items-center gap-1.5 text-sm">
                      <Checkbox checked={users.includes(p.id)} onCheckedChange={() => toggle(users, setUsers, p.id)} />
                      {p.first_name} {p.last_name}
                    </label>
                  ))}
                </div>
              </div>
            </>
          )}

          <Button type="submit" className="w-full" disabled={mutation.isPending}>
            <Plus className="mr-1 h-4 w-4" /> {isEdit ? 'Save changes' : 'Create task'}
          </Button>
        </form>
      </DialogContent>
    </Dialog>
  )
}