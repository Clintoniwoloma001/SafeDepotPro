import { useMemo, useState } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Label } from '@/components/ui/label'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Camera, X } from 'lucide-react'
import type { ChecklistQuestion, ChecklistSection, InspectionAnswer } from '@/types/entities'
import type { InspectionResponse, Priority } from '@/types/enums'
import { storage } from '@/services/storage.service'
import { cn } from '@/lib/utils'
import CameraModal, { type CapturedPhoto } from '@/components/CameraModal'
import { useCurrentUser } from '@/hooks/useCurrentUser'

export interface CheckedAnswers {
  [questionId: string]: InspectionAnswer
}

interface ChecklistRendererProps {
  sections: ChecklistSection[]
  answers: CheckedAnswers
  onChange: (answers: CheckedAnswers) => void
  /** Read-only review mode (e.g. viewing a submitted inspection). */
  readOnly?: boolean
}

/**
 * Dynamic checklist renderer. Question text is shown with Pass/Fail/N-A only —
 * internal severity labels are intentionally hidden from the respondent.
 * Fail/NON_COMPLIANT answers demand a photo + corrective action + responsible + due date + priority.
 */
export default function ChecklistRenderer({ sections, answers, onChange, readOnly = false }: ChecklistRendererProps) {
  const user = useCurrentUser()
  const [cameraFor, setCameraFor] = useState<string | null>(null)

  const setAnswer = (q: ChecklistQuestion, section: ChecklistSection, patch: Partial<InspectionAnswer>) => {
    const current = answers[q.id] ?? { question_id: q.id, section_id: section.id, response: 'NA', photo_paths: [], note: null, corrective_action: null, responsible_user_id: null, responsible_name: null, due_date: null, priority: null }
    onChange({ ...answers, [q.id]: { ...current, ...patch } })
  }

  const total = useMemo(
    () =>
      sections.reduce((acc, s) => {
        s.questions.forEach((q) => {
          const a = answers[q.id]
          if (a && (a.response === 'PASS' || a.response === 'FAIL' || a.response === 'NON_COMPLIANT')) acc++
        })
        return acc
      }, 0),
    [sections, answers],
  )
  const passed = useMemo(
    () =>
      sections.reduce((acc, s) => {
        s.questions.forEach((q) => {
          if (answers[q.id]?.response === 'PASS') acc++
        })
        return acc
      }, 0),
    [sections, answers],
  )
  const compliance = total === 0 ? 0 : Math.round((passed / total) * 100)

  const responseOptions: { value: InspectionResponse; label: string }[] = [
    { value: 'PASS', label: 'Pass' },
    { value: 'FAIL', label: 'Fail' },
    { value: 'NA', label: 'N/A' },
  ]

  const failed = (response: InspectionResponse) => response === 'FAIL' || response === 'NON_COMPLIANT'

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader className="flex-row items-center justify-between space-y-0">
          <CardTitle className="text-sm font-medium">Compliance</CardTitle>
          <div className="flex items-center gap-2">
            <span className="text-lg font-bold">{compliance}%</span>
            <div className="h-2 w-24 overflow-hidden rounded-full bg-muted">
              <div className={cn('h-full rounded-full', compliance >= 85 ? 'bg-rag-good' : compliance >= 70 ? 'bg-rag-warn' : 'bg-rag-bad')} style={{ width: `${compliance}%` }} />
            </div>
          </div>
        </CardHeader>
      </Card>

      {sections
        .slice()
        .sort((a, b) => a.order - b.order)
        .map((section) => (
          <Card key={section.id}>
            <CardHeader>
              <CardTitle className="text-base">{section.name}</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              {section.questions.map((q) => {
                const a = answers[q.id]
                const isFailed = a ? failed(a.response) : false
                const severityHidden = true
                return (
                  <div key={q.id} className="rounded-md border bg-muted/10 p-3">
                    <div className="flex flex-wrap items-start justify-between gap-2">
                      <div className="flex items-start gap-2">
                        <div className="text-sm font-medium">
                          {q.text}
                          {severityHidden && q.requires_photo && <span className="ml-1 text-xs text-muted-foreground">*photo required on fail</span>}
                        </div>
                      </div>
                      {!readOnly ? (
                        <div className="flex gap-1">
                          {responseOptions.map((opt) => (
                            <Button
                              key={opt.value}
                              type="button"
                              size="sm"
                              variant={a?.response === opt.value ? 'default' : 'outline'}
                              className={cn(a?.response === opt.value && opt.value === 'PASS' && 'bg-rag-good text-white', a?.response === opt.value && failed(opt.value) && 'bg-rag-bad text-white')}
                              onClick={() => setAnswer(q, section, { response: opt.value })}
                            >
                              {opt.label}
                            </Button>
                          ))}
                        </div>
                      ) : (
                        <div className="text-sm font-semibold">{a ? a.response : '—'}</div>
                      )}
                    </div>

                    {isFailed && (
                      <div className="mt-3 space-y-2 rounded-md bg-white p-2">
                        <div className="flex items-center gap-2">
                          <Button type="button" size="sm" variant="outline" onClick={() => setCameraFor(q.id)} disabled={readOnly}>
                            <Camera className="mr-1 h-4 w-4" /> {a?.photo_paths?.length ? `Photo (${a.photo_paths.length})` : 'Attach photo (required)'}
                          </Button>
                          {a?.photo_paths?.length ? (
                            <div className="flex gap-1">
                              {a.photo_paths.map((p, i) => (
                                <div key={i} className="relative h-10 w-10 overflow-hidden rounded border">
                                  <img src={storage.publicUrl('images', p)} alt="" className="h-full w-full object-cover" />
                                  {!readOnly && (
                                    <button className="absolute right-0 top-0 rounded-full bg-black/70 p-0.5 text-white" onClick={() => setAnswer(q, section, { photo_paths: a.photo_paths.filter((_, j) => j !== i) })}>
                                      <X className="h-3 w-3" />
                                    </button>
                                  )}
                                </div>
                              ))}
                            </div>
                          ) : (
                            <span className="text-xs text-rag-bad">Mandatory photo missing</span>
                          )}
                        </div>
                        <Textarea
                          placeholder="Corrective action"
                          value={a?.corrective_action ?? ''}
                          disabled={readOnly}
                          onChange={(e) => setAnswer(q, section, { corrective_action: e.target.value })}
                        />
                        <div className="grid grid-cols-1 gap-2 sm:grid-cols-3">
                          <div>
                            <Label className="text-xs">Responsible</Label>
                            <Input
                              placeholder="Name"
                              value={a?.responsible_name ?? ''}
                              disabled={readOnly}
                              onChange={(e) => setAnswer(q, section, { responsible_name: e.target.value })}
                            />
                          </div>
                          <div>
                            <Label className="text-xs">Due date</Label>
                            <Input type="date" value={a?.due_date ?? ''} disabled={readOnly} onChange={(e) => setAnswer(q, section, { due_date: e.target.value || null })} />
                          </div>
                          <div>
                            <Label className="text-xs">Priority</Label>
                            <Select
                              value={a?.priority ?? ''}
                              onValueChange={(v) => setAnswer(q, section, { priority: v as Priority })}
                              disabled={readOnly}
                            >
                              <SelectTrigger className="h-9">
                                <SelectValue placeholder="Priority" />
                              </SelectTrigger>
                              <SelectContent>
                                <SelectItem value="LOW">Low</SelectItem>
                                <SelectItem value="MEDIUM">Medium</SelectItem>
                                <SelectItem value="HIGH">High</SelectItem>
                                <SelectItem value="CRITICAL">Critical</SelectItem>
                              </SelectContent>
                            </Select>
                          </div>
                        </div>
                        <Textarea
                          placeholder="Note / observation"
                          value={a?.note ?? ''}
                          disabled={readOnly}
                          onChange={(e) => setAnswer(q, section, { note: e.target.value })}
                        />
                      </div>
                    )}

                    {!isFailed && a?.note && <div className="mt-2 text-sm text-muted-foreground">{a.note}</div>}
                  </div>
                )
              })}
            </CardContent>
          </Card>
        ))}

      <CameraModal
        open={Boolean(cameraFor)}
        onOpenChange={(o) => { if (!o) setCameraFor(null) }}
        userId={user.userId ?? 'anon'}
        multiple
        onCaptured={(photos) => {
          if (cameraFor) {
            const paths = photos.map((p) => p.storagePath).filter(Boolean) as string[]
            const section = sections.find((s) => s.questions.some((qq) => qq.id === cameraFor))
            const q = section?.questions.find((qq) => qq.id === cameraFor)
            if (section && q) {
              const base = answers[cameraFor] ?? { question_id: cameraFor, section_id: section.id, response: 'FAIL' as InspectionResponse, photo_paths: [], note: null, corrective_action: null, responsible_name: null, due_date: null, priority: null }
              setAnswer(q, section, { photo_paths: [...(base.photo_paths ?? []), ...paths] })
            }
          }
        }}
      />
    </div>
  )
}

export type { CapturedPhoto }