/**
 * Manually authored database types matching the schema defined in supabase/migrations.
 * Regenerate with `supabase gen types typescript --project-id <ref> --schema public --output src/types/database.types.ts`
 * once a live Supabase project is linked.
 */

export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

type GenericRelationship = {
  foreignKeyName: string
  columns: string[]
  isOneToOne?: boolean
  referencedRelation: string
  referencedColumns: string[]
}

type TableRow<T> = {
  readonly Row: T & Record<string, unknown>
  readonly Insert: Partial<T> & Record<string, unknown>
  readonly Update: Partial<T> & Record<string, unknown>
  readonly Relationships: GenericRelationship[]
}

export type Database = {
  public: {
    Tables: {
      depots: TableRow<import('./entities').Depot>
      depot_zones: TableRow<import('./entities').DepotZone>
      profiles: TableRow<import('./entities').Profile>
      personnel: TableRow<import('./entities').Personnel>
      routine_tasks: TableRow<import('./entities').RoutineTask>
      task_history: TableRow<import('./entities').TaskHistory>
      toolbox_talks: TableRow<import('./entities').ToolboxTalk>
      toolbox_attendees: TableRow<import('./entities').ToolboxAttendee>
      permits: TableRow<import('./entities').Permit>
      checklist_templates: TableRow<import('./entities').ChecklistTemplate>
      inspections: TableRow<import('./entities').Inspection>
      trucks: TableRow<import('./entities').Truck>
      truck_inspections: TableRow<import('./entities').TruckInspection>
      incidents: TableRow<import('./entities').Incident>
      hazards: TableRow<import('./entities').Hazard>
      capa: TableRow<import('./entities').CapaRecord>
      assets: TableRow<import('./entities').Asset>
      man_hours: TableRow<import('./entities').ManHourRecord>
      shift_handovers: TableRow<import('./entities').ShiftHandover>
      stand_ins: TableRow<import('./entities').StandIn>
      app_settings: {
        Row: { key: string; value: Json; updated_by: string | null; updated_at: string }
        Insert: Partial<{ key: string; value: Json; updated_by: string | null; updated_at: string }>
        Update: Partial<{ key: string; value: Json; updated_by: string | null; updated_at: string }>
        Relationships: GenericRelationship[]
      }
      notifications: TableRow<import('./entities').NotificationRecord>
      audit_logs: TableRow<import('./entities').AuditLog>
    }
    Views: {}
    Functions: {
      user_depot_ids: {
        Args: Record<PropertyKey, never>
        Returns: string[]
      }
      current_profile_role: {
        Args: Record<PropertyKey, never>
        Returns: string
      }
      is_superadmin: {
        Args: Record<PropertyKey, never>
        Returns: boolean
      }
    }
    Enums: {
      user_role:
        | 'USER'
        | 'COUNTRY_HEAD'
        | 'ADMIN'
        | 'SUPERADMIN'
      task_status: 'PENDING' | 'COMPLETED' | 'OVERDUE' | 'SKIPPED'
      severity: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'
      priority: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'
      frequency: 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'QUARTERLY' | 'BIANNUAL' | 'ANNUAL'
      completion_method:
        | 'MANUAL'
        | 'FORM'
        | 'COUNT'
        | 'PERMIT'
        | 'VEHICLE'
        | 'EQUIPMENT'
        | 'PERSONNEL'
        | 'AI_VERIFIED'
      permit_status: 'DRAFT' | 'SUBMITTED' | 'APPROVED' | 'REJECTED' | 'CANCELLED' | 'COMPLETED'
      inspection_status: 'DRAFT' | 'SUBMITTED' | 'APPROVED' | 'CLOSED'
      inspection_response: 'PASS' | 'FAIL' | 'NON_COMPLIANT' | 'NA'
      incident_status: 'OPEN' | 'IN_PROGRESS' | 'RESOLVED' | 'CLOSED'
      hazard_status: 'OPEN' | 'IN_PROGRESS' | 'MITIGATED' | 'CLOSED'
      capa_status: 'OPEN' | 'IN_PROGRESS' | 'VERIFICATION' | 'CLOSED'
      stand_in_status: 'PENDING' | 'ACTIVE' | 'COMPLETED' | 'CANCELLED' | 'REJECTED'
      shift_status: 'PENDING' | 'COMPLETED' | 'CONFIRMED'
      asset_status: 'AVAILABLE' | 'IN_USE' | 'MAINTENANCE' | 'RETIRED'
      truck_result: 'PASS' | 'FAIL'
      source_type: 'INCIDENT' | 'INSPECTION' | 'HAZARD' | 'STANDALONE'
      notification_type:
        | 'OVERDUE_TASK'
        | 'OVERDUE_PERMIT'
        | 'OVERDUE_CAPA'
        | 'OVERDUE_INSPECTION'
        | 'SYSTEM'
    }
    CompositeTypes: {}
  }
}

export type Tables<T extends keyof Database['public']['Tables']> =
  Database['public']['Tables'][T]['Row']
export type TableRowT<T extends keyof Database['public']['Tables']> =
  Database['public']['Tables'][T]['Row']
export type TableInsert<T extends keyof Database['public']['Tables']> =
  Database['public']['Tables'][T]['Insert']
export type TableUpdate<T extends keyof Database['public']['Tables']> =
  Database['public']['Tables'][T]['Update']