# Plan de trabajo — TP Introducción a Bases de Datos

**Dominio elegido:** Fábrica de Pastas (cadena de franquicias, `modelo.txt`).
**Consigna:** `IBD_TrabajoPractico.pdf`.
**Propósito de este archivo:** ser la guía para continuar el TP en próximas
sesiones. Cada etapa tiene: objetivo, entregables, pasos concretos y criterio
de "terminado". Al completar una etapa, marcar los checkboxes y actualizar la
sección *Estado actual*.

---

## Estado actual (actualizado: 2026-06-10)

| Etapa | Estado | Archivos |
|---|---|---|
| 1.1 Elección del modelo (DER) | ✅ Hecho | `informe/der.md` |
| 1.2 Schema PostgreSQL | ✅ Hecho | `etapa1-postgres/01_schema.sql` |
| 1.3 Poblado + validación | ✅ Hecho | `generar_datos.py`, `02_seed.sql`, `03_validacion.sql`, `data/*.csv` |
| Etapa 0: entorno reproducible | ✅ Hecho | `docker-compose.yml`, `README.md`, `requirements.txt` |
| 2.1 Funciones de ventana | ⬜ Pendiente | — |
| 2.2 Funciones estadísticas (C1/C2/C3) + CTE | ⬜ Pendiente | — |
| 2.3 Análisis de performance | ⬜ Pendiente | — |
| 3.1 MapReduce con Spark RDDs | ⬜ Pendiente | — |
| 4.1 Redis | ⬜ Pendiente | — |
| 4.2 MongoDB | ⬜ Pendiente | — |
| Informe final (PDF, ≤15 páginas) | 🟡 Parcial | `informe/der.md` (sección 1.1) |
| README reproducibilidad | ✅ Hecho | `README.md` |

---

## Estructura objetivo del repositorio

```
tpdb/
├── README.md                      # Cómo reproducir TODO el entorno (entregable)
├── PLAN.md                        # Este archivo (guía interna, no se entrega)
├── docker-compose.yml             # Postgres + Redis + Mongo en un solo comando
├── IBD_TrabajoPractico.pdf        # Consigna
├── modelo.txt                     # Enunciado del dominio
│
├── data/                          # CSVs generados (fuente única para Spark/Mongo)
│   └── *.csv                      # 10 tablas, mismo dataset que 02_seed.sql
│
├── etapa1-postgres/
│   ├── generar_datos.py           # Generador determinista (seed 42) → SQL + CSVs
│   ├── requirements.txt
│   ├── 01_schema.sql              # Tablas, PK/FK, constraints, triggers (sin índices)
│   ├── 02_seed.sql                # INSERTs (≥5000 filas en tablas principales)
│   └── 03_validacion.sql          # Chequeos de integridad + perfilado básico
│
├── etapa2-sql-avanzado/
│   ├── 01_ventanas.sql            # 2.1 — ≥2 consultas con funciones de ventana
│   ├── 02_estadisticas.sql        # 2.2 — C1, C2, C3 + consulta con CTE
│   └── 03_performance.sql         # 2.3 — EXPLAIN ANALYZE antes/después + índices
│
├── etapa3-spark/
│   └── mapreduce_rdd.ipynb        # 3.1 — ≥3 procesamientos MapReduce sobre data/*.csv
│
├── etapa4-nosql/
│   ├── redis.ipynb                # 4.1 — KV/hashes, listas, TTL
│   └── mongodb.ipynb              # 4.2 — colecciones, CRUD, aggregation pipelines
│
└── informe/
    ├── der.md                     # Sección 1.1 (ya escrita)
    ├── etapa1.md                  # Secciones 1.2 y 1.3
    ├── etapa2.md                  # Secciones 2.1–2.3 (con capturas de resultados)
    ├── etapa3.md                  # Sección 3.1
    ├── etapa4.md                  # Secciones 4.1–4.2
    └── img/                       # DER exportado, capturas de EXPLAIN, resultados
```

**Convenciones que ya rigen y deben mantenerse:**
- Todo vive en el schema `pastas` de PostgreSQL (`SET search_path TO pastas;`).
- Los datos son **deterministas** (seed 42, fecha fija 2026-06-09 en
  `generar_datos.py`). Si se regeneran, re-correr `02_seed.sql` y los CSVs
  quedan sincronizados — Postgres, Spark y Mongo siempre ven el mismo dataset.
- Los scripts SQL deben ser ejecutables de punta a punta sin modificaciones
  (criterio de entrega del PDF).
