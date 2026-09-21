import type {
  AssetStatus,
  CapaStatus,
  CompletionMethod,
  Frequency,
  HazardStatus,
  IncidentStatus,
  InspectionResponse,
  InspectionStatus,
  PermitStatus,
  Priority,
  Severity,
  ShiftStatus,
  SourceType,
  StandInStatus,
  TruckResult,
  UserRole,
} from './enums'

export interface Depot {
  id: string
  name: string
  code: string
  address: string | null
  latitude: number | null
  longitude: number | null
  is_active: boolean
  created_at: string
  updated_at: string
}

export interface DepotZone {
  id: string
  depot_id: string
  name: string
  created_at: string
}

export interface Profile {
  id: string
  email: string
  full_name: string
  role: UserRole
  depot_id: string | null
  is_active: boolean
  must_change_password: boolean
  created_at: string
  updated_at: string
}

export interface Personnel {
  id: string
  user_id: string | null
  first_name: string
  last_name: string
  email: string
  phone: string | null
  position: string | null
  depot_id: string | null
  is_active: boolean
  created_at: string
  updated_at: string
}

export interface AdminDepot {
  admin_user_id: string
  depot_id: string
}

export interface RoutineTask {
  id: string
  title: string
  description: string | null
  task_type: CompletionMethod
  category: string | null
  all_depots: boolean
  assigned_depot_ids: string[]
  assigned_user_ids: string[]
  frequency: Frequency
  monthly_dates: number[]
  start_date: string
  end_date: string | null
  expected_occurrences: number | null
  linked_module: 'TOOLBOX' | 'HOUSEKEEPING' | null
  ai_prompt: string | null
  requires_photo_on_completion: boolean
  is_active: boolean
  sequence_order: number
  created_by: string | null
  created_at: string
  updated_at: string
}

export interface TaskHistory {
  id: string
  task_id: string
  user_id: string | null
  actor_name: string | null
  depot_id: string | null
  completed_at: string
  occurrences: number
  expected_occurrences: number | null
  comment: string | null
  photo_paths: string[]
  signature_path: string | null
  latitude: number | null
  longitude: number | null
  ai_verified: boolean
  form_answers: Record<string, unknown> | null
  attendance_count: number | null
  created_at: string
}

export interface ToolboxTalk {
  id: string
  depot_id: string
  talk_date: string
  facilitator: string
  topic: string
  discussion_points: string | null
  takeaways: string | null
  action_items: string | null
  photo_paths: string[]
  created_by: string | null
  created_at: string
}

export interface ToolboxAttendee {
  id: string
  toolbox_talk_id: string
  full_name: string
  signature_path: string | null
  created_at: string
}

export interface HazardAssessmentRow {
  hazard: string
  consequence: string
  existing_controls: string
  additional_controls: string
  initial_risk: number
  residual_risk: number
  risk_rating: string
}

export interface Permit {
  id: string
  permit_number: string
  depot_id: string
  permit_type: string | null
  job_title: string
  job_description: string | null
  tasks: string[]
  location: string | null
  start_datetime: string | null
  end_datetime: string | null
  hazard_assessment: HazardAssessmentRow[]
  additional_controls: string | null
  ppe: string[]
  isolation_loto: string | null
  gas_tests: Record<string, unknown> | null
  confined_space: Record<string, unknown> | null
  work_at_height: Record<string, unknown> | null
  electrical_isolation: Record<string, unknown> | null
  excavation: Record<string, unknown> | null
  certificates: string[]
  attachment_paths: string[]
  signature_applicant: string | null
  signature_approving: string | null
  status: PermitStatus
  created_by: string | null
  approved_by: string | null
  approved_at: string | null
  rejection_reason: string | null
  created_at: string
  updated_at: string
}

export interface ChecklistSection {
  id: string
  name: string
  order: number
  questions: ChecklistQuestion[]
}

export interface ChecklistQuestion {
  id: string
  text: string
  severity: Severity
  requires_photo: boolean
  auto_capa: boolean
  options: string[]
}

export interface ChecklistTemplate {
  id: string
  title: string
  template_type: 'HSE' | 'TRUCK'
  category: string | null
  description: string | null
  sections: ChecklistSection[]
  is_standard: boolean
  is_active: boolean
  created_by: string | null
  created_at: string
  updated_at: string
}

export interface InspectionAnswer {
  question_id: string
  section_id: string
  response: InspectionResponse
  note: string | null
  photo_paths: string[]
  corrective_action: string | null
  responsible_user_id: string | null
  responsible_name: string | null
  due_date: string | null
  priority: Priority | null
}

export interface Inspection {
  id: string
  template_id: string | null
  depot_id: string
  title: string | null
  inspection_date: string
  inspector_user_id: string | null
  inspector_name: string | null
  status: InspectionStatus
  answers: InspectionAnswer[]
  compliance_percentage: number | null
  overall_note: string | null
  signature_path: string | null
  created_by: string | null
  created_at: string
  updated_at: string
}

export interface Truck {
  id: string
  depot_id: string
  plate_number: string
  chassis_number: string | null
  make: string | null
  model: string | null
  year: number | null
  mileage: number | null
  is_company_owned: boolean
  is_active: boolean
  created_at: string
  updated_at: string
}

export interface TruckInspection {
  id: string
  truck_id: string
  depot_id: string
  inspection_date: string
  inspection_type: string
  odometer: number | null
  driver_user_id: string | null
  driver_name: string | null
  template_id: string | null
  answers: InspectionAnswer[]
  compliance_percentage: number | null
  result: TruckResult | null
  defect_notes: string | null
  signature_path: string | null
  created_by: string | null
  created_at: string
  updated_at: string
}

export interface Incident {
  id: string
  depot_id: string
  incident_number: string
  occurred_at: string
  incident_type: string | null
  severity: Severity
  description: string
  root_cause: string | null
  actions_taken: string | null
  involved_personnel: string[]
  photo_paths: string[]
  status: IncidentStatus
  reported_by: string | null
  reported_by_name: string | null
  created_at: string
  updated_at: string
}

export interface Hazard {
  id: string
  depot_id: string
  location: string | null
  description: string
  hazard_type: string | null
  likelihood: number
  severity: Severity
  risk_score: number | null
  risk_rating: string | null
  reported_by: string | null
  reported_by_name: string | null
  photo_paths: string[]
  corrective_action: string | null
  controlled_confirmed: boolean
  status: HazardStatus
  created_at: string
  updated_at: string
}

export interface CapaRecord {
  id: string
  depot_id: string
  capa_number: string
  title: string
  source_type: SourceType
  source_id: string | null
  description: string | null
  root_cause: string | null
  corrective_action: string
  responsible_user_id: string | null
  responsible_name: string | null
  assigner_user_id: string | null
  assigner_name: string | null
  priority: Priority
  status: CapaStatus
  due_date: string | null
  completion_rate: number
  proof_paths: string[]
  signature_path: string | null
  completed_at: string | null
  completed_by: string | null
  created_at: string
  updated_at: string
}

export interface Asset {
  id: string
  depot_id: string
  asset_tag: string | null
  name: string
  asset_type: string | null
  make_model: string | null
  serial_number: string | null
  zone_id: string | null
  zone_name: string | null
  purchase_date: string | null
  status: AssetStatus
  condition: string | null
  last_calibration_date: string | null
  next_calibration_date: string | null
  assigned_to_user_id: string | null
  assigned_to_name: string | null
  notes: string | null
  created_at: string
  updated_at: string
}

export interface ManHourRecord {
  id: string
  depot_id: string
  period_start: string
  period_end: string
  report_date: string
  employees_scheduled: number
  employees_present: number
  hours_worked: number
  overtime_hours: number
  lost_time_injuries: number
  first_aid_cases: number
  medical_treatment_cases: number
  near_misses: number
  recordable_incidents: number
  days_lost: number
  created_by: string | null
  created_at: string
  updated_at: string
}

export interface ShiftHandover {
  id: string
  depot_id: string
  shift_date: string
  shift: string
  outgoing_user_id: string | null
  outgoing_name: string | null
  incoming_user_id: string | null
  incoming_name: string | null
  status: ShiftStatus
  summary: string | null
  checklist: Record<string, unknown>
  open_issues: string | null
  follow_up_actions: string | null
  photo_paths: string[]
  outgoing_signature_path: string | null
  incoming_signature_path: string | null
  created_at: string
  updated_at: string
}

export interface StandIn {
  id: string
  user_id: string
  covering_depot_id: string
  requested_by_user_id: string | null
  requested_by_name: string | null
  start_date: string
  end_date: string
  reason: string | null
  status: StandInStatus
  created_at: string
  updated_at: string
}

export interface AppSettings {
  [key: string]: Record<string, unknown> | null
}

export interface OrgSettings {
  org_name: string
  logo_url: string | null
  company_website: string | null
  notification_config: {
    overdue_check: boolean
    email_escalation: boolean
    cc_country_head: boolean
    bcc_superadmin: boolean
  }
  reminder_policy: {
    reminder_hours: number
    escalation_days: number
  }
}

export interface NotificationRecord {
  id: string
  user_id: string
  type: string
  title: string
  body: string | null
  link: string | null
  is_read: boolean
  created_at: string
}

export interface AuditLog {
  id: string
  user_id: string | null
  user_email: string | null
  action: string
  ip_address: string | null
  success: boolean
  metadata: Record<string, unknown>
  file_size: number | null
  created_at: string
}