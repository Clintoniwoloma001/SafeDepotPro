-- 0014_assistant_documents.sql — RAG knowledge-base catalogue used by the AI Copilot.

create table public.assistant_documents (
  id uuid primary key default gen_random_uuid(),
  title text,
  url text,
  source_type text not null default 'manual' check (source_type in ('manual', 'policy', 'procedure', 'sop', 'regulation', 'training')),
  content_type text,
  filename text,
  active boolean not null default true,
  uploaded_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index assistant_documents_active_idx on public.assistant_documents(active);