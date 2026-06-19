# TP Introducción a Bases de Datos — Fábrica de Pastas

Trabajo práctico grupal. Modela una **cadena de fábricas de pastas** con
franquicias independientes (enunciado en `enunciado.pdf`) y la implementa sobre
cuatro tecnologías:

- **PostgreSQL** — modelo relacional (Etapa 1) y SQL avanzado (Etapa 2)
- **Apache Spark** — MapReduce con RDDs (Etapa 3)
- **Redis** y **MongoDB** — persistencia políglota (Etapa 4)

Las cuatro trabajan sobre el **mismo dataset**, generado de forma determinista
por `etapa1-postgres/generar_datos.py`.

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
│   ├── 01_ventanas.sql         # Funciones de ventana
│   ├── 02_estadisticas.sql     # Consultas estadísticas
│   └── 03_performance.sql      # Índices y análisis de performance
├── etapa3-spark/               # MapReduce con RDDs
│   └── mapreduce.ipynb         # Notebook PySpark
└── etapa4-nosql/               # Persistencia políglota
    ├── redis.ipynb             # Notebook Redis
    └── mongodb.ipynb           # Notebook MongoDB
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
| MongoDB | 27017 | `mongodb://localhost:27017` |

Para reiniciar la base desde cero: `docker compose down -v && docker compose up -d`.

Entorno Python (notebooks):

```bash
python -m venv .venv
source .venv/bin/activate      # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

## Notas

- **Determinismo:** el generador usa semilla fija (42), así que produce siempre
  el mismo dataset en SQL y CSV.
- **Sin índices en la Etapa 1:** la consigna lo prohíbe; se crean recién en
  `etapa2-sql-avanzado/03_performance.sql`.
