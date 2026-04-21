create table if not exists public.user_subscriptions (
  user_id                 text primary key,
  status                  text not null default 'inactive'
                            check (status in ('inactive', 'active', 'lifetime', 'canceled')),
  billing_period          text
                            check (billing_period in ('monthly', 'annual', 'lifetime')),
  source                  text,
  store                   text,
  product_id              text,
  purchase_id             text,
  purchase_token          text,
  raw_verification_data   text,
  trial_started_at        timestamptz,
  trial_ends_at           timestamptz,
  promo_code_redeemed_at  timestamptz,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

create index if not exists user_subscriptions_status_idx
  on public.user_subscriptions (status, updated_at desc);

alter table public.user_subscriptions enable row level security;

create policy "users read own subscription"
  on public.user_subscriptions for select
  using (public.current_user_id() = user_id);

create trigger user_subscriptions_set_updated_at
  before update on public.user_subscriptions
  for each row execute procedure public.set_updated_at();
