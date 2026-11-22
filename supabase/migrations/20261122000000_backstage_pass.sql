-- Backstage Pass: one table per synced record type.
--
-- Paste this whole file into Supabase > SQL Editor > New query > Run.
-- It is safe to run more than once.
--
-- Every table has the same shape. `data` holds the record's JSON exactly as
-- the app saves it on the device. Row Level Security limits each runner to
-- their own rows.

create or replace function public.sync_stamp()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    -- An older copy never overwrites a newer edit: keep the stored row.
    if new.updated_at < old.updated_at then
      return null;
    end if;
    new.user_id := old.user_id;
  else
    new.user_id := auth.uid();
  end if;
  -- The server's own clock decides what "new since last pull" means.
  new.synced_at := clock_timestamp();
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array['shows', 'gear', 'saved_mixes', 'tours'] loop
    execute format($f$
      create table if not exists public.%1$I (
        id uuid primary key,
        user_id uuid not null default auth.uid()
          references auth.users (id) on delete cascade,
        data jsonb not null,
        updated_at timestamptz not null,
        deleted_at timestamptz,
        synced_at timestamptz not null default clock_timestamp()
      );

      create index if not exists %1$s_user_synced_idx
        on public.%1$I (user_id, synced_at, id);

      alter table public.%1$I enable row level security;

      drop policy if exists "own rows: read" on public.%1$I;
      create policy "own rows: read" on public.%1$I
        for select to authenticated
        using ((select auth.uid()) = user_id);

      drop policy if exists "own rows: add" on public.%1$I;
      create policy "own rows: add" on public.%1$I
        for insert to authenticated
        with check ((select auth.uid()) = user_id);

      drop policy if exists "own rows: change" on public.%1$I;
      create policy "own rows: change" on public.%1$I
        for update to authenticated
        using ((select auth.uid()) = user_id)
        with check ((select auth.uid()) = user_id);

      drop trigger if exists sync_stamp on public.%1$I;
      create trigger sync_stamp
        before insert or update on public.%1$I
        for each row execute function public.sync_stamp();
    $f$, t);
  end loop;
end;
$$;

-- Records are soft-deleted (deleted_at) so the removal reaches every device,
-- so there is no delete policy: rows go away only with the account.

-- "Delete account" in Backstage. Removing the auth user cascades to every
-- synced row above.
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
