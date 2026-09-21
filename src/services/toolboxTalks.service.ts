import { supabase } from '@/lib/supabaseClient'
import type { ToolboxTalk, ToolboxAttendee } from '@/types/entities'

export async function listToolboxTalks(options: { depotId?: string; from?: string; to?: string } = {}) {
  let q = supabase.from('toolbox_talks').select('*').order('talk_date', { ascending: false })
  if (options.depotId) q = q.eq('depot_id', options.depotId)
  if (options.from) q = q.gte('talk_date', options.from)
  if (options.to) q = q.lte('talk_date', options.to)
  const { data, error } = await q
  if (error) throw error
  return data as ToolboxTalk[]
}

export async function getToolboxTalk(id: string) {
  const { data, error } = await supabase.from('toolbox_talks').select('*').eq('id', id).single()
  if (error) throw error
  return data as ToolboxTalk
}

export async function listAttendees(talkId: string) {
  const { data, error } = await supabase
    .from('toolbox_attendees')
    .select('*')
    .eq('toolbox_talk_id', talkId)
    .order('created_at', { ascending: true })
  if (error) throw error
  return data as ToolboxAttendee[]
}

export async function createToolboxTalk(input: Partial<ToolboxTalk>) {
  const { data, error } = await supabase
    .from('toolbox_talks')
    .insert({
      depot_id: input.depot_id!,
      talk_date: input.talk_date ?? new Date().toISOString().slice(0, 10),
      facilitator: input.facilitator!,
      topic: input.topic!,
      discussion_points: input.discussion_points ?? null,
      takeaways: input.takeaways ?? null,
      action_items: input.action_items ?? null,
      photo_paths: input.photo_paths ?? [],
      created_by: input.created_by ?? null,
    })
    .select()
    .single()
  if (error) throw error
  return data as ToolboxTalk
}

export async function updateToolboxTalk(id: string, input: Partial<ToolboxTalk>) {
  const { data, error } = await supabase
    .from('toolbox_talks')
    .update({
      talk_date: input.talk_date,
      facilitator: input.facilitator,
      topic: input.topic,
      discussion_points: input.discussion_points,
      takeaways: input.takeaways,
      action_items: input.action_items,
      photo_paths: input.photo_paths,
    })
    .eq('id', id)
    .select()
    .single()
  if (error) throw error
  return data as ToolboxTalk
}

export async function replaceAttendees(talkId: string, attendees: Omit<ToolboxAttendee, 'id' | 'toolbox_talk_id' | 'created_at'>[]) {
  const { error: delError } = await supabase.from('toolbox_attendees').delete().eq('toolbox_talk_id', talkId)
  if (delError) throw delError
  if (attendees.length === 0) return
  const { error } = await supabase
    .from('toolbox_attendees')
    .insert(attendees.map((a) => ({ toolbox_talk_id: talkId, full_name: a.full_name, signature_path: a.signature_path })))
  if (error) throw error
}

export async function deleteToolboxTalk(id: string) {
  const { error } = await supabase.from('toolbox_talks').delete().eq('id', id)
  if (error) throw error
}