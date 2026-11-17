-- VOLL community maps + name filter.
-- Run this once in Supabase: SQL Editor -> New query -> paste -> Run.
-- Safe to run again. Requires leaderboard.sql to have been run first.

-- Name filter: same rules as godot/scenes/game/name_filter.gd. Lowercases,
-- undoes leetspeak, drops non-letters, then looks for blocked words; short
-- words are only blocked as whole words so names like "Classic" stay allowed.
create or replace function public.voll_name_ok(p_name text)
returns boolean
language plpgsql
immutable
set search_path = public, extensions
as $$
declare
	v_lower text := lower(coalesce(p_name, ''));
	v_letters text;
	v_squashed text;
	v_term text;
	v_word text;
	v_anywhere text[] := array['fuck', 'shit', 'bitch', 'cunt', 'nigger', 'nigga', 'faggot', 'retard',
		'whore', 'slut', 'pussy', 'penis', 'vagina', 'nazi', 'hitler', 'porn', 'kike', 'wank', 'twat',
		'dildo', 'jizz', 'molest', 'pedophil', 'asshole', 'dickhead', 'bastard', 'chink', 'tranny', 'kkk', 'rapist'];
	v_whole text[] := array['ass', 'dick', 'cock', 'rape', 'sex', 'cum', 'tits', 'spic', 'fag', 'pedo', 'anal', 'coon', 'hoe'];
begin
	v_letters := regexp_replace(translate(v_lower, '01!34@5$789', 'oiieaasstbg'), '[^a-z]', '', 'g');
	v_squashed := regexp_replace(v_letters, '(.)\1+', '\1', 'g');
	foreach v_term in array v_anywhere loop
		if position(v_term in v_letters) > 0 then
			return false;
		end if;
		if v_term = regexp_replace(v_term, '(.)\1+', '\1', 'g') and position(v_term in v_squashed) > 0 then
			return false;
		end if;
	end loop;
	foreach v_word in array regexp_split_to_array(v_lower, '[^a-z]+') loop
		if v_word = any(v_whole) or regexp_replace(v_word, '(.)\1+', '\1', 'g') = any(v_whole) then
			return false;
		end if;
	end loop;
	return true;
end;
$$;

-- Registration now refuses offensive names.
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
	if not voll_name_ok(p_username) then
		raise exception 'rude_name';
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

create table if not exists public.voll_maps (
	id uuid primary key default gen_random_uuid(),
	owner uuid not null references public.voll_players (id) on delete cascade,
	name text not null check (char_length(name) between 1 and 24),
	map jsonb not null,
	object_count integer not null default 0,
	plays integer not null default 0,
	created_at timestamptz not null default now(),
	updated_at timestamptz not null default now()
);

create unique index if not exists voll_maps_owner_name_idx on public.voll_maps (owner, lower(name));
create index if not exists voll_maps_new_idx on public.voll_maps (updated_at desc);
create index if not exists voll_maps_plays_idx on public.voll_maps (plays desc);

alter table public.voll_maps enable row level security;
revoke all on public.voll_maps from public;

create or replace function public.voll_publish_map(p_token uuid, p_name text, p_map jsonb)
returns json
language plpgsql
volatile
security definer
set search_path = public, extensions
as $$
declare
	v_owner uuid;
	v_map_id uuid;
	v_count integer;
begin
	select player_id into v_owner from voll_sessions where token = p_token;
	if v_owner is null then
		raise exception 'bad_token';
	end if;
	p_name := trim(coalesce(p_name, ''));
	if char_length(p_name) not between 1 and 24 then
		raise exception 'bad_map_name';
	end if;
	if not voll_name_ok(p_name) then
		raise exception 'rude_name';
	end if;
	if p_map is null or jsonb_typeof(p_map) <> 'object' or jsonb_typeof(p_map -> 'objects') <> 'array'
		or jsonb_array_length(p_map -> 'objects') not between 2 and 600 or octet_length(p_map::text) > 65536 then
		raise exception 'bad_map';
	end if;
	select count(*) into v_count from voll_maps where owner = v_owner and lower(name) <> lower(p_name);
	if v_count >= 25 then
		raise exception 'too_many_maps';
	end if;
	insert into voll_maps (owner, name, map, object_count)
	values (v_owner, p_name, p_map, jsonb_array_length(p_map -> 'objects'))
	on conflict (owner, lower(name)) do update
		set name = excluded.name, map = excluded.map, object_count = excluded.object_count, updated_at = now()
	returning id into v_map_id;
	return json_build_object('id', v_map_id);
end;
$$;

create or replace function public.voll_list_maps(p_sort text default 'new', p_limit integer default 60)
returns table (id uuid, name text, author text, plays integer, object_count integer, updated_at timestamptz)
language sql
stable
security definer
set search_path = public, extensions
as $$
	select m.id, m.name, p.username, m.plays, m.object_count, m.updated_at
	from voll_maps m
	join voll_players p on p.id = m.owner
	order by case when p_sort = 'popular' then m.plays end desc nulls last, m.updated_at desc
	limit least(greatest(coalesce(p_limit, 60), 1), 100);
$$;

create or replace function public.voll_get_map(p_id uuid)
returns json
language plpgsql
volatile
security definer
set search_path = public, extensions
as $$
declare
	v_result json;
begin
	update voll_maps set plays = plays + 1 where id = p_id;
	select json_build_object('id', m.id, 'name', m.name, 'author', p.username, 'map', m.map)
	into v_result
	from voll_maps m join voll_players p on p.id = m.owner
	where m.id = p_id;
	if v_result is null then
		raise exception 'no_map';
	end if;
	return v_result;
end;
$$;

create or replace function public.voll_delete_map(p_token uuid, p_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = public, extensions
as $$
declare
	v_owner uuid;
begin
	select player_id into v_owner from voll_sessions where token = p_token;
	if v_owner is null then
		raise exception 'bad_token';
	end if;
	delete from voll_maps where id = p_id and owner = v_owner;
end;
$$;

revoke all on function public.voll_name_ok(text) from public;
revoke all on function public.voll_register(text, text) from public;
revoke all on function public.voll_publish_map(uuid, text, jsonb) from public;
revoke all on function public.voll_list_maps(text, integer) from public;
revoke all on function public.voll_get_map(uuid) from public;
revoke all on function public.voll_delete_map(uuid, uuid) from public;

do $$
begin
	if exists (select 1 from pg_roles where rolname = 'anon') then
		revoke all on public.voll_maps from anon, authenticated;
		revoke all on function public.voll_name_ok(text) from anon, authenticated;
		grant execute on function public.voll_register(text, text) to anon, authenticated;
		grant execute on function public.voll_publish_map(uuid, text, jsonb) to anon, authenticated;
		grant execute on function public.voll_list_maps(text, integer) to anon, authenticated;
		grant execute on function public.voll_get_map(uuid) to anon, authenticated;
		grant execute on function public.voll_delete_map(uuid, uuid) to anon, authenticated;
	end if;
end;
$$;

notify pgrst, 'reload schema';
