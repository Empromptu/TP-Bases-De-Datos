# Etapa 1.3 - Poblado de datos.
# Genera datos con Faker y los escribe en dos formatos a partir del mismo dataset:
#   1) 02_seed.sql  -> INSERTs para PostgreSQL
#   2) data/*.csv   -> un archivo por tabla (para despues usar Spark y Mongo)

# Uso:  pip install -r requirements.txt  &&  python generar_datos.py

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
# Para que haya barrios con varias franquicias: estos barrios reciben un cupo
# fijo y el resto de las franquicias se reparte aleatoriamente entre todos.
FRANQ_FIJAS_POR_BARRIO = {"Recoleta": 3, "Palermo": 2}
CALLES_POR_BARRIO     = (8, 12)     # rango de calles generadas por barrio
N_INGREDIENTES        = 45
N_RELLENOS            = 50
PASTAS_POR_FRANQ      = (18, 32)    # rango por franquicia
CLIENTES_POR_FRANQ    = (300, 700)  # < 1000 (constraint de negocio)
# Cantidad de compras por cliente: distribucion con cola larga (la mayoria
# compra poco, unos pocos son clientes frecuentes) en vez de uniforme, para que
# la cantidad de clientes por nivel de compras NO salga pareja. Tuneable: ajustar
# los pesos (mas peso = mas clientes con esa cantidad de compras).
COMPRAS_VALORES = list(range(0, 13))                       # 0..12 compras
COMPRAS_PESOS   = [5, 16, 20, 18, 14, 10, 7, 5, 3, 2, 1.5, 1, 0.5]
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
# Catalogo geografico: solo barrios de la Ciudad Autonoma de Buenos Aires.
# No hay jerarquia pais/provincia/localidad; el barrio es el nivel raiz y guarda
# su codigo postal. La cadena del modelo es direccion -> calle -> barrio.
# Se define como lista (nombre, codigo_postal) para que los ids salgan por orden
# de iteracion (estable en Python 3.7+) y el dataset siga siendo determinista.
BARRIOS_CABA = [
    ("Palermo", "1425"),       ("Recoleta", "1113"),
    ("Belgrano", "1426"),      ("Caballito", "1405"),
    ("Almagro", "1172"),       ("Flores", "1406"),
    ("Villa Crespo", "1414"),  ("San Telmo", "1103"),
    ("Boedo", "1218"),         ("Núñez", "1429"),
    ("Villa Urquiza", "1431"), ("Saavedra", "1430"),
    ("Colegiales", "1427"),    ("Chacarita", "1414"),
    ("Barracas", "1267"),      ("La Boca", "1161"),
    ("Constitución", "1153"),  ("Balvanera", "1208"),
    ("Villa Devoto", "1419"),  ("Liniers", "1408"),
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


def n_compras_cliente():
    """Cantidad de compras de un cliente, con distribucion de cola larga."""
    return random.choices(COMPRAS_VALORES, weights=COMPRAS_PESOS, k=1)[0]


def telefono_ar():
    return "+54 11 " + f"{random.randint(4000, 6999)}-{random.randint(1000, 9999)}"


# ============================================================================
# 0) GEOGRAFIA (barrio CABA > calle) + helper de direcciones
# ============================================================================
print("Generando geografia...")
barrios = []                 # (id_barrio, nombre, codigo_postal)
id_barrio_por_nombre = {}    # nombre -> id_barrio
for nombre_barrio, cp in BARRIOS_CABA:
    id_barrio = len(barrios) + 1
    barrios.append([id_barrio, nombre_barrio, cp])
    id_barrio_por_nombre[nombre_barrio] = id_barrio
ids_barrios = [row[0] for row in barrios]

# Cada barrio tiene un pool de calles; las direcciones reutilizan esas calles
# variando el numero de puerta. Nombres unicos dentro del barrio.
calles = []                  # (id_calle, nombre, id_barrio)
calles_por_barrio = {}       # id_barrio -> [id_calle, ...]
for id_barrio in ids_barrios:
    calles_por_barrio[id_barrio] = []
    nombres_usados = set()
    for _ in range(random.randint(*CALLES_POR_BARRIO)):
        # nombre unico dentro del barrio
        while True:
            nombre_calle = fake.street_name()
            if nombre_calle not in nombres_usados:
                nombres_usados.add(nombre_calle)
                break
        id_calle = len(calles) + 1
        calles.append([id_calle, nombre_calle, id_barrio])
        calles_por_barrio[id_barrio].append(id_calle)

# Cada franquicia y cada cliente tiene su propia direccion (relacion 1:1).
direcciones = []   # (id_direccion, id_calle, numero_puerta)


def nueva_direccion(id_barrio):
    """Crea una direccion unica en el barrio dado y devuelve su id.

    Elige una calle del pool del barrio y un numero de puerta. El codigo postal
    no se guarda aca: vive en el barrio y se obtiene via calle -> barrio.
    """
    id_direccion = len(direcciones) + 1
    direcciones.append([
        id_direccion,
        random.choice(calles_por_barrio[id_barrio]),
        random.randint(1, 9500),
    ])
    return id_direccion


# ============================================================================
# 1) FRANQUICIAS
# ============================================================================
print("Generando franquicias...")
# Barrio de cada franquicia: primero los cupos fijos (Recoleta 3, Palermo 2,
# etc.) para garantizar barrios con varias franquicias; el resto, aleatorio
# sobre todos los barrios (puede sumar mas repeticiones).
barrios_franq = []
for nombre_barrio, cupo in FRANQ_FIJAS_POR_BARRIO.items():
    barrios_franq.extend([id_barrio_por_nombre[nombre_barrio]] * cupo)
for _ in range(N_FRANQUICIAS - len(barrios_franq)):
    barrios_franq.append(random.choice(ids_barrios))

franquicias = []
sellos = []
for i in range(N_FRANQUICIAS):
    sello = f"FR-{i+1:03d}"
    sellos.append(sello)
    fecha_inicio = fake.date_between_dates(date(2005, 1, 1), date(2024, 12, 31))
    franquicias.append([
        sello,
        nueva_direccion(barrios_franq[i]),
        f"contacto.{sello.lower().replace('-', '')}@pastas.com.ar",
        telefono_ar(),
        fecha_inicio,
    ])
fecha_inicio_por_sello = {f[0]: f[4] for f in franquicias}

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
pastas_secas = []    # (sello, codigo_pasta)
pastas_rellenas = [] # (sello, codigo_pasta, id_relleno, promedio_kilos_diarios)
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
                sello, codigo,
                random.choice(ids_rellenos),
                round(random.uniform(5, 120), 2),  # promedio kilos diarios
            ])
        else:
            nombre = random.choice(PASTAS_SECAS)
            precio = round(random.uniform(1500, 4000), 2)
            pastas.append([sello, codigo, nombre, precio, "S"])
            pastas_secas.append([sello, codigo])
        pastas_por_franq[sello].append((codigo, precio))

