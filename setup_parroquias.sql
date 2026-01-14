-- Función para obtener los límites de las parroquias (agrupando barrios si es necesario)
-- Devuelve GeoJSON válido para Leaflet

create or replace function obtener_capa_parroquias()
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    result json;
begin
    select json_build_object(
        'type', 'FeatureCollection',
        'features', json_agg(
            json_build_object(
                'type', 'Feature',
                'properties', json_build_object(
                    'parroquia', parroquia,
                    'barrio', barrio
                ),
                'geometry', st_asgeojson(geometry)::json
            )
        )
    )
    into result
    from limites_barriales;

    return result;
end;
$$;

grant execute on function obtener_capa_parroquias() to anon;
grant execute on function obtener_capa_parroquias() to authenticated;
