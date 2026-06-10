# Etapa 1.1 — Elección del modelo (DER)

## Dominio elegido y relevancia

Cadena de **fábricas de pastas** con franquicias independientes en CABA. Es un
dominio rico porque combina: una **jerarquía de especialización** (pastas secas vs.
rellenas), una **entidad débil** (la pasta existe solo dentro de su franquicia),
una **relación N:M con atributo** (rellenos ↔ ingredientes con cantidad) y un
flujo **transaccional** (clientes → compras) que genera el volumen necesario para
las etapas analíticas (SQL avanzado, Spark, NoSQL).

## Diagrama Entidad-Relación

```mermaid
erDiagram
    FRANQUICIA ||--o{ PASTA          : "elabora"
    FRANQUICIA ||--o{ CLIENTE        : "tiene (máx 1000)"
    PASTA      ||--o| PASTA_SECA     : "es-un"
    PASTA      ||--o| PASTA_RELLENA  : "es-un"
    PASTA_RELLENA }o--|| RELLENO     : "usa"
    RELLENO    ||--o{ RELLENO_INGREDIENTE : "compuesto (máx 6)"
    INGREDIENTE||--o{ RELLENO_INGREDIENTE : "aparece en"
    CLIENTE    ||--o{ COMPRA         : "realiza"
    CLIENTE    }o--o| PASTA          : "favorita"
    COMPRA     ||--|{ DETALLE_COMPRA : "contiene"
    PASTA      ||--o{ DETALLE_COMPRA : "vendida en"

    FRANQUICIA {
        varchar sello PK
        varchar calle
        int     numero_puerta
        varchar codigo_postal
        varchar barrio
        varchar email
        varchar telefono
        date    fecha_inicio
    }
    PASTA {
        varchar sello PK_FK
        varchar codigo_pasta PK
        varchar nombre
        numeric precio_por_kilo
        char    tipo "S|R"
    }
    PASTA_SECA {
        varchar sello PK_FK
        varchar codigo_pasta PK_FK
    }
    PASTA_RELLENA {
        varchar sello PK_FK
        varchar codigo_pasta PK_FK
        int     id_relleno FK
        numeric promedio_kilos_diarios
    }
    RELLENO {
        int     id_relleno PK
        varchar nombre
    }
    INGREDIENTE {
        int     id_ingrediente PK
        varchar nombre
    }
    RELLENO_INGREDIENTE {
        int     id_relleno PK_FK
        int     id_ingrediente PK_FK
        numeric cantidad
    }
    CLIENTE {
        int     id_cliente PK
        varchar sello FK
        varchar nombre
        varchar apellido
        varchar documento
        date    fecha_nacimiento
        varchar email
        varchar telefono
        varchar codigo_favorita FK
    }
    COMPRA {
        int       id_compra PK
        int       id_cliente FK
        timestamp fecha_hora
    }
    DETALLE_COMPRA {
        int     id_compra PK_FK
        varchar sello PK_FK
        varchar codigo_pasta PK_FK
        numeric cantidad_kg
        numeric precio_unitario
    }
```

## Decisiones de diseño

| Decisión | Justificación |
|---|---|
| **Pasta como entidad débil** con PK compuesta `(sello, codigo_pasta)` | El enunciado exige que "los fideos tirabuzón de A se distingan de los de B". La identidad de la pasta depende de su franquicia. |
| **Jerarquía disjunta** Pasta → {Seca, Rellena} mediante tablas por subtipo | Solo las rellenas tienen relleno y promedio de kilos diarios; modelar dos tablas evita columnas nulas y captura la especialización del enunciado. |
| **Disjunción forzada por FK con `tipo`** | `UNIQUE(sello, codigo_pasta, tipo)` permite que cada subtabla referencie el tipo y garantice que una pasta esté en una sola subtabla. |
| **Relleno como entidad propia** (no atributo de la pasta) | El enunciado dice que un ingrediente puede repetirse entre rellenos → N:M; y modela rellenos potencialmente reutilizables. |
| **`cantidad` en RELLENO_INGREDIENTE** | El enunciado pide guardar cuánta cantidad de cada ingrediente usa cada relleno. |
| **Pasta favorita reusando la columna `sello`** | La FK `(sello, codigo_favorita) → pasta` obliga a que la favorita sea de la franquicia del cliente, sin trigger extra. |
| **`precio_unitario` snapshot en DETALLE_COMPRA** *(agregado)* | El precio por kilo cambia con el tiempo; guardar el precio al momento de la compra preserva la historia de ventas. |
| **DETALLE_COMPRA** *(agregado)* | No está explícito en el enunciado, pero da el volumen y la variedad que necesitan las consultas analíticas de las Etapas 2–4. |
| **`promedio_kilos_diarios` como atributo** | El enunciado lo pide como dato a guardar de las pastas rellenas, no como cálculo derivado. |

### Qué se dejó fuera
- **Stock / inventario**: el enunciado no lo menciona; se omite para no inflar el modelo.
- **Empleados / sucursales físicas**: fuera del alcance descripto.

## Constraints de negocio

| # | Constraint | Implementación |
|---|---|---|
| C1 | Una pasta pertenece a una sola franquicia y se identifica con ella | PK compuesta `(sello, codigo_pasta)` + FK a franquicia |
| C2 | Una pasta es seca **o** rellena, nunca ambas | Jerarquía disjunta vía `UNIQUE(...,tipo)` + FK con literal de tipo |
| C3 | Un relleno tiene **máximo 6 ingredientes** | Trigger `trg_max_ingredientes_relleno` |
| C4 | Una franquicia tiene **máximo 1000 clientes** | Trigger `trg_max_clientes_franquicia` |
| C5 | El precio por kilo es **positivo** | `CHECK (precio_por_kilo > 0)` |
| C6 | Cantidades (ingrediente, kg vendidos) **positivas** | `CHECK (cantidad > 0)`, `CHECK (cantidad_kg > 0)` |
| C7 | La fecha de inicio / nacimiento / compra no es futura | `CHECK (... <= CURRENT_DATE/TIMESTAMP)` |
| C8 | La pasta favorita es de la franquicia del cliente | FK `(sello, codigo_favorita) → pasta` |
| C9 | Documento de cliente único por franquicia | `UNIQUE (sello, documento)` |
| C10 | Email con formato válido y único por franquicia/global | `CHECK (email LIKE ...)` + `UNIQUE` |

> Los diagramas Mermaid se renderizan en GitHub y en VS Code (extensión Markdown
> Preview Mermaid). Para el informe PDF, exportar a imagen con mermaid.live.
