-- Enable pgvector extension for embedding-based similarity search
create extension if not exists vector with schema extensions;

-- ────────────────────────────────────────────────────────────────────────────
-- Table: navigation_events
-- Stores every page-to-page transition by anonymous users (session-based).
-- ────────────────────────────────────────────────────────────────────────────
create table if not exists public.navigation_events (
  id            bigint generated always as identity primary key,
  session_id    text          not null,
  from_route    text          not null,
  to_route      text          not null,
  from_screen   text          not null,  -- human-readable name
  to_screen     text          not null,
  created_at    timestamptz   not null default now()
);

-- Fast lookup for aggregation queries
create index idx_nav_events_from_route on public.navigation_events (from_route);
create index idx_nav_events_created    on public.navigation_events (created_at);

-- ────────────────────────────────────────────────────────────────────────────
-- Table: route_transition_stats
-- Materialized aggregate: how many users went from route A → B.
-- Re-computed periodically or via trigger.
-- ────────────────────────────────────────────────────────────────────────────
create table if not exists public.route_transition_stats (
  id            bigint generated always as identity primary key,
  from_route    text    not null,
  to_route      text    not null,
  to_screen     text    not null,
  transition_count  int not null default 0,
  unique (from_route, to_route)
);

create index idx_rts_from_route on public.route_transition_stats (from_route);

-- ────────────────────────────────────────────────────────────────────────────
-- Table: route_embeddings
-- Stores a vector embedding per route so similar pages can be grouped.
-- Uses 8-dimensional embedding encoding route features:
--   [is_dashboard, is_plant, is_inverter, is_sensor, is_alert,
--    is_export, is_slms, depth_level]
-- ────────────────────────────────────────────────────────────────────────────
create table if not exists public.route_embeddings (
  id        bigint generated always as identity primary key,
  route     text                  not null unique,
  screen    text                  not null,
  embedding extensions.vector(8)  not null
);

create index idx_route_emb on public.route_embeddings
  using ivfflat (embedding extensions.vector_cosine_ops) with (lists = 4);

-- ────────────────────────────────────────────────────────────────────────────
-- Function: refresh_transition_stats()
-- Recomputes the aggregate stats from raw navigation events.
-- ────────────────────────────────────────────────────────────────────────────
create or replace function public.refresh_transition_stats()
returns void
language plpgsql
security definer
as $$
begin
  -- Upsert aggregated counts
  insert into public.route_transition_stats (from_route, to_route, to_screen, transition_count)
  select
    from_route,
    to_route,
    (array_agg(to_screen order by created_at desc))[1] as to_screen,
    count(*) as transition_count
  from public.navigation_events
  where created_at > now() - interval '30 days'  -- rolling 30-day window
  group by from_route, to_route
  on conflict (from_route, to_route)
  do update set
    transition_count = excluded.transition_count,
    to_screen = excluded.to_screen;
end;
$$;

-- ────────────────────────────────────────────────────────────────────────────
-- Function: get_crowd_suggestions(p_route text, p_limit int)
-- Returns the most popular next routes from p_route, ranked by count.
-- Also includes similar-route suggestions via pgvector cosine similarity.
-- ────────────────────────────────────────────────────────────────────────────
create or replace function public.get_crowd_suggestions(
  p_route   text,
  p_limit   int default 5
)
returns table (
  to_route          text,
  to_screen         text,
  transition_count  int,
  similarity_score  double precision
)
language plpgsql
security definer
as $$
declare
  v_embedding extensions.vector(8);
begin
  -- Get embedding for current route
  select re.embedding into v_embedding
  from public.route_embeddings re
  where re.route = p_route
  limit 1;

  -- Direct transition suggestions (exact match)
  return query
  select
    rts.to_route,
    rts.to_screen,
    rts.transition_count,
    case
      when v_embedding is not null and re2.embedding is not null
      then 1.0 - (v_embedding <=> re2.embedding)::double precision
      else 0.5
    end as similarity_score
  from public.route_transition_stats rts
  left join public.route_embeddings re2 on re2.route = rts.to_route
  where rts.from_route = p_route
    and rts.transition_count >= 2   -- minimum threshold
  order by rts.transition_count desc, similarity_score desc
  limit p_limit;
end;
$$;

