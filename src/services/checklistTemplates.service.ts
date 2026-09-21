import { supabase } from '@/lib/supabaseClient'

export interface ChecklistTemplateInput {
  title: string
  template_type: 'HSE' | 'TRUCK'
  category?: string | null
  description?: string | null
  sections: import('@/types/entities').ChecklistSection[]
  is_standard?: boolean
  is_active?: boolean
}

export async function listChecklistTemplates(type?: 'HSE' | 'TRUCK') {
  let q = supabase.from('checklist_templates').select('*').order('created_at', { ascending: false })
  if (type) q = q.eq('template_type', type)
  const { data, error } = await q
  if (error) throw error
  return data as import('@/types/entities').ChecklistTemplate[]
}

export async function getChecklistTemplate(id: string) {
  const { data, error } = await supabase.from('checklist_templates').select('*').eq('id', id).single()
  if (error) throw error
  return data as import('@/types/entities').ChecklistTemplate
}

export async function createChecklistTemplate(input: ChecklistTemplateInput) {
  const { data, error } = await supabase
    .from('checklist_templates')
    .insert({
      title: input.title,
      template_type: input.template_type,
      category: input.category ?? null,
      description: input.description ?? null,
      sections: input.sections,
      is_standard: input.is_standard ?? false,
      is_active: input.is_active ?? true,
    })
    .select()
    .single()
  if (error) throw error
  return data as import('@/types/entities').ChecklistTemplate
}

export async function updateChecklistTemplate(id: string, input: Partial<ChecklistTemplateInput>) {
  const { data, error } = await supabase.from('checklist_templates').update(input).eq('id', id).select().single()
  if (error) throw error
  return data as import('@/types/entities').ChecklistTemplate
}

export async function deleteChecklistTemplate(id: string) {
  const { error } = await supabase.from('checklist_templates').delete().eq('id', id)
  if (error) throw error
}