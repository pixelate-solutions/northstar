create table public.reminders (
  id         uuid primary key default uuid_generate_v4(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  trip_id    uuid references public.trips(id) on delete cascade,
  stop_id    text,
  title      text not null,
  body       text,
  remind_at  timestamptz not null,
  sent       boolean not null default false,
  created_at timestamptz not null default now()
);

-- partial index: only unsent, sorted by time — used by the pg_cron job
create index reminders_pending_idx on public.reminders (user_id, remind_at)
  where sent = false;

alter table public.reminders enable row level security;

create policy "users manage own reminders"
  on public.reminders for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- pg_cron job: mark reminders as sent every 5 minutes
-- Run this after enabling pg_cron extension in your Supabase project:
--
-- select cron.schedule(
--   'mark-reminders-sent',
--   '*/5 * * * *',
--   $$update public.reminders set sent = true
--     where remind_at <= now() and sent = false$$
-- );
