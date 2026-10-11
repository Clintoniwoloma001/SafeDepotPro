import type { CompletionMethod, Frequency, UserRole } from '@/types/enums'
import { ROLE_RANK } from '@/types/enums'

/** Rank numbers as specified: SUPERADMIN(4) > ADMIN(3) > COUNTRY_HEAD(2) > USER(1). */
export const ROLE_RANK_MAP: Record<UserRole, number> = ROLE_RANK

export interface NavItem {
  label: string
  to: string
  icon: string
  badge?: string
  group: 'Overview' | 'Operations' | 'Safety' | 'Assets' | 'Admin'
  /** Lowest rank allowed to see the item. */
  minRank: number
  /** SUPERADMIN-only items (User Management, Platform Export). */
  superadminOnly?: boolean
}

/** Nav groups for the sidebar. minRole is the lowest rank allowed to see the item. */
export const NAV_ITEMS: NavItem[] = [
  { label: 'Dashboard', to: '/', icon: 'LayoutDashboard', group: 'Overview', minRank: ROLE_RANK_MAP.USER },
  { label: 'AI Copilot', to: '/assistant', icon: 'Bot', badge: 'AI', group: 'Overview', minRank: ROLE_RANK_MAP.USER },
  { label: 'Routine Tasks', to: '/tasks', icon: 'CheckSquare', group: 'Operations', minRank: ROLE_RANK_MAP.USER },
  { label: 'Shift Handover', to: '/shift-handover', icon: 'RefreshCw', group: 'Operations', minRank: ROLE_RANK_MAP.USER },
  { label: 'Toolbox Talks', to: '/toolbox', icon: 'MessageSquare', group: 'Operations', minRank: ROLE_RANK_MAP.USER },
  { label: 'Man-Hours', to: '/manhours', icon: 'Clock', group: 'Operations', minRank: ROLE_RANK_MAP.USER },
  { label: 'Permit to Work', to: '/permits', icon: 'FileCheck', group: 'Safety', minRank: ROLE_RANK_MAP.USER },
  { label: 'HSE Inspections', to: '/inspections', icon: 'ClipboardCheck', group: 'Safety', minRank: ROLE_RANK_MAP.USER },
  { label: 'Customer Truck Inspection', to: '/truck-inspections', icon: 'Truck', group: 'Safety', minRank: ROLE_RANK_MAP.USER },
  { label: 'Incidents', to: '/incidents', icon: 'AlertTriangle', group: 'Safety', minRank: ROLE_RANK_MAP.USER },
  { label: 'Hazards', to: '/hazards', icon: 'ShieldAlert', group: 'Safety', minRank: ROLE_RANK_MAP.USER },
  { label: 'CAPA', to: '/capa', icon: 'Wrench', group: 'Safety', minRank: ROLE_RANK_MAP.USER },
  { label: 'Equipment & Assets', to: '/assets', icon: 'Package', group: 'Assets', minRank: ROLE_RANK_MAP.USER },
  { label: 'Personnel', to: '/personnel', icon: 'Users', group: 'Admin', minRank: ROLE_RANK_MAP.COUNTRY_HEAD },
  { label: 'Depots', to: '/depots', icon: 'Warehouse', group: 'Admin', minRank: ROLE_RANK_MAP.COUNTRY_HEAD },
  { label: 'Checklist Builder', to: '/checklist-builder', icon: 'ListChecks', group: 'Admin', minRank: ROLE_RANK_MAP.COUNTRY_HEAD },
  { label: 'DSO Stand-In', to: '/stand-in', icon: 'UserCog', group: 'Admin', minRank: ROLE_RANK_MAP.COUNTRY_HEAD },
  { label: 'Platform Export', to: '/platform-export', icon: 'Download', group: 'Admin', minRank: ROLE_RANK_MAP.SUPERADMIN, superadminOnly: true },
  { label: 'Settings', to: '/settings', icon: 'Settings', group: 'Admin', minRank: ROLE_RANK_MAP.COUNTRY_HEAD },
  { label: 'User Management', to: '/users', icon: 'UserPlus', group: 'Admin', minRank: ROLE_RANK_MAP.SUPERADMIN, superadminOnly: true },
]

export const GROUP_ORDER: NavItem['group'][] = ['Overview', 'Operations', 'Safety', 'Assets', 'Admin']

/** RAG thresholds expressed as named ratios to keep components text-free of magic numbers. */
export const RAG_THRESHOLDS = {
  GOOD: 0.8,
  WARN: 0.6,
  /** Inspection compliance bar: >=0.85 green, >=0.70 amber, else red. */
  INSPECTION_GOOD: 0.85,
  INSPECTION_WARN: 0.7,
} as const

/** Completion % → Tailwind classes (>=80 green, 60-79 amber, <60 red). */
export function ragTone(ratio: number | null | undefined): { color: 'text-rag-good' | 'text-rag-warn' | 'text-rag-bad'; bg: string; label: string } {
  const r = ratio ?? 0
  if (r >= RAG_THRESHOLDS.GOOD) return { color: 'text-rag-good', bg: 'bg-rag-good', label: r >= 1 ? '' : 'On track' }
  if (r >= RAG_THRESHOLDS.WARN) return { color: 'text-rag-warn', bg: 'bg-rag-warn', label: 'Needs attention' }
  return { color: 'text-rag-bad', bg: 'bg-rag-bad', label: 'At risk' }
}

