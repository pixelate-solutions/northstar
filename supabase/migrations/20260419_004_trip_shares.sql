alter table public.trips
  drop constraint if exists trips_user_id_fkey;

alter table public.trips
  alter column user_id type text using user_id::text;

create table public.trip_shares (
  id              uuid primary key default uuid_generate_v4(),
  trip_id         uuid not null references public.trips(id) on delete cascade,
  owner_user_id   text not null,
  recipient_email text not null,
  role            text not null default 'viewer'
                    check (role in ('viewer', 'editor')),
  created_at      timestamptz not null default now(),
  unique (trip_id, recipient_email)
);

create index trip_shares_trip_id_idx on public.trip_shares (trip_id);
create index trip_shares_recipient_email_idx
  on public.trip_shares (lower(recipient_email));

alter table public.trip_shares enable row level security;

create or replace function public.current_user_id()
returns text
language sql
stable
as $$
  select auth.jwt()->>'sub';
$$;

create or replace function public.current_user_email()
returns text
language sql
stable
as $$
  select lower(
    coalesce(
      auth.jwt()->>'email',
      auth.jwt()->>'email_address',
      auth.jwt()->'user_metadata'->>'email'
    )
  );
$$;

drop policy if exists "users manage own trips" on public.trips;

create policy "users can read own and shared trips"
  on public.trips for select
  using (
    public.current_user_id() = user_id
    or exists (
      select 1
      from public.trip_shares s
      where s.trip_id = trips.id
        and lower(s.recipient_email) = public.current_user_email()
    )
  );

create policy "users can insert own trips"
  on public.trips for insert
  with check (public.current_user_id() = user_id);

create policy "users can update own trips"
  on public.trips for update
  using (public.current_user_id() = user_id)
  with check (public.current_user_id() = user_id);

create policy "users can delete own trips"
  on public.trips for delete
  using (public.current_user_id() = user_id);

create policy "owners can manage trip shares"
  on public.trip_shares for all
  using (public.current_user_id() = owner_user_id)
  with check (
    public.current_user_id() = owner_user_id
    and exists (
      select 1
      from public.trips t
      where t.id = trip_id
        and t.user_id = public.current_user_id()
    )
  );

create policy "recipients can read their trip shares"
  on public.trip_shares for select
  using (lower(recipient_email) = public.current_user_email());
