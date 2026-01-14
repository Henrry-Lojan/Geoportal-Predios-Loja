-- FUNCIÓN RPC: obtener_reporte_predio (VERSIÓN 4.0 - CERTIFICADO COMPLETO)
-- Incluye campos detallados como PIT, Categoría, Subclasificación y Material de tubería.

create or replace function obtener_reporte_predio(clave_catastral text)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    v_clave_limpia text;
    v_predio record;
    v_normativa record;
    v_riesgos record;
    v_patrimonio record;
    v_ubicacion record;
    v_vias json;
    v_agua json;
    result json;
begin
    -- 0. Limpieza de input
    v_clave_limpia := trim(clave_catastral);

    -- 1. BUSCAR PREDIO
    select clave_cata, parroquia as parroquia_cod, barrio as barrio_cod, 
           area_grafi, area_gim, 
           st_asgeojson(geometry)::json as geometry, geometry as geom
    into v_predio
    from predios_urbanos
    where trim(clave_cata) ilike v_clave_limpia;

    if not found then
        -- Intento de rescate con búsqueda parcial
        select clave_cata, parroquia as parroquia_cod, barrio as barrio_cod, 
               area_grafi, area_gim, 
               st_asgeojson(geometry)::json as geometry, geometry as geom
        into v_predio
        from predios_urbanos
        where clave_cata ilike '%' || v_clave_limpia || '%'
        limit 1;
        
        if not found then return null; end if;
    end if;

    -- 2. UBICACIÓN REAL
    begin
        select parroquia as nombre_parroquia, barrio as nombre_barrio, poblacion, densidad
        into v_ubicacion
        from limites_barriales
        where st_intersects(geometry, st_centroid(v_predio.geom))
        limit 1;
    exception when others then v_ubicacion := null; end;

    -- 3. NORMATIVA Y USO DE SUELO (Extendida)
    begin
        select 
            clasificacion, subclasificacion, categoria, pit,
            uso_principal, uso_general, uso_prohibido,
            n_pisos, cos, cus,
            retiro_fron, retiro_lat, retiro_pos,
            lote_min, frente_min
        into v_normativa
        from clasificacion_suelo
        where st_intersects(geometry, st_centroid(v_predio.geom))
        limit 1;
    exception when others then v_normativa := null; end;

    -- 4. RIESGOS
    begin
        select aptitud, amenazas, estudios
        into v_riesgos
        from aptitud_constructiva
        where st_intersects(geometry, st_centroid(v_predio.geom))
        limit 1;
    exception when others then v_riesgos := null; end;

    -- 5. PATRIMONIO
    begin
        select zona, descripcio as descripcion
        into v_patrimonio
        from zonas_patrimoniales
        where st_intersects(geometry, v_predio.geom)
        limit 1;
    exception when others then v_patrimonio := null; end;

    -- 6. VIALIDAD
    begin
        select json_agg(row_to_json(t))
        into v_vias
        from (
            select nombre, jerarquia, dim_total as ancho_total, dim_via as ancho_calzada,
                   st_distance(geometry::geography, v_predio.geom::geography) as distancia_m
            from vialidad
            where st_dwithin(geometry::geography, v_predio.geom::geography, 30)
            order by distancia_m asc
            limit 3
        ) t;
    exception when others then v_vias := '[]'::json; end;

    -- 7. AGUA POTABLE (Con detalles)
    begin
        select row_to_json(t)
        into v_agua
        from (
            select material, d as diametro, true as tiene_red,
                   st_distance(geometry::geography, v_predio.geom::geography) as distancia_m
            from red_tuberias
            where st_dwithin(geometry::geography, v_predio.geom::geography, 50)
            order by distancia_m asc
            limit 1
        ) t;
    exception when others then v_agua := null; end;

    if v_agua is null then v_agua := '{"tiene_red": false}'::json; end if;

    -- CONSTRUCCIÓN DEL REPORTE FINAL
    result := json_build_object(
        'info_predio', json_build_object(
            'clave', v_predio.clave_cata,
            'area_escritura', coalesce(v_predio.area_grafi, 0),
            'geometry', v_predio.geometry
        ),
        'ubicacion', row_to_json(v_ubicacion),
        'normativa', row_to_json(v_normativa),
        'riesgos', row_to_json(v_riesgos),
        'patrimonio', row_to_json(v_patrimonio),
        'vias', coalesce(v_vias, '[]'::json),
        'agua_potable', v_agua
    );

    return result;
end;
$$;

-- Permisos
grant execute on function obtener_reporte_predio(text) to anon;
grant execute on function obtener_reporte_predio(text) to authenticated;
grant execute on function obtener_reporte_predio(text) to service_role;
