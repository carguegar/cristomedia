import 'models/user.dart';
import 'models/content.dart';
import 'models/review.dart';
import 'models/associated_user.dart';
import 'models/content_detail.dart';

class Protocolo {
  static const String HEADER = "PROTOCOLCRISTOMEDIA1.0";

  // --- ARMAR MENSAJES (CLIENTE -> SERVIDOR) ---

  static String armarLogin(String user, String pass) {
    final timestamp = DateTime.now().toString();
    return "$HEADER#$timestamp#LOGIN#$user#$pass\n";
  }

  static String armarGetInfoCliente(String user, String token) {
    final timestamp = DateTime.now().toString();
    return "$HEADER#$timestamp#GET_INFO_CLIENT#$user#WITH_TOKEN#$token\n";
  }

  // NUEVO: Protocolo de desconexión
  static String armarLogout(String user, String token) {
    final timestamp = DateTime.now().toString();
    // PROTOCOLCRISTOMEDIA1.0#<time>#BYEBYE#<user>#WITH_TOKEN#<token>
    return "$HEADER#$timestamp#BYEBYE#$user#WITH_TOKEN#$token\n";
  }

  // NUEVO: Pedir info de un contenido por ID
  static String armarGetInfoContent(
    String contentId,
    String user,
    String token,
  ) {
    final timestamp = DateTime.now().toString();
    return "$HEADER#$timestamp#GET_INFO_CONTENT_ID#$contentId#BY#$user#WITH_TOKEN#$token\n";
  }

  // --- INTERPRETAR RESPUESTAS (SERVIDOR -> CLIENTE) ---

  static bool esBienvenida(String mensaje) => mensaje.contains("#WELLCOME#");
  static bool esInfoCliente(String mensaje) => mensaje.contains("#INFO_CLIENT");
  static bool esDespedida(String mensaje) =>
      mensaje.contains("#SEEYOU#"); // NUEVO
  static bool esError(String mensaje) => mensaje.contains("#ERROR#");
  static bool esGameContent(String mensaje) =>
      mensaje.contains("#CONTENT_INFO_TO#") ||
      mensaje.contains("#GAME_CONTENT_TO#");

  // CAMBIO SOLICITADO: El token siempre está en la posición 5
  static String extraerToken(String mensaje) {
    try {
      final partes = mensaje.trim().split("#");
      // 0:HEADER, 1:TIME, 2:CMD, 3:USER, 4:WITH_TOKEN, 5:TOKEN
      if (partes.length > 5) {
        return partes[5].trim();
      }
      return "";
    } catch (e) {
      return "";
    }
  }

  static Usuario? parsearUsuario(String mensaje) {
    try {
      // Usamos trim() al principio para limpiar saltos de línea del final
      final partes = mensaje.trim().split("#");

      // Buscamos WITH_TOKEN para ubicarnos, aunque podríamos usar índices fijos,
      // buscar la etiqueta es más seguro si el header cambia de longitud.
      int indexToken = partes.indexOf("WITH_TOKEN");
      if (indexToken == -1) return null;

      // El token está en indexToken + 1.
      // Los datos del usuario empiezan en indexToken + 2.
      int p = indexToken + 2;

      // --- LEER DATOS USUARIO ---
      String username = partes[p++];
      String nombre = partes[p++];
      String ap1 = partes[p++];
      String ap2 = partes[p++];

      // --- LEER CONTENIDOS DEL SISTEMA ---
      int totalSystem = int.tryParse(partes[p++]) ?? 0;

      Map<String, Content> mapaContenidos = {};

      for (int i = 0; i < totalSystem; i++) {
        // Aseguramos leer 5 campos por contenido
        String cId = partes[p++].trim(); // Importante: trim() al ID
        String cName = partes[p++];
        double cVal = double.tryParse(partes[p++]) ?? 0.0;
        int cSize = int.tryParse(partes[p++]) ?? 0;
        String cFormat = partes[p++];

        mapaContenidos[cId] = Content(
          id: cId,
          nombre: cName,
          avgValoracion: cVal,
          sizeBytes: cSize,
          format: cFormat,
        );
      }

      // --- LEER CONTENIDOS DEL USUARIO ---
      // Aquí solía fallar. Aseguramos leer bien el entero.
      int totalUser = int.tryParse(partes[p++]) ?? 0;

      List<Content> contenidosUsuario = [];

      for (int i = 0; i < totalUser; i++) {
        // Leemos el ID y le quitamos espacios por si acaso (" 123 " != "123")
        String idBuscado = partes[p++].trim();

        if (mapaContenidos.containsKey(idBuscado)) {
          contenidosUsuario.add(mapaContenidos[idBuscado]!);
        } else {
          // Opcional: Log para depurar si faltan contenidos
          print(
            "Aviso: El usuario tiene el ID $idBuscado pero no vino en la lista del sistema.",
          );
        }
      }

      // El token lo sacamos con el método fijo o del array, aquí usamos el del array por coherencia local
      String token = partes[indexToken + 1];

      return Usuario.create(
        username: username,
        nombre: nombre,
        apellido1: ap1,
        apellido2: ap2,
        token: token,
        contenidos: contenidosUsuario,
        contenidosSistema: mapaContenidos.values.toList(),
      );
    } catch (e) {
      print("Error parseando usuario: $e");
      return null;
    }
  }

