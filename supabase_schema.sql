-- ============================================================
-- SubTrack2 — Supabase Schema
-- รัน SQL นี้ใน Supabase Dashboard > SQL Editor > New Query
-- ============================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ===============================
-- 1. PROFILES TABLE
-- ===============================
create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  email text not null,
  display_name text,
  photo_url text,
  currency text not null default 'THB',
  monthly_budget double precision not null default 0,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
create policy "Users can view their own profile"
  on public.profiles for select using (auth.uid() = id);
create policy "Users can update their own profile"
  on public.profiles for update using (auth.uid() = id);
create policy "Users can insert their own profile"
  on public.profiles for insert with check (auth.uid() = id);

-- ===============================
-- 2. CATEGORIES TABLE
-- ===============================
create table if not exists public.categories (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users on delete cascade,
  name text not null,
  icon_code integer not null,
  color_value integer not null,
  monthly_budget double precision not null default 0,
  currency text not null default 'THB',
  created_at timestamptz not null default now()
);

alter table public.categories enable row level security;
create policy "Users manage their own categories"
  on public.categories for all using (auth.uid() = user_id);

-- ===============================
-- 3. SUBSCRIPTIONS TABLE
-- ===============================
create table if not exists public.subscriptions (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users on delete cascade,
  category_id uuid references public.categories on delete set null,
  name text not null,
  price double precision not null default 0,
  currency text not null default 'THB',
  cycle text not null default 'monthly', -- 'weekly','monthly','yearly'
  first_payment_date timestamptz not null,
  next_payment_date timestamptz not null,
  status text not null default 'Active', -- 'Active','Paused','Cancelled'
  family_member_id uuid,
  url text,
  logo_url text,
  is_free_trial boolean not null default false,
  is_auto_renew boolean not null default true,
  has_reminder boolean not null default true,
  reminder_days_prior integer not null default 1,
  termination_date timestamptz,
  created_at timestamptz not null default now()
);

alter table public.subscriptions enable row level security;
create policy "Users manage their own subscriptions"
  on public.subscriptions for all using (auth.uid() = user_id);

-- ===============================
-- 4. PAYMENT_HISTORY TABLE
-- ===============================
create table if not exists public.payment_history (
  id uuid primary key default uuid_generate_v4(),
  subscription_id uuid not null references public.subscriptions on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  amount double precision not null default 0,
  date timestamptz not null,
  status text not null default 'Paid', -- 'Paid','Skipped'
  created_at timestamptz not null default now()
);

alter table public.payment_history enable row level security;
create policy "Users manage their own payment history"
  on public.payment_history for all using (auth.uid() = user_id);

-- ===============================
-- 5. FAMILY_MEMBERS TABLE
-- ===============================
create table if not exists public.family_members (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users on delete cascade,
  name text not null,
  photo_url text,
  is_current_user boolean not null default false,
  email text,
  status text not null default 'pending', -- 'pending','accepted'
  linked_user_id uuid references auth.users on delete set null,
  created_by uuid references auth.users not null default auth.uid(),
  created_at timestamptz not null default now()
);

alter table public.family_members enable row level security;
create policy "Users manage their own family members"
  on public.family_members for all using (auth.uid() = user_id);

-- ===============================
-- 6. AUTO-CREATE PROFILE ON SIGNUP
-- (Supabase Auth Trigger)
-- ===============================
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, display_name, photo_url)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'avatar_url'
  );
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
