import { supabase } from '@/lib/supabaseClient'
import type { Json } from '@/types/database.types'
import type { OrgSettings } from '@/types/entities'

const defaults: OrgSettings = {
  org_name: 'SafeDepot Pro',
  logo_url: null,
  company_website: null,
  notification_config: {
    overdue_check: true,
    email_escalation: true,
    cc_country_head: true,
    bcc_superadmin: true,
  },
  reminder_policy: {
    reminder_hours: 24,
    escalation_days: 2,
  },
}

export async function getSettings(): Promise<OrgSettings> {
  const { data, error } = await supabase.from('app_settings').select('*')
  if (error) throw error
  const map = (data ?? []).reduce<Record<string, Json>>((acc, row) => {
    acc[row.key] = row.value
    return acc
  }, {})
  return { ...defaults, ...(map.org as Partial<OrgSettings>), ...(map.reminder_policy ? { reminder_policy: map.reminder_policy } : {}) } as OrgSettings
}

export async function getSetting(key: string): Promise<Json | null> {
  const { data } = await supabase.from('app_settings').select('value').eq('key', key).maybeSingle()
  return data?.value ?? null
}

export async function setSetting(key: string, value: Json) {
  const { data: session } = await supabase.auth.getSession()
  const { error } = await supabase
    .from('app_settings')
    .upsert({ key, value, updated_by: session.session?.user.id ?? null }, { onConflict: 'key' })
  if (error) throw error
}

export async function saveSettings(settings: Partial<OrgSettings>) {
  const tasks: Promise<void>[] = []
  const current = await getSettings()
  const merged = { ...current, ...settings, reminder_policy: { ...current.reminder_policy, ...(settings.reminder_policy ?? {}) } }
  tasks.push(setSetting('org', { org_name: merged.org_name, logo_url: merged.logo_url, company_website: merged.company_website, notification_config: merged.notification_config }))
  tasks.push(setSetting('reminder_policy', merged.reminder_policy))
  await Promise.all(tasks)
}