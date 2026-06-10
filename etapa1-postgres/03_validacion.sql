-- =============================================================================
-- Trabajo Práctico - Introducción a Bases de Datos
-- Etapa 1.3 (parte 2) - Validación de consistencia de los datos cargados
--
-- Este script NO modifica datos: solo consulta. Se ejecuta después de
-- 01_schema.sql y 02_seed.sql para confirmar que la carga quedó coherente
-- y para mostrar estadísticos descriptivos básicos de la base.
--
-- Está dividido en dos bloques:
--   A) Chequeos de integridad  -> las consultas marcadas "DEBE devolver 0 filas"
--                                 no deben arrojar resultados si la carga es sana.
--   B) Estadísticos descriptivos (perfilado) -> versión liviana; el perfilado
--                                 completo y parametrizado va en la Etapa 2.2.
--
-- Uso:  psql -d <db> -f 03_validacion.sql
-- =============================================================================

SET search_path TO pastas;

\echo '==========================================================='
\echo ' A) CHEQUEOS DE INTEGRIDAD (todas DEBEN devolver 0 filas)'
\echo '==========================================================='

-- A1. Ninguna franquicia puede superar 1000 clientes (constraint de negocio C4)
\echo '-- A1. Franquicias con mas de 1000 clientes (esperado: 0 filas)'
SELECT sello, COUNT(*) AS n_clientes
FROM cliente
GROUP BY sello
HAVING COUNT(*) > 1000;

-- A2. Ningún relleno puede tener más de 6 ingredientes (constraint C3)
\echo '-- A2. Rellenos con mas de 6 ingredientes (esperado: 0 filas)'
SELECT id_relleno, COUNT(*) AS n_ingredientes
FROM relleno_ingrediente
GROUP BY id_relleno
HAVING COUNT(*) > 6;

-- A3. Toda pasta debe pertenecer a exactamente UNA subtabla (jerarquía disjunta y total)
\echo '-- A3. Pastas sin subtipo o en ambos subtipos (esperado: 0 filas)'
SELECT p.sello, p.codigo_pasta, p.tipo,
       (s.codigo_pasta IS NOT NULL) AS es_seca,
       (r.codigo_pasta IS NOT NULL) AS es_rellena
FROM pasta p
LEFT JOIN pasta_seca    s ON (p.sello, p.codigo_pasta) = (s.sello, s.codigo_pasta)
LEFT JOIN pasta_rellena r ON (p.sello, p.codigo_pasta) = (r.sello, r.codigo_pasta)
WHERE (s.codigo_pasta IS NULL AND r.codigo_pasta IS NULL)   -- sin subtipo
   OR (s.codigo_pasta IS NOT NULL AND r.codigo_pasta IS NOT NULL); -- en ambos

-- A4. La pasta favorita de un cliente debe ser de SU franquicia (constraint C8)
--     (la FK lo garantiza; este chequeo es defensivo/documental)
\echo '-- A4. Clientes con favorita de otra franquicia (esperado: 0 filas)'
SELECT c.id_cliente, c.sello, c.codigo_favorita
FROM cliente c
WHERE c.codigo_favorita IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM pasta p
      WHERE p.sello = c.sello AND p.codigo_pasta = c.codigo_favorita
  );

-- A5. Todo detalle de compra debe corresponder a una pasta de la franquicia
--     del cliente que hizo la compra (coherencia transaccional)
\echo '-- A5. Detalles de compra de otra franquicia (esperado: 0 filas)'
SELECT d.id_compra, d.sello AS sello_detalle, cl.sello AS sello_cliente
FROM detalle_compra d
JOIN compra  co ON co.id_compra  = d.id_compra
JOIN cliente cl ON cl.id_cliente = co.id_cliente
WHERE d.sello <> cl.sello;

-- A6. Toda compra debe tener al menos un detalle (no hay compras "vacías")
\echo '-- A6. Compras sin detalle (esperado: 0 filas)'
SELECT co.id_compra
FROM compra co
LEFT JOIN detalle_compra d ON d.id_compra = co.id_compra
WHERE d.id_compra IS NULL;

-- A7. Ninguna compra puede ser anterior al inicio de operaciones de la franquicia
\echo '-- A7. Compras anteriores al inicio de la franquicia (esperado: 0 filas)'
SELECT co.id_compra, co.fecha_hora, f.fecha_inicio
FROM compra co
JOIN cliente cl   ON cl.id_cliente = co.id_cliente
JOIN franquicia f ON f.sello = cl.sello
WHERE co.fecha_hora::date < f.fecha_inicio;


\echo ''
\echo '==========================================================='
\echo ' B) RESUMEN DE VOLUMENES'
\echo '==========================================================='

\echo '-- B1. Cantidad de registros por tabla'
SELECT 'franquicia'          AS tabla, COUNT(*) AS filas FROM franquicia
UNION ALL SELECT 'pasta',               COUNT(*) FROM pasta
UNION ALL SELECT 'pasta_seca',          COUNT(*) FROM pasta_seca
UNION ALL SELECT 'pasta_rellena',       COUNT(*) FROM pasta_rellena
UNION ALL SELECT 'relleno',             COUNT(*) FROM relleno
UNION ALL SELECT 'ingrediente',         COUNT(*) FROM ingrediente
UNION ALL SELECT 'relleno_ingrediente', COUNT(*) FROM relleno_ingrediente
UNION ALL SELECT 'cliente',             COUNT(*) FROM cliente
UNION ALL SELECT 'compra',              COUNT(*) FROM compra
UNION ALL SELECT 'detalle_compra',      COUNT(*) FROM detalle_compra
ORDER BY filas DESC;


\echo ''
\echo '==========================================================='
\echo ' C) ESTADISTICOS DESCRIPTIVOS (perfilado liviano)'
\echo '==========================================================='

-- C1. Estadísticos de una columna NUMERICA: precio_por_kilo de las pastas.
--     Usa funciones de agregación + percentiles (PERCENTILE_CONT).
\echo '-- C1. Estadisticos de pasta.precio_por_kilo'
SELECT
    COUNT(*)                                                       AS n,
    ROUND(MIN(precio_por_kilo), 2)                                 AS minimo,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY precio_por_kilo)::numeric, 2) AS q1,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY precio_por_kilo)::numeric, 2) AS mediana,
    ROUND(AVG(precio_por_kilo), 2)                                 AS promedio,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY precio_por_kilo)::numeric, 2) AS q3,
    ROUND(MAX(precio_por_kilo), 2)                                 AS maximo,
    ROUND(STDDEV_SAMP(precio_por_kilo), 2)                         AS desvio
FROM pasta;

-- C2. Mismo estadístico pero AGRUPADO por tipo de pasta (seca vs rellena),
--     para verificar que las rellenas son más caras (distribución plausible).
\echo '-- C2. precio_por_kilo por tipo de pasta'
SELECT
    tipo,
    COUNT(*)                        AS n,
    ROUND(AVG(precio_por_kilo), 2)  AS precio_promedio,
    ROUND(MIN(precio_por_kilo), 2)  AS precio_min,
    ROUND(MAX(precio_por_kilo), 2)  AS precio_max
FROM pasta
GROUP BY tipo
ORDER BY tipo;

-- C3. Estadístico de una columna CATEGORICA: distribución de franquicias por barrio.
--     Frecuencia + porcentaje usando una window function sobre el total.
\echo '-- C3. Distribucion de franquicias por barrio'
SELECT
    barrio,
    COUNT(*)                                                  AS frecuencia,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)        AS porcentaje
FROM franquicia
GROUP BY barrio
ORDER BY frecuencia DESC, barrio;

-- C4. Variedad de comportamiento de clientes: cuántas compras hizo cada uno,
--     resumido en una distribución (valida que NO todos compran lo mismo).
\echo '-- C4. Distribucion de cantidad de compras por cliente'
WITH compras_por_cliente AS (
    SELECT cl.id_cliente, COUNT(co.id_compra) AS n_compras
    FROM cliente cl
    LEFT JOIN compra co ON co.id_cliente = cl.id_cliente
    GROUP BY cl.id_cliente
)
SELECT
    MIN(n_compras)                                                       AS min_compras,
    ROUND(AVG(n_compras), 2)                                             AS prom_compras,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY n_compras)               AS mediana_compras,
    MAX(n_compras)                                                       AS max_compras,
    COUNT(*) FILTER (WHERE n_compras = 0)                                AS clientes_sin_compras
FROM compras_por_cliente;

\echo ''
\echo 'Validacion finalizada.'
