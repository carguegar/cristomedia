DROP SCHEMA IF EXISTS cristo_media CASCADE;
CREATE SCHEMA cristo_media;
SET search_path TO cristo_media;

BEGIN WORK;
SET TRANSACTION READ WRITE;
SET datestyle = DMY;

-- 1. Tabla Usuario
DROP TABLE IF EXISTS Valora;
DROP TABLE IF EXISTS Poseer;
DROP TABLE IF EXISTS Contenido;
DROP TABLE IF EXISTS Usuario;

CREATE TABLE Usuario(
    idUser BIGINT GENERATED ALWAYS AS IDENTITY,
    userName VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    surname1 VARCHAR(255) NOT NULL,
    surname2 VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    conectionsCounter INTEGER NOT NULL,
    password VARCHAR(255) NOT NULL,
    userImagePath VARCHAR(255),
    PRIMARY KEY(idUser)
);

-- 2. Tabla Contenido
CREATE TABLE Contenido (
    idContent BIGINT GENERATED ALWAYS AS IDENTITY,
    nameContent VARCHAR(255) NOT NULL,
    pathContent VARCHAR(255) NOT NULL,
    sizeBytes BIGINT,
    avgValoracion DECIMAL(3,2),
    format VARCHAR(10),
    PRIMARY KEY(idContent)
);

-- 3. Tabla Intermedia 'Poseer' (Relación N:M)
CREATE TABLE Poseer (
    idUser BIGINT NOT NULL,
    idContent BIGINT NOT NULL,
    CONSTRAINT fk_poseer_usuario FOREIGN KEY (idUser)
        REFERENCES Usuario(idUser)
        ON DELETE CASCADE,
    CONSTRAINT fk_poseer_contenido FOREIGN KEY (idContent)
        REFERENCES Contenido(idContent)
        ON DELETE CASCADE,
    PRIMARY KEY (idUser, idContent)
);

-- 4. Tabla Valora (Relación N:M)
CREATE TABLE Valora(
    idValoracion BIGINT GENERATED ALWAYS AS IDENTITY,
    score INTEGER CHECK (score BETWEEN 0 AND 5),
    idUser BIGINT NOT NULL,
    idContent BIGINT NOT NULL,
    comment TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_valora_usuario FOREIGN KEY (idUser)
        REFERENCES Usuario(idUser)
        ON DELETE CASCADE,
    CONSTRAINT fk_valora_contenido FOREIGN KEY (idContent)
        REFERENCES Contenido(idContent)
        ON DELETE CASCADE,
    CONSTRAINT uq_valoracion_logica UNIQUE (idUser, idContent, timestamp),
    PRIMARY KEY (idValoracion)
);

COMMIT;