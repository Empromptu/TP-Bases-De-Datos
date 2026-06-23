-- Etapa 1.2 - Modelo relacional en PostgreSQL (fabrica de pastas)
-- Crea el esquema: tablas, claves y constraints. Sin indices (van en la Etapa 2.3).
-- Las tablas se crean respetando el orden de las FK.

DROP SCHEMA IF EXISTS pastas CASCADE;
CREATE SCHEMA pastas;
SET search_path TO pastas;


CREATE TABLE pais (
    id_pais SERIAL      PRIMARY KEY,
    nombre  VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE provincia (
    id_provincia SERIAL      PRIMARY KEY,
    nombre       VARCHAR(80) NOT NULL,
    id_pais      INTEGER     NOT NULL,

    CONSTRAINT fk_provincia_pais       FOREIGN KEY (id_pais)
        REFERENCES pais (id_pais) ON DELETE CASCADE,
    CONSTRAINT uq_provincia_nombre_pais UNIQUE (id_pais, nombre)
);

CREATE TABLE localidad (
    id_localidad SERIAL      PRIMARY KEY,
    nombre       VARCHAR(80) NOT NULL,
    id_provincia INTEGER     NOT NULL,

    CONSTRAINT fk_localidad_provincia        FOREIGN KEY (id_provincia)
        REFERENCES provincia (id_provincia) ON DELETE CASCADE,
    CONSTRAINT uq_localidad_nombre_provincia UNIQUE (id_provincia, nombre)
);

CREATE TABLE barrio (
    id_barrio    SERIAL      PRIMARY KEY,
    nombre       VARCHAR(80) NOT NULL,
    id_localidad INTEGER     NOT NULL,

    CONSTRAINT fk_barrio_localidad        FOREIGN KEY (id_localidad)
        REFERENCES localidad (id_localidad) ON DELETE CASCADE,
    CONSTRAINT uq_barrio_nombre_localidad UNIQUE (id_localidad, nombre)
);

CREATE TABLE direccion (
    id_direccion  SERIAL       PRIMARY KEY,
    calle         VARCHAR(120) NOT NULL,
    numero_puerta INTEGER      NOT NULL,
    codigo_postal VARCHAR(10)  NOT NULL,
    id_barrio     INTEGER      NOT NULL,

    CONSTRAINT fk_direccion_barrio  FOREIGN KEY (id_barrio)
        REFERENCES barrio (id_barrio) ON DELETE RESTRICT,
    CONSTRAINT chk_direccion_puerta CHECK (numero_puerta > 0)
);

-- Cada franquicia es independiente y se identifica por su sello. Su ubicacion
-- vive en direccion.
CREATE TABLE franquicia (
    sello           VARCHAR(20)  PRIMARY KEY,
    id_direccion    INTEGER      NOT NULL UNIQUE,
    email           VARCHAR(150) NOT NULL UNIQUE,
    telefono        VARCHAR(30)  NOT NULL,
    fecha_inicio    DATE         NOT NULL,

    CONSTRAINT fk_franquicia_direccion FOREIGN KEY (id_direccion)
        REFERENCES direccion (id_direccion) ON DELETE RESTRICT,
    CONSTRAINT chk_franquicia_fecha    CHECK (fecha_inicio <= CURRENT_DATE)
);

-- La pasta pertenece a una franquicia, por eso la PK es (sello, codigo_pasta):
-- asi el tirabuzon de una franquicia se distingue del de otra.
-- tipo 'S' = seca, 'R' = rellena.
CREATE TABLE pasta (
    sello           VARCHAR(20)   NOT NULL,
    codigo_pasta    VARCHAR(20)   NOT NULL,
    nombre          VARCHAR(100)  NOT NULL,
    precio_por_kilo NUMERIC(10,2) NOT NULL,
    tipo            CHAR(1)       NOT NULL,

    CONSTRAINT pk_pasta            PRIMARY KEY (sello, codigo_pasta),
    CONSTRAINT fk_pasta_franquicia FOREIGN KEY (sello)
        REFERENCES franquicia (sello) ON DELETE CASCADE,
    CONSTRAINT chk_pasta_precio    CHECK (precio_por_kilo > 0),
    CONSTRAINT chk_pasta_tipo      CHECK (tipo IN ('S', 'R'))
);

-- Subtipo seca. No agrega atributos, modela la especializacion.
CREATE TABLE pasta_seca (
    sello        VARCHAR(20) NOT NULL,
    codigo_pasta VARCHAR(20) NOT NULL,

    CONSTRAINT pk_pasta_seca PRIMARY KEY (sello, codigo_pasta),
    CONSTRAINT fk_seca_pasta FOREIGN KEY (sello, codigo_pasta)
        REFERENCES pasta (sello, codigo_pasta) ON DELETE CASCADE
);

-- Un relleno se puede reutilizar en varias pastas. Tiene hasta 6 ingredientes (trigger).
CREATE TABLE relleno (
    id_relleno  SERIAL       PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL UNIQUE
);

-- Subtipo rellena. Atributos del enunciado: promedio de kilos diarios y el relleno.
CREATE TABLE pasta_rellena (
    sello                  VARCHAR(20)   NOT NULL,
    codigo_pasta           VARCHAR(20)   NOT NULL,
    id_relleno             INTEGER       NOT NULL,
    promedio_kilos_diarios NUMERIC(10,2) NOT NULL,

    CONSTRAINT pk_pasta_rellena   PRIMARY KEY (sello, codigo_pasta),
    CONSTRAINT chk_rellena_prom   CHECK (promedio_kilos_diarios >= 0),
    CONSTRAINT fk_rellena_pasta   FOREIGN KEY (sello, codigo_pasta)
        REFERENCES pasta (sello, codigo_pasta) ON DELETE CASCADE,
    CONSTRAINT fk_rellena_relleno FOREIGN KEY (id_relleno)
        REFERENCES relleno (id_relleno)
);

-- Un ingrediente puede aparecer en varios rellenos.
CREATE TABLE ingrediente (
    id_ingrediente SERIAL       PRIMARY KEY,
    nombre         VARCHAR(100) NOT NULL UNIQUE
);

-- Relacion N:M relleno-ingrediente con la cantidad usada.
CREATE TABLE relleno_ingrediente (
    id_relleno     INTEGER       NOT NULL,
    id_ingrediente INTEGER       NOT NULL,
    cantidad       NUMERIC(10,3) NOT NULL,

    CONSTRAINT pk_relleno_ingrediente PRIMARY KEY (id_relleno, id_ingrediente),
    CONSTRAINT fk_ri_relleno          FOREIGN KEY (id_relleno)
        REFERENCES relleno (id_relleno) ON DELETE CASCADE,
    CONSTRAINT fk_ri_ingrediente      FOREIGN KEY (id_ingrediente)
        REFERENCES ingrediente (id_ingrediente),
    CONSTRAINT chk_ri_cantidad        CHECK (cantidad > 0)
);

-- Cliente de una franquicia. Su pasta favorita (opcional) tiene que ser de esa
-- misma franquicia: como la FK incluye el sello del cliente, queda garantizado.
CREATE TABLE cliente (
    id_cliente       SERIAL       PRIMARY KEY,
    sello            VARCHAR(20)  NOT NULL,
    id_direccion     INTEGER      NOT NULL UNIQUE,
    nombre           VARCHAR(80)  NOT NULL,
    apellido         VARCHAR(80)  NOT NULL,
    documento        VARCHAR(20)  NOT NULL,
    fecha_nacimiento DATE,
    email            VARCHAR(150) NOT NULL,
    telefono         VARCHAR(30),
    codigo_favorita  VARCHAR(20),

    CONSTRAINT fk_cliente_franquicia FOREIGN KEY (sello)
        REFERENCES franquicia (sello) ON DELETE CASCADE,
    CONSTRAINT fk_cliente_direccion  FOREIGN KEY (id_direccion)
        REFERENCES direccion (id_direccion) ON DELETE RESTRICT,
    CONSTRAINT fk_cliente_favorita   FOREIGN KEY (sello, codigo_favorita)
        REFERENCES pasta (sello, codigo_pasta) ON DELETE SET NULL,
    CONSTRAINT uq_cliente_documento  UNIQUE (sello, documento),
    CONSTRAINT chk_cliente_nacimiento CHECK (fecha_nacimiento IS NULL
                                             OR fecha_nacimiento <= CURRENT_DATE)
);

-- Un cliente hace compras en una fecha y hora.
CREATE TABLE compra (
    id_compra   SERIAL    PRIMARY KEY,
    id_cliente  INTEGER   NOT NULL,
    fecha_hora  TIMESTAMP NOT NULL,

    CONSTRAINT fk_compra_cliente FOREIGN KEY (id_cliente)
        REFERENCES cliente (id_cliente) ON DELETE CASCADE,
    CONSTRAINT chk_compra_fecha  CHECK (fecha_hora <= CURRENT_TIMESTAMP)
);

-- Detalle de cada compra: que pasta y cuantos kilos. Guardamos el precio del kilo
-- para que las consultas de las etapas siguientes tengan algo que sumar.
CREATE TABLE detalle_compra (
    id_compra        INTEGER       NOT NULL,
    sello            VARCHAR(20)   NOT NULL,
    codigo_pasta     VARCHAR(20)   NOT NULL,
    cantidad_kg      NUMERIC(10,3) NOT NULL,
    precio_unitario  NUMERIC(10,2) NOT NULL,

    CONSTRAINT pk_detalle_compra  PRIMARY KEY (id_compra, sello, codigo_pasta),
    CONSTRAINT fk_detalle_compra  FOREIGN KEY (id_compra)
        REFERENCES compra (id_compra) ON DELETE CASCADE,
    CONSTRAINT fk_detalle_pasta   FOREIGN KEY (sello, codigo_pasta)
        REFERENCES pasta (sello, codigo_pasta),
    CONSTRAINT chk_detalle_cant   CHECK (cantidad_kg > 0),
    CONSTRAINT chk_detalle_precio CHECK (precio_unitario > 0)
);

-- Restricciones para el modelo.

-- Un relleno no puede tener mas de 6 ingredientes.
CREATE OR REPLACE FUNCTION fn_max_ingredientes_relleno()
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT COUNT(*) FROM relleno_ingrediente
        WHERE id_relleno = NEW.id_relleno) >= 6 THEN
        RAISE EXCEPTION 'El relleno % ya tiene 6 ingredientes.', NEW.id_relleno;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_max_ingredientes_relleno
    BEFORE INSERT ON relleno_ingrediente
    FOR EACH ROW EXECUTE FUNCTION fn_max_ingredientes_relleno();

-- Una franquicia no puede tener mas de 1000 clientes.
CREATE OR REPLACE FUNCTION fn_max_clientes_franquicia()
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT COUNT(*) FROM cliente
        WHERE sello = NEW.sello) >= 1000 THEN
        RAISE EXCEPTION 'La franquicia % ya tiene 1000 clientes.', NEW.sello;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_max_clientes_franquicia
    BEFORE INSERT ON cliente
    FOR EACH ROW EXECUTE FUNCTION fn_max_clientes_franquicia();
