create table if not exists public.user_usage_settings (
  user_id                  text primary key,
  ai_token_limit_disabled  boolean not null default false,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);

alter table public.user_usage_settings enable row level security;

create policy "users read own usage settings"
  on public.user_usage_settings for select
  using (public.current_user_id() = user_id);

create trigger user_usage_settings_set_updated_at
  before update on public.user_usage_settings
  for each row execute procedure public.set_updated_at();
