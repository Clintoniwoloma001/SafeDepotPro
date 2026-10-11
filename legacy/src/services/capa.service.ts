import { supabase } from '@/lib/supabaseClient'
import type { CapaRecord } from '@/types/entities'
import type { CapaStatus } from '@/types/enums'

export async function listCapas(options: { depotId?: string; status?: CapaRecord['status']; assignedToMe?: boolean } = {}) {
  let q = supabase.from('capa').select('*').order('created_at', { ascending: false })
  if (options.depotId) q = q.eq('depot_id', options.depotId)
  if (options.status) q = q.eq('status', options.status)
  if (options.assignedToMe) {
    const { data: session } = await supabase.auth.getSession()
    if (session.session) q = q.eq('responsible_user_id', session.session.user.id)
  }
  const { data, error } = await q
  if (error) throw error
  return data as CapaRecord[]
}

export async function getCapa(id: string) {
  const { data, error } = await supabase.from('capa').select('*').eq('id', id).single()
  if (error) throw error
  return data as CapaRecord
}

export async function nextCapaNumber(): Promise<string> {
  const { data } = await supabase.from('capa').select('capa_number').order('created_at', { ascending: false }).limit(1)
  const num = data?.[0]?.capa_number ? parseInt(data[0].capa_number.replace(/^\D+/g, ''), 10) + 1 : 1
  return `CAPA-${String(num).padStart(4, '0')}`
}

export async function createCapa(input: Partial<CapaRecord>) {
  const { data, error } = await supabase
    .from('capa')
    .insert({
      depot_id: input.depot_id!,
      capa_number: input.capa_number!,
      title: input.title!,
      source_type: input.source_type ?? 'STANDALONE',
      source_id: input.source_id ?? null,
      description: input.description ?? null,
      root_cause: input.root_cause ?? null,
      corrective_action: input.corrective_action ?? '',
      responsible_user_id: input.responsible_user_id ?? null,
      responsible_name: input.responsible_name ?? null,
      assigner_user_id: input.assigner_user_id ?? null,
      assigner_name: input.assigner_name ?? null,
      priority: input.priority ?? 'MEDIUM',
      status: input.status ?? 'OPEN',
      due_date: input.due_date ?? null,
      completion_rate: 0,
      proof_paths: [],
      signature_path: null,
      completed_at: null,
      completed_by: null,
    })
    .select()
    .single()
  if (error) throw error
  return data as CapaRecord
}

export async function updateCapa(id: string, input: Partial<CapaRecord>) {
  const { data, error } = await supabase.from('capa').update(input).eq('id', id).select().single()
  if (error) throw error
  return data as CapaRecord
}

export async function completeCapaRecord(id: string, input: { proof_paths: string[]; signature_path: string | null; status?: CapaStatus }) {
  const now = new Date().toISOString()
  const { data, error } = await supabase
    .from('capa')
    .update({
      proof_paths: input.proof_paths,
      signature_path: input.signature_path,
      completion_rate: 100,
      status: input.status ?? 'CLOSED',
      completed_at: now,
      completed_by: (await supabase.auth.getUser()).data.user?.id ?? null,
    })
    .eq('id', id)
    .select()
    .single()
  if (error) throw error
  return data as CapaRecord
}

export async function deleteCapa(id: string) {
  const { error } = await supabase.from('capa').delete().eq('id', id)
  if (error) throw error
}