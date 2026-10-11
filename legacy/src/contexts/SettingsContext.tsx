import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import type { OrgSettings } from '@/types/entities'
import { getSettings } from '@/services/settings.service'

interface SettingsContextValue {
  settings: OrgSettings
  isLoading: boolean
  reload: () => Promise<void>
}

const SettingsContext = createContext<SettingsContextValue | null>(null)

export function SettingsProvider({ children }: { children: ReactNode }) {
  const [settings, setSettings] = useState<OrgSettings>({
    org_name: 'SafeDepot Pro',
    logo_url: null,
    company_website: null,
    notification_config: { overdue_check: true, email_escalation: true, cc_country_head: true, bcc_superadmin: true },
    reminder_policy: { reminder_hours: 24, escalation_days: 2 },
  })
  const [isLoading, setIsLoading] = useState(true)

  const reload = async () => {
    try {
      setSettings(await getSettings())
    } catch {
      // fall back to defaults
    } finally {
      setIsLoading(false)
    }
  }

  useEffect(() => {
    reload()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  return (
    <SettingsContext.Provider value={{ settings, isLoading, reload }}>{children}</SettingsContext.Provider>
  )
}

export function useSettings(): SettingsContextValue {
  const ctx = useContext(SettingsContext)
  if (!ctx) throw new Error('useSettings must be used within SettingsProvider')
  return ctx
}