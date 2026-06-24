-- Etapa 1.3 - Validacion de los datos cargados.
-- Se corre despues de 01_schema.sql y 02_seed.sql. Solo consultas.
-- Las consultas de la parte A no deben devolver ninguna fila si la carga esta bien.

SET search_path TO pastas;

\echo '== A) Chequeos de integridad (todas deben dar 0 filas) =='

\echo '-- A1. Franquicias con mas de 1000 clientes'
SELECT sello, COUNT(*) AS n_clientes
FROM cliente
GROUP BY sello
HAVING COUNT(*) > 1000;

\echo '-- A2. Rellenos con mas de 6 ingredientes'
SELECT id_relleno, COUNT(*) AS n_ingredientes
FROM relleno_ingrediente
GROUP BY id_relleno
HAVING COUNT(*) > 6;

\echo '-- A3. Pastas sin subtipo o en los dos subtipos (la jerarquia es disjunta y total)'
SELECT p.sello, p.codigo_pasta, p.tipo
FROM pasta p
LEFT JOIN pasta_seca    s ON (p.sello, p.codigo_pasta) = (s.sello, s.codigo_pasta)
LEFT JOIN pasta_rellena r ON (p.sello, p.codigo_pasta) = (r.sello, r.codigo_pasta)
WHERE (s.codigo_pasta IS NULL AND r.codigo_pasta IS NULL)
   OR (s.codigo_pasta IS NOT NULL AND r.codigo_pasta IS NOT NULL);

\echo '-- A4. Clientes con favorita de otra franquicia'
SELECT c.id_cliente, c.sello, c.codigo_favorita
FROM cliente c
WHERE c.codigo_favorita IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM pasta p
      WHERE p.sello = c.sello AND p.codigo_pasta = c.codigo_favorita
  );

\echo '-- A5. Detalles de compra de una pasta de otra franquicia'
SELECT d.id_compra, d.sello AS sello_detalle, cl.sello AS sello_cliente
FROM detalle_compra d
JOIN compra  co ON co.id_compra  = d.id_compra
JOIN cliente cl ON cl.id_cliente = co.id_cliente
WHERE d.sello <> cl.sello;

\echo '-- A6. Compras sin detalle'
SELECT co.id_compra
FROM compra co
LEFT JOIN detalle_compra d ON d.id_compra = co.id_compra
WHERE d.id_compra IS NULL;

\echo '-- A7. Compras anteriores al inicio de la franquicia'
SELECT co.id_compra, co.fecha_hora, f.fecha_inicio
FROM compra co
JOIN cliente cl   ON cl.id_cliente = co.id_cliente
JOIN franquicia f ON f.sello = cl.sello
WHERE co.fecha_hora::date < f.fecha_inicio;

\echo '-- A8. Direcciones huerfanas (sin franquicia ni cliente)'
SELECT d.id_direccion
FROM direccion d
LEFT JOIN franquicia f ON f.id_direccion = d.id_direccion
LEFT JOIN cliente    c ON c.id_direccion = d.id_direccion
WHERE f.id_direccion IS NULL AND c.id_direccion IS NULL;

\echo '-- A9. Direcciones compartidas por mas de un dueno (rompe el 1:1)'
SELECT d.id_direccion,
       COUNT(DISTINCT f.sello)      AS n_franquicias,
       COUNT(DISTINCT c.id_cliente) AS n_clientes
FROM direccion d
LEFT JOIN franquicia f ON f.id_direccion = d.id_direccion
LEFT JOIN cliente    c ON c.id_direccion = d.id_direccion
GROUP BY d.id_direccion
HAVING COUNT(DISTINCT f.sello) + COUNT(DISTINCT c.id_cliente) > 1;

\echo '-- A10. Integridad de la jerarquia geografica (niveles sin padre)'
SELECT 'calle' AS nivel, c.id_calle AS id FROM calle c
  LEFT JOIN barrio b ON b.id_barrio = c.id_barrio WHERE b.id_barrio IS NULL
UNION ALL
SELECT 'direccion', d.id_direccion FROM direccion d
  LEFT JOIN calle c ON c.id_calle = d.id_calle WHERE c.id_calle IS NULL;

\echo '-- A11. Direcciones con numero de puerta invalido'
SELECT id_direccion, numero_puerta
FROM direccion
WHERE numero_puerta <= 0;

\echo ''
\echo '== B) Cantidad de registros por tabla =='
SELECT 'barrio'              AS tabla, COUNT(*) AS filas FROM barrio
UNION ALL SELECT 'calle',               COUNT(*) FROM calle
UNION ALL SELECT 'direccion',           COUNT(*) FROM direccion
UNION ALL SELECT 'franquicia',          COUNT(*) FROM franquicia
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
