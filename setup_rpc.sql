-- RPC: get_predios_in_view
-- Returns properties within a bounding box, optionally filtered by barrio names.

create or replace function get_predios_in_view(
  min_lon float,
  min_lat float,
  max_lon float,
  max_lat float,
  barrios_names text[] default null
)
returns table (
  clave_cata text,
  geometry json
)
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  return query
  with view_box as (
    select st_makeenvelope(min_lon, min_lat, max_lon, max_lat, 4326) as geom
  )
  select 
    p.clave_cata,
    st_asgeojson(p.geometry)::json
  from predios_urbanos p
  join view_box vb on st_intersects(p.geometry, vb.geom)
  where
    (barrios_names is null or cardinality(barrios_names) = 0 or exists (
      select 1 from limites_barriales lb
      where lb.barrio = any(barrios_names)
      and st_intersects(p.geometry, lb.geometry)
    ))
  limit 2000;
end;
$$;

grant execute on function get_predios_in_view(float, float, float, float, text[]) to anon;
grant execute on function get_predios_in_view(float, float, float, float, text[]) to authenticated;
