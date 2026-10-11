import { supabase } from '@/lib/supabaseClient'
import type { Permit } from '@/types/entities'

export const PERMIT_DEFAULTS = {
  gas_tests: { readings: [], test_equipment: '', calibrated: false },
  confined_space: { is_confined_space: false, entry_permit: false, gas_monitor: false, rescue_plan: false },
  work_at_height: { is_work_at_height: false, harness: false, anchored_100pct: false, guardrails: false, scaff_tag: '' },
  electrical_isolation: { isolation_required: false, lockout_tags: 0, permits_issued: false },
  excavation: { is_excavation: false, depth_meters: 0, shoring: false, buried_services: false, utility_clearance: false },
}

export async function listPermits(options: { depotId?: string; status?: Permit['status'] } = {}) {
  let q = supabase.from('permits').select('*').order('created_at', { ascending: false })
  if (options.depotId) q = q.eq('depot_id', options.depotId)
  if (options.status) q = q.eq('status', options.status)
  const { data, error } = await q
  if (error) throw error
  return data as Permit[]
}

export async function getPermit(id: string) {
  const { data, error } = await supabase.from('permits').select('*').eq('id', id).single()
  if (error) throw error
  return data as Permit
}

export async function nextPermitNumber(): Promise<string> {
  const { data } = await supabase.from('permits').select('permit_number').order('created_at', { ascending: false }).limit(1)
  const last = data?.[0]?.permit_number
  const num = last ? parseInt(last.replace(/^\D+/g, ''), 10) + 1 : 1
  return `PTW-${String(num).padStart(4, '0')}`
}

export async function createPermit(input: Partial<Permit>) {
  const { data, error } = await supabase
    .from('permits')
    .insert({
      permit_number: input.permit_number!,
      depot_id: input.depot_id!,
      permit_type: input.permit_type ?? null,
      job_title: input.job_title!,
      job_description: input.job_description ?? null,
      tasks: input.tasks ?? [],
      location: input.location ?? null,
      start_datetime: input.start_datetime ?? null,
      end_datetime: input.end_datetime ?? null,
      hazard_assessment: input.hazard_assessment ?? [],
      additional_controls: input.additional_controls ?? null,
      ppe: input.ppe ?? [],
      isolation_loto: input.isolation_loto ?? null,
      gas_tests: input.gas_tests ?? PERMIT_DEFAULTS.gas_tests,
      confined_space: input.confined_space ?? PERMIT_DEFAULTS.confined_space,
      work_at_height: input.work_at_height ?? PERMIT_DEFAULTS.work_at_height,
      electrical_isolation: input.electrical_isolation ?? PERMIT_DEFAULTS.electrical_isolation,
      excavation: input.excavation ?? PERMIT_DEFAULTS.excavation,
      certificates: input.certificates ?? [],
      attachment_paths: input.attachment_paths ?? [],
      signature_applicant: input.signature_applicant ?? null,
      signature_approving: input.signature_approving ?? null,
      status: input.status ?? 'DRAFT',
      created_by: input.created_by ?? null,
    })
    .select()
    .single()
  if (error) throw error
  return data as Permit
}

export async function updatePermit(id: string, input: Partial<Permit>) {
  const { data, error } = await supabase.from('permits').update(input).eq('id', id).select().single()
  if (error) throw error
  return data as Permit
}

export async function setPermitStatus(id: string, status: Permit['status'], extra: Partial<Permit> = {}) {
  return updatePermit(id, { ...extra, status, approved_at: status === 'APPROVED' ? new Date().toISOString() : undefined })
}

export async function deletePermit(id: string) {
  const { error } = await supabase.from('permits').delete().eq('id', id)
  if (error) throw error
}

/** Block approval unless risk assessment, hazards, controls and PPE are complete. */
export function permitValidationErrors(p: Partial<Permit>): string[] {
  const errors: string[] = []
  if (!p.job_title?.trim()) errors.push('Job title is required.')
  if (!p.hazard_assessment || p.hazard_assessment.length === 0) errors.push('Hazard assessment must contain at least one hazard.')
  for (const [i, h] of (p.hazard_assessment ?? []).entries()) {
    if (!h.hazard?.trim()) errors.push(`Hazard ${i + 1}: hazard description is required.`)
    if (!h.initial_risk || h.initial_risk < 1) errors.push(`Hazard ${i + 1}: initial risk score is required.`)
    if (!h.existing_controls?.trim()) errors.push(`Hazard ${i + 1}: existing controls are required.`)
  }
  if (!p.ppe || p.ppe.length === 0) errors.push('PPE selection is required.')
  return errors
}