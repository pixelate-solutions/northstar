create table if not exists public.travel_memories (
  id             uuid primary key default uuid_generate_v4(),
  user_id        text not null,
  source_plan_id uuid references public.trips(id) on delete set null,
  memory_text    text not null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (user_id, memory_text)
);

create index if not exists travel_memories_user_updated_idx
  on public.travel_memories (user_id, updated_at desc);

alter table public.travel_memories enable row level security;

create policy "users manage own travel memories"
  on public.travel_memories for all
  using (public.current_user_id() = user_id)
  with check (public.current_user_id() = user_id);

create trigger travel_memories_set_updated_at
  before update on public.travel_memories
  for each row execute procedure public.set_updated_at();
