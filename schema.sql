-- Run this once in Supabase → SQL Editor.
-- Organizer email is set below; change it if you log in with a different address (same as OWNER_EMAIL in index.html).

create table if not exists public.availability (
  user_id    uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  name       text not null check (char_length(name) between 1 and 60),
  slots      text[] not null default '{}',
  updated_at timestamptz not null default now()
);

alter table public.availability enable row level security;

-- Who is the organizer? Checked against the verified email in the login token.
create or replace function public.is_owner() returns boolean
language sql stable as $$
  select lower(coalesce(auth.jwt() ->> 'email', '')) = lower('fynn.neurath@uni-tuebingen.de')
$$;

-- Everyone sees only their own row; the organizer sees all rows.
drop policy if exists "read own or owner" on public.availability;
create policy "read own or owner" on public.availability
  for select to authenticated
  using (user_id = auth.uid() or public.is_owner());

-- Everyone can only create / change / delete their own row.
drop policy if exists "insert own" on public.availability;
create policy "insert own" on public.availability
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "update own" on public.availability;
create policy "update own" on public.availability
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "delete own" on public.availability;
create policy "delete own" on public.availability
  for delete to authenticated using (user_id = auth.uid());

-- keep updated_at fresh
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$ begin new.updated_at = now(); return new; end $$;
drop trigger if exists availability_touch on public.availability;
create trigger availability_touch before update on public.availability
  for each row execute function public.touch_updated_at();
