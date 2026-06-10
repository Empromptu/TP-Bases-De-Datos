#!/usr/bin/env python3
# =============================================================================
# Trabajo Práctico - Introducción a Bases de Datos
# Etapa 1.3 - Poblado de datos
#
# Genera datos coherentes para el dominio "fábrica de pastas" usando Faker y
# produce DOS salidas a partir del MISMO dataset (así Postgres, Spark y Mongo
# trabajan sobre datos idénticos):
#
#   1) etapa1-postgres/02_seed.sql  -> INSERTs batcheados para PostgreSQL
#   2) data/*.csv                   -> una tabla por archivo (para Spark/Mongo)
#
# Respeta TODAS las constraints del esquema (01_schema.sql):
#   - PK compuestas, FKs coherentes (sin violaciones)
#   - jerarquía disjunta seca/rellena
#   - máx 6 ingredientes por relleno
#   - máx 1000 clientes por franquicia
#   - pasta favorita de la MISMA franquicia del cliente
#   - precios y cantidades positivas, fechas no futuras
#
# Es DETERMINISTA (semilla fija) para que el poblado sea reproducible.
#
# Uso:
#   pip install -r requirements.txt
#   python generar_datos.py
# =============================================================================

import csv
import os
import random
from datetime import datetime, date, timedelta

from faker import Faker

# ----------------------------------------------------------------------------
# Configuración / parámetros de volumen
# ----------------------------------------------------------------------------
SEED = 42
HOY = date(2026, 6, 9)  # fecha fija para reproducibilidad (no usar date.today())

N_FRANQUICIAS         = 15
N_INGREDIENTES        = 45
N_RELLENOS            = 50
PASTAS_POR_FRANQ      = (18, 32)    # rango por franquicia
CLIENTES_POR_FRANQ    = (300, 700)  # < 1000 (constraint de negocio)
COMPRAS_POR_CLIENTE   = (0, 8)      # algunos clientes no compran
ITEMS_POR_COMPRA      = (1, 4)
ING_POR_RELLENO       = (2, 6)      # <= 6 (constraint de negocio)
BATCH                 = 500         # filas por sentencia INSERT multi-row

# Rutas de salida
BASE_DIR   = os.path.dirname(os.path.abspath(__file__))
REPO_DIR   = os.path.dirname(BASE_DIR)
SQL_PATH   = os.path.join(BASE_DIR, "02_seed.sql")
DATA_DIR   = os.path.join(REPO_DIR, "data")

fake = Faker("es_AR")
Faker.seed(SEED)
random.seed(SEED)

# ----------------------------------------------------------------------------
# Catálogos del dominio (datos realistas de pastas)
# ----------------------------------------------------------------------------
BARRIOS_CABA = [
    "Palermo", "Recoleta", "Belgrano", "Caballito", "Almagro", "Flores",
    "Villa Crespo", "San Telmo", "Boedo", "Núñez", "Villa Urquiza",
    "Saavedra", "Colegiales", "Chacarita", "Barracas", "La Boca",
    "Constitución", "Balvanera", "Villa Devoto", "Liniers",
]

PASTAS_SECAS = [
    "Spaghetti", "Tirabuzón", "Mostacholes", "Ñoquis", "Tallarín",
    "Fideos finos", "Penne", "Fusilli", "Tagliatelle", "Lasaña",
    "Cintas", "Codito", "Farfalle", "Rigatoni", "Vermicelli",
]
PASTAS_RELLENAS = [
    "Ravioles", "Sorrentinos", "Capeletti", "Agnolotti", "Canelones",
    "Ravioloni", "Tortellini", "Panzotti", "Mezzelune",
]
INGREDIENTES_POSIBLES = [
    "Ricota", "Espinaca", "Jamón", "Queso mozzarella", "Queso parmesano",
    "Nuez", "Calabaza", "Carne vacuna", "Pollo", "Choclo", "Verdura",
    "Salmón", "Cebolla", "Acelga", "Hongos", "Roquefort", "Provolone",
    "Tomate seco", "Albahaca", "Panceta", "Huevo", "Pera", "Batata",
    "Berenjena", "Zucchini", "Ajo", "Morrón", "Aceitunas", "Atún",
    "Crema", "Almendra", "Cordero", "Cerdo", "Trufa", "Manteca",
    "Sésamo", "Perejil", "Nuez moscada", "Pistacho", "Mascarpone",
    "Burrata", "Gorgonzola", "Radicchio", "Puerro", "Castaña",
]
RELLENO_PREFIJOS = ["Clásico de", "Especial de", "Casero de", "Gourmet de",
                    "Tradicional de", "Premium de"]

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
def sql_str(value):
    """Serializa un valor Python a literal SQL seguro."""
    if value is None:
        return "NULL"
    if isinstance(value, bool):
        return "TRUE" if value else "FALSE"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, (datetime,)):
        return "'" + value.strftime("%Y-%m-%d %H:%M:%S") + "'"
    if isinstance(value, date):
        return "'" + value.strftime("%Y-%m-%d") + "'"
    # string: escapar comillas simples
    return "'" + str(value).replace("'", "''") + "'"


def emit_inserts(fh, table, columns, rows):
    """Escribe INSERTs multi-row batcheados para una tabla."""
    if not rows:
        return
    col_list = ", ".join(columns)
    for i in range(0, len(rows), BATCH):
        chunk = rows[i:i + BATCH]
        fh.write(f"INSERT INTO pastas.{table} ({col_list}) VALUES\n")
        values = ",\n".join(
            "(" + ", ".join(sql_str(v) for v in row) + ")" for row in chunk
        )
        fh.write(values + ";\n")
    fh.write("\n")


def write_csv(table, columns, rows):
    """Exporta una tabla a CSV (para Spark / Mongo)."""
    path = os.path.join(DATA_DIR, f"{table}.csv")
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(columns)
        w.writerows(rows)


def telefono_ar():
    return "+54 11 " + f"{random.randint(4000, 6999)}-{random.randint(1000, 9999)}"


# ============================================================================
# 1) FRANQUICIAS
# ============================================================================
print("Generando franquicias...")
franquicias = []
sellos = []
for i in range(N_FRANQUICIAS):
    sello = f"FR-{i+1:03d}"
    sellos.append(sello)
    fecha_inicio = fake.date_between_dates(date(2005, 1, 1), date(2024, 12, 31))
    franquicias.append([
        sello,
        fake.street_name(),
        random.randint(1, 9500),
        str(random.randint(1000, 1900)),
        random.choice(BARRIOS_CABA),
        f"contacto.{sello.lower().replace('-', '')}@pastas.com.ar",
        telefono_ar(),
        fecha_inicio,
    ])
fecha_inicio_por_sello = {f[0]: f[7] for f in franquicias}

# ============================================================================
# 2) INGREDIENTES
# ============================================================================
print("Generando ingredientes...")
nombres_ing = random.sample(INGREDIENTES_POSIBLES,
                            min(N_INGREDIENTES, len(INGREDIENTES_POSIBLES)))
ingredientes = [[i + 1, nombre] for i, nombre in enumerate(nombres_ing)]
ids_ingredientes = [row[0] for row in ingredientes]

# ============================================================================
# 3) RELLENOS + RELLENO_INGREDIENTE  (<= 6 ingredientes por relleno)
# ============================================================================
print("Generando rellenos e ingredientes de relleno...")
rellenos = []
relleno_ingrediente = []
nombres_relleno_usados = set()
for r in range(N_RELLENOS):
    # nombre único de relleno
    while True:
        base = random.choice(INGREDIENTES_POSIBLES)
        nombre = f"{random.choice(RELLENO_PREFIJOS)} {base.lower()}"
        if nombre not in nombres_relleno_usados:
            nombres_relleno_usados.add(nombre)
            break
    id_relleno = r + 1
    rellenos.append([id_relleno, nombre])
    # entre 2 y 6 ingredientes distintos
    k = random.randint(*ING_POR_RELLENO)
    for ing in random.sample(ids_ingredientes, k):
        cantidad = round(random.uniform(0.05, 2.5), 3)  # kg de ingrediente
        relleno_ingrediente.append([id_relleno, ing, cantidad])
ids_rellenos = [row[0] for row in rellenos]

# ============================================================================
# 4) PASTAS (+ subtipos seca / rellena)
# ============================================================================
print("Generando pastas...")
pastas = []          # (sello, codigo_pasta, nombre, precio_por_kilo, tipo)
pastas_secas = []    # (sello, codigo_pasta, tipo)
pastas_rellenas = [] # (sello, codigo_pasta, tipo, id_relleno, promedio_kilos_diarios)
pastas_por_franq = {s: [] for s in sellos}  # sello -> [(codigo, precio)]

for sello in sellos:
    n = random.randint(*PASTAS_POR_FRANQ)
    # mezclamos secas y rellenas
    for c in range(n):
        codigo = f"P{c+1:03d}"
        es_rellena = random.random() < 0.45
        if es_rellena:
            nombre = random.choice(PASTAS_RELLENAS)
            precio = round(random.uniform(4000, 9000), 2)
            pastas.append([sello, codigo, nombre, precio, "R"])
            pastas_rellenas.append([
                sello, codigo, "R",
                random.choice(ids_rellenos),
                round(random.uniform(5, 120), 2),  # promedio kilos diarios
            ])
        else:
            nombre = random.choice(PASTAS_SECAS)
            precio = round(random.uniform(1500, 4000), 2)
            pastas.append([sello, codigo, nombre, precio, "S"])
            pastas_secas.append([sello, codigo, "S"])
        pastas_por_franq[sello].append((codigo, precio))

# ============================================================================
# 5) CLIENTES  (<= 1000 por franquicia; favorita de la misma franquicia)
# ============================================================================
print("Generando clientes...")
clientes = []  # (id, sello, nombre, apellido, doc, fnac, email, tel, cod_fav)
id_cliente = 0
documentos_por_franq = {s: set() for s in sellos}
for sello in sellos:
    n = random.randint(*CLIENTES_POR_FRANQ)  # siempre < 1000
    codigos_franq = [c for c, _ in pastas_por_franq[sello]]
    for _ in range(n):
        id_cliente += 1
        # documento único dentro de la franquicia
        while True:
            doc = str(random.randint(20_000_000, 45_000_000))
            if doc not in documentos_por_franq[sello]:
                documentos_por_franq[sello].add(doc)
                break
        nombre = fake.first_name()
        apellido = fake.last_name()
        fnac = fake.date_between_dates(date(1950, 1, 1), date(2007, 12, 31))
        email = f"{nombre}.{apellido}.{id_cliente}@mail.com".lower().replace(" ", "")
        # favorita: 80% tiene, de su propia franquicia
        favorita = random.choice(codigos_franq) if (codigos_franq and random.random() < 0.8) else None
        clientes.append([id_cliente, sello, nombre, apellido, doc, fnac,
                         email, telefono_ar(), favorita])

# ============================================================================
# 6) COMPRAS + DETALLE_COMPRA
# ============================================================================
print("Generando compras y detalles...")
compras = []         # (id_compra, id_cliente, fecha_hora)
detalle_compra = []  # (id_compra, sello, codigo_pasta, cantidad_kg, precio_unitario)
id_compra = 0
for cli in clientes:
    cli_id, sello = cli[0], cli[1]
    codigos_precios = pastas_por_franq[sello]
    if not codigos_precios:
        continue
    n_compras = random.randint(*COMPRAS_POR_CLIENTE)
    # las compras no pueden ser anteriores al inicio de la franquicia
    inicio = max(fecha_inicio_por_sello[sello], HOY - timedelta(days=730))
    for _ in range(n_compras):
        id_compra += 1
        fecha_hora = fake.date_time_between_dates(
            datetime(inicio.year, inicio.month, inicio.day, 9, 0, 0),
            datetime(HOY.year, HOY.month, HOY.day, 21, 0, 0),
        )
        compras.append([id_compra, cli_id, fecha_hora])
        # items distintos en la compra
        n_items = random.randint(*ITEMS_POR_COMPRA)
        elegidos = random.sample(codigos_precios, min(n_items, len(codigos_precios)))
        for codigo, precio in elegidos:
            cantidad = round(random.uniform(0.25, 5.0), 3)
            # snapshot del precio con pequeña variación histórica (+-8%)
            precio_unit = round(precio * random.uniform(0.92, 1.08), 2)
            detalle_compra.append([id_compra, sello, codigo, cantidad, precio_unit])

# ============================================================================
# Resumen de volúmenes
# ============================================================================
print("\n=== Volúmenes generados ===")
print(f"  franquicias          : {len(franquicias):>7}")
print(f"  ingredientes         : {len(ingredientes):>7}")
print(f"  rellenos             : {len(rellenos):>7}")
print(f"  relleno_ingrediente  : {len(relleno_ingrediente):>7}")
print(f"  pastas               : {len(pastas):>7}")
print(f"    - secas            : {len(pastas_secas):>7}")
print(f"    - rellenas         : {len(pastas_rellenas):>7}")
print(f"  clientes             : {len(clientes):>7}")
print(f"  compras              : {len(compras):>7}")
print(f"  detalle_compra       : {len(detalle_compra):>7}")
total_principales = len(clientes) + len(compras) + len(detalle_compra)
print(f"  -> registros en tablas principales: {total_principales} (mínimo exigido: 5000)")

# ============================================================================
# Escritura del script SQL
# ============================================================================
print(f"\nEscribiendo {SQL_PATH} ...")
with open(SQL_PATH, "w", encoding="utf-8") as fh:
    fh.write("-- =============================================================\n")
    fh.write("-- Etapa 1.3 - Poblado de datos (GENERADO por generar_datos.py)\n")
    fh.write(f"-- Semilla: {SEED}  |  Fecha de referencia: {HOY}\n")
    fh.write("-- No editar a mano: re-generar con `python generar_datos.py`.\n")
    fh.write("-- =============================================================\n\n")
    fh.write("SET search_path TO pastas;\n")
    fh.write("BEGIN;\n\n")

    emit_inserts(fh, "franquicia",
                 ["sello", "calle", "numero_puerta", "codigo_postal", "barrio",
                  "email", "telefono", "fecha_inicio"], franquicias)
    emit_inserts(fh, "ingrediente", ["id_ingrediente", "nombre"], ingredientes)
    emit_inserts(fh, "relleno", ["id_relleno", "nombre"], rellenos)
    emit_inserts(fh, "relleno_ingrediente",
                 ["id_relleno", "id_ingrediente", "cantidad"], relleno_ingrediente)
    emit_inserts(fh, "pasta",
                 ["sello", "codigo_pasta", "nombre", "precio_por_kilo", "tipo"], pastas)
    emit_inserts(fh, "pasta_seca", ["sello", "codigo_pasta", "tipo"], pastas_secas)
    emit_inserts(fh, "pasta_rellena",
                 ["sello", "codigo_pasta", "tipo", "id_relleno",
                  "promedio_kilos_diarios"], pastas_rellenas)
    emit_inserts(fh, "cliente",
                 ["id_cliente", "sello", "nombre", "apellido", "documento",
                  "fecha_nacimiento", "email", "telefono", "codigo_favorita"], clientes)
    emit_inserts(fh, "compra", ["id_compra", "id_cliente", "fecha_hora"], compras)
    emit_inserts(fh, "detalle_compra",
                 ["id_compra", "sello", "codigo_pasta", "cantidad_kg",
                  "precio_unitario"], detalle_compra)

    # Reajustar las secuencias SERIAL al máximo id insertado
    fh.write("-- Sincronizar secuencias con los ids insertados explícitamente\n")
    fh.write("SELECT setval('pastas.ingrediente_id_ingrediente_seq', "
             f"{len(ingredientes)});\n")
    fh.write("SELECT setval('pastas.relleno_id_relleno_seq', "
             f"{len(rellenos)});\n")
    fh.write("SELECT setval('pastas.cliente_id_cliente_seq', "
             f"{len(clientes)});\n")
    fh.write("SELECT setval('pastas.compra_id_compra_seq', "
             f"{len(compras)});\n\n")
    fh.write("COMMIT;\n")

# ============================================================================
# Escritura de CSVs (para Spark / Mongo)
# ============================================================================
print(f"Escribiendo CSVs en {DATA_DIR} ...")
os.makedirs(DATA_DIR, exist_ok=True)
write_csv("franquicia",
          ["sello", "calle", "numero_puerta", "codigo_postal", "barrio",
           "email", "telefono", "fecha_inicio"], franquicias)
write_csv("ingrediente", ["id_ingrediente", "nombre"], ingredientes)
write_csv("relleno", ["id_relleno", "nombre"], rellenos)
write_csv("relleno_ingrediente",
          ["id_relleno", "id_ingrediente", "cantidad"], relleno_ingrediente)
write_csv("pasta",
          ["sello", "codigo_pasta", "nombre", "precio_por_kilo", "tipo"], pastas)
write_csv("pasta_seca", ["sello", "codigo_pasta", "tipo"], pastas_secas)
write_csv("pasta_rellena",
          ["sello", "codigo_pasta", "tipo", "id_relleno",
           "promedio_kilos_diarios"], pastas_rellenas)
write_csv("cliente",
          ["id_cliente", "sello", "nombre", "apellido", "documento",
           "fecha_nacimiento", "email", "telefono", "codigo_favorita"], clientes)
write_csv("compra", ["id_compra", "id_cliente", "fecha_hora"], compras)
write_csv("detalle_compra",
          ["id_compra", "sello", "codigo_pasta", "cantidad_kg",
           "precio_unitario"], detalle_compra)

print("\nListo. Generado 02_seed.sql y CSVs en data/.")
