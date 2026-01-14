SELECT clave_cata, parroquia, barrio 
FROM predios_urbanos 
LIMIT 5;

SELECT count(*) as total_predios FROM predios_urbanos;

SELECT clave_cata FROM predios_urbanos WHERE clave_cata LIKE '%1101040105084004%';
