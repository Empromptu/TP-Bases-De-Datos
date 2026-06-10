# TP Introducción a Bases de Datos — Fábrica de Pastas

Trabajo práctico grupal de la materia Introducción a Bases de Datos.
Dominio: **cadena de fábricas de pastas** con franquicias independientes
(enunciado en `modelo.txt`, consigna completa en `IBD_TrabajoPractico.pdf`).

El TP implementa el mismo dominio sobre cuatro tecnologías: PostgreSQL
(modelo relacional y SQL avanzado), Apache Spark (MapReduce con RDDs),
Redis y MongoDB (persistencia políglota).

## Estructura del repositorio

```
├── docker-compose.yml         # Postgres + Redis + Mongo
├── requirements.txt           # Dependencias Python (todas las etapas)
├── data/                      # CSVs generados: mismo dataset que el seed SQL
├── etapa1-postgres/
│   ├── 01_schema.sql          # Tablas, PK/FK, constraints y triggers
│   ├── 02_seed.sql            # Poblado (>5000 filas en tablas principales)
│   ├── 03_validacion.sql      # Chequeos de integridad + perfilado básico
│   └── generar_datos.py       # Generador determinista del seed y los CSVs
├── etapa2-sql-avanzado/       # Ventanas, estadísticas, performance
├── etapa3-spark/              # Notebook MapReduce (RDDs)
├── etapa4-nosql/              # Notebooks Redis y MongoDB
└── informe/                   # Informe por secciones + imágenes
```

## Requisitos

| Herramienta | Versión usada | Notas |
|---|---|---|
| Docker / Docker Compose | Docker Desktop 4.x (Compose v2) | Único requisito para las bases |
| Python | 3.10+ | Para notebooks y generador de datos |
| Java (JDK) | 11 o 17 | Solo para PySpark (Etapa 3) |

No hace falta tener PostgreSQL, Redis ni MongoDB instalados localmente:
todo corre en contenedores.

## Levantar el entorno

```bash
docker compose up -d
```

Esto levanta tres servicios:

| Servicio | Imagen | Puerto | Conexión |
|---|---|---|---|
| PostgreSQL | `postgres:16` | 5432 | `postgresql://postgres:pastas@localhost:5432/pastas_tp` |
| Redis | `redis:7` | 6379 | `redis://localhost:6379` |
| MongoDB | `mongo:7` | 27017 | `mongodb://localhost:27017` |

**La base PostgreSQL se crea y se puebla sola** en el primer arranque: los
scripts de `etapa1-postgres/` se ejecutan automáticamente en orden
(`01_schema.sql` → `02_seed.sql` → `03_validacion.sql`). La salida de la
validación queda en los logs: `docker compose logs postgres`.

Para verificar que todo está arriba y la base quedó poblada:

```bash
docker compose ps   # los tres servicios deben figurar "healthy"
docker compose exec postgres psql -U postgres -d pastas_tp \
  -c "SELECT COUNT(*) AS compras FROM pastas.compra;"
```

Para **re-inicializar la base desde cero** (vuelve a correr schema + seed):

```bash
docker compose down -v
docker compose up -d
```

## Entorno Python (notebooks y generador)

```bash
python -m venv .venv
# Windows:           .venv\Scripts\activate
# Linux / macOS:     source .venv/bin/activate
pip install -r requirements.txt
```

Para la Etapa 3, PySpark necesita un JDK 11 o 17 con `JAVA_HOME` configurado.

## Ejecución por etapa

Todos los scripts y notebooks corren de punta a punta sin modificaciones,
con los servicios del compose levantados.

### Etapa 1 — Modelo relacional

Se carga automáticamente con el compose (ver arriba). Para correr los
scripts a mano contra el contenedor:

```bash
docker compose exec postgres psql -U postgres -d pastas_tp -f /docker-entrypoint-initdb.d/01_schema.sql
docker compose exec postgres psql -U postgres -d pastas_tp -f /docker-entrypoint-initdb.d/02_seed.sql
docker compose exec postgres psql -U postgres -d pastas_tp -f /docker-entrypoint-initdb.d/03_validacion.sql
```

**Regenerar los datos** (opcional — el seed y los CSVs ya están versionados;
el generador es determinista, seed fija 42, así que produce siempre el mismo
dataset):

```bash
python etapa1-postgres/generar_datos.py
```

### Etapa 2 — SQL avanzado

```bash
docker compose cp etapa2-sql-avanzado tpdb-postgres:/tmp/etapa2
docker compose exec postgres psql -U postgres -d pastas_tp -f /tmp/etapa2/01_ventanas.sql
docker compose exec postgres psql -U postgres -d pastas_tp -f /tmp/etapa2/02_estadisticas.sql
docker compose exec postgres psql -U postgres -d pastas_tp -f /tmp/etapa2/03_performance.sql
```

### Etapas 3 y 4 — Notebooks

```bash
jupyter notebook
```

y ejecutar con *Restart & Run All*:

- `etapa3-spark/mapreduce_rdd.ipynb` — lee los CSVs de `data/`; no necesita
  los contenedores (Spark corre local).
- `etapa4-nosql/redis.ipynb` — requiere el servicio `redis` levantado.
- `etapa4-nosql/mongodb.ipynb` — requiere el servicio `mongo` levantado.

## Notas de reproducibilidad

- **Mismo dataset en todos los motores:** `generar_datos.py` produce a la vez
  `02_seed.sql` (PostgreSQL) y `data/*.csv` (Spark y los notebooks NoSQL), por
  lo que las cuatro tecnologías trabajan sobre datos idénticos.
- **Determinismo:** el generador usa semilla fija (42) y fecha de referencia
  fija (2026-06-09); regenerar no cambia los datos.
- **Sin índices en la Etapa 1:** la consigna lo prohíbe; los índices se crean
  recién en `etapa2-sql-avanzado/03_performance.sql` como parte del análisis
  de performance.
- MongoDB corre **local con Docker** (imagen oficial `mongo:7`, sin
  autenticación) en lugar de Atlas, para que la reproducción no dependa de
  credenciales de nube.
