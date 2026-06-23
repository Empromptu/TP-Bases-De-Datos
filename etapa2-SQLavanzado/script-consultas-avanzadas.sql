-- Etapa 2 --

-- Ejercicio 2.1 --

-- PREGUNTA 1 --
-- ¿Cómo evolucionó la recaudación de cada franquicia mes a mes en el último año? --
-- Paso 1: Calculamos las ventas por franquicia por mes durante el ultimo año
-- Paso 2: Apareamos los ingresos de un mes con los del mes anterior

WITH recaudacion_mensual AS (
    -- PASO 1 --
    SELECT 
        d.sello,
        TO_CHAR(c.fecha_hora, 'YYYY-MM') AS mes_anio,
        SUM(d.cantidad_kg * d.precio_unitario) AS ingreso_mensual
    FROM pastas.compra c
    JOIN pastas.detalle_compra d ON c.id_compra = d.id_compra
	WHERE c.fecha_hora BETWEEN DATE'2025-05-01' AND DATE '2026-06-01' -- No ponemos CURRENT_DATE- INTERVAL '1 year' para poder replicar los resultados, tambien ponemos un mes demas para poder calcular el primer mes --
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
ORDER BY sello, mes_anio ASC
LIMIT 12;

-- Pregunta 2 --
-- ¿Cuáles son los 3 tipos de pastas más vendidas y las 3 menos vendidas en cada una de las franquicias? -- 
-- Para responder esta pregunta vamos a hacer un plan de pasos --
-- 1. Obtenemos la cantidad de kilos de cada pasta que se vendio en cada franquicia --
-- 2. Creamos un ranking con el resultado anterior --
-- 3. Nos quedamos con los dos tops segun el ranking --

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

