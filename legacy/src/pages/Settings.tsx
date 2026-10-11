import { useEffect, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Download, Save, Building2 } from 'lucide-react'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { CardContent } from '@/components/ui/card'
import { SectionCard, PageHeader } from '@/components/shared'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { getSettings, saveSettings } from '@/services/settings.service'
import { DOWNLOAD_SOURCE_BASE } from '@/lib/constants'

export default function Settings() {
  const user = useCurrentUser()
  const queryClient = useQueryClient()
  const { data: settings } = useQuery({ queryKey: ['settings'], queryFn: () => getSettings() })

  const [orgName, setOrgName] = useState('SafeDepot Pro')
  const [website, setWebsite] = useState('')
  const [logoUrl, setLogoUrl] = useState('')
  const [overdueCheck, setOverdueCheck] = useState(true)
  const [emailEscalation, setEmailEscalation] = useState(true)
  const [ccCountryHead, setCcCountryHead] = useState(true)
  const [bccSuperadmin, setBccSuperadmin] = useState(true)
  const [reminderHours, setReminderHours] = useState('24')
  const [escalationDays, setEscalationDays] = useState('2')
  const [saving, setSaving] = useState(false)
  const [downloading, setDownloading] = useState(false)

  useEffect(() => {
    if (!settings) return
    setOrgName(settings.org_name ?? 'SafeDepot Pro')
    setWebsite(settings.company_website ?? '')
    setLogoUrl(settings.logo_url ?? '')
    const nc = settings.notification_config ?? {}
    setOverdueCheck(nc.overdue_check ?? true)
    setEmailEscalation(nc.email_escalation ?? true)
    setCcCountryHead(nc.cc_country_head ?? true)
    setBccSuperadmin(nc.bcc_superadmin ?? true)
    const rp = settings.reminder_policy ?? {}
    setReminderHours(String(rp.reminder_hours ?? 24))
    setEscalationDays(String(rp.escalation_days ?? 2))
  }, [settings])

  const save = useMutation({
    mutationFn: () =>
      saveSettings({
        org_name: orgName,
        company_website: website || null,
        logo_url: logoUrl || null,
        notification_config: { overdue_check: overdueCheck, email_escalation: emailEscalation, cc_country_head: ccCountryHead, bcc_superadmin: bccSuperadmin },
        reminder_policy: { reminder_hours: Number(reminderHours) || 0, escalation_days: Number(escalationDays) || 0 },
      }),
    onSuccess: () => {
      toast.success('Settings saved')
      queryClient.invalidateQueries({ queryKey: ['settings'] })
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not save settings'),
    onSettled: () => setSaving(false),
  })

  const downloadSource = async () => {
    setDownloading(true)
    try {
      const res = await fetch(DOWNLOAD_SOURCE_BASE, { credentials: 'include' })
      if (!res.ok) {
        const text = await res.text().catch(() => '')
        throw new Error(text || `Request failed (${res.status})`)
      }
      const blob = await res.blob()
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = 'safedepotpro-source.zip'
      a.click()
      URL.revokeObjectURL(url)
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Source download failed')
    } finally {
      setDownloading(false)
    }
  }

  return (
    <div className="space-y-8">
      <PageHeader
        title="Settings"
        subtitle="Organisation, notifications and reminders"
        actions={<Button onClick={() => { setSaving(true); save.mutate() }} disabled={saving}><Save className="mr-1 h-4 w-4" /> {saving ? 'Saving…' : 'Save changes'}</Button>}
      />

      <div className="grid grid-cols-1 gap-8 xl:grid-cols-3">
        <div className="space-y-8 xl:col-span-2">
          <SectionCard title="Organisation">
            <CardContent className="space-y-4">
              <div className="grid gap-3 sm:grid-cols-2">
                <Field label="Organisation name"><Input value={orgName} onChange={(e) => setOrgName(e.target.value)} /></Field>
                <Field label="Company website"><Input value={website} onChange={(e) => setWebsite(e.target.value)} placeholder="https://…" /></Field>
              </div>
              <Field label="Logo URL (optional)"><Input value={logoUrl} onChange={(e) => setLogoUrl(e.target.value)} placeholder="https://…/logo.png" /></Field>
            </CardContent>
          </SectionCard>

          <SectionCard title="Notification configuration">
            <CardContent className="space-y-3">
              <Toggle label="Overdue check" hint="Daily scan for overdue tasks, permits and CAPAs." checked={overdueCheck} onChange={setOverdueCheck} />
              <Toggle label="Email escalation" hint="Send escalation emails when items are overdue." checked={emailEscalation} onChange={setEmailEscalation} />
              <Toggle label="CC country head" hint="Copy the country head on all escalations." checked={ccCountryHead} onChange={setCcCountryHead} />
              <Toggle label="BCC superadmin" hint="Blind-copy the superadmin as a compliance audit trail." checked={bccSuperadmin} onChange={setBccSuperadmin} />
            </CardContent>
          </SectionCard>

          <SectionCard title="Reminder policy">
            <CardContent className="grid gap-3 sm:grid-cols-2">
              <Field label="Reminder hours before due">
                <Input type="number" min={1} value={reminderHours} onChange={(e) => setReminderHours(e.target.value)} />
              </Field>
              <Field label="Escalation days after overdue">
                <Input type="number" min={1} value={escalationDays} onChange={(e) => setEscalationDays(e.target.value)} />
              </Field>
            </CardContent>
          </SectionCard>
        </div>

        <SectionCard title="Source code" className="h-fit">
          <CardContent className="space-y-3">
            <div className="flex items-center gap-2">
              <Building2 className="h-4 w-4 text-muted-foreground" />
              <p className="text-sm text-muted-foreground">
                Download a verified snapshot of the deployed application source and schema.
              </p>
            </div>
            {user.isSuperadmin ? (
              <Button variant="outline" className="w-full" disabled={downloading} onClick={() => void downloadSource()}>
                <Download className="mr-1 h-4 w-4" /> {downloading ? 'Preparing…' : 'Download source.zip'}
              </Button>
            ) : (
              <p className="text-xs text-rag-bad">Only the SUPERADMIN can download the source archive.</p>
            )}
          </CardContent>
        </SectionCard>
      </div>
    </div>
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

function Toggle({ label, hint, checked, onChange }: { label: string; hint: string; checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <div className="flex items-start gap-3">
      <input type="checkbox" checked={checked} onChange={(e) => onChange(e.target.checked)} className="mt-0.5 rounded border-gray-300" />
      <div>
        <div className="text-sm font-medium">{label}</div>
        <div className="text-xs text-muted-foreground">{hint}</div>
      </div>
    </div>
  )
}