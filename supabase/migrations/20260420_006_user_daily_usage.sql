create table if not exists public.user_daily_usage (
  user_id     text not null,
  usage_date date not null,
  tokens_used bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, usage_date)
);

create index if not exists user_daily_usage_user_date_idx
  on public.user_daily_usage (user_id, usage_date desc);

alter table public.user_daily_usage enable row level security;

create policy "users read own daily usage"
  on public.user_daily_usage for select
  using (public.current_user_id() = user_id);

create or replace function public.increment_user_daily_usage(
  p_user_id text,
  p_usage_date date,
  p_token_delta bigint
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tokens_used bigint;
begin
  insert into public.user_daily_usage (user_id, usage_date, tokens_used)
  values (p_user_id, p_usage_date, greatest(p_token_delta, 0))
  on conflict (user_id, usage_date)
  do update set
    tokens_used = public.user_daily_usage.tokens_used + greatest(p_token_delta, 0),
    updated_at = now()
  returning tokens_used into v_tokens_used;

  return v_tokens_used;
end;
$$;

create trigger user_daily_usage_set_updated_at
  before update on public.user_daily_usage
  for each row execute procedure public.set_updated_at();
