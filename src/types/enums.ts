export type UserRole = 'USER' | 'COUNTRY_HEAD' | 'ADMIN' | 'SUPERADMIN'

export type TaskStatus = 'PENDING' | 'COMPLETED' | 'OVERDUE' | 'SKIPPED'

export type Severity = 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'

export type Priority = 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'

export type Frequency = 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'QUARTERLY' | 'BIANNUAL' | 'ANNUAL'

export type CompletionMethod =
  | 'MANUAL'
  | 'FORM'
  | 'COUNT'
  | 'PERMIT'
  | 'VEHICLE'
  | 'EQUIPMENT'
  | 'PERSONNEL'
  | 'AI_VERIFIED'

export type PermitStatus =
  | 'DRAFT'
  | 'SUBMITTED'
  | 'APPROVED'
  | 'REJECTED'
  | 'CANCELLED'
  | 'COMPLETED'

export type InspectionStatus = 'DRAFT' | 'SUBMITTED' | 'APPROVED' | 'CLOSED'

export type InspectionResponse = 'PASS' | 'FAIL' | 'NON_COMPLIANT' | 'NA'

export type IncidentStatus = 'OPEN' | 'IN_PROGRESS' | 'RESOLVED' | 'CLOSED'

export type HazardStatus = 'OPEN' | 'IN_PROGRESS' | 'MITIGATED' | 'CLOSED'

export type CapaStatus = 'OPEN' | 'IN_PROGRESS' | 'VERIFICATION' | 'CLOSED'

export type StandInStatus = 'PENDING' | 'ACTIVE' | 'COMPLETED' | 'CANCELLED' | 'REJECTED'

export type ShiftStatus = 'PENDING' | 'COMPLETED' | 'CONFIRMED'

export type AssetStatus = 'AVAILABLE' | 'IN_USE' | 'MAINTENANCE' | 'RETIRED'

export type TruckResult = 'PASS' | 'FAIL'

export type SourceType = 'INCIDENT' | 'INSPECTION' | 'HAZARD' | 'STANDALONE'

export type NotificationType =
  | 'OVERDUE_TASK'
  | 'OVERDUE_PERMIT'
  | 'OVERDUE_CAPA'
  | 'OVERDUE_INSPECTION'
  | 'SYSTEM'

/** Rank numbers are intentionally as specified: SUPERADMIN(4) > ADMIN(3) > COUNTRY_HEAD(2) > USER(1). */
export const ROLE_RANK: Record<UserRole, number> = {
  SUPERADMIN: 4,
  ADMIN: 3,
  COUNTRY_HEAD: 2,
  USER: 1,
}

export const ROLE_LABELS: Record<UserRole, string> = {
  USER: 'User',
  COUNTRY_HEAD: 'Country Head',
  ADMIN: 'Admin',
  SUPERADMIN: 'Super Admin',
}

export interface EnumLabel {
  value: string
  label: string
  className: string
}

export const RISK_BADGE: Record<string, EnumLabel> = {
  LOW: { value: 'LOW', label: 'Low', className: 'bg-green-100 text-green-700' },
  MEDIUM: { value: 'MEDIUM', label: 'Medium', className: 'bg-amber-100 text-amber-700' },
  HIGH: { value: 'HIGH', label: 'High', className: 'bg-orange-100 text-orange-700' },
  CRITICAL: { value: 'CRITICAL', label: 'Critical', className: 'bg-red-100 text-red-700' },
}

export const PRIORITY_BADGE: Record<string, EnumLabel> = {
  CRITICAL: { value: 'CRITICAL', label: 'Critical', className: 'bg-red-100 text-red-700' },
  HIGH: { value: 'HIGH', label: 'High', className: 'bg-orange-100 text-orange-700' },
  MEDIUM: { value: 'MEDIUM', label: 'Medium', className: 'bg-gray-100 text-gray-600' },
  LOW: { value: 'LOW', label: 'Low', className: 'bg-gray-100 text-gray-600' },
}

export const STATUS_BADGE: Record<string, EnumLabel> = {
  PASS: { value: 'PASS', label: 'Pass', className: 'bg-green-100 text-green-700' },
  COMPLETED: { value: 'COMPLETED', label: 'Completed', className: 'bg-green-100 text-green-700' },
  CLOSED: { value: 'CLOSED', label: 'Closed', className: 'bg-green-100 text-green-700' },
  RESOLVED: { value: 'RESOLVED', label: 'Resolved', className: 'bg-green-100 text-green-700' },
  MITIGATED: { value: 'MITIGATED', label: 'Mitigated', className: 'bg-green-100 text-green-700' },
  FAIL: { value: 'FAIL', label: 'Fail', className: 'bg-red-100 text-red-700' },
  OVERDUE: { value: 'OVERDUE', label: 'Overdue', className: 'bg-red-100 text-red-700' },
  OPEN: { value: 'OPEN', label: 'Open', className: 'bg-amber-100 text-amber-800' },
  PENDING: { value: 'PENDING', label: 'Pending', className: 'bg-amber-100 text-amber-800' },
  IN_PROGRESS: { value: 'IN_PROGRESS', label: 'In Progress', className: 'bg-blue-100 text-blue-700' },
  SUBMITTED: { value: 'SUBMITTED', label: 'Submitted', className: 'bg-blue-100 text-blue-700' },
  APPROVED: { value: 'APPROVED', label: 'Approved', className: 'bg-blue-100 text-blue-700' },
  ACTIVE: { value: 'ACTIVE', label: 'Active', className: 'bg-blue-100 text-blue-700' },
  VERIFICATION: { value: 'VERIFICATION', label: 'Verification', className: 'bg-blue-100 text-blue-700' },
  DRAFT: { value: 'DRAFT', label: 'Draft', className: 'bg-gray-100 text-gray-600' },
  SKIPPED: { value: 'SKIPPED', label: 'Skipped', className: 'bg-gray-100 text-gray-600' },
  CANCELLED: { value: 'CANCELLED', label: 'Cancelled', className: 'bg-gray-100 text-gray-600' },
  REJECTED: { value: 'REJECTED', label: 'Rejected', className: 'bg-red-100 text-red-700' },
  CONFIRMED: { value: 'CONFIRMED', label: 'Confirmed', className: 'bg-green-100 text-green-700' },
}