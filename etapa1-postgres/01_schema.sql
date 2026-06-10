-- =============================================================================
-- Trabajo Práctico - Introducción a Bases de Datos
-- Dominio: Cadena de fábricas de pastas (franquicias)
-- Etapa 1.2 - Implementación del modelo relacional en PostgreSQL
--
-- Este script crea el esquema completo: tablas, PK/FK y constraints de negocio.
-- NO incluye índices (se agregan en la Etapa 2.3 - Análisis de Performance).
--
-- Orden de creación respeta las dependencias de FK.
-- Es idempotente: se puede re-ejecutar de punta a punta sin modificaciones.
-- =============================================================================

DROP SCHEMA IF EXISTS pastas CASCADE;
CREATE SCHEMA pastas;
SET search_path TO pastas;

-- -----------------------------------------------------------------------------
-- FRANQUICIA
-- Cada franquicia es independiente y se identifica por su "sello".
-- Guardamos dirección completa, contacto y fecha de inicio de operaciones.
-- -----------------------------------------------------------------------------
CREATE TABLE franquicia (
    sello           VARCHAR(20)  PRIMARY KEY,
    -- Dirección completa (atributo compuesto del enunciado)
    calle           VARCHAR(120) NOT NULL,
    numero_puerta   INTEGER      NOT NULL,
    codigo_postal   VARCHAR(10)  NOT NULL,
    barrio          VARCHAR(80)  NOT NULL,
    -- Contacto
    email           VARCHAR(150) NOT NULL,
    telefono        VARCHAR(30)  NOT NULL,
    fecha_inicio    DATE         NOT NULL,

    CONSTRAINT uq_franquicia_email      UNIQUE (email),
    CONSTRAINT chk_franquicia_puerta    CHECK (numero_puerta > 0),
    CONSTRAINT chk_franquicia_email     CHECK (email LIKE '%_@_%.__%'),
    -- Una franquicia no puede haber iniciado operaciones en el futuro
    CONSTRAINT chk_franquicia_fecha     CHECK (fecha_inicio <= CURRENT_DATE)
);

-- -----------------------------------------------------------------------------
-- PASTA  (entidad débil de FRANQUICIA)
-- "Los fideos tirabuzón de la franquicia A deben distinguirse de los de B":
-- por eso la PK es compuesta (sello, codigo_pasta). La pasta no existe sin
-- su franquicia (ON DELETE CASCADE).
--
-- Jerarquía de especialización DISJUNTA: tipo 'S' (seca) o 'R' (rellena).
-- El UNIQUE (sello, codigo_pasta, tipo) habilita que las subtablas referencien
-- también el tipo y así garanticen que una pasta seca solo puede ligarse a una
-- fila de tipo 'S' y una rellena a una de tipo 'R'.
-- -----------------------------------------------------------------------------
CREATE TABLE pasta (
    sello           VARCHAR(20)   NOT NULL,
    codigo_pasta    VARCHAR(20)   NOT NULL,
    nombre          VARCHAR(100)  NOT NULL,
    precio_por_kilo NUMERIC(10,2) NOT NULL,
    tipo            CHAR(1)       NOT NULL,

    CONSTRAINT pk_pasta            PRIMARY KEY (sello, codigo_pasta),
    CONSTRAINT fk_pasta_franquicia FOREIGN KEY (sello)
        REFERENCES franquicia (sello) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_pasta_precio    CHECK (precio_por_kilo > 0),
    CONSTRAINT chk_pasta_tipo      CHECK (tipo IN ('S', 'R')),
    -- Necesario para que las subtablas referencien (sello, codigo_pasta, tipo)
    CONSTRAINT uq_pasta_tipo       UNIQUE (sello, codigo_pasta, tipo)
);

