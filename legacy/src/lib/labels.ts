import { FREQUENCY_LABELS } from '@/lib/constants'
import type { Frequency, Severity } from '@/types/enums'

/** Select-option friendly severity list. Risk/semantic hues are handled by badges. */
export const SEVERITY_LABELS: { value: Severity; label: string }[] = [
  { value: 'LOW', label: 'Low' },
  { value: 'MEDIUM', label: 'Medium' },
  { value: 'HIGH', label: 'High' },
  { value: 'CRITICAL', label: 'Critical' },
]

export const PRIORITY_LABELS: { value: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'; label: string }[] = SEVERITY_LABELS

export const FREQUENCY_LABELS_ARRAY: { value: Frequency; label: string }[] = (
  Object.keys(FREQUENCY_LABELS) as Frequency[]
).map((f) => ({ value: f, label: FREQUENCY_LABELS[f] }))

export const INCIDENT_TYPES = ['First aid', 'Medical treatment', 'Lost time injury', 'Property damage', 'Near miss', 'Fire', 'Vehicle', 'Theft', 'Security', 'Other'] as const

export const HAZARD_TYPES = ['Slip / trip / fall', 'Electrical', 'Fire', 'Chemical', 'Manual handling', 'Work at height', 'Housekeeping', 'Machinery / equipment', 'Environmental', 'Other'] as const