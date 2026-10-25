# CristoMedia · Cliente Flutter

Cliente de escritorio/móvil para el servidor de CristoMedia. Implementa el
protocolo de texto `PROTOCOLCRISTOMEDIA1.0` sobre TCP y permite iniciar sesión,
consultar el catálogo, ver la ficha de un contenido, enviar reseñas y descargar
archivos por streaming.

> Proyecto educativo del CFGS DAM (CES Cristo Rey). No es una aplicación de
> producción.

## Requisitos

- Flutter 3.38 o superior (Dart `^3.10.7`).
- El servidor de CristoMedia arrancado en el puerto `4444`.

## Arranque

```bash
flutter pub get
flutter run -d windows   # o -d chrome, -d android...
```

En la pantalla de login introduce:

- IP: `127.0.0.1` (o la IP de la máquina donde corre el servidor).
- Puerto: `4444`.
- Usuario: `demo1`.
- Contraseña: `demo123`.

Los datos de demostración se cargan con `ServidorPSP/src/main/java/modelo/sql/instanciacion.sql`.

## Estructura

```
lib/
├── main.dart                  # Login y arranque de la app
├── home_screen.dart           # Perfil, catálogo y búsqueda
├── content_detail_screen.dart # Ficha, reseñas y descarga
├── socket_service.dart        # Conexión TCP, buffer y estado
├── protocolo.dart             # Construcción/parseo de mensajes
├── models/                    # Usuario, contenido, reseña...
└── widgets/LogConsole.dart    # Consola de depuración del protocolo
```

## Notas

- La descarga se hace en paquetes Base64 de 1024 bytes; el cliente reconstruye
  el archivo y lo guarda en el directorio temporal del sistema.
- La consola inferior muestra las tramas enviadas y recibidas. Es útil para
  entender el protocolo, pero no debe usarse en producción.
- No hay TLS ni cifrado: el proyecto está pensado para una red local de aula.
