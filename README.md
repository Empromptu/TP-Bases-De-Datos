# TP Introducción a Bases de Datos — Fábrica de Pastas

Trabajo práctico grupal. Modela una **cadena de fábricas de pastas** con
franquicias independientes (enunciado en `enunciado.pdf`) y la implementa sobre
cuatro tecnologías:

- **PostgreSQL** — modelo relacional (Etapa 1) y SQL avanzado (Etapa 2)
- **Apache Spark** — MapReduce con RDDs (Etapa 3)
- **Redis** y **MongoDB** — persistencia políglota (Etapa 4)

PostgreSQL, Spark y Redis trabajan sobre el **mismo dataset**, generado de
forma determinista por `etapa1-postgres/generar_datos.py`. MongoDB genera su
propio conjunto de documentos (con Faker, dentro del notebook) para mostrar un
modelo documental denormalizado.

## Modelo de datos (DER)

![Diagrama Entidad-Relación](DER.png)

## Estructura

```
├── docker-compose.yml      # Postgres + Redis + Mongo
├── enunciado.pdf           # Consigna del TP
├── DER.png                 # Diagrama Entidad-Relación
├── data/                       # CSVs (mismo dataset que el seed SQL)
├── etapa1-postgres/            # Modelo relacional
│   ├── 01_schema.sql           # DDL: tablas y restricciones
│   ├── 02_seed.sql             # Carga de datos
│   ├── 03_validacion.sql       # Consultas de validación
│   ├── generar_datos.py        # Generador determinista (semilla 42) → SQL y CSV
│   └── requirements.txt        # Dependencias del generador
├── etapa2-sql-avanzado/        # SQL avanzado
│   └── script-consultas-avanzadas.sql  # Funciones de ventana, estadísticas e índices
├── etapa3-spark/               # MapReduce con RDDs
│   └── mapreduce.ipynb         # Notebook PySpark
└── etapa4-nosql/               # Persistencia políglota
    ├── redis.ipynb             # Notebook Redis
    └── MongoDB.ipynb           # Notebook MongoDB
```

## Requisitos

- **Docker / Docker Compose** — único requisito para las bases (corren en contenedores)
- **Python 3.10+** — notebooks y generador de datos
- **JDK 11 o 17** — solo para PySpark (Etapa 3)

## Puesta en marcha

```bash
docker compose up -d
```

Levanta los tres servicios y **crea y puebla PostgreSQL solo** en el primer
arranque (ejecuta `01_schema.sql` → `02_seed.sql` → `03_validacion.sql`).

| Servicio | Puerto | Conexión |
|---|---|---|
| PostgreSQL | 5432 | `postgresql://postgres:pastas@localhost:5432/pastas_tp` |
| Redis | 6379 | `redis://localhost:6379` |
| MongoDB | 27017 | `mongodb://mongo:pastas_mongo@localhost:27017/` |

Para reiniciar la base desde cero: `docker compose down -v && docker compose up -d`.

Entorno Python (notebooks):

```bash
python -m venv .venv
source .venv/bin/activate      # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

## Cómo correr cada etapa

Antes de cualquier etapa, levantá las tres bases:

```bash
docker compose up -d
```

### Etapa 1 — Modelo relacional (PostgreSQL)

Se carga **sola** al levantar los contenedores (schema → seed → validación).
Para abrir una consola SQL contra la base ya poblada:

```bash
docker exec -it tpdb-postgres psql -U postgres -d pastas_tp
```

Para volver a correr las consultas de validación:

```bash
docker exec -it tpdb-postgres psql -U postgres -d pastas_tp -f /docker-entrypoint-initdb.d/03_validacion.sql
```

Para regenerar el dataset (reescribe `02_seed.sql` y los CSV de `data/`):

```bash
cd etapa1-postgres
pip install -r requirements.txt
python generar_datos.py
```

### Etapa 2 — SQL avanzado (PostgreSQL)

No se ejecuta sola: se corre a mano sobre la base ya poblada por la Etapa 1.

```bash
docker exec -i tpdb-postgres psql -U postgres -d pastas_tp < etapa2-sql-avanzado/script-consultas-avanzadas.sql
```

### Etapas 3 y 4 — Spark, Redis y MongoDB (notebooks)

Con el venv activado y los contenedores arriba, lanzá Jupyter:

```bash
jupyter notebook
```

Se abre en el navegador; desde ahí abrí y ejecutá cada notebook **de arriba hacia abajo**:

- `etapa3-spark/mapreduce.ipynb` — Spark (requiere **JDK 11 o 17**).
- `etapa4-nosql/redis.ipynb` — Redis (requiere el contenedor `tpdb-redis` levantado).
- `etapa4-nosql/MongoDB.ipynb` — MongoDB (requiere el contenedor `tpdb-mongo` levantado).

## Notas

- **Determinismo:** el generador usa semilla fija (42), así que produce siempre
  el mismo dataset en SQL y CSV.
- **Sin índices en la Etapa 1:** la consigna lo prohíbe; se crean recién en
  `etapa2-sql-avanzado/script-consultas-avanzadas.sql`.