# ============================================================================
# 5) CLIENTES  (<= 1000 por franquicia; favorita de la misma franquicia)
# ============================================================================
print("Generando clientes...")
clientes = []  # (id, sello, id_direccion, nombre, apellido, doc, fnac, email, tel, cod_fav)
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
        # el cliente vive en cualquier barrio de CABA (no atado al de su franquicia)
        clientes.append([id_cliente, sello,
                         nueva_direccion(random.choice(ids_barrios)),
                         nombre, apellido, doc, fnac, email,
                         telefono_ar(), favorita])

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
    n_compras = n_compras_cliente()
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
            detalle_compra.append([id_compra, sello, codigo, cantidad, precio])

# ============================================================================
# Resumen de volúmenes
# ============================================================================
print("\n=== Volúmenes generados ===")
print(f"  barrios              : {len(barrios):>7}")
print(f"  calles               : {len(calles):>7}")
print(f"  direcciones          : {len(direcciones):>7}")
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

    emit_inserts(fh, "barrio",
                 ["id_barrio", "nombre", "codigo_postal"], barrios)
    emit_inserts(fh, "calle",
                 ["id_calle", "nombre", "id_barrio"], calles)
    emit_inserts(fh, "direccion",
                 ["id_direccion", "id_calle", "numero_puerta"], direcciones)
    emit_inserts(fh, "franquicia",
                 ["sello", "id_direccion", "email", "telefono",
                  "fecha_inicio"], franquicias)
    emit_inserts(fh, "ingrediente", ["id_ingrediente", "nombre"], ingredientes)
    emit_inserts(fh, "relleno", ["id_relleno", "nombre"], rellenos)
    emit_inserts(fh, "relleno_ingrediente",
                 ["id_relleno", "id_ingrediente", "cantidad"], relleno_ingrediente)
    emit_inserts(fh, "pasta",
                 ["sello", "codigo_pasta", "nombre", "precio_por_kilo", "tipo"], pastas)
    emit_inserts(fh, "pasta_seca", ["sello", "codigo_pasta"], pastas_secas)
    emit_inserts(fh, "pasta_rellena",
                 ["sello", "codigo_pasta", "id_relleno",
                  "promedio_kilos_diarios"], pastas_rellenas)
    emit_inserts(fh, "cliente",
                 ["id_cliente", "sello", "id_direccion", "nombre", "apellido",
                  "documento", "fecha_nacimiento", "email", "telefono",
                  "codigo_favorita"], clientes)
    emit_inserts(fh, "compra", ["id_compra", "id_cliente", "fecha_hora"], compras)
    emit_inserts(fh, "detalle_compra",
                 ["id_compra", "sello", "codigo_pasta", "cantidad_kg",
                  "precio_unitario"], detalle_compra)

    # Reajustar las secuencias SERIAL al máximo id insertado
    fh.write("-- Sincronizar secuencias con los ids insertados explícitamente\n")
    fh.write("SELECT setval('pastas.barrio_id_barrio_seq', "
             f"{len(barrios)});\n")
    fh.write("SELECT setval('pastas.calle_id_calle_seq', "
             f"{len(calles)});\n")
    fh.write("SELECT setval('pastas.direccion_id_direccion_seq', "
             f"{len(direcciones)});\n")
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
write_csv("barrio", ["id_barrio", "nombre", "codigo_postal"], barrios)
write_csv("calle", ["id_calle", "nombre", "id_barrio"], calles)
write_csv("direccion",
          ["id_direccion", "id_calle", "numero_puerta"], direcciones)
write_csv("franquicia",
          ["sello", "id_direccion", "email", "telefono", "fecha_inicio"],
          franquicias)
write_csv("ingrediente", ["id_ingrediente", "nombre"], ingredientes)
write_csv("relleno", ["id_relleno", "nombre"], rellenos)
write_csv("relleno_ingrediente",
          ["id_relleno", "id_ingrediente", "cantidad"], relleno_ingrediente)
write_csv("pasta",
          ["sello", "codigo_pasta", "nombre", "precio_por_kilo", "tipo"], pastas)
write_csv("pasta_seca", ["sello", "codigo_pasta"], pastas_secas)
write_csv("pasta_rellena",
          ["sello", "codigo_pasta", "id_relleno",
           "promedio_kilos_diarios"], pastas_rellenas)
write_csv("cliente",
          ["id_cliente", "sello", "id_direccion", "nombre", "apellido",
           "documento", "fecha_nacimiento", "email", "telefono",
           "codigo_favorita"], clientes)
write_csv("compra", ["id_compra", "id_cliente", "fecha_hora"], compras)
write_csv("detalle_compra",
          ["id_compra", "sello", "codigo_pasta", "cantidad_kg",
           "precio_unitario"], detalle_compra)

print("\nListo. Generado 02_seed.sql y CSVs en data/.")