-- ────────────────────────────────────────────────────────────────────────────
-- Function: get_similar_route_suggestions(p_route text, p_limit int)
-- Uses pgvector cosine similarity to find similar routes and their
-- most popular outgoing transitions.
-- ────────────────────────────────────────────────────────────────────────────
create or replace function public.get_similar_route_suggestions(
  p_route   text,
  p_limit   int default 3
)
returns table (
  similar_route     text,
  to_route          text,
  to_screen         text,
  transition_count  int,
  cosine_similarity double precision
)
language plpgsql
security definer
as $$
declare
  v_embedding extensions.vector(8);
begin
  select re.embedding into v_embedding
  from public.route_embeddings re
  where re.route = p_route
  limit 1;

  if v_embedding is null then
    return;
  end if;

  return query
  select
    re.route as similar_route,
    rts.to_route,
    rts.to_screen,
    rts.transition_count,
    (1.0 - (v_embedding <=> re.embedding))::double precision as cosine_similarity
  from public.route_embeddings re
  inner join public.route_transition_stats rts on rts.from_route = re.route
  where re.route != p_route
    and (1.0 - (v_embedding <=> re.embedding)) > 0.7  -- similarity threshold
  order by cosine_similarity desc, rts.transition_count desc
  limit p_limit;
end;
$$;

-- ────────────────────────────────────────────────────────────────────────────
-- Seed well-known route embeddings
-- Encoding: [dashboard, plant, inverter, sensor, alert, export, slms, depth]
-- depth: 0 = top-level, 0.5 = list, 1.0 = detail
-- ────────────────────────────────────────────────────────────────────────────
insert into public.route_embeddings (route, screen, embedding) values
  ('/dashboard',    'Dashboard',          '[1,0,0,0,0,0,0,0]'),
  ('/my-plants',    'My Plants',          '[0,1,0,0,0,0,0,0.25]'),
  ('/inverters',    'Inverters',          '[0,0,1,0,0,0,0,0.25]'),
  ('/sensors',      'Sensors',            '[0,0,0,1,0,0,0,0.25]'),
  ('/alerts',       'Alerts',             '[0,0,0,0,1,0,0,0.25]'),
  ('/exports',      'Exports',            '[0,0,0,0,0,1,0,0.25]'),
  ('/slms',         'SLMS Devices',       '[0,0,0,0,0,0,1,0.25]'),
  -- Detail-level pages
  ('/plants/:id',               'Plant Detail',       '[0,1,0,0,0,0,0,0.5]'),
  ('/plants/:id/inverters/:id', 'Inverter Detail',    '[0,1,1,0,0,0,0,1]'),
  ('/plants/:id/mfm/:id',      'MFM Detail',         '[0,1,0,1,0,0,0,1]'),
  ('/plants/:id/temp/:id',     'Temperature Detail',  '[0,1,0,1,0,0,0,1]'),
  ('/slms/:id',                'SLMS Detail',         '[0,0,0,0,0,0,1,0.5]')
on conflict (route) do nothing;

