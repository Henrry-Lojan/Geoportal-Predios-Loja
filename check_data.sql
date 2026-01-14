-- Ver qué tiene la tabla limites_barriales para sacar el nombre de la parroquia
SELECT parroquia, barrio FROM limites_barriales LIMIT 5;

-- Ver qué tienen las columnas de uso en clasificacion_suelo
SELECT uso_general, uso_principal, subclasificacion FROM clasificacion_suelo LIMIT 5;
