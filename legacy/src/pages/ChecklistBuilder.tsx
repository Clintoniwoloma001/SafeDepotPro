import { useEffect, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ListChecks, Plus, Pencil, Trash2, Anchor, Layers } from 'lucide-react'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { CardContent } from '@/components/ui/card'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { PageHeader, EmptyState, SectionCard, KPICard } from '@/components/shared'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { listChecklistTemplates, createChecklistTemplate, updateChecklistTemplate, deleteChecklistTemplate } from '@/services/checklistTemplates.service'
import { cn } from '@/lib/utils'
import type { ChecklistSection, ChecklistQuestion, ChecklistTemplate } from '@/types/entities'
import type { Severity } from '@/types/enums'

const newQuestion = (n: number): ChecklistQuestion => ({
  id: `q_${Date.now()}_${n}`,
  text: '',
  severity: 'LOW',
  requires_photo: false,
  auto_capa: false,
  options: [],
})

const newSection = (n: number): ChecklistSection => ({
  id: `s_${Date.now()}_${n}`,
  name: '',
  order: 0,
  questions: [newQuestion(1)],
})

export default function ChecklistBuilder() {
  const user = useCurrentUser()
  const queryClient = useQueryClient()
  const [filter, setFilter] = useState<'ALL' | 'HSE' | 'TRUCK'>('ALL')
  const [editing, setEditing] = useState<ChecklistTemplate | null>(null)
  const [creating, setCreating] = useState(false)

  const { data: templates = [] } = useQuery({ queryKey: ['templates'], queryFn: () => listChecklistTemplates() })
  const filtered = filter === 'ALL' ? templates : templates.filter((t) => t.template_type === filter)

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['templates'] })

  const del = useMutation({
    mutationFn: deleteChecklistTemplate,
    onSuccess: () => {
      toast.success('Template deleted')
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not delete template'),
  })

  const setOpen = (v: boolean) => {
    if (!v) {
      setCreating(false)
      setEditing(null)
    }
  }

  return (
    <div className="space-y-8">
      <PageHeader
        title="Checklist Builder"
        subtitle={`${templates.length} templates · ${templates.filter((t) => t.template_type === 'HSE').length} HSE · ${templates.filter((t) => t.template_type === 'TRUCK').length} truck`}
        actions={user.isManagement ? <Button onClick={() => setCreating(true)}><Plus className="mr-1 h-4 w-4" /> New template</Button> : undefined}
      />

      <div className="grid grid-cols-1 gap-6 sm:grid-cols-3">
        <KPICard icon={<ListChecks className="h-4 w-4" />} iconHue="green" label="HSE templates" value={templates.filter((t) => t.template_type === 'HSE').length} />
        <KPICard icon={<TruckIcon />} iconHue="blue" label="Truck templates" value={templates.filter((t) => t.template_type === 'TRUCK').length} />
        <KPICard icon={<Layers className="h-4 w-4" />} iconHue="amber" label="Total sections" value={templates.reduce((acc, t) => acc + t.sections.length, 0)} />
      </div>

      <SectionCard title="Templates">
        <CardContent className="p-0">
          <div className="flex gap-2 p-4">
            {(['ALL', 'HSE', 'TRUCK'] as const).map((f) => (
              <Button key={f} size="sm" variant={filter === f ? 'default' : 'outline'} onClick={() => setFilter(f)}>{f === 'ALL' ? 'All' : f}</Button>
            ))}
          </div>
          {filtered.length === 0 ? (
            <EmptyState title="No templates" description="Build a reusable HSE or truck inspection checklist." />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Title</TableHead>
                  <TableHead>Type</TableHead>
                  <TableHead className="hidden md:table-cell">Sections</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="w-24">{/* actions */}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filtered.map((t) => (
                  <TableRow key={t.id}>
                    <TableCell className="max-w-[16rem]">
                      <span className="line-clamp-1 font-medium">{t.title}</span>
                      {t.category && <span className="text-xs text-muted-foreground">{t.category}</span>}
                    </TableCell>
                    <TableCell><StatusPill value={t.template_type} /></TableCell>
                    <TableCell className="hidden md:table-cell">{t.sections.length} sections · {t.sections.reduce((acc, s) => acc + s.questions.length, 0)} questions</TableCell>
                    <TableCell>
                      <span className={cn('rounded-full px-2 py-0.5 text-xs font-medium', t.is_active ? 'bg-rag-good/10 text-rag-good' : 'bg-muted text-muted-foreground')}>
                        {t.is_active ? 'Active' : 'Archived'}
                      </span>
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex justify-end gap-1">
                        {!t.is_standard && (
                          <Button size="sm" variant="outline" className="h-7 px-2" onClick={() => setEditing(t)}>
                            <Pencil className="h-3.5 w-3.5" />
                          </Button>
                        )}
                        {!t.is_standard && (
                          <Button size="sm" variant="ghost" className="h-7 px-2 text-rag-bad" onClick={() => del.mutate(t.id)}>
                            <Trash2 className="h-3.5 w-3.5" />
                          </Button>
                        )}
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
          <div className="flex items-center gap-2 border-t p-3 text-xs text-muted-foreground">
            <Anchor className="h-3.5 w-3.5" />
            Standard templates are factory-locked. Custom templates can be edited and archived.
          </div>
        </CardContent>
      </SectionCard>

      <TemplateEditor open={creating || editing !== null} onOpenChange={setOpen} template={editing} invalidate={invalidate} />
    </div>
  )
}

function TemplateEditor({
  open,
  onOpenChange,
  template,
  invalidate,
}: {
  open: boolean
  onOpenChange: (v: boolean) => void
  template: ChecklistTemplate | null
  invalidate: () => void
}) {
  const queryClient = useQueryClient()
  const [title, setTitle] = useState('')
  const [templateType, setTemplateType] = useState<'HSE' | 'TRUCK'>('HSE')
  const [category, setCategory] = useState('')
  const [description, setDescription] = useState('')
  const [sections, setSections] = useState<ChecklistSection[]>([])
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    if (!open) return
    setTitle(template?.title ?? '')
    setTemplateType(template?.template_type ?? 'HSE')
    setCategory(template?.category ?? '')
    setDescription(template?.description ?? '')
    setSections(template ? JSON.parse(JSON.stringify(template.sections)) : [newSection(1)])
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, template])

  const section = (id: string) => sections.find((s) => s.id === id)

  const patchSection = (id: string, patch: Partial<ChecklistSection>) =>
    setSections((prev) => prev.map((s) => (s.id === id ? { ...s, ...patch } : s)))

  const addQuestion = (secId: string) => {
    const sec = section(secId)
    if (!sec) return
    patchSection(secId, { questions: [...sec.questions, newQuestion(sec.questions.length + 1)] })
  }

  const patchQuestion = (secId: string, qId: string, patch: Partial<ChecklistQuestion>) => {
    const sec = section(secId)
    if (!sec) return
    patchSection(secId, {
      questions: sec.questions.map((q) => (q.id === qId ? { ...q, ...patch } : q)),
    })
  }

  const submit = async () => {
    if (!title.trim()) return toast.error('Template title is required.')
    const cleaned = sections
      .filter((s) => s.name.trim())
      .map((s, i) => ({
        ...s,
        order: i,
        questions: s.questions.filter((q) => q.text.trim()).map((q) => ({ ...q, text: q.text.trim() })),
      }))
    if (cleaned.length === 0) return toast.error('Add at least one section with a question.')
    setSaving(true)
    try {
      if (template) {
        await updateChecklistTemplate(template.id, { title: title.trim(), template_type: templateType, category: category || null, description: description || null, sections: cleaned })
      } else {
        await createChecklistTemplate({ title: title.trim(), template_type: templateType, category: category || null, description: description || null, sections: cleaned })
      }
      toast.success(template ? 'Template updated' : 'Template created')
      invalidate()
      onOpenChange(false)
      void queryClient.invalidateQueries({ queryKey: ['templates'] })
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not save template')
    } finally {
      setSaving(false)
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-3xl max-h-[92vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{template ? `Edit ${template.title}` : 'New checklist template'}</DialogTitle>
        </DialogHeader>
        <div className="space-y-4">
          <div className="grid gap-3 sm:grid-cols-2">
            <div className="space-y-1.5">
              <Label className="text-sm font-medium text-muted-foreground">Title *</Label>
              <Input value={title} onChange={(e) => setTitle(e.target.value)} />
            </div>
            <div className="space-y-1.5">
              <Label className="text-sm font-medium text-muted-foreground">Type</Label>
              <Select value={templateType} onValueChange={(v) => setTemplateType(v as 'HSE' | 'TRUCK')}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="HSE">HSE site inspection</SelectItem>
                  <SelectItem value="TRUCK">Truck inspection</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label className="text-sm font-medium text-muted-foreground">Category</Label>
              <Input value={category} onChange={(e) => setCategory(e.target.value)} placeholder="e.g. Fire safety" />
            </div>
            <div className="space-y-1.5 sm:col-span-2">
              <Label className="text-sm font-medium text-muted-foreground">Description</Label>
              <Input value={description} onChange={(e) => setDescription(e.target.value)} />
            </div>
          </div>

          <div className="space-y-3">
            {sections.map((s) => (
              <div key={s.id} className="rounded-lg border p-3">
                <div className="flex items-center gap-2">
                  <Input placeholder="Section name" value={s.name} onChange={(e) => patchSection(s.id, { name: e.target.value })} />
                  <Button size="sm" variant="ghost" className="h-8 px-2 text-rag-bad" onClick={() => setSections((prev) => prev.filter((x) => x.id !== s.id))}>
                    <Trash2 className="h-4 w-4" />
                  </Button>
                </div>
                <div className="mt-2 space-y-2">
                  {s.questions.map((q) => (
                    <div key={q.id} className="rounded-md bg-muted/40 p-2">
                      <div className="flex items-center gap-2">
                        <Input placeholder="Question text" value={q.text} onChange={(e) => patchQuestion(s.id, q.id, { text: e.target.value })} className="bg-white" />
                        <Button size="sm" variant="ghost" className="h-8 px-2 text-rag-bad" onClick={() => patchSection(s.id, { questions: s.questions.filter((x) => x.id !== q.id) })}>
                          <Trash2 className="h-3.5 w-3.5" />
                        </Button>
                      </div>
                      <div className="mt-2 flex flex-wrap gap-3">
                        <label className="flex items-center gap-1.5 text-xs">
                          <input
                            type="checkbox"
                            checked={q.requires_photo}
                            onChange={(e) => patchQuestion(s.id, q.id, { requires_photo: e.target.checked })}
                            className="rounded border-gray-300"
                          />
                          Photo on fail
                        </label>
                        <label className="flex items-center gap-1.5 text-xs">
                          <input
                            type="checkbox"
                            checked={q.auto_capa}
                            onChange={(e) => patchQuestion(s.id, q.id, { auto_capa: e.target.checked })}
                            className="rounded border-gray-300"
                          />
                          Auto-create CAPA
                        </label>
                        <Select value={q.severity} onValueChange={(v) => patchQuestion(s.id, q.id, { severity: v as Severity })}>
                          <SelectTrigger className="h-7 w-32 text-xs"><SelectValue /></SelectTrigger>
                          <SelectContent>
                            <SelectItem value="LOW">Low</SelectItem>
                            <SelectItem value="MEDIUM">Medium</SelectItem>
                            <SelectItem value="HIGH">High</SelectItem>
                            <SelectItem value="CRITICAL">Critical</SelectItem>
                          </SelectContent>
                        </Select>
                      </div>
                    </div>
                  ))}
                  <Button type="button" size="sm" variant="outline" onClick={() => addQuestion(s.id)}>+ Question</Button>
                </div>
              </div>
            ))}
            <Button type="button" variant="outline" onClick={() => setSections((prev) => [...prev, newSection(prev.length + 1)])}>+ Section</Button>
          </div>

          <DialogFooter>
            <Button variant="ghost" onClick={() => onOpenChange(false)}>Cancel</Button>
            <Button disabled={saving} onClick={() => void submit()}>{saving ? 'Saving…' : template ? 'Save changes' : 'Create template'}</Button>
          </DialogFooter>
        </div>
      </DialogContent>
    </Dialog>
  )
}

function StatusPill({ value }: { value: 'HSE' | 'TRUCK' }) {
  return (
    <span className={cn('rounded-full px-2 py-0.5 text-xs font-medium', value === 'HSE' ? 'bg-green-50 text-green-700' : 'bg-blue-50 text-blue-700')}>
      {value === 'HSE' ? 'HSE' : 'Truck'}
    </span>
  )
}

function TruckIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="h-4 w-4">
      <path d="M14 18V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v11a1 1 0 0 0 1 1h2" />
      <path d="M15 18h-5" />
      <path d="M14 18h4" />
      <path d="M4 18H2a1 1 0 0 1-1-1" />
      <path d="M14 6h4l4 5v6a1 1 0 0 1-1 1h-1" />
      <circle cx="7" cy="18" r="2" />
      <circle cx="19" cy="18" r="2" />
      <path d="M9 18h1" />
    </svg>
  )
}