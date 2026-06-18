# TP Introducción a Bases de Datos — Fábrica de Pastas

Trabajo práctico grupal. Modela una **cadena de fábricas de pastas** con
franquicias independientes (enunciado en `modelo.txt`) y la implementa sobre
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
├── modelo.txt              # Enunciado del dominio
├── DER.png                 # Diagrama Entidad-Relación
├── data/                   # CSVs (mismo dataset que el seed SQL)
├── etapa1-postgres/        # Esquema, seed, validación y generador de datos
├── etapa2-sql-avanzado/    # Ventanas, estadísticas, performance
├── etapa3-spark/           # Notebook MapReduce (RDDs)
└── etapa4-nosql/           # Notebooks Redis y MongoDB
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
