/** RAG copilot source document surfaced alongside an answer. */
export interface AssistDoc {
  id?: string
  title?: string | null
  filename?: string | null
  snippet?: string
  score?: number
  url?: string | null
}

/** Document record from the assistant_documents table / edge function. */
export interface AssistantDocument {
  id: string
  title: string | null
  url: string | null
  source_type: string | null
  content_type: string | null
  filename: string | null
  active: boolean
  uploaded_by: string | null
  created_at: string
  updated_at: string
}