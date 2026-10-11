import { supabase } from '@/lib/supabaseClient'
import type { ChecklistTemplate, Inspection, InspectionAnswer, Truck, TruckInspection } from '@/types/entities'
import type { InspectionResponse, Priority, Severity } from '@/types/enums'

export async function listChecklistTemplates(type?: 'HSE' | 'TRUCK') {
  let q = supabase.from('checklist_templates').select('*').order('created_at', { ascending: false })
  if (type) q = q.eq('template_type', type)
  const { data, error } = await q
  if (error) throw error
  return data as ChecklistTemplate[]
}

export async function getChecklistTemplate(id: string) {
  const { data, error } = await supabase.from('checklist_templates').select('*').eq('id', id).single()
  if (error) throw error
  return data as ChecklistTemplate
}

export async function createChecklistTemplate(input: Partial<ChecklistTemplate>) {
  const { data, error } = await supabase
    .from('checklist_templates')
    .insert({
      title: input.title!,
      template_type: input.template_type ?? 'HSE',
      category: input.category ?? null,
      description: input.description ?? null,
      sections: input.sections ?? [],
      is_standard: input.is_standard ?? false,
      is_active: input.is_active ?? true,
      created_by: input.created_by ?? null,
    })
    .select()
    .single()
  if (error) throw error
  return data as ChecklistTemplate
}

export async function updateChecklistTemplate(id: string, input: Partial<ChecklistTemplate>) {
  const { data, error } = await supabase.from('checklist_templates').update(input).eq('id', id).select().single()
  if (error) throw error
  return data as ChecklistTemplate
}

export async function deleteChecklistTemplate(id: string) {
  const { error } = await supabase.from('checklist_templates').delete().eq('id', id)
  if (error) throw error
}

// ---------------------------------------------------------------------------
// Inspections
// ---------------------------------------------------------------------------

export async function listInspections(options: { depotId?: string; from?: string; to?: string } = {}) {
  let q = supabase.from('inspections').select('*').order('inspection_date', { ascending: false })
  if (options.depotId) q = q.eq('depot_id', options.depotId)
  if (options.from) q = q.gte('inspection_date', options.from)
  if (options.to) q = q.lte('inspection_date', options.to)
  const { data, error } = await q
  if (error) throw error
  return data as Inspection[]
}

export async function getInspection(id: string) {
  const { data, error } = await supabase.from('inspections').select('*').eq('id', id).single()
  if (error) throw error
  return data as Inspection
}

export async function createInspection(input: Partial<Inspection>) {
  const { data, error } = await supabase
    .from('inspections')
    .insert({
      template_id: input.template_id ?? null,
      depot_id: input.depot_id!,
      title: input.title ?? null,
      inspection_date: input.inspection_date ?? new Date().toISOString().slice(0, 10),
      inspector_user_id: input.inspector_user_id ?? null,
      inspector_name: input.inspector_name ?? null,
      status: input.status ?? 'DRAFT',
      answers: input.answers ?? [],
      compliance_percentage: input.compliance_percentage ?? 0,
      overall_note: input.overall_note ?? null,
      signature_path: input.signature_path ?? null,
      created_by: input.created_by ?? null,
    })
    .select()
    .single()
  if (error) throw error
  return data as Inspection
}

export async function updateInspection(id: string, input: Partial<Inspection>) {
  const { data, error } = await supabase.from('inspections').update(input).eq('id', id).select().single()
  if (error) throw error
  return data as Inspection
}

export async function deleteInspection(id: string) {
  const { error } = await supabase.from('inspections').delete().eq('id', id)
  if (error) throw error
}

/** Compliance = PASS answers / (PASS + FAIL + NON_COMPLIANT) — N/A excluded. */
export function computeCompliance(answers: InspectionAnswer[]): number {
  const scored = answers.filter((a) => a.response === 'PASS' || a.response === 'FAIL' || a.response === 'NON_COMPLIANT')
  if (scored.length === 0) return 0
  const passed = scored.filter((a) => a.response === 'PASS').length
  return Math.round((passed / scored.length) * 100)
}

/** Auto-generate CAPA payloads from failed/non-compliant answers flagged with auto_capa. */
export function capasFromAnswers(answers: InspectionAnswer[]): {
  title: string
  description: string
  corrective_action: string
  responsible_name: string | null
  due_date: string | null
  priority: Priority
}[] {
  return answers
    .filter((a) => a.response === 'FAIL' || a.response === 'NON_COMPLIANT')
    .map((a) => ({
      title: `Inspection finding: ${a.corrective_action || a.note || 'Failed item'}`,
      description: a.note ?? '',
      corrective_action: a.corrective_action ?? '',
      responsible_name: a.responsible_name ?? null,
      due_date: a.due_date ?? null,
      priority: a.priority ?? 'MEDIUM',
    }))
}

// ---------------------------------------------------------------------------
// Trucks + Truck inspections
// ---------------------------------------------------------------------------

export async function listTrucks(options: { depotId?: string } = {}) {
  let q = supabase.from('trucks').select('*').order('plate_number', { ascending: true })
  if (options.depotId) q = q.eq('depot_id', options.depotId)
  const { data, error } = await q
  if (error) throw error
  return data as Truck[]
}

export async function createTruck(input: Partial<Truck>) {
  const { data, error } = await supabase
    .from('trucks')
    .insert({ depot_id: input.depot_id!, plate_number: input.plate_number!, chassis_number: input.chassis_number ?? null })
    .select()
    .single()
  if (error) throw error
  return data as Truck
}

export async function deleteTruck(id: string) {
  const { error } = await supabase.from('trucks').delete().eq('id', id)
  if (error) throw error
}

export async function listTruckInspections(options: { depotId?: string; truckId?: string } = {}) {
  let q = supabase.from('truck_inspections').select('*').order('inspection_date', { ascending: false })
  if (options.depotId) q = q.eq('depot_id', options.depotId)
  if (options.truckId) q = q.eq('truck_id', options.truckId)
  const { data, error } = await q
  if (error) throw error
  return data as TruckInspection[]
}

export async function createTruckInspection(input: Partial<TruckInspection>) {
  const { data, error } = await supabase
    .from('truck_inspections')
    .insert({
      truck_id: input.truck_id!,
      depot_id: input.depot_id!,
      inspection_date: input.inspection_date ?? new Date().toISOString().slice(0, 10),
      inspection_type: input.inspection_type ?? 'PRE_TRIP',
      odometer: input.odometer ?? null,
      driver_user_id: input.driver_user_id ?? null,
      driver_name: input.driver_name ?? null,
      template_id: input.template_id ?? null,
      answers: input.answers ?? [],
      compliance_percentage: input.compliance_percentage ?? 0,
      result: input.result ?? null,
      defect_notes: input.defect_notes ?? null,
      signature_path: input.signature_path ?? null,
      created_by: input.created_by ?? null,
    })
    .select()
    .single()
  if (error) throw error
  return data as TruckInspection
}

export async function updateTruckInspection(id: string, input: Partial<TruckInspection>) {
  const { data, error } = await supabase.from('truck_inspections').update(input).eq('id', id).select().single()
  if (error) throw error
  return data as TruckInspection
}

export type { InspectionResponse, Severity }