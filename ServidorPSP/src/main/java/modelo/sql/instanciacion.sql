-- Datos de demostración de CristoMedia
-- Ejecutar después de create_dbSQL.sql, sobre la base de datos postgres:
--   psql -U postgres -d postgres -f instanciacion.sql
--
-- Los usuarios, imágenes y documentos son ficticios y se incluyen únicamente
-- para poder probar la aplicación sin utilizar datos personales reales.

SET search_path TO cristo_media;

BEGIN WORK;

-- ---------------------------------------------------
-- 1. USUARIOS DE DEMOSTRACIÓN
-- ---------------------------------------------------
INSERT INTO Usuario (userName, name, surname1, surname2, email, conectionscounter, password, userImagePath) VALUES
    ('demo1', 'Demo', 'Uno', 'Prueba', 'demo1@example.com', 0, 'demo123', 'data/users/demo1/demo1.png'),
    ('demo2', 'Demo', 'Dos', 'Prueba', 'demo2@example.com', 0, 'demo123', 'data/users/demo2/demo2.png'),
    ('demo3', 'Demo', 'Tres', 'Prueba', 'demo3@example.com', 0, 'demo123', 'data/users/demo3/demo3.png');

-- ---------------------------------------------------
-- 2. CONTENIDOS DE DEMOSTRACIÓN
-- Ruta: data/content/<id>/<id>.<ext>
-- ---------------------------------------------------
INSERT INTO Contenido (nameContent, pathContent, sizeBytes, avgValoracion, format) VALUES
    ('bienvenida',       'data/content/1/1.png', 12680, 4.5, 'png'),
    ('documento_ejemplo','data/content/2/2.pdf',  1146, 0.0, 'pdf'),
    ('flujos_y_sockets', 'data/content/3/3.png', 11732, 5.0, 'png'),
    ('guia_rapida',      'data/content/4/4.pdf',  1141, 4.0, 'pdf');

-- ---------------------------------------------------
-- 3. RELACIÓN "POSEER" (qué contenidos tiene cada usuario)
-- ---------------------------------------------------
INSERT INTO Poseer (idUser, idContent) VALUES
    ((SELECT idUser FROM Usuario WHERE userName = 'demo1'), (SELECT idContent FROM Contenido WHERE nameContent = 'bienvenida')),
    ((SELECT idUser FROM Usuario WHERE userName = 'demo1'), (SELECT idContent FROM Contenido WHERE nameContent = 'documento_ejemplo')),
    ((SELECT idUser FROM Usuario WHERE userName = 'demo2'), (SELECT idContent FROM Contenido WHERE nameContent = 'flujos_y_sockets')),
    ((SELECT idUser FROM Usuario WHERE userName = 'demo3'), (SELECT idContent FROM Contenido WHERE nameContent = 'guia_rapida'));

-- ---------------------------------------------------
-- 4. RELACIÓN "VALORA" (reseñas de ejemplo)
-- ---------------------------------------------------
INSERT INTO Valora (idUser, idContent, score, comment) VALUES
    ((SELECT idUser FROM Usuario WHERE userName = 'demo1'), (SELECT idContent FROM Contenido WHERE nameContent = 'bienvenida'), 5, 'Contenido de ejemplo para probar la ficha y el streaming.'),
    ((SELECT idUser FROM Usuario WHERE userName = 'demo2'), (SELECT idContent FROM Contenido WHERE nameContent = 'bienvenida'), 4, 'La imagen se descarga correctamente por el socket.'),
    ((SELECT idUser FROM Usuario WHERE userName = 'demo3'), (SELECT idContent FROM Contenido WHERE nameContent = 'flujos_y_sockets'), 5, 'Buena demostración del envío de contenido en tiempo real.'),
    ((SELECT idUser FROM Usuario WHERE userName = 'demo1'), (SELECT idContent FROM Contenido WHERE nameContent = 'guia_rapida'), 4, 'Documento útil para arrancar el proyecto.');

COMMIT;