-- -----------------------------------------------------------------------------
-- PASTA_SECA  (subtipo de PASTA)
-- No agrega atributos propios en el enunciado; modela la especialización.
-- La FK incluye el literal 'S' para forzar la disjunción de la jerarquía.
-- -----------------------------------------------------------------------------
CREATE TABLE pasta_seca (
    sello        VARCHAR(20) NOT NULL,
    codigo_pasta VARCHAR(20) NOT NULL,
    tipo         CHAR(1)     NOT NULL DEFAULT 'S',

    CONSTRAINT pk_pasta_seca   PRIMARY KEY (sello, codigo_pasta),
    CONSTRAINT chk_seca_tipo   CHECK (tipo = 'S'),
    CONSTRAINT fk_seca_pasta   FOREIGN KEY (sello, codigo_pasta, tipo)
        REFERENCES pasta (sello, codigo_pasta, tipo)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- -----------------------------------------------------------------------------
-- RELLENO
-- Entidad propia y reutilizable: un mismo relleno podría asociarse a más de una
-- pasta. Se compone de hasta 6 ingredientes (constraint vía trigger).
-- -----------------------------------------------------------------------------
CREATE TABLE relleno (
    id_relleno  SERIAL       PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL,

    CONSTRAINT uq_relleno_nombre UNIQUE (nombre)
);

-- -----------------------------------------------------------------------------
-- PASTA_RELLENA  (subtipo de PASTA)
-- Atributos del enunciado: promedio de kilos diarios vendidos y su relleno.
-- -----------------------------------------------------------------------------
CREATE TABLE pasta_rellena (
    sello                  VARCHAR(20)   NOT NULL,
    codigo_pasta           VARCHAR(20)   NOT NULL,
    tipo                   CHAR(1)       NOT NULL DEFAULT 'R',
    id_relleno             INTEGER       NOT NULL,
    promedio_kilos_diarios NUMERIC(10,2) NOT NULL,

    CONSTRAINT pk_pasta_rellena   PRIMARY KEY (sello, codigo_pasta),
    CONSTRAINT chk_rellena_tipo   CHECK (tipo = 'R'),
    CONSTRAINT chk_rellena_prom   CHECK (promedio_kilos_diarios >= 0),
    CONSTRAINT fk_rellena_pasta   FOREIGN KEY (sello, codigo_pasta, tipo)
        REFERENCES pasta (sello, codigo_pasta, tipo)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_rellena_relleno FOREIGN KEY (id_relleno)
        REFERENCES relleno (id_relleno) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- -----------------------------------------------------------------------------
-- INGREDIENTE
-- Un ingrediente puede estar presente en más de un relleno.
-- -----------------------------------------------------------------------------
CREATE TABLE ingrediente (
    id_ingrediente SERIAL       PRIMARY KEY,
    nombre         VARCHAR(100) NOT NULL,

    CONSTRAINT uq_ingrediente_nombre UNIQUE (nombre)
);

-- -----------------------------------------------------------------------------
-- RELLENO_INGREDIENTE  (relación N:M con atributo "cantidad")
-- Un ingrediente puede estar en varios rellenos en distinta cantidad.
-- Constraint de negocio "máx 6 ingredientes por relleno" -> trigger más abajo.
-- -----------------------------------------------------------------------------
CREATE TABLE relleno_ingrediente (
    id_relleno     INTEGER       NOT NULL,
    id_ingrediente INTEGER       NOT NULL,
    cantidad       NUMERIC(10,3) NOT NULL,

    CONSTRAINT pk_relleno_ingrediente PRIMARY KEY (id_relleno, id_ingrediente),
    CONSTRAINT fk_ri_relleno          FOREIGN KEY (id_relleno)
        REFERENCES relleno (id_relleno) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_ri_ingrediente      FOREIGN KEY (id_ingrediente)
        REFERENCES ingrediente (id_ingrediente) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_ri_cantidad        CHECK (cantidad > 0)
);

-- -----------------------------------------------------------------------------
-- CLIENTE
-- Pertenece a una franquicia. Guardamos datos del usuario + contactabilidad y
-- su pasta favorita. La favorita se modela con la MISMA columna 'sello': así la
-- FK (sello, codigo_favorita) -> pasta garantiza que la pasta favorita pertenece
-- a la franquicia del cliente, sin necesidad de un trigger adicional.
-- Constraint de negocio "máx 1000 clientes por franquicia" -> trigger más abajo.
-- -----------------------------------------------------------------------------
CREATE TABLE cliente (
    id_cliente       SERIAL       PRIMARY KEY,
    sello            VARCHAR(20)  NOT NULL,
    -- Datos del usuario
    nombre           VARCHAR(80)  NOT NULL,
    apellido         VARCHAR(80)  NOT NULL,
    documento        VARCHAR(20)  NOT NULL,
    fecha_nacimiento DATE,
    -- Datos de contactabilidad
    email            VARCHAR(150) NOT NULL,
    telefono         VARCHAR(30),
    -- Pasta favorita (de la misma franquicia); opcional
    codigo_favorita  VARCHAR(20),

    CONSTRAINT fk_cliente_franquicia FOREIGN KEY (sello)
        REFERENCES franquicia (sello) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_cliente_favorita   FOREIGN KEY (sello, codigo_favorita)
        REFERENCES pasta (sello, codigo_pasta) ON DELETE SET NULL ON UPDATE CASCADE,
    -- El documento es único dentro de cada franquicia
    CONSTRAINT uq_cliente_documento  UNIQUE (sello, documento),
    CONSTRAINT chk_cliente_email     CHECK (email LIKE '%_@_%.__%'),
    CONSTRAINT chk_cliente_nacimiento CHECK (fecha_nacimiento IS NULL
                                             OR fecha_nacimiento <= CURRENT_DATE)
);

-- -----------------------------------------------------------------------------
-- COMPRA
-- Un cliente realiza compras en una fecha y hora determinada.
-- -----------------------------------------------------------------------------
CREATE TABLE compra (
    id_compra   SERIAL    PRIMARY KEY,
    id_cliente  INTEGER   NOT NULL,
    fecha_hora  TIMESTAMP NOT NULL,

    CONSTRAINT fk_compra_cliente FOREIGN KEY (id_cliente)
        REFERENCES cliente (id_cliente) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_compra_fecha  CHECK (fecha_hora <= CURRENT_TIMESTAMP)
);

-- -----------------------------------------------------------------------------
-- DETALLE_COMPRA  (decisión de diseño AGREGADA)
-- El enunciado no lo pide explícitamente, pero modelar el detalle de cada compra
-- (qué pasta y cuántos kilos) es lo que da volumen y permite que las consultas
-- analíticas de las Etapas 2 y 3 (rankings, ventas por período, MapReduce) sean
-- significativas. Guardamos el precio unitario como snapshot histórico, porque
-- el precio de la pasta puede cambiar y no queremos reescribir compras pasadas.
-- -----------------------------------------------------------------------------
CREATE TABLE detalle_compra (
    id_compra        INTEGER       NOT NULL,
    sello            VARCHAR(20)   NOT NULL,
    codigo_pasta     VARCHAR(20)   NOT NULL,
    cantidad_kg      NUMERIC(10,3) NOT NULL,
    precio_unitario  NUMERIC(10,2) NOT NULL,  -- precio/kg al momento de la compra

    CONSTRAINT pk_detalle_compra  PRIMARY KEY (id_compra, sello, codigo_pasta),
    CONSTRAINT fk_detalle_compra  FOREIGN KEY (id_compra)
        REFERENCES compra (id_compra) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_detalle_pasta   FOREIGN KEY (sello, codigo_pasta)
        REFERENCES pasta (sello, codigo_pasta) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_detalle_cant   CHECK (cantidad_kg > 0),
    CONSTRAINT chk_detalle_precio CHECK (precio_unitario > 0)
);

-- =============================================================================
-- CONSTRAINTS DE NEGOCIO IMPLEMENTADAS CON TRIGGERS
-- (no expresables con un CHECK simple porque involucran agregaciones)
-- =============================================================================

-- 1) Un relleno no puede tener más de 6 ingredientes.
CREATE OR REPLACE FUNCTION fn_max_ingredientes_relleno()
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT COUNT(*) FROM relleno_ingrediente
        WHERE id_relleno = NEW.id_relleno) >= 6 THEN
        RAISE EXCEPTION 'El relleno % ya tiene 6 ingredientes (máximo permitido).',
            NEW.id_relleno;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_max_ingredientes_relleno
    BEFORE INSERT ON relleno_ingrediente
    FOR EACH ROW
    EXECUTE FUNCTION fn_max_ingredientes_relleno();

-- 2) Una franquicia no puede tener más de 1000 clientes.
CREATE OR REPLACE FUNCTION fn_max_clientes_franquicia()
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT COUNT(*) FROM cliente
        WHERE sello = NEW.sello) >= 1000 THEN
        RAISE EXCEPTION 'La franquicia % ya alcanzó el máximo de 1000 clientes.',
            NEW.sello;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_max_clientes_franquicia
    BEFORE INSERT ON cliente
    FOR EACH ROW
    EXECUTE FUNCTION fn_max_clientes_franquicia();

-- =============================================================================
-- Fin del esquema.
-- =============================================================================
