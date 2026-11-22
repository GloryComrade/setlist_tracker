-- The Crew: running friends who share Shows with each other.
--
-- Paste this whole file into Supabase > SQL Editor > New query > Run, after
-- the Backstage Pass file (20261122000000_backstage_pass.sql). It is safe to
-- run more than once.
--
-- How it fits together:
--   crew_profiles  your stage name, avatar color and (if you choose) your
--                  Opening Night countdown. Only you and your Crew can see it.
--   crew_invites   an 8-character code you send to a friend. Anyone with the
--                  code can join your Crew until it expires (7 days).
--   crew_links     one row per pair of runners in each other's Crew.
--   crew_blocks    who blocked whom. Each runner's block is their own row,
--                  so one runner can't undo the other's.
--   crew_posts     a snapshot of a Show you chose to share. Your Crew can
--                  read it. Stop sharing deletes it.
--   crew_encores   one cheer per runner per shared Show.
--   crew_reports   a report about a shared Show, for the app's owner to read
--                  in the Supabase dashboard.
--
-- Links, blocks and invites change only through the functions below.
-- Deleting an account removes all of it (every table cascades from
-- auth.users).

create extension if not exists pgcrypto with schema extensions;

-- ---- Profiles ----

create table if not exists public.crew_profiles (
  user_id uuid primary key default auth.uid()
    references auth.users (id) on delete cascade,
  stage_name text not null
    check (char_length(btrim(stage_name)) between 1 and 30),
  color smallint not null default 0 check (color between 0 and 7),
  always_share boolean not null default false,
  -- Opening Night and the Tour's name are kept only while this is on.
  show_opening_night boolean not null default false,
  opening_night date,
  tour_name text check (char_length(tour_name) <= 60),
  updated_at timestamptz not null default now()
);

create or replace function public.crew_profile_stamp()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not new.show_opening_night then
    new.opening_night := null;
    new.tour_name := null;
  end if;
  new.stage_name := btrim(new.stage_name);
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists crew_profile_stamp on public.crew_profiles;
create trigger crew_profile_stamp
  before insert or update on public.crew_profiles
  for each row execute function public.crew_profile_stamp();

-- ---- Links and blocks ----

create table if not exists public.crew_links (
  -- Stored with the smaller id first, so each pair has exactly one row.
  user_a uuid not null references auth.users (id) on delete cascade,
  user_b uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_a, user_b),
  check (user_a < user_b)
);

create index if not exists crew_links_b_idx on public.crew_links (user_b);

create table if not exists public.crew_blocks (
  blocker uuid not null references auth.users (id) on delete cascade,
  blocked uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked),
  check (blocker <> blocked)
);

create index if not exists crew_blocks_blocked_idx
  on public.crew_blocks (blocked);

-- True when either runner blocked the other.
create or replace function public.crew_blocked(one uuid, other uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.crew_blocks b
    where (b.blocker = one and b.blocked = other)
       or (b.blocker = other and b.blocked = one)
  );
$$;

-- True when the signed-in runner and [other] are in each other's Crew.
-- security definer so policies on other tables can call it without the
-- caller reading crew_links directly.
create or replace function public.is_crew(other uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.crew_links l
    where l.user_a = least(auth.uid(), other)
      and l.user_b = greatest(auth.uid(), other)
  ) and not public.crew_blocked(auth.uid(), other);
$$;

alter table public.crew_profiles enable row level security;

drop policy if exists "crew profiles: read" on public.crew_profiles;
create policy "crew profiles: read" on public.crew_profiles
  for select to authenticated
  using (user_id = (select auth.uid()) or public.is_crew(user_id));

drop policy if exists "crew profiles: add own" on public.crew_profiles;
create policy "crew profiles: add own" on public.crew_profiles
  for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists "crew profiles: change own" on public.crew_profiles;
create policy "crew profiles: change own" on public.crew_profiles
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- Read-only from the app; the functions below make every change.
alter table public.crew_links enable row level security;

drop policy if exists "crew links: read own" on public.crew_links;
create policy "crew links: read own" on public.crew_links
  for select to authenticated
  using ((select auth.uid()) in (user_a, user_b));

alter table public.crew_blocks enable row level security;

drop policy if exists "crew blocks: read own" on public.crew_blocks;
create policy "crew blocks: read own" on public.crew_blocks
  for select to authenticated
  using (blocker = (select auth.uid()));

-- ---- Invites ----

create table if not exists public.crew_invites (
  code text primary key check (code ~ '^[A-HJ-NP-Z2-9]{8}$'),
  owner uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days'
);

create index if not exists crew_invites_owner_idx
  on public.crew_invites (owner);

alter table public.crew_invites enable row level security;

drop policy if exists "crew invites: read own" on public.crew_invites;
create policy "crew invites: read own" on public.crew_invites
  for select to authenticated
  using (owner = (select auth.uid()));

-- Wrong codes tried, so nobody can guess their way into a Crew. Old rows
-- are cleared as new ones arrive.
create table if not exists public.crew_invite_misses (
  user_id uuid not null references auth.users (id) on delete cascade,
  at timestamptz not null default now()
);

create index if not exists crew_invite_misses_idx
  on public.crew_invite_misses (user_id, at);

alter table public.crew_invite_misses enable row level security;
-- No policies: only the functions below touch it.

-- Raises when the signed-in runner tried too many wrong codes lately.
create or replace function public.crew_check_misses()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.crew_invite_misses
    where at < now() - interval '1 day';
  if (select count(*) from public.crew_invite_misses
      where user_id = auth.uid() and at > now() - interval '1 hour') >= 10 then
    raise exception 'Too many tries';
  end if;
end;
$$;

-- Your current invite code, made if there isn't one that lasts at least
-- another day. Letters and digits that can't be misread (no 0/O, 1/I/L).
create or replace function public.crew_invite_code()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  found text;
  bytes bytea;
  i int;
begin
  if me is null then
    raise exception 'Not signed in';
  end if;
  if not exists (select 1 from public.crew_profiles where user_id = me) then
    raise exception 'Pick a stage name first';
  end if;
  select c.code into found from public.crew_invites c
    where c.owner = me and c.expires_at > now() + interval '1 day'
    order by c.expires_at desc limit 1;
  if found is not null then
    return found;
  end if;
  delete from public.crew_invites where owner = me;
  loop
    -- Cryptographic randomness: 31^8 (about 850 billion) codes.
    bytes := extensions.gen_random_bytes(8);
    found := '';
    for i in 0..7 loop
      found := found || substr(alphabet, 1 + get_byte(bytes, i) % 31, 1);
    end loop;
    begin
      insert into public.crew_invites (code, owner) values (found, me);
      return found;
    exception when unique_violation then
      -- Try another code.
    end;
  end loop;
end;
$$;

-- The live invite [invite] points to, if any, and not between blocked
-- runners. Counts a miss otherwise.
create or replace function public.crew_find_invite(invite text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  them uuid;
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;
  perform public.crew_check_misses();
  select c.owner into them from public.crew_invites c
    where c.code = upper(regexp_replace(invite, '[^A-Za-z0-9]', '', 'g'))
      and c.expires_at > now();
  if them is null or public.crew_blocked(auth.uid(), them) then
    insert into public.crew_invite_misses (user_id) values (auth.uid());
    return null;
  end if;
  return them;
end;
$$;

-- Who sent a code, so the join screen can say "Maya invites you". No rows
-- when it expired or doesn't exist.
create or replace function public.crew_invite_preview(invite text)
returns table (stage_name text, color smallint, already_crew boolean,
               own_invite boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  them uuid := public.crew_find_invite(invite);
begin
  return query
    select p.stage_name, p.color, public.is_crew(them), them = auth.uid()
    from public.crew_profiles p
    where them is not null and p.user_id = them;
end;
$$;

-- Joins the Crew of whoever made [invite]. Returns their user id, or null
-- when the invite expired or doesn't exist.
create or replace function public.join_crew(invite text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  them uuid;
begin
  if me is null then
    raise exception 'Not signed in';
  end if;
  if not exists (select 1 from public.crew_profiles where user_id = me) then
    raise exception 'Pick a stage name first';
  end if;
  them := public.crew_find_invite(invite);
  if them is null then
    return null;
  end if;
  if them = me then
    raise exception 'That is your own invite';
  end if;
  insert into public.crew_links (user_a, user_b)
    values (least(me, them), greatest(me, them))
    on conflict (user_a, user_b) do nothing;
  return them;
end;
$$;

-- Takes [other] out of your Crew (both ways). Their shared Shows disappear
-- from your feed and yours from theirs.
create or replace function public.leave_crew(other uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.crew_links
  where auth.uid() is not null
    and user_a = least(auth.uid(), other)
    and user_b = greatest(auth.uid(), other);
$$;

-- Blocks [other]: out of the Crew, and their invites stop working for you.
create or replace function public.block_crew(other uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
begin
  if me is null or other is null or other = me
     or not exists (select 1 from auth.users where id = other) then
    raise exception 'Can''t block that runner';
  end if;
  delete from public.crew_links
    where user_a = least(me, other) and user_b = greatest(me, other);
  insert into public.crew_blocks (blocker, blocked) values (me, other)
    on conflict do nothing;
end;
$$;

-- Undoes your own block. A block the other runner made stays.
create or replace function public.unblock_crew(other uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.crew_blocks
  where blocker = auth.uid() and blocked = other;
$$;

-- Your Crew, then the runners you blocked, with their profiles.
create or replace function public.my_crew()
returns table (user_id uuid, stage_name text, color smallint,
               opening_night date, tour_name text, since timestamptz,
               blocked boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select * from (
    select o.other, coalesce(p.stage_name, 'Runner'),
      coalesce(p.color, 0::smallint), p.opening_night, p.tour_name,
      l.created_at, false
    from public.crew_links l
    cross join lateral (
      select case when l.user_a = auth.uid() then l.user_b else l.user_a end
        as other
    ) o
    left join public.crew_profiles p on p.user_id = o.other
    where auth.uid() in (l.user_a, l.user_b)
      and not public.crew_blocked(l.user_a, l.user_b)
    union all
    select b.blocked, coalesce(p.stage_name, 'Runner'),
      coalesce(p.color, 0::smallint), null::date, null::text, b.created_at,
      true
    from public.crew_blocks b
    left join public.crew_profiles p on p.user_id = b.blocked
    where b.blocker = auth.uid()
  ) r (user_id, stage_name, color, opening_night, tour_name, since, blocked)
  order by blocked, stage_name;
$$;

do $$
declare
  f text;
begin
  -- Helpers the app never calls directly.
  foreach f in array array[
    'crew_check_misses()', 'crew_find_invite(text)'
  ] loop
    execute format(
      'revoke all on function public.%s from public, anon, authenticated', f
    );
  end loop;
  foreach f in array array[
    'crew_blocked(uuid, uuid)', 'is_crew(uuid)',
    'crew_invite_code()', 'crew_invite_preview(text)', 'join_crew(text)',
    'leave_crew(uuid)', 'block_crew(uuid)', 'unblock_crew(uuid)', 'my_crew()'
  ] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end;
$$;

-- ---- Shared Shows ----

create table if not exists public.crew_posts (
  id uuid primary key default gen_random_uuid(),
  owner uuid not null default auth.uid()
    references public.crew_profiles (user_id) on delete cascade,
  -- The Show's id on the owner's Setlist. One post per Show.
  show_id uuid not null,
  -- A snapshot of the Show: date, Studio Session or Live Show, miles, time,
  -- Song of the Show, Gold Records and (only if ticked) the notes.
  data jsonb not null check (octet_length(data::text) <= 8000),
  -- The Show's own updatedAt when this snapshot was taken, so the app can
  -- re-share it after an edit.
  show_updated_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner, show_id)
);

create index if not exists crew_posts_created_idx
  on public.crew_posts (created_at desc);

-- The server's clock decides when a Show was shared, so nobody can pin a
-- post to the top of the feed.
create or replace function public.crew_post_stamp()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.created_at := now();
  else
    new.created_at := old.created_at;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists crew_post_stamp on public.crew_posts;
create trigger crew_post_stamp
  before insert or update on public.crew_posts
  for each row execute function public.crew_post_stamp();

alter table public.crew_posts enable row level security;

drop policy if exists "crew posts: read" on public.crew_posts;
create policy "crew posts: read" on public.crew_posts
  for select to authenticated
  using (owner = (select auth.uid()) or public.is_crew(owner));

drop policy if exists "crew posts: add own" on public.crew_posts;
create policy "crew posts: add own" on public.crew_posts
  for insert to authenticated
  with check (owner = (select auth.uid()));

drop policy if exists "crew posts: change own" on public.crew_posts;
create policy "crew posts: change own" on public.crew_posts
  for update to authenticated
  using (owner = (select auth.uid()))
  with check (owner = (select auth.uid()));

drop policy if exists "crew posts: remove own" on public.crew_posts;
create policy "crew posts: remove own" on public.crew_posts
  for delete to authenticated
  using (owner = (select auth.uid()));

-- ---- Encores ----

create table if not exists public.crew_encores (
  post_id uuid not null references public.crew_posts (id) on delete cascade,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

alter table public.crew_encores enable row level security;

-- An Encore is visible on a post you can see, and only when it's yours, on
-- your own post, or from someone in your Crew. A friend of a friend stays
-- anonymous.
drop policy if exists "crew encores: read" on public.crew_encores;
create policy "crew encores: read" on public.crew_encores
  for select to authenticated
  using (
    exists (
      select 1 from public.crew_posts p
      where p.id = post_id
        and (
          crew_encores.user_id = (select auth.uid())
          or p.owner = (select auth.uid())
          or public.is_crew(crew_encores.user_id)
        )
    )
  );

drop policy if exists "crew encores: add own" on public.crew_encores;
create policy "crew encores: add own" on public.crew_encores
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.crew_posts p
      where p.id = post_id and p.owner <> (select auth.uid())
    )
  );

drop policy if exists "crew encores: remove own" on public.crew_encores;
create policy "crew encores: remove own" on public.crew_encores
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- ---- Reports ----

create table if not exists public.crew_reports (
  id uuid primary key default gen_random_uuid(),
  reporter uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  -- Kept if the post is later unshared, so the report still makes sense.
  post_id uuid not null,
  reported_user uuid not null references auth.users (id) on delete cascade,
  -- Filled in by the server from the post itself.
  post_data jsonb not null default '{}'::jsonb,
  reason text not null check (char_length(reason) between 1 and 500),
  created_at timestamptz not null default now()
);

alter table public.crew_reports enable row level security;

-- Your own reports only, so the app can hide what you reported.
drop policy if exists "crew reports: read own" on public.crew_reports;
create policy "crew reports: read own" on public.crew_reports
  for select to authenticated
  using (reporter = (select auth.uid()));

drop policy if exists "crew reports: add" on public.crew_reports;
create policy "crew reports: add" on public.crew_reports
  for insert to authenticated
  with check (
    reporter = (select auth.uid())
    and exists (
      select 1 from public.crew_posts p
      where p.id = post_id and p.owner = reported_user
        and p.owner <> (select auth.uid())
    )
  );

-- Copies the reported Show into the report, so it can't be made up.
create or replace function public.crew_report_snapshot()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  select p.data into new.post_data from public.crew_posts p
    where p.id = new.post_id;
  new.reporter := auth.uid();
  new.created_at := now();
  return new;
end;
$$;

drop trigger if exists crew_report_snapshot on public.crew_reports;
create trigger crew_report_snapshot
  before insert on public.crew_reports
  for each row execute function public.crew_report_snapshot();
