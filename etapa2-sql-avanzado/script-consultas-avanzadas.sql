-- Etapa 2 --

-- Ejercicio 2.1 --

-- PREGUNTA 1 --
-- ¿Cómo evolucionó la recaudación de las franquicias del barrio Centro mes a mes en el último año? --
-- Paso 1: Nos quedamos con todas las compras que se realizaron en villa crespo
-- Paso 2: Calculamos las ventas de la franquicia por mes durante el ultimo año
-- Paso 3: Apareamos los ingresos de un mes con los del mes anterior

select * from pastas.franquicia f
inner join pastas.direccion d ON d.id_direccion = f.id_direccion
inner join pastas.barrio b on b.id_barrio = d.id_barrio

select * from pastas.barrio where nombre = 'Villa Crespo'
select * from pastas.barrio
WITH compra_villa_crespo AS (
	SELECT 
		cl.id_cliente AS cliente,
		cl.sello,
		co.id_compra,
		co.fecha_hora,
		b.nombre
	FROM pastas.compra co
	JOIN pastas.cliente cl ON cl.id_cliente = co.id_cliente
	JOIN pastas.franquicia f ON f.sello = cl.sello
	JOIN pastas.direccion d ON d.id_direccion = f.id_direccion
	JOIN pastas.barrio b ON b.id_barrio = d.id_barrio
	WHERE b.nombre ='Palermo'
),
recaudacion_mensual AS (
    -- PASO 2 --
    SELECT 
        d.sello,
        TO_CHAR(c.fecha_hora, 'YYYY-MM') AS mes_anio,
        SUM(d.cantidad_kg * d.precio_unitario) AS ingreso_mensual
    FROM compra_villa_crespo c
    JOIN pastas.detalle_compra d ON c.id_compra = d.id_compra
	WHERE c.fecha_hora BETWEEN DATE'2025-05-01' AND DATE '2026-06-01' -- No ponemos (CURRENT_DATE - INTERVAL '1 year') para poder replicar los resultados, tambien ponemos un mes demas para poder calcular el primer mes --
    GROUP BY d.sello, TO_CHAR(c.fecha_hora, 'YYYY-MM')
),
comparativa_mes_a_mes AS (
    -- PASO 3 --
    SELECT 
        sello,
        mes_anio,
        ingreso_mensual,
        LAG(ingreso_mensual) OVER (
            PARTITION BY sello 
            ORDER BY mes_anio ASC
        ) AS ingreso_mes_anterior
    FROM recaudacion_mensual
)
SELECT 
    sello,
    mes_anio,
    ingreso_mensual,
    ingreso_mes_anterior,
    (ingreso_mensual - ingreso_mes_anterior) AS crecimiento_neto,
	ROUND(((ingreso_mensual - ingreso_mes_anterior) / ingreso_mes_anterior) * 100, 2) AS porcentaje_crecimiento -- Vemos el porcentaje para mejor lectura --
FROM comparativa_mes_a_mes mam
WHERE ingreso_mes_anterior IS NOT NULL
ORDER BY sello,
		mes_anio ASC;

-- Pregunta 2 --
-- ¿Cuáles son los 3 tipos de pastas más vendidas y las 3 menos vendidas en cada una de las franquicias? -- 
-- Para responder esta pregunta vamos a hacer un plan de pasos --
-- 1. Obtenemos la cantidad de kilos de cada pasta que se vendio en cada franquicia --
-- 2. Creamos un ranking con el resultado anterior --
-- 3. Nos quedamos con los dos tops segun el ranking --

EXPLAIN ANALYZE
-- PASO 1 --
WITH venta_por_pasta AS (
    SELECT 
        p.sello,
        p.nombre AS nombre_pasta,
        COALESCE(SUM(d.cantidad_kg), 0) AS total_kilos_vendidos -- Esto nos permite que las pastas sin ventas figuren con 0 en vez de NULL --
    FROM pastas.pasta p
    LEFT JOIN pastas.detalle_compra d ON p.sello = d.sello AND p.codigo_pasta = d.codigo_pasta -- LEFT JOIN para no perder las pastas que no se vendieron --
    GROUP BY p.sello, p.nombre
	),
