-- Run this once in Supabase → SQL Editor.
-- Organizer email is set below; change it if you log in with a different address (same as OWNER_EMAIL in index.html).

create table if not exists public.availability (
  user_id    uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  name       text not null check (char_length(name) between 1 and 60),
  slots      text[] not null default '{}',
  updated_at timestamptz not null default now()
);

-- "possible as exception" slots (added later; this line also upgrades an existing table)
alter table public.availability add column if not exists maybe_slots text[] not null default '{}';

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

-- Events the organizer plans on real dates (independent of the weekly availability grid).
-- Invited participants can see an event; only the organizer can create, change or delete events.
create table if not exists public.events (
  id         uuid primary key default gen_random_uuid(),
  title      text not null check (char_length(title) between 1 and 100),
  location   text not null default '' check (char_length(location) <= 200),
  date       date not null,
  start_time time not null,
  end_time   time check (end_time is null or end_time > start_time),
  invitees   uuid[] not null default '{}',
  created_at timestamptz not null default now()
);

-- people invited by typed name (added later; this line also upgrades an existing table)
alter table public.events add column if not exists invitee_names text[] not null default '{}';

alter table public.events enable row level security;

-- Can the current user see this event? The organizer, people invited directly, and people whose own name
-- matches an invited name (case-insensitive). Note: names are self-chosen, so anyone using that name will see it.
-- (security definer so the answer/comment tables below can use it too)
create or replace function public.can_see_event(eid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.events e
    where e.id = eid and (
      auth.uid() = any(e.invitees)
      or public.is_owner()
      or exists (
        select 1 from public.availability a
        where a.user_id = auth.uid()
          and lower(btrim(a.name)) in (select lower(btrim(x)) from unnest(e.invitee_names) as x)
      )
    )
  )
$$;

drop policy if exists "read invited or owner" on public.events;
create policy "read invited or owner" on public.events
  for select to authenticated
  using (public.can_see_event(id));

drop policy if exists "owner writes" on public.events;
create policy "owner writes" on public.events
  for all to authenticated
  using (public.is_owner()) with check (public.is_owner());

-- Accept / decline. Everyone who can see the event sees all answers; each person can only set their own.
create table if not exists public.event_responses (
  event_id   uuid not null references public.events(id) on delete cascade,
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name       text not null check (char_length(name) between 1 and 60),
  status     text not null check (status in ('accepted', 'declined')),
  updated_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

alter table public.event_responses enable row level security;

drop policy if exists "read if event visible" on public.event_responses;
create policy "read if event visible" on public.event_responses
  for select to authenticated using (public.can_see_event(event_id));

drop policy if exists "answer own" on public.event_responses;
create policy "answer own" on public.event_responses
  for insert to authenticated with check (user_id = auth.uid() and public.can_see_event(event_id));

drop policy if exists "change own answer" on public.event_responses;
create policy "change own answer" on public.event_responses
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid() and public.can_see_event(event_id));

drop policy if exists "withdraw own answer" on public.event_responses;
create policy "withdraw own answer" on public.event_responses
  for delete to authenticated using (user_id = auth.uid());

drop trigger if exists event_responses_touch on public.event_responses;
create trigger event_responses_touch before update on public.event_responses
  for each row execute function public.touch_updated_at();

-- Comments. Everyone who can see the event sees and can write comments; people delete their own,
-- the organizer can delete any. by_owner (the "organizer" label) can only be set by the organizer.
create table if not exists public.event_comments (
  id         uuid primary key default gen_random_uuid(),
  event_id   uuid not null references public.events(id) on delete cascade,
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name       text not null check (char_length(name) between 1 and 60),
  by_owner   boolean not null default false,
  body       text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);

alter table public.event_comments enable row level security;

drop policy if exists "read if event visible" on public.event_comments;
create policy "read if event visible" on public.event_comments
  for select to authenticated using (public.can_see_event(event_id));

drop policy if exists "comment if event visible" on public.event_comments;
create policy "comment if event visible" on public.event_comments
  for insert to authenticated
  with check (user_id = auth.uid() and public.can_see_event(event_id) and (not by_owner or public.is_owner()));

drop policy if exists "delete own or owner" on public.event_comments;
create policy "delete own or owner" on public.event_comments
  for delete to authenticated using (user_id = auth.uid() or public.is_owner());
