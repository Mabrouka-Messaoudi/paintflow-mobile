-- =========================================================
-- PaintFlow — initial schema
-- Tables: profiles, clients, payments, purchases
-- View:   client_summary (received / remaining / purchases total)
-- RLS:    admin = full access, client = read-only on own project
-- Storage: private bucket "receipts" (path: <client_id>/<file>)
-- =========================================================

-- ---------- 1. Profiles (one row per auth user) ----------
create table public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  full_name  text,
  role       text not null default 'client' check (role in ('admin', 'client')),
  created_at timestamptz not null default now()
);

-- Auto-create a profile when a user signs up / is created
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, new.raw_user_meta_data ->> 'full_name');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Helper: is the current user the admin (painter)?
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

-- ---------- 2. Clients (one client = one project) ----------
create table public.clients (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid unique references auth.users (id) on delete set null,
  full_name      text not null,
  phone          text,
  email          text,
  address        text,
  agreed_amount  numeric(12, 3) not null default 0 check (agreed_amount >= 0),
  status         text not null default 'todo' check (status in ('todo', 'progress', 'done')),
  created_at     timestamptz not null default now()
);

-- ---------- 3. Payments received ----------
create table public.payments (
  id          uuid primary key default gen_random_uuid(),
  client_id   uuid not null references public.clients (id) on delete cascade,
  amount      numeric(12, 3) not null check (amount > 0),
  method      text not null default 'cash' check (method in ('cash', 'transfer', 'postal')),
  note        text,
  paid_at     date not null default current_date,
  created_at  timestamptz not null default now()
);
create index payments_client_id_idx on public.payments (client_id);

-- ---------- 4. Purchases ----------
create table public.purchases (
  id               uuid primary key default gen_random_uuid(),
  client_id        uuid not null references public.clients (id) on delete cascade,
  item_name        text not null,
  quantity         numeric(10, 2) not null default 1 check (quantity > 0),
  unit_price       numeric(12, 3) not null check (unit_price >= 0),
  total            numeric(14, 3) generated always as (quantity * unit_price) stored,
  shop_name        text,
  receipt_path     text,
  item_photo_path  text,
  purchased_at     date not null default current_date,
  created_at       timestamptz not null default now()
);
create index purchases_client_id_idx on public.purchases (client_id);

-- ---------- 5. Summary view (always computed, never stored) ----------
create or replace view public.client_summary
with (security_invoker = true) as
select
  c.*,
  coalesce(p.received, 0)                     as received,
  c.agreed_amount - coalesce(p.received, 0)   as remaining,
  coalesce(pu.purchases_total, 0)             as purchases_total
from public.clients c
left join (
  select client_id, sum(amount) as received
  from public.payments group by client_id
) p on p.client_id = c.id
left join (
  select client_id, sum(total) as purchases_total
  from public.purchases group by client_id
) pu on pu.client_id = c.id;

-- ---------- 6. Row Level Security ----------
alter table public.profiles  enable row level security;
alter table public.clients   enable row level security;
alter table public.payments  enable row level security;
alter table public.purchases enable row level security;

-- profiles
create policy "profiles: read own" on public.profiles
  for select using (id = auth.uid() or public.is_admin());

-- clients
create policy "clients: admin all" on public.clients
  for all using (public.is_admin()) with check (public.is_admin());
create policy "clients: client reads own" on public.clients
  for select using (user_id = auth.uid());

-- payments
create policy "payments: admin all" on public.payments
  for all using (public.is_admin()) with check (public.is_admin());
create policy "payments: client reads own" on public.payments
  for select using (
    client_id in (select id from public.clients where user_id = auth.uid())
  );

-- purchases
create policy "purchases: admin all" on public.purchases
  for all using (public.is_admin()) with check (public.is_admin());
create policy "purchases: client reads own" on public.purchases
  for select using (
    client_id in (select id from public.clients where user_id = auth.uid())
  );

-- ---------- 7. Storage: receipts & purchase photos ----------
insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', false)
on conflict (id) do nothing;

create policy "receipts: admin all" on storage.objects
  for all using (bucket_id = 'receipts' and public.is_admin())
  with check (bucket_id = 'receipts' and public.is_admin());

create policy "receipts: client reads own" on storage.objects
  for select using (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] in (
      select id::text from public.clients where user_id = auth.uid()
    )
  );

-- ---------- 8. Realtime (amounts update live on the client's phone) ----------
alter publication supabase_realtime add table public.clients, public.payments, public.purchases;