-- ────────────────────────────────────────────────────────────────────────────
-- Seed crowd navigation data — realistic transition patterns based on
-- typical solar plant monitoring workflows. This bootstraps the system
-- so suggestions appear immediately for new users.
-- ────────────────────────────────────────────────────────────────────────────
insert into public.route_transition_stats (from_route, to_route, to_screen, transition_count) values
  -- From Dashboard: most users check inverters or plants next
  ('/dashboard', '/inverters',    'Inverters',    42),
  ('/dashboard', '/my-plants',    'My Plants',    38),
  ('/dashboard', '/alerts',       'Alerts',       25),
  ('/dashboard', '/sensors',      'Sensors',      15),
  ('/dashboard', '/exports',      'Exports',       5),

  -- From My Plants: users check inverters, sensors, or go back to dashboard
  ('/my-plants', '/inverters',    'Inverters',    50),
  ('/my-plants', '/dashboard',    'Dashboard',    12),
  ('/my-plants', '/sensors',      'Sensors',      10),
  ('/my-plants', '/alerts',       'Alerts',        8),

  -- From Plant Detail: users check inverters, sensors, or alerts
  ('/plants/:id', '/inverters',   'Inverters',    55),
  ('/plants/:id', '/sensors',     'Sensors',      20),
  ('/plants/:id', '/alerts',      'Alerts',       15),
  ('/plants/:id', '/my-plants',   'My Plants',     8),
  ('/plants/:id', '/exports',     'Exports',       5),

  -- From Inverter Detail: SLMS deep-dive, alerts, or sensors
  ('/plants/:id/inverters/:id', '/slms',       'SLMS Devices',   35),
  ('/plants/:id/inverters/:id', '/alerts',     'Alerts',         28),
  ('/plants/:id/inverters/:id', '/my-plants',  'My Plants',      20),
  ('/plants/:id/inverters/:id', '/sensors',    'Sensors',        12),
  ('/plants/:id/inverters/:id', '/exports',    'Exports',         8),

  -- From Inverters list: check dashboard, SLMS, or alerts
  ('/inverters', '/my-plants',    'My Plants',     45),
  ('/inverters', '/dashboard',    'Dashboard',     18),
  ('/inverters', '/slms',         'SLMS Devices',  15),
  ('/inverters', '/alerts',       'Alerts',        10),
  ('/inverters', '/sensors',      'Sensors',        8),

  -- From Sensors: check inverters, alerts, or export
  ('/sensors', '/inverters',      'Inverters',     30),
  ('/sensors', '/alerts',         'Alerts',        25),
  ('/sensors', '/my-plants',      'My Plants',     18),
  ('/sensors', '/exports',        'Exports',       12),
  ('/sensors', '/dashboard',      'Dashboard',      8),

  -- From MFM Detail: check inverters, export, or alerts
  ('/plants/:id/mfm/:id', '/inverters',   'Inverters',  22),
  ('/plants/:id/mfm/:id', '/exports',     'Exports',    15),
  ('/plants/:id/mfm/:id', '/alerts',      'Alerts',     10),
  ('/plants/:id/mfm/:id', '/sensors',     'Sensors',     8),

  -- From Temperature Detail: check plants, alerts, or inverters
  ('/plants/:id/temp/:id', '/my-plants',   'My Plants',   25),
  ('/plants/:id/temp/:id', '/alerts',      'Alerts',      18),
  ('/plants/:id/temp/:id', '/inverters',   'Inverters',   12),
  ('/plants/:id/temp/:id', '/sensors',     'Sensors',      8),

  -- From Alerts: investigate with inverters or sensors
  ('/alerts', '/inverters',    'Inverters',    35),
  ('/alerts', '/sensors',      'Sensors',      22),
  ('/alerts', '/dashboard',    'Dashboard',    15),
  ('/alerts', '/my-plants',    'My Plants',     8),

  -- From SLMS list: check inverters or dashboard
  ('/slms', '/inverters',   'Inverters',    40),
  ('/slms', '/my-plants',   'My Plants',    20),
  ('/slms', '/dashboard',   'Dashboard',     8),
  ('/slms', '/alerts',      'Alerts',        6),

  -- From SLMS Detail: compare with inverters or back to list
  ('/slms/:id', '/inverters',  'Inverters',    28),
  ('/slms/:id', '/slms',       'SLMS Devices', 15),
  ('/slms/:id', '/alerts',     'Alerts',       10),

  -- From Exports: navigate to data source pages
  ('/exports', '/inverters',  'Inverters',  25),
  ('/exports', '/sensors',    'Sensors',    18),
  ('/exports', '/dashboard',  'Dashboard',  10),
  ('/exports', '/my-plants',  'My Plants',   7)
on conflict (from_route, to_route) do update set
  transition_count = excluded.transition_count;

-- Row-Level Security (allow inserts from anonymous/authenticated users)
alter table public.navigation_events enable row level security;
create policy "Anyone can insert navigation events"
  on public.navigation_events for insert
  with check (true);
create policy "Anyone can read navigation events"
  on public.navigation_events for select
  using (true);

alter table public.route_transition_stats enable row level security;
create policy "Anyone can read transition stats"
  on public.route_transition_stats for select
  using (true);

alter table public.route_embeddings enable row level security;
create policy "Anyone can read route embeddings"
  on public.route_embeddings for select
  using (true);
create policy "Anyone can insert route embeddings"
  on public.route_embeddings for insert
  with check (true);

-- ────────────────────────────────────────────────────────────────────────────
-- Grant table-level permissions to anon and authenticated roles
-- (RLS only controls row-level access; GRANTs control table-level access)
-- ────────────────────────────────────────────────────────────────────────────
grant usage on schema extensions to anon, authenticated;
grant insert, select on public.navigation_events to anon, authenticated;
grant select, insert, update on public.route_transition_stats to anon, authenticated;
grant select, insert on public.route_embeddings to anon, authenticated;
grant execute on function public.refresh_transition_stats() to anon, authenticated;
grant execute on function public.get_crowd_suggestions(text, int) to anon, authenticated;
grant execute on function public.get_similar_route_suggestions(text, int) to anon, authenticated;
