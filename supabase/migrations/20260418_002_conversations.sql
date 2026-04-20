create table public.conversations (
  id         uuid primary key default uuid_generate_v4(),
  trip_id    uuid references public.trips(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  role       text not null check (role in ('user', 'assistant', 'tool', 'system')),
  content    text,
  tool_calls jsonb,
  tool_name  text,
  created_at timestamptz not null default now()
);

create index conversations_trip_id_idx on public.conversations (trip_id, created_at);

alter table public.conversations enable row level security;

create policy "users manage own conversations"
  on public.conversations for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
