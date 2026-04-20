create extension if not exists "uuid-ossp";

create table public.trips (
  id           uuid primary key default uuid_generate_v4(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  title        text not null,
  destinations text[] not null default '{}',
  date_range   text not null default '',
  summary      text not null default '',
  pace         text not null default 'Balanced',
  plan_json    jsonb not null default '{}',
  status       text not null default 'draft'
                 check (status in ('draft', 'planning', 'ready', 'archived')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index trips_user_id_idx on public.trips (user_id);
create index trips_updated_at_idx on public.trips (updated_at desc);

alter table public.trips enable row level security;

create policy "users manage own trips"
  on public.trips for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trips_set_updated_at
  before update on public.trips
  for each row execute procedure public.set_updated_at();