  static String extraerMensajeError(String mensaje) {
    if (!esError(mensaje)) return "Error desconocido";
    return mensaje.trim().split("#").last;
  }

  /// Parsea la respuesta GAME_CONTENT_TO del servidor
  /// Formato: HEADER#TIME#GAME_CONTENT_TO#user#WITH_TOKEN#token#id#name#size#format#avg#n_reviews#review1...#user1...
  static ContentDetail? parsearContentDetail(String mensaje) {
    try {
      final partes = mensaje.trim().split("#");

      // Buscar WITH_TOKEN para ubicarnos
      int indexToken = partes.indexOf("WITH_TOKEN");
      if (indexToken == -1) return null;

      int p = indexToken + 2; // Saltar el token, empezar en datos de content

      // --- LEER CONTENT ---
      String id = partes[p++];
      String name = partes[p++];
      int sizeBytes = int.tryParse(partes[p++]) ?? 0;
      String format = partes[p++];
      double avgVal = double.tryParse(partes[p++]) ?? 0.0;

      Content content = Content(
        id: id,
        nombre: name,
        avgValoracion: avgVal,
        sizeBytes: sizeBytes,
        format: format,
      );

      // --- LEER REVIEWS ---
      int nReviews = int.tryParse(partes[p++]) ?? 0;
      List<Review> reviews = [];

      for (int i = 0; i < nReviews; i++) {
        String rUser = partes[p++];
        String rFecha = partes[p++];
        String rTexto = partes[p++];
        double rCalif = double.tryParse(partes[p++]) ?? 0.0;
        reviews.add(
          Review(
            username: rUser,
            fecha: rFecha,
            texto: rTexto,
            calificacion: rCalif,
          ),
        );
      }

      // --- LEER USUARIOS ASOCIADOS ---
      // Los usuarios restantes hasta el final del mensaje
      List<AssociatedUser> users = [];
      while (p + 3 < partes.length) {
        String uUser = partes[p++];
        String uAp1 = partes[p++];
        String uAp2 = partes[p++];
        String uEmail = partes[p++];
        users.add(
          AssociatedUser(
            username: uUser,
            apellido1: uAp1,
            apellido2: uAp2,
            email: uEmail,
          ),
        );
      }

      return ContentDetail(
        content: content,
        reviews: reviews,
        associatedUsers: users,
      );
    } catch (e) {
      print("Error parseando content detail: $e");
      return null;
    }
  }

  // --- STREAMING DE CONTENIDO ---

  /// Detecta paquete de streaming de contenido
  static bool esContentStreamPacket(String mensaje) {
    return mensaje.contains("#OK_CONTENT_STREAM_TO#") &&
        mensaje.contains("#ID_PACKAGE#") &&
        mensaje.contains("#BYTES#");
  }

  /// Construye mensaje OK_INFO_CONTENT_RECEIVED (paso 3 del protocolo)
  static String armarOkInfoContentReceived(
    String contentId,
    String user,
    String token,
  ) {
    final timestamp = DateTime.now().toString();
    return "$HEADER#$timestamp#OK_INFO_CONTENT_RECEIVED#$contentId#BY#$user#WITH_TOKEN#$token#NOW_READY_TO_RECEIVE_CONTENT_STREAM\n";
  }

  /// Construye mensaje RECEIVED_AND_FINISHED (paso 5 del protocolo)
  static String armarContentReceivedAndFinished(String user, String token) {
    final timestamp = DateTime.now().toString();
    return "$HEADER#$timestamp#GET_INFO_CONTENT_ID#$user#WITH_TOKEN#$token#RECEIVED_AND_FINISHED\n";
  }

  /// Extrae datos base64 de un paquete de streaming de contenido
  static String? extraerContentStreamBase64(String mensaje) {
    try {
      int idx = mensaje.lastIndexOf("#BYTES#");
      if (idx == -1) return null;
      return mensaje.substring(idx + 7).trim();
    } catch (e) {
      return null;
    }
  }

  // --- FOTO DE USUARIO ---

  static String armarGetUserPhoto(String user, String token) {
    final timestamp = DateTime.now().toString();
    return "$HEADER#$timestamp#GET_USER_PHOTO#$user#WITH_TOKEN#$token\n";
  }

  /// Pedir foto de OTRO usuario (no el logueado)
  static String armarGetOtherUserPhoto(
    String targetUser,
    String requestorUser,
    String token,
  ) {
    final timestamp = DateTime.now().toString();
    return "$HEADER#$timestamp#GET_USER_PHOTO#$targetUser#BY#$requestorUser#WITH_TOKEN#$token\n";
  }

  static String armarReadyToReceive(
    String user,
    String token,
    int fileSize,
    int sizePackage,
  ) {
    final timestamp = DateTime.now().toString();
    return "$HEADER#$timestamp#READY_TO_RECEIVE_IMAGE_FOR#$user#WITH_TOKEN#$token#FILE_SIZE#$fileSize#SIZE_PACKAGE#$sizePackage\n";
  }

  static String armarReceivedAndFinished(String user, String token) {
    final timestamp = DateTime.now().toString();
    return "$HEADER#$timestamp#GET_USER_PHOTO#$user#WITH_TOKEN#$token#RECEIVED_AND_FINISHED\n";
  }

  /// Detecta respuesta OK_IMAGE_FOR con metadatos (FILE_SIZE)
  static bool esOkImageMetadata(String mensaje) {
    return mensaje.contains("#OK_IMAGE_FOR#") &&
        mensaje.contains("#FILE_SIZE#");
  }

  /// Detecta paquete de datos de imagen (ID_PACKAGE + BYTES)
  static bool esImagePacket(String mensaje) {
    return mensaje.contains("#OK_IMAGE_FOR#") &&
        mensaje.contains("#ID_PACKAGE#") &&
        mensaje.contains("#BYTES#");
  }

  /// Extrae FILE_SIZE y SIZE_PACKAGE de la respuesta de metadatos
  static Map<String, int>? extraerImageMetadata(String mensaje) {
    try {
      final partes = mensaje.split("#");
      int fileSizeIdx = partes.indexOf("FILE_SIZE");
      int sizePackageIdx = partes.indexOf("SIZE_PACKAGE");
      if (fileSizeIdx == -1 || sizePackageIdx == -1) return null;
      return {
        'fileSize': int.parse(partes[fileSizeIdx + 1]),
        'sizePackage': int.parse(partes[sizePackageIdx + 1]),
      };
    } catch (e) {
      return null;
    }
  }

  /// Extrae datos base64 de un paquete de imagen
  static String? extraerImagePacketBase64(String mensaje) {
    try {
      int idx = mensaje.lastIndexOf("#BYTES#");
      if (idx == -1) return null;
      return mensaje.substring(idx + 7).trim();
    } catch (e) {
      return null;
    }
  }

  /// Extrae el username del campo OK_IMAGE_FOR de la respuesta
  static String? extraerImageTargetUser(String mensaje) {
    try {
      final partes = mensaje.split("#");
      int idx = partes.indexOf("OK_IMAGE_FOR");
      if (idx == -1 || idx + 1 >= partes.length) return null;
      return partes[idx + 1];
    } catch (e) {
      return null;
    }
  }

  // --- USER_PHOTO_RESPONSE (respuesta directa, sin streaming) ---

  /// Detecta respuesta USER_PHOTO_RESPONSE
  static bool esUserPhotoResponse(String mensaje) {
    return mensaje.contains("#USER_PHOTO_RESPONSE#") &&
        mensaje.contains("#DATA#");
  }

  /// Parsea USER_PHOTO_RESPONSE: extrae targetUser, expectedLength y base64
  static Map<String, dynamic>? parsearUserPhotoResponse(String mensaje) {
    try {
      final partes = mensaje.trim().split("#");
      int idx = partes.indexOf("USER_PHOTO_RESPONSE");
      int lengthIdx = partes.indexOf("LENGTH");
      int dataIdx = partes.indexOf("DATA");
      if (idx == -1 || lengthIdx == -1 || dataIdx == -1) return null;

      String targetUser = partes[idx + 1];
      int expectedLength = int.tryParse(partes[lengthIdx + 1]) ?? 0;
      // Todo lo que hay después de #DATA# es base64
      // Reconstruir desde el mensaje original para no perder datos
      int dataStart = mensaje.indexOf("#DATA#");
      if (dataStart == -1) return null;
      String base64Data = mensaje.substring(dataStart + 6).trim();

      return {
        'targetUser': targetUser,
        'expectedLength': expectedLength,
        'base64': base64Data,
      };
    } catch (e) {
      print("Error parseando USER_PHOTO_RESPONSE: $e");
      return null;
    }
  }

  // --- REVIEWS ---

  /// Arma mensaje para enviar nueva review
  static String armarNewReview(
    String contentId,
    String user,
    String token,
    String texto,
    int scoring,
  ) {
    final timestamp = DateTime.now().toString();
    // Limitar a 256 caracteres y quitar # para no romper el protocolo
    String safeText = texto.length > 256 ? texto.substring(0, 256) : texto;
    safeText = safeText.replaceAll('#', '');
    return "$HEADER#$timestamp#NEW_REVIEW_FOR#$contentId#BY#$user#WITH_TOKEN#$token#REVIEW_TEXT#$safeText#SCORING#$scoring\n";
  }

  /// Detecta broadcast de nueva review (contiene AVG_SCORING)
  static bool esNewReviewBroadcast(String mensaje) {
    return mensaje.contains("#NEW_REVIEW_FOR#") &&
        mensaje.contains("#AVG_SCORING#");
  }

  /// Parsea broadcast de nueva review del servidor
  static Map<String, dynamic>? parsearNewReviewBroadcast(String mensaje) {
    try {
      final partes = mensaje.trim().split("#");

      int nrIdx = partes.indexOf("NEW_REVIEW_FOR");
      int reviewTextIdx = partes.indexOf("REVIEW_TEXT");
      int scoringIdx = partes.indexOf("SCORING");
      int dateIdx = partes.indexOf("DATE");
      int contentNameIdx = partes.indexOf("CONTENT_NAME");
      int avgIdx = partes.indexOf("AVG_SCORING");

      if (nrIdx == -1 ||
          reviewTextIdx == -1 ||
          scoringIdx == -1 ||
          dateIdx == -1 ||
          contentNameIdx == -1 ||
          avgIdx == -1)
        return null;

      return {
        'contentId': partes[nrIdx + 1],
        'username': partes[nrIdx + 3], // después de BY
        'reviewText': partes[reviewTextIdx + 1],
        'scoring': int.tryParse(partes[scoringIdx + 1]) ?? 0,
        'date': partes[dateIdx + 1],
        'contentName': partes[contentNameIdx + 1],
        'avgScoring': double.tryParse(partes[avgIdx + 1]) ?? 0.0,
      };
    } catch (e) {
      print("Error parseando new review broadcast: $e");
      return null;
    }
  }
}