-- PASO 2 --
ranking AS (
    SELECT 
        sello,
        nombre_pasta,
        total_kilos_vendidos,
        DENSE_RANK() OVER (PARTITION BY sello ORDER BY total_kilos_vendidos DESC) AS rank_mas_vendido, -- Ranking de las pastas más vendidas
		DENSE_RANK() OVER (PARTITION BY sello ORDER BY total_kilos_vendidos ASC) AS rank_menos_vendido -- Ranking de las pastas menos vendidas (esto nos facilita las cosas despues)
    FROM venta_por_pasta
)
-- PASO 3 -- 
SELECT 
    sello,
    nombre_pasta,
    total_kilos_vendidos,
    CASE 
        WHEN rank_mas_vendido <= 3 THEN rank_mas_vendido
	END AS top_mas_ventas,
	CASE
        WHEN rank_menos_vendido <= 3 THEN rank_menos_vendido
    END AS top_menos_ventas
FROM ranking
WHERE rank_mas_vendido <= 3 OR rank_menos_vendido <= 3
ORDER BY 
    sello, 
    top_mas_ventas ASC NULLS LAST, 
    top_menos_ventas ASC NULLS LAST
LIMIT 12;

select * from pastas.detalle_compra


/* 
Consultas ejercicio 2.2 - Funciones estadísticas 

Para este ejercicio vamos a utilizar la tabla detalle_compra 
Columnas y categoria:
id_compra ---> Integer (Lo consideramos categorico)
sello ---> Character (categorica)
codigo_pasta ---> Character (categorica)
cantidad_kg ---> Numeric
precio_unitario ---> Numeric

*/

-- Consulta C1 --
-- Realizamos la misma consulta para cada columna --

SELECT 
    'sello' AS nombre_columna,
    COUNT(*) AS total_filas,
    COUNT(sello) AS filas_no_nulas,
    ROUND((COUNT(sello) * 100.0) / COUNT(*), 2) AS porcentaje_no_nulos,
    COUNT(DISTINCT sello) AS valores_diferentes
FROM pastas.detalle_compra

UNION ALL

SELECT 
    'codigo_pasta' AS nombre_columna,
    COUNT(*) AS total_filas,
    COUNT(codigo_pasta) AS filas_no_nulas,
    ROUND((COUNT(codigo_pasta) * 100.0) / COUNT(*), 2) AS porcentaje_no_nulos,
    COUNT(DISTINCT codigo_pasta) AS valores_diferentes
FROM pastas.detalle_compra

UNION ALL

SELECT 
    'id_compra' AS nombre_columna,
    COUNT(*) AS total_filas,
    COUNT(id_compra) AS filas_no_nulas,
    ROUND((COUNT(id_compra) * 100.0) / COUNT(*), 2) AS porcentaje_no_nulos,
    COUNT(DISTINCT id_compra) AS valores_diferentes
FROM pastas.detalle_compra

UNION ALL

SELECT 
    'cantidad_kg' AS nombre_columna,
    COUNT(*) AS total_filas,
    COUNT(cantidad_kg) AS filas_no_nulas,
    ROUND((COUNT(cantidad_kg) * 100.0) / COUNT(*), 2) AS porcentaje_no_nulos,
    COUNT(DISTINCT cantidad_kg) AS valores_diferentes
FROM pastas.detalle_compra

UNION ALL

SELECT 
    'precio_unitario' AS nombre_columna,
    COUNT(*) AS total_filas,
    COUNT(precio_unitario) AS filas_no_nulas,
    ROUND((COUNT(precio_unitario) * 100.0) / COUNT(*), 2) AS porcentaje_no_nulos,
    COUNT(DISTINCT precio_unitario) AS valores_diferentes
FROM pastas.detalle_compra;




-- Consulta C2 --

-- desvío estándar, mínimo, P05, primer cuartil, mediana,
-- promedio, tercer cuartil, P95, máximo, cantidad y porcentaje de ceros,
-- cantidad y porcentaje de valores negativos, cantidad de outliers

-- COLS NUMERICAS : (cantidad_kg, precio_unitario)

-- Hacemos las consultas con dos CTE y depues unimos todo --
WITH metricas_cantidad_kg AS (
    SELECT 
        'cantidad_kg' AS variable,
        ROUND(STDDEV(cantidad_kg), 2) AS desvio_estandar,
        MIN(cantidad_kg) AS minimo,
        PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY cantidad_kg) AS P05,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY cantidad_kg) AS Q1,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY cantidad_kg) AS mediana,
        ROUND(AVG(cantidad_kg), 2) AS promedio,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY cantidad_kg) AS Q3,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY cantidad_kg) AS P95,
        MAX(cantidad_kg) AS maximo,
        COUNT(*) FILTER (WHERE cantidad_kg = 0) AS cant_ceros,
        ROUND((COUNT(*) FILTER (WHERE cantidad_kg = 0) * 100.0) / COUNT(*), 2) AS pct_ceros,
        COUNT(*) FILTER (WHERE cantidad_kg < 0) AS cant_negativos,
        ROUND((COUNT(*) FILTER (WHERE cantidad_kg < 0) * 100.0) / COUNT(*), 2) AS pct_negativos,
        
        COUNT(*) AS total_filas
    FROM pastas.detalle_compra
),
metricas_precio AS (
    SELECT 
        'precio_unitario' AS variable,
        ROUND(STDDEV(precio_unitario), 2) AS desvio_estandar,
        MIN(precio_unitario) AS minimo,
        PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY precio_unitario) AS P05,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY precio_unitario) AS Q1,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY precio_unitario) AS mediana,
        ROUND(AVG(precio_unitario), 2) AS promedio,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY precio_unitario) AS Q3,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY precio_unitario) AS P95,
        MAX(precio_unitario) AS maximo,
        COUNT(*) FILTER (WHERE precio_unitario = 0) AS cant_ceros,
        ROUND((COUNT(*) FILTER (WHERE precio_unitario = 0) * 100.0) / COUNT(*), 2) AS pct_ceros,
        COUNT(*) FILTER (WHERE precio_unitario < 0) AS cant_negativos,
        ROUND((COUNT(*) FILTER (WHERE precio_unitario < 0) * 100.0) / COUNT(*), 2) AS pct_negativos,
        
        COUNT(*) AS total_filas
    FROM pastas.detalle_compra
)
SELECT 
    c_kg.*,
    (SELECT COUNT(*) 
     FROM pastas.detalle_compra 
     WHERE cantidad_kg < (c_kg.Q1 - 1.5 * (c_kg.Q3 - c_kg.Q1)) -- Outlier Q1 - 1.5(Q3-Q1)
        OR cantidad_kg > (c_kg.Q3 + 1.5 * (c_kg.Q3 - c_kg.Q1)) -- Outlier Q3 - 1.5(Q3-Q1)
    ) AS cant_outliers
FROM metricas_cantidad_kg c_kg

UNION ALL

SELECT 
    p.*,
    (SELECT COUNT(*) 
     FROM pastas.detalle_compra 
     WHERE precio_unitario < (p.Q1 - 1.5 * (p.Q3 - p.Q1)) -- Outlier Q1 - 1.5(Q3-Q1)
        OR precio_unitario > (p.Q3 + 1.5 * (p.Q3 - p.Q1)) -- Outlier Q3 - 1.5(Q3-Q1) 
    ) AS cant_outliers
FROM metricas_precio p;


-- Consulta C3 --
-- la frecuencia y el porcentaje de los hasta 10
-- valores más frecuentes (de mayor a menor frecuencia), y del resto.

-- Total de filas me va a servir para los porcentajes --
WITH total_filas AS (
    SELECT COUNT(*) AS total FROM pastas.detalle_compra
),

-- CONSULTAS PARA SELLO --
freq_sello AS (
	SELECT 
		'sello' AS variable,
		sello::TEXT AS categoria,
		count(*) AS cantidad
	FROM pastas.detalle_compra
	GROUP BY sello
),
rank_sello AS (
	SELECT 
		variable, 
		categoria, 
		cantidad, 
		ROW_NUMBER() OVER(ORDER BY cantidad DESC) AS rank
    FROM freq_sello
),
-- Juntamos todo --
resumen_sello AS (
    SELECT 
        variable,
        CASE WHEN rank <= 10 THEN categoria ELSE 'Otros' END AS categoria_final,
        SUM(cantidad) AS frecuencia,
        ROUND((SUM(cantidad) * 100.0) / (SELECT total FROM total_filas), 2) AS porcentaje,
        CASE WHEN rank <= 10 THEN rank ELSE 11 END AS rank
    FROM rank_sello
    GROUP BY variable, 
		CASE 
			WHEN rank <= 10 THEN categoria ELSE 'Otros' END,
		CASE 
			WHEN rank <= 10 THEN rank ELSE 11 END
	ORDER BY rank 
),