- Cada sección del informe se redacta en `informe/etapaN.md` a medida que se
  termina la etapa, no al final. El PDF final se arma concatenando esos .md.

---

## Etapa 0 (transversal): entorno reproducible

**Objetivo:** que todo el TP se levante con un comando. ✅ **Completa (2026-06-10).**

- [x] `docker-compose.yml` con tres servicios: `postgres:16` (5432,
  `pastas_tp`), `redis:7` (6379), `mongo:7` (27017). Postgres monta
  `etapa1-postgres/` en `/docker-entrypoint-initdb.d`, así que **schema +
  seed + validación corren solos en el primer arranque**; para resetear:
  `docker compose down -v && docker compose up -d`.
- [x] `README.md` raíz con versiones, levantado, conexiones, ejecución por
  etapa y notas de reproducibilidad.
- [x] `requirements.txt` raíz con dependencias de todas las etapas
  (`faker`, `pyspark`, `redis`, `pymongo`, `jupyter`, `pandas`).
  El de `etapa1-postgres/` queda solo para quien corra el generador aislado.

**Verificado (2026-06-10):** `docker compose up -d` desde cero deja los tres
servicios healthy; Postgres queda poblado solo (15 franquicias, 361 pastas,
7986 clientes, 32008 compras, 80102 detalles); Redis responde PONG y Mongo
responde al ping.

**Conexiones para las próximas etapas:**
- PostgreSQL: `postgresql://postgres:pastas@localhost:5432/pastas_tp` (schema `pastas`)
- Redis: `redis://localhost:6379`
- MongoDB: `mongodb://localhost:27017`

---

## Etapa 2: SQL Avanzado → `etapa2-sql-avanzado/`

### 2.1 Funciones de ventana (`01_ventanas.sql`)

≥2 consultas **no resolubles trivialmente con GROUP BY**. Candidatas que
explotan bien este modelo (elegir 2–3):

1. **Ranking intra-franquicia:** top-N clientes por monto comprado dentro de
   cada franquicia → `RANK() OVER (PARTITION BY sello ORDER BY SUM(...) DESC)`.
   La gracia: el ranking se reinicia por franquicia, cosa que GROUP BY solo no da.
2. **Recurrencia de clientes:** días transcurridos entre compras consecutivas
   de un mismo cliente → `LAG(fecha_hora) OVER (PARTITION BY id_cliente ORDER BY fecha_hora)`.
   Responde "¿cada cuánto vuelve un cliente?".
3. **Primera/última compra por cliente** con `FIRST_VALUE`/`ROW_NUMBER`, o
   **participación de cada pasta en las ventas de su franquicia** con
   `SUM(...) OVER (PARTITION BY sello)` (porcentaje sin subquery).

Para cada consulta, dejar en comentario del .sql y en `informe/etapa2.md`:
pregunta de negocio, por qué ventana (y no GROUP BY), y lectura del resultado.

- [ ] Escribir y probar las consultas contra la base poblada
- [ ] Capturar resultados (primeras ~10 filas) para el informe
- [ ] Redactar sección 2.1 en `informe/etapa2.md`

### 2.2 Funciones estadísticas (`02_estadisticas.sql`)

Tres consultas de perfilado sobre **una tabla elegida** (recomendada:
`detalle_compra` — tiene numéricas con buena distribución — o `cliente` para
categóricas). Nota: `03_validacion.sql` ya tiene una versión liviana de esto;
acá va la versión completa que pide la consigna.

- [ ] **C1 (todas las columnas):** total de filas, cantidad y % de no nulos,
      cantidad de valores distintos. Patrón: un `SELECT` por columna unido con
      `UNION ALL`, o `COUNT(col)`, `COUNT(DISTINCT col)` sobre la tabla.
- [ ] **C2 (numéricas):** stddev, min, P05, Q1, mediana, promedio, Q3, P95, max
      (`PERCENTILE_CONT(...) WITHIN GROUP`), cantidad y % de ceros, cantidad y
      % de negativos, y **outliers** (criterio IQR: fuera de
      `[Q1 − 1.5·IQR, Q3 + 1.5·IQR]` — explicitar el criterio en el informe).
- [ ] **C3 (categóricas):** top-10 valores por frecuencia con su % +
      una fila "resto" agregando lo demás (acá conviene `ROW_NUMBER()` +
      `CASE WHEN rn <= 10`).
