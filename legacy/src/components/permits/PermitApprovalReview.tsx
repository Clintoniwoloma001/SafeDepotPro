import { useMemo, useState } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { AlertTriangle, CheckCircle2, XCircle } from 'lucide-react'
import { RiskBadge, StatusBadge } from '@/components/shared'
import { permitValidationErrors } from '@/services/permits.service'
import type { Permit } from '@/types/entities'
import { storage } from '@/services/storage.service'
import { formatDateTime } from '@/lib/utils'

interface PermitApprovalReviewProps {
  permit: Permit
  onApprove: () => Promise<void>
  onReject: (reason: string) => Promise<void>
  onBackToDraft: () => Promise<void>
  onSave: () => Promise<void>
  canApprove: boolean
}

/**
 * Renders EVERY submitted section — nothing hidden — and blocks approval until
 * risk assessment, hazards, controls and PPE are complete.
 */
export default function PermitApprovalReview({ permit, onApprove, onReject, onBackToDraft, onSave, canApprove }: PermitApprovalReviewProps) {
  const [rejectMode, setRejectMode] = useState(false)
  const [rejectReason, setRejectReason] = useState('')
  const [busy, setBusy] = useState(false)
  const errors = useMemo(() => permitValidationErrors(permit), [permit])
  const isComplete = errors.length === 0

  const namedError = errors.length > 0 ? errors[0] : null

  const run = async (fn: () => Promise<void>) => {
    setBusy(true)
    try {
      await fn()
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="space-y-4">
      {namedError && (
        <div className="flex items-start gap-2 rounded-lg border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
          <div>
            <div className="font-medium">Approval blocked</div>
            <div>{namedError}</div>
          </div>
        </div>
      )}

      <Card>
        <CardHeader className="flex-row items-center justify-between space-y-0">
          <CardTitle>Job details</CardTitle>
          <StatusBadge status={permit.status} />
        </CardHeader>
        <CardContent className="grid grid-cols-1 gap-2 text-sm sm:grid-cols-2">
          <Section label="Permit number" value={permit.permit_number} />
          <Section label="Type" value={permit.permit_type ?? '—'} />
          <Section label="Job title" value={permit.job_title} />
          <Section label="Location" value={permit.location ?? '—'} />
          <Section label="Start" value={formatDateTime(permit.start_datetime)} />
          <Section label="End" value={formatDateTime(permit.end_datetime)} />
          <div className="sm:col-span-2">
            <Section label="Job description" value={permit.job_description ?? '—'} />
          </div>
          <div className="sm:col-span-2">
            <Section label="Tasks" value={permit.tasks?.join(', ') || '—'} />
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Hazard assessment ({permit.hazard_assessment?.length ?? 0})</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2">
          {(permit.hazard_assessment ?? []).length === 0 && <p className="text-sm text-muted-foreground">No hazards recorded.</p>}
          {(permit.hazard_assessment ?? []).map((h, i) => (
            <div key={i} className="rounded-md border p-3 text-sm">
              <div className="mb-1 flex items-center justify-between">
                <span className="font-medium">Hazard {i + 1}: {h.hazard}</span>
                <div className="flex items-center gap-2">
                  <span className="text-xs text-muted-foreground">Residual risk</span>
                  <RiskBadge risk={h.risk_rating?.toUpperCase() ?? 'LOW'} />
                </div>
              </div>
              <dl className="grid grid-cols-1 gap-1 sm:grid-cols-2">
                <Section label="Consequence" value={h.consequence} />
                <Section label="Existing controls" value={h.existing_controls} />
                <Section label="Additional controls" value={h.additional_controls} />
                <Section label="Initial risk" value={String(h.initial_risk)} />
              </dl>
            </div>
          ))}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Controls & PPE</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3 text-sm">
          <Section label="PPE" value={permit.ppe?.join(', ') || 'None selected'} />
          <Section label="Isolation / LOTO" value={permit.isolation_loto ?? '—'} />
          <Section label="Additional controls" value={permit.additional_controls ?? '—'} />
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            {['gas_tests', 'confined_space', 'work_at_height', 'electrical_isolation', 'excavation'].map((key) => (
              <JsonSection key={key} label={key.replace(/_/g, ' ')} value={permit[key as keyof Permit] as Record<string, unknown>} />
            ))}
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Certificates & attachments</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm">
          <Section label="Certificates" value={permit.certificates?.join(', ') || '—'} />
          {permit.attachment_paths?.length ? (
            <div className="flex flex-wrap gap-2">
              {permit.attachment_paths.map((p, i) => (
                <a key={i} href={storage.publicUrl('images', p)} target="_blank" rel="noreferrer" className="rounded-md border px-2 py-1 text-xs hover:bg-muted">
                  Attachment {i + 1}
                </a>
              ))}
            </div>
          ) : (
            <p className="text-muted-foreground">No attachments.</p>
          )}
          <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
            <Section label="Applicant signature" value={permit.signature_applicant ? 'Signed' : '—'} />
            <Section label="Approving authority signature" value={permit.signature_approving ? 'Signed' : '—'} />
          </div>
        </CardContent>
      </Card>

      <div className="flex flex-wrap items-center gap-2">
        {permit.status === 'SUBMITTED' && (
          <>
            <Button disabled={!isComplete || !canApprove || busy} onClick={() => run(onApprove)} className="gap-2">
              <CheckCircle2 className="h-4 w-4" /> Approve permit
            </Button>
            <Button variant="outline" onClick={() => setRejectMode((v) => !v)}>
              <XCircle className="mr-1 h-4 w-4" /> Reject
            </Button>
          </>
        )}
        {permit.status === 'DRAFT' && (
          <Button variant="secondary" onClick={() => run(onSave)} disabled={busy}>
            Save draft
          </Button>
        )}
        {(permit.status === 'SUBMITTED' || permit.status === 'REJECTED') && (
          <Button variant="ghost" onClick={() => run(onBackToDraft)} disabled={busy}>
            Return to draft
          </Button>
        )}
      </div>

      {rejectMode && (
        <div className="space-y-2 rounded-md border border-red-200 p-3">
          <div className="text-sm font-medium">Rejection reason</div>
          <textarea className="min-h-20 w-full rounded-md border p-2 text-sm" value={rejectReason} onChange={(e) => setRejectReason(e.target.value)} placeholder="Explain why the permit is rejected…" />
          <Button variant="destructive" disabled={!rejectReason.trim()} onClick={() => run(() => onReject(rejectReason))}>
            Confirm rejection
          </Button>
        </div>
      )}
    </div>
  )
}

function Section({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-xs uppercase tracking-wide text-muted-foreground">{label}</dt>
      <dd className="mt-0.5 break-words">{value}</dd>
    </div>
  )
}

function JsonSection({ label, value }: { label: string; value: Record<string, unknown> }) {
  if (!value || Object.keys(value).length === 0) return null
  return (
    <div className="rounded-md border p-2">
      <dt className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">{label}</dt>
      <dl className="mt-1 space-y-1">
        {Object.entries(value).map(([k, v]) => (
          <div key={k} className="flex justify-between gap-2 text-xs">
            <span className="capitalize text-muted-foreground">{k.replace(/_/g, ' ')}</span>
            <span className="font-medium">{v === true ? 'Yes' : v === false ? 'No' : String(v)}</span>
          </div>
        ))}
      </dl>
    </div>
  )
}