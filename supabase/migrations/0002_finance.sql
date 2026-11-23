-- =========================================================
-- Finance: general expenses + worker wages (admin only)
-- =========================================================

create table public.expenses (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  amount      numeric(12, 3) not null check (amount > 0),
  spent_at    date not null default current_date,
  note        text,
  created_at  timestamptz not null default now()
);

create table public.worker_wages (
  id           uuid primary key default gen_random_uuid(),
  worker_name  text not null,
  amount       numeric(12, 3) not null check (amount > 0),
  paid_at      date not null default current_date,
  note         text,
  created_at   timestamptz not null default now()
);

alter table public.expenses     enable row level security;
alter table public.worker_wages enable row level security;

-- No client policy on purpose: clients can never read these tables.
create policy "expenses: admin all" on public.expenses
  for all using (public.is_admin()) with check (public.is_admin());

create policy "worker_wages: admin all" on public.worker_wages
  for all using (public.is_admin()) with check (public.is_admin());