-- Repetimos para codigo_pasta --
freq_pasta AS (
	SELECT 
		'codigo_pasta' AS variable,
		codigo_pasta::TEXT AS categoria,
		count(*) AS cantidad
	FROM pastas.detalle_compra
	GROUP BY codigo_pasta
),
rank_pasta AS (
	SELECT 
		variable, 
		categoria, 
		cantidad, 
		ROW_NUMBER() OVER(ORDER BY cantidad DESC) AS rank
    FROM freq_pasta
),
-- Juntamos todo --
resumen_pasta AS (
    SELECT 
        variable,
        CASE WHEN rank <= 10 THEN categoria ELSE 'Otros' END AS categoria_final,
        SUM(cantidad) AS frecuencia,
        ROUND((SUM(cantidad) * 100.0) / (SELECT total FROM total_filas), 2) AS porcentaje,
        CASE WHEN rank <= 10 THEN rank ELSE 11 END AS rank
    FROM rank_pasta
    GROUP BY variable, 
		CASE 
			WHEN rank <= 10 THEN categoria ELSE 'Otros' END,
		CASE 
			WHEN rank <= 10 THEN rank ELSE 11 END
	ORDER BY rank 
),


freq_id_compra AS (
	SELECT 
		'id_compra' AS variable,
		id_compra::TEXT AS categoria,
		count(*) AS cantidad
	FROM pastas.detalle_compra
	GROUP BY id_compra
),
rank_id_compra AS (
	SELECT 
		variable, 
		categoria, 
		cantidad, 
		ROW_NUMBER() OVER(ORDER BY cantidad DESC) AS rank
    FROM freq_id_compra
),
-- Juntamos todo --
resumen_id_compra AS (
    SELECT 
        variable,
        CASE WHEN rank <= 10 THEN categoria ELSE 'Otros' END AS categoria_final,
        SUM(cantidad) AS frecuencia,
        ROUND((SUM(cantidad) * 100.0) / (SELECT total FROM total_filas), 2) AS porcentaje,
        CASE WHEN rank <= 10 THEN rank ELSE 11 END AS rank
    FROM rank_id_compra
    GROUP BY variable, 
		CASE 
			WHEN rank <= 10 THEN categoria ELSE 'Otros' END,
		CASE 
			WHEN rank <= 10 THEN rank ELSE 11 END
	ORDER BY rank 
)

SELECT 
	variable,
	categoria_final AS categoria,
	frecuencia, 
	porcentaje,
	rank
FROM resumen_pasta

UNION ALL

SELECT 
	variable, 
	categoria_final AS categoria, 
	frecuencia, 
	porcentaje,
	rank
FROM resumen_sello

UNION ALL

SELECT 
	variable, 
	categoria_final AS categoria, 
	frecuencia, 
	porcentaje,
	rank
FROM resumen_id_compra



-- Ejercicio 2.3 --
-- Usamos la primera consulta del documento --

EXPLAIN ANALYZE

WITH recaudacion_mensual AS (
    -- PASO 1 --
    SELECT 
        d.sello,
        TO_CHAR(c.fecha_hora, 'YYYY-MM') AS mes_anio,
        SUM(d.cantidad_kg * d.precio_unitario) AS ingreso_mensual
    FROM pastas.compra c
    JOIN pastas.detalle_compra d ON c.id_compra = d.id_compra
	WHERE c.fecha_hora BETWEEN DATE'2025-05-01' AND DATE '2026-06-01' AND d.sello = 'FR-001' -- No ponemos (CURRENT_DATE - INTERVAL '1 year') para poder replicar los resultados, tambien ponemos un mes demas para poder calcular el primer mes --
    GROUP BY d.sello, TO_CHAR(c.fecha_hora, 'YYYY-MM')
),
comparativa_mes_a_mes AS (
    -- PASO 2 --
    SELECT 
        sello,
        mes_anio,
        ingreso_mensual,
        LAG(ingreso_mensual) OVER (
            PARTITION BY sello 
            ORDER BY mes_anio ASC
        ) AS ingreso_mes_anterior
    FROM recaudacion_mensual
	
)
SELECT 
    sello,
    mes_anio,
    ingreso_mensual,
    ingreso_mes_anterior,
    (ingreso_mensual - ingreso_mes_anterior) AS crecimiento_neto,
	ROUND(((ingreso_mensual - ingreso_mes_anterior) / ingreso_mes_anterior) * 100, 2) AS porcentaje_crecimiento -- Vemos el porcentaje para mejor lectura --
FROM comparativa_mes_a_mes mam
WHERE ingreso_mes_anterior IS NOT NULL
ORDER BY mes_anio ASC;

CREATE INDEX idx_compra_fecha_hora ON pastas.compra(fecha_hora); -- No obtuvimos mejoras con este index
DROP INDEX pastas.idx_compra_fecha_hora;

CREATE INDEX idx_detalle_compra_sello ON pastas.detalle_compra(sello);