- [ ] **CTE:** al menos una consulta con `WITH` (C2/C3 ya lo van a necesitar;
      si no, agregar una pregunta de negocio aparte, p. ej. "ticket promedio
      por franquicia comparado con el promedio global" con dos CTEs).
- [ ] Redactar sección 2.2 en `informe/etapa2.md`

### 2.3 Análisis de performance (`03_performance.sql`)

- [ ] Elegir la consulta más pesada de 2.1/2.2 (ideal: el ranking de clientes,
      que joinea `cliente → compra → detalle_compra`).
- [ ] `EXPLAIN ANALYZE` **antes**: guardar el plan completo (seq scans, costo,
      tiempo) en comentario del .sql y captura para el informe.
- [ ] Proponer mejora: índices sobre las FKs usadas en los joins
      (p. ej. `compra(id_cliente)`, `detalle_compra(id_compra)`,
      `compra(fecha_hora)` si se filtra por fecha) y/o reescritura de la consulta.
      Los `CREATE INDEX` van en este archivo (la consigna prohibió índices en
      Etapa 1, acá es el lugar correcto).
- [ ] `EXPLAIN ANALYZE` **después**: comparar costos y explicar la diferencia
      de planes (seq scan → index scan / hash join → nested loop, etc.).
- [ ] Redactar sección 2.3 en `informe/etapa2.md` con tabla comparativa
      antes/después.

**Terminado cuando:** los tres .sql corren de punta a punta con `psql -f` sobre
la base recién poblada, y `informe/etapa2.md` cubre los tres puntos.

---

## Etapa 3: Spark → `etapa3-spark/mapreduce_rdd.ipynb`

**Fuente de datos:** los CSVs de `data/` (ya exportados por `generar_datos.py`
justamente para esto). Leer con `sc.textFile` + parseo manual del CSV, porque
la consigna pide la **API de RDDs**, no DataFrames.

≥3 procesamientos MapReduce. Candidatos alineados con "naturalmente paralelos":

1. **Facturación total por franquicia:** map sobre `detalle_compra.csv` →
   `(sello, cantidad_kg * precio_unitario)`; reduce → `reduceByKey(add)`.
2. **Top-N pastas más vendidas por kilos:** map → `((sello, codigo_pasta), kg)`;
   reduce → `reduceByKey` + `takeOrdered(N, key=lambda x: -x[1])`.
3. **Compras por franja horaria / mes:** map sobre `compra.csv` →
   `(hora_o_mes, 1)`; reduce → `reduceByKey(add)` (distribución temporal).
4. (alternativa) **Ticket promedio por cliente:** map → `(id_cliente, (monto, 1))`;
   reduce → `reduceByKey` sumando tuplas y dividiendo al final — buen ejemplo
   de que AVG en MapReduce requiere par (suma, conteo).

Estructura de cada ejercicio en el notebook (lo exige la consigna):
celda markdown con (1) pregunta de negocio, (2) fase Map con la estructura
(clave, valor) generada, (3) fase Reduce y sobre qué claves agrega,
(4) celda de código comentada + impresión clara del resultado.

- [ ] Setup: celda inicial con `SparkContext` local + parseo de CSVs (con
      manejo del header)
- [ ] Implementar los 3 procesamientos
- [ ] Celda/markdown sobre **lazy evaluation**: mostrar que las
      transformaciones no ejecutan nada hasta la acción (`collect`/`take`)
      — la consigna lo pide explícitamente en el informe
- [ ] Redactar `informe/etapa3.md`

**Terminado cuando:** "Restart & Run All" del notebook funciona sin errores
contra `data/`.

---

## Etapa 4: NoSQL → `etapa4-nosql/`

### 4.1 Redis (`redis.ipynb`)

Justificación general para el informe: lecturas por ID de altísima frecuencia
(perfil del cliente en el mostrador, precios en pantalla) no necesitan joins ni
ACID — Redis las sirve en memoria sin cargar Postgres.

- [ ] **4.1.1 KV y hashes — 3 tipos de datos del dominio:**
  - `franquicia:{sello}` → hash con dirección/contacto (perfil consultado por ID)
  - `cliente:{id}` → hash con datos de contactabilidad + pasta favorita
  - `precio:{sello}:{codigo_pasta}` → string/valor simple (lookup de precio al
    facturar, el dato más leído del sistema)
  - Cargar desde `data/*.csv`, consultar con `get/hget/hgetall`, actualizar un
    campo (p. ej. cambio de teléfono o de precio) y verificar el cambio.
- [ ] **4.1.2 Lista — cola de pedidos de elaboración:** las compras del día
      entran como cola de producción por franquicia
      (`rpush pedidos:{sello}`, el elaborador hace `lpop`). Mostrar
      `lrange`, `llen` y simular el flujo completo entrada→salida con prints.
- [ ] **4.1.3 TTL — 3 claves con vida distinta y justificada:**
  - `promo:{sello}:descuento-dia` → TTL hasta fin del día (promo diaria)
  - `sesion:{id_cliente}` → TTL ~30 min (sesión de la app de pedidos)
  - `cache:ranking-pastas:{sello}` → TTL ~5 min (cache del ranking de 2.1,
    consulta costosa que no necesita estar al segundo)
  - Verificar con `ttl/pttl` e imprimir mensajes tipo "La promo X expiró".
- [ ] Redactar sección 4.1 en `informe/etapa4.md` (por qué Redis vs Postgres
      en cada caso)

### 4.2 MongoDB (`mongodb.ipynb`)

Entorno: **Docker local** (más simple de reproducir que Atlas; documentar la
imagen y el string de conexión `mongodb://localhost:27017` en el informe).

- [ ] **4.2.1 Diseño — 2 colecciones (≥100 docs c/u, desde `data/` + Faker):**
  - `pastas`: documento por pasta **embebiendo** el relleno con su array de
    ingredientes (`{nombre, tipo, precio, relleno: {nombre, ingredientes: [...]}}`)
    — elimina el join de 4 tablas del modelo relacional; campos opcionales:
    `relleno` solo en rellenas, `promedio_kilos_diarios` solo en rellenas.
  - `clientes`: documento por cliente embebiendo un array `compras` (con sus
    items) — el historial se lee siempre junto al cliente; campos opcionales:
    `telefono`, `fecha_nacimiento`, `pasta_favorita`.
  - Discutir en el informe: embeber vs referenciar (`sello` queda como
    referencia), y por qué difiere del modelo de Etapa 1.
- [ ] **4.2.2 CRUD:** `insert_one`/`insert_many`; filtros con `$gt/$lt/$gte/$lte`
      y `$and/$or` (p. ej. pastas entre $X y $Y, clientes nacidos antes de 1990
      o sin teléfono); proyecciones; `update_one/update_many` con `$set`
      (cambio de precio), `$push` (nueva compra al array), `$inc` (contador);
      `delete_one/delete_many` condicional (p. ej. clientes sin compras).
- [ ] **4.2.3 Aggregation — 2 pipelines de ≥3 etapas c/u:**
  - Ranking de pastas por facturación: `$unwind` compras → `$unwind` items →
    `$group` por pasta → `$sort` → `$limit`.
  - Ventas por mes: `$unwind` → `$group` por `{$dateToString o $month}` →
    `$project` → `$sort`. (Si se quiere `$lookup`: clientes ↔ pastas por favorita.)
  - Explicar etapa por etapa en el informe + reflexión Postgres vs Spark vs
    Mongo que pide la nota de la consigna.
- [ ] Redactar sección 4.2 en `informe/etapa4.md`

**Terminado cuando:** ambos notebooks corren con "Restart & Run All" contra los
contenedores del compose.

---

## Cierre: informe y entrega

- [ ] Exportar el DER de `informe/der.md` a imagen (mermaid.live) → `informe/img/`
- [ ] Consolidar `informe/*.md` en un solo PDF de ≤15 páginas con capturas de
      resultados (pandoc o impresión desde el editor)
- [ ] `README.md` final verificado en limpio: borrar contenedores y volúmenes,
      seguir el README al pie de la letra, confirmar que todo corre
- [ ] Checklist de entregables del PDF de la consigna:
  - [ ] Informe PDF
  - [ ] Script SQL de creación (Etapa 1) ✅ ya existe
  - [ ] Script SQL de poblado (Etapa 1) ✅ ya existe
  - [ ] Scripts SQL avanzado (Etapa 2)
  - [ ] Notebook Spark (Etapa 3.1)
  - [ ] Notebook Redis (Etapa 4.1)
  - [ ] Notebook MongoDB (Etapa 4.2)
  - [ ] README de reproducibilidad

---

## Cómo retomar en una sesión nueva

1. Leer este archivo y la sección *Estado actual*.
2. Levantar el entorno: `docker compose up -d` (Postgres se puebla solo;
   ver README para verificación y reset).
3. Continuar con la primera etapa marcada ⬜, en orden: los archivos de la
   Etapa 2 dependen de la base poblada; las Etapas 3 y 4 solo dependen de
   `data/*.csv` y de los contenedores, así que pueden hacerse en paralelo.
4. Al terminar una sub-etapa: tildar el checkbox, actualizar la tabla de
   estado y redactar la sección correspondiente en `informe/`.
