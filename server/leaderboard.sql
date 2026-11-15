create extension if not exists pgcrypto;

create table if not exists public.voll_players (
	id uuid primary key default gen_random_uuid(),
	username text not null check (username ~ '^[A-Za-z0-9_]{3,16}$'),
	pass_hash text not null,
	best integer not null default 0,
	variety text not null default 'yellow',
	best_at timestamptz,
	created_at timestamptz not null default now()
);

create unique index if not exists voll_players_name_idx on public.voll_players (lower(username));
create index if not exists voll_players_best_idx on public.voll_players (best desc, best_at asc);

create table if not exists public.voll_sessions (
	token uuid primary key default gen_random_uuid(),
	player_id uuid not null references public.voll_players (id) on delete cascade,
	created_at timestamptz not null default now()
);

alter table public.voll_players enable row level security;
alter table public.voll_sessions enable row level security;
revoke all on public.voll_players from public;
revoke all on public.voll_sessions from public;

create or replace function public.voll_rank_of(p_best integer)
returns integer
language sql
stable
security definer
set search_path = public, extensions
as $$
	select (count(*) + 1)::integer from voll_players where best > p_best;
$$;

create or replace function public.voll_profile(p_player uuid, p_token uuid)
returns json
language sql
stable
security definer
set search_path = public, extensions
as $$
	select json_build_object(
		'token', p_token,
		'username', username,
		'best', best,
		'variety', variety,
		'rank', case when best > 0 then voll_rank_of(best) else null end
	)
	from voll_players where id = p_player;
$$;

create or replace function public.voll_register(p_username text, p_password text)
returns json
language plpgsql
volatile
security definer
set search_path = public, extensions
as $$
declare
	v_id uuid;
	v_token uuid;
begin
	p_username := trim(p_username);
	if p_username !~ '^[A-Za-z0-9_]{3,16}$' then
		raise exception 'bad_name';
	end if;
	if length(coalesce(p_password, '')) < 4 then
		raise exception 'short_password';
	end if;
	if exists (select 1 from voll_players where lower(username) = lower(p_username)) then
		raise exception 'name_taken';
	end if;
	insert into voll_players (username, pass_hash)
	values (p_username, crypt(p_password, gen_salt('bf')))
	returning id into v_id;
	insert into voll_sessions (player_id) values (v_id) returning token into v_token;
	return voll_profile(v_id, v_token);
end;
$$;

create or replace function public.voll_login(p_username text, p_password text)
returns json
language plpgsql
volatile
security definer
set search_path = public, extensions
as $$
declare
	v_id uuid;
	v_hash text;
	v_token uuid;
begin
	select id, pass_hash into v_id, v_hash from voll_players where lower(username) = lower(trim(p_username));
	if v_id is null or v_hash <> crypt(coalesce(p_password, ''), v_hash) then
		raise exception 'bad_login';
	end if;
	delete from voll_sessions where player_id = v_id and created_at < now() - interval '90 days';
	insert into voll_sessions (player_id) values (v_id) returning token into v_token;
	return voll_profile(v_id, v_token);
end;
$$;

create or replace function public.voll_me(p_token uuid)
returns json
language plpgsql
stable
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
	return voll_profile(v_id, p_token);
end;
$$;

create or replace function public.voll_submit(p_token uuid, p_score integer, p_variety text default 'yellow')
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
	if p_score is null or p_score < 0 or p_score > 100000 then
		raise exception 'bad_score';
	end if;
	update voll_players
	set best = p_score,
		best_at = now(),
		variety = coalesce(nullif(left(p_variety, 24), ''), 'yellow')
	where id = v_id and p_score > best;
	return voll_profile(v_id, p_token);
end;
$$;

create or replace function public.voll_logout(p_token uuid)
returns void
language sql
volatile
security definer
set search_path = public, extensions
as $$
	delete from voll_sessions where token = p_token;
$$;

create or replace function public.voll_top(p_limit integer default 20)
returns table (rank integer, username text, best integer, variety text)
language sql
stable
security definer
set search_path = public, extensions
as $$
	select (rank() over (order by best desc))::integer, username, best, variety
	from voll_players
	where best > 0
	order by best desc, best_at asc
	limit least(greatest(coalesce(p_limit, 20), 1), 100);
$$;

revoke all on function public.voll_rank_of(integer) from public;
revoke all on function public.voll_profile(uuid, uuid) from public;
revoke all on function public.voll_register(text, text) from public;
revoke all on function public.voll_login(text, text) from public;
revoke all on function public.voll_me(uuid) from public;
revoke all on function public.voll_submit(uuid, integer, text) from public;
revoke all on function public.voll_logout(uuid) from public;
revoke all on function public.voll_top(integer) from public;

do $$
begin
	if exists (select 1 from pg_roles where rolname = 'anon') then
		revoke all on public.voll_players from anon, authenticated;
		revoke all on public.voll_sessions from anon, authenticated;
		revoke all on function public.voll_rank_of(integer) from anon, authenticated;
		revoke all on function public.voll_profile(uuid, uuid) from anon, authenticated;
		grant execute on function public.voll_register(text, text) to anon, authenticated;
		grant execute on function public.voll_login(text, text) to anon, authenticated;
		grant execute on function public.voll_me(uuid) to anon, authenticated;
		grant execute on function public.voll_submit(uuid, integer, text) to anon, authenticated;
		grant execute on function public.voll_logout(uuid) to anon, authenticated;
		grant execute on function public.voll_top(integer) to anon, authenticated;
	end if;
end;
$$;
