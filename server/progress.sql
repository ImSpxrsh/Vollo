-- VOLL account progress sync (coins, upgrades, varieties, awards, stats).
-- Run this once in Supabase: SQL Editor -> New query -> paste -> Run.
-- Safe to run again. Requires leaderboard.sql to have been run first.

alter table public.voll_players add column if not exists progress jsonb not null default '{}'::jsonb;
alter table public.voll_players add column if not exists progress_at timestamptz;

create or replace function public.voll_get_progress(p_token uuid)
returns json
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
	v_id uuid;
	v_progress jsonb;
begin
	select player_id into v_id from voll_sessions where token = p_token;
	if v_id is null then
		raise exception 'bad_token';
	end if;
	select progress into v_progress from voll_players where id = v_id;
	return coalesce(v_progress, '{}'::jsonb)::json;
end;
$$;

create or replace function public.voll_put_progress(p_token uuid, p_progress jsonb)
returns json
language plpgsql
volatile
security definer
set search_path = public, extensions
as $$
declare
	v_id uuid;
begin
	select player_id into v_id from voll_sessions where token = p_token;
	if v_id is null then
		raise exception 'bad_token';
	end if;
	if p_progress is null or jsonb_typeof(p_progress) <> 'object' or octet_length(p_progress::text) > 16384 then
		raise exception 'bad_progress';
	end if;
	update voll_players set progress = p_progress, progress_at = now() where id = v_id;
	return json_build_object('saved', true);
end;
$$;

revoke all on function public.voll_get_progress(uuid) from public;
revoke all on function public.voll_put_progress(uuid, jsonb) from public;

do $$
begin
	if exists (select 1 from pg_roles where rolname = 'anon') then
		grant execute on function public.voll_get_progress(uuid) to anon, authenticated;
		grant execute on function public.voll_put_progress(uuid, jsonb) to anon, authenticated;
	end if;
end;
$$;

notify pgrst, 'reload schema';