export function inspectionTone(ratio: number | null | undefined): { color: 'text-rag-good' | 'text-rag-warn' | 'text-rag-bad'; bg: string } {
  const r = ratio ?? 0
  if (r >= RAG_THRESHOLDS.INSPECTION_GOOD) return { color: 'text-rag-good', bg: 'bg-rag-good' }
  if (r >= RAG_THRESHOLDS.INSPECTION_WARN) return { color: 'text-rag-warn', bg: 'bg-rag-warn' }
  return { color: 'text-rag-bad', bg: 'bg-rag-bad' }
}

export const FREQUENCIES: Frequency[] = ['DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY', 'BIANNUAL', 'ANNUAL']

export const COMPLETION_METHODS: CompletionMethod[] = [
  'MANUAL',
  'FORM',
  'COUNT',
  'PERMIT',
  'VEHICLE',
  'EQUIPMENT',
  'PERSONNEL',
  'AI_VERIFIED',
]

export const FREQUENCY_LABELS: Record<Frequency, string> = {
  DAILY: 'Daily',
  WEEKLY: 'Weekly (weekdays)',
  MONTHLY: 'Monthly (specific dates)',
  QUARTERLY: 'Quarterly',
  BIANNUAL: 'Biannual',
  ANNUAL: 'Annual',
}

/** Severity scoring for risk matrix: Low=1, Medium=2, High=3, Critical=4. */
export const SEVERITY_SCORE = { LOW: 1, MEDIUM: 2, HIGH: 3, CRITICAL: 4 } as const

export const LIKELIHOOD_SCORES = [
  { value: 1, label: 'Rare (1)' },
  { value: 2, label: 'Unlikely (2)' },
  { value: 3, label: 'Possible (3)' },
  { value: 4, label: 'Likely (4)' },
  { value: 5, label: 'Almost Certain (5)' },
]

/** Risk = likelihood × severity(1-4). */
export function riskScore(likelihood: number, severityValue: 1 | 2 | 3 | 4): number {
  return likelihood * severityValue
}

export function riskRating(score: number): 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL' {
  if (score >= 15) return 'CRITICAL'
  if (score >= 8) return 'HIGH'
  if (score >= 4) return 'MEDIUM'
  return 'LOW'
}

/** Personnel scorecard rating thresholds. */
export function scorecardRating(total: number): { label: string; color: string } {
  if (total >= 20) return { label: 'Excellent', color: 'text-rag-good' }
  if (total >= 10) return { label: 'Good', color: 'text-blue-600' }
  if (total >= 5) return { label: 'Fair', color: 'text-rag-warn' }
  return { label: 'Needs Improvement', color: 'text-rag-bad' }
}

export const STORAGE_BUCKETS = {
  images: 'images',
  signatures: 'signatures',
  attachments: 'attachments',
} as const

export const APP_META = {
  name: 'SafeDepot Pro',
  subtitle: 'HSE Management',
  primary: '#cc0000',
  accent: '#f59e0b',
} as const

/** Monthly reporting period starts on the 20th of each calendar month. */
export function manHoursPeriod(): { start: string; end: string } {
  const now = new Date()
  const y = now.getFullYear()
  const m = now.getMonth()
  const day = now.getDate()
  let start: Date
  if (day >= 20) {
    start = new Date(y, m, 20)
  } else {
    start = new Date(y, m - 1, 20)
  }
  const end = new Date(start)
  end.setMonth(end.getMonth() + 1)
  end.setDate(19)
  const iso = (d: Date) =>
    new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 10)
  return { start: iso(start), end: iso(end) }
}

export const DOWNLOAD_SOURCE_BASE = '/download-source'

/**
 * KPI icon-badge tints (soft fills on white — hue carries meaning, saturation is muted).
 * chip = icon badge background/text, value = big-number color.
 */
export const KPI_HUES = {
  green: { chip: 'bg-green-50 text-green-600', value: 'text-rag-good' },
  amber: { chip: 'bg-amber-50 text-amber-600', value: 'text-rag-warn' },
  red: { chip: 'bg-red-50 text-red-600', value: 'text-rag-bad' },
  orange: { chip: 'bg-orange-50 text-orange-600', value: 'text-foreground' },
  blue: { chip: 'bg-blue-50 text-blue-600', value: 'text-foreground' },
  purple: { chip: 'bg-purple-50 text-purple-600', value: 'text-foreground' },
  slate: { chip: 'bg-gray-100 text-gray-600', value: 'text-foreground' },
} as const

export type KpiHue = keyof typeof KPI_HUES

/** Semantic → hue mapping used by the dashboard KPI grid. */
export const SDP_SEMANTIC_HUES = {
  hazards: 'red',
  capa: 'purple',
  permits: 'blue',
  inspections: 'purple',
  incidents: 'orange',
  personnel: 'blue',
  depots: 'slate',
} as const