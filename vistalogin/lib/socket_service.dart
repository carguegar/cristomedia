import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'protocolo.dart';
import 'models/user.dart';
import 'models/content_detail.dart';
import 'models/review.dart';
import 'models/content.dart';

enum LoginStatus { none, connecting, loading, fetchingProfile, success, error }

class LogMessage {
  final String message;
  final bool isSent;
  final DateTime timestamp;
  LogMessage(this.message, this.isSent) : timestamp = DateTime.now();
}

class SocketService with ChangeNotifier {
  Socket? _socket;
  final List<LogMessage> _logs = [];

  LoginStatus _loginStatus = LoginStatus.none;
  String _lastErrorMessage = "";
  Usuario? _usuarioActual;

  // Variables de conexión
  String _serverIP = "";
  String _serverPort = "";

  // --- BUFFER TCP ---
  String _dataBuffer = '';

  // --- FOTO DE USUARIO ---
  bool _isReceivingImage = false;
  bool _isLoadingPhoto = false;
  int _expectedFileSize = 0;
  int _expectedSizePackage = 0;
  int _receivedImageBytes = 0;
  final BytesBuilder _imageBuilder = BytesBuilder();
  Uint8List? _userPhoto;

  // --- DETALLE DE CONTENIDO ---
  ContentDetail? _contentDetail;
  bool _isLoadingContentDetail = false;
  String _contentDetailError = '';
  String _reviewSubmitError = '';

  // --- STREAMING DE CONTENIDO ---
  bool _isReceivingContentStream = false;
  bool _isContentStreamComplete = false;
  int _contentStreamReceivedBytes = 0;
  int _contentStreamPacketCount = 0;
  final BytesBuilder _contentStreamBuilder = BytesBuilder();
  Uint8List? _contentBytes;

  // --- FOTOS DE USUARIOS (MAP) ---
  final Map<String, Uint8List> _userPhotosMap = {};
  final List<String> _photoRequestQueue = [];
  String? _currentPhotoTarget;
  bool _contentStreamFailed = false;
  Timer? _photoFinalizeTimer;

  // Getters
  List<LogMessage> get logs => _logs;
  LoginStatus get loginStatus => _loginStatus;
  String get lastErrorMessage => _lastErrorMessage;
  bool get isConnected => _socket != null;
  Usuario? get usuarioActual => _usuarioActual;
  String get serverIP => _serverIP;
  String get serverPort => _serverPort;
  Uint8List? get userPhoto => _userPhoto;
  bool get isLoadingPhoto => _isLoadingPhoto;
  ContentDetail? get contentDetail => _contentDetail;
  bool get isLoadingContentDetail => _isLoadingContentDetail;
  String get contentDetailError => _contentDetailError;
  String get reviewSubmitError => _reviewSubmitError;
  Uint8List? get contentBytes => _contentBytes;
  bool get isReceivingContentStream => _isReceivingContentStream;
  bool get isContentStreamComplete => _isContentStreamComplete;
  int get contentStreamReceivedBytes => _contentStreamReceivedBytes;
  double get contentStreamProgress =>
      (_contentDetail != null && _contentDetail!.content.sizeBytes > 0)
      ? _contentStreamReceivedBytes / _contentDetail!.content.sizeBytes
      : 0.0;
  Map<String, Uint8List> get userPhotosMap => _userPhotosMap;
  bool get contentStreamFailed => _contentStreamFailed;

  // --- CONEXIÓN ---
  Future<void> connect(String ip, String port) async {
    // Cerrar conexión previa si existe
    if (_socket != null) {
      disconnect();
    }

    _serverIP = ip;
    _serverPort = port;
    _loginStatus = LoginStatus.connecting;
    _lastErrorMessage = ""; // Limpiar errores anteriores
    notifyListeners();

    try {
      _socket = await Socket.connect(
        ip,
        int.parse(port),
        timeout: const Duration(seconds: 5),
      );
      _log("Conectado a $ip:$port", isSent: true);

      _dataBuffer = '';

      _socket!.listen(
        (List<int> data) {
          _dataBuffer += utf8.decode(data);
          _drainBuffer();
        },
        onError: (error) {
          _log("Error de socket: $error", isSent: false);
          disconnect();
        },
        onDone: () {
          _log("Servidor cerró la conexión.", isSent: false);
          disconnect();
        },
      );
    } catch (e) {
      _lastErrorMessage = "No se pudo conectar: $e";
      _loginStatus = LoginStatus.error;
      _log(_lastErrorMessage, isSent: false);
      notifyListeners();
    }
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.destroy();
      _socket = null;
      _loginStatus = LoginStatus.none;
      _usuarioActual = null;
      _dataBuffer = '';
      _isReceivingImage = false;
      _isLoadingPhoto = false;
      _imageBuilder.clear();
      _receivedImageBytes = 0;
      _userPhoto = null;
      _photoFinalizeTimer?.cancel();
      // Content stream cleanup
      _isReceivingContentStream = false;
      _isContentStreamComplete = false;
      _contentStreamReceivedBytes = 0;
      _contentStreamPacketCount = 0;
      _contentStreamBuilder.clear();
      _contentBytes = null;
      _contentDetail = null;
      _reviewSubmitError = '';
      _contentStreamFailed = false;
      _userPhotosMap.clear();
      _photoRequestQueue.clear();
      _currentPhotoTarget = null;
      notifyListeners();
      _log("Desconectado localmente.", isSent: true);
    }
  }

  // --- ACCIONES DEL USUARIO ---

  void sendLogin(String user, String pass) {
    if (_socket == null) return;
    _loginStatus = LoginStatus.loading;
    notifyListeners();

    final msg = Protocolo.armarLogin(user, pass);
    _socket!.write(msg);
    _log(msg.trim(), isSent: true);
  }

  // NUEVO: Método para cerrar sesión ordenadamente
  void logout() {
    if (_socket == null || _usuarioActual == null) {
      disconnect(); // Si no hay conexión real, cerramos local
      return;
    }

    final msg = Protocolo.armarLogout(
      _usuarioActual!.username,
      _usuarioActual!.token,
    );
    _socket!.write(msg);
    _log(msg.trim(), isSent: true);
  }

  // --- DETALLE DE CONTENIDO ---

  void requestContentDetail(String contentId) {
    if (_socket == null || _usuarioActual == null) return;
    // No enviar petición duplicada si ya estamos cargando o recibiendo stream
    if (_isLoadingContentDetail || _isReceivingContentStream) return;
    _isLoadingContentDetail = true;
    _contentDetail = null;
    _contentDetailError = '';
    _contentStreamFailed = false;
    notifyListeners();

    final msg = Protocolo.armarGetInfoContent(
      contentId,
      _usuarioActual!.username,
      _usuarioActual!.token,
    );
    _socket!.write(msg);
    _log(msg.trim(), isSent: true);
  }

  void clearContentDetail() {
    _contentDetail = null;
    _contentDetailError = '';
    _isLoadingContentDetail = false;
    _isReceivingContentStream = false;
    _isContentStreamComplete = false;
    _contentStreamReceivedBytes = 0;
    _contentStreamPacketCount = 0;
    _contentStreamBuilder.clear();
    _contentBytes = null;
    _contentStreamFailed = false;
    notifyListeners();
  }

  // --- ENVIAR NUEVA REVIEW ---

  void sendNewReview(String contentId, String texto, int scoring) {
    if (_socket == null || _usuarioActual == null) return;
    _reviewSubmitError = '';
    notifyListeners();

    final msg = Protocolo.armarNewReview(
      contentId,
      _usuarioActual!.username,
      _usuarioActual!.token,
      texto,
      scoring,
    );
    _socket!.write(msg);
    _log(msg.trim(), isSent: true);
  }

  void clearReviewError() {
    _reviewSubmitError = '';
  }

  // --- FOTOS POR USERNAME ---

  void requestPhotosForUsers(List<String> usernames) {
    if (_socket == null || _usuarioActual == null) return;
    final toRequest = usernames
        .where(
          (u) =>
              !_userPhotosMap.containsKey(u) &&
              !_photoRequestQueue.contains(u) &&
              u != _currentPhotoTarget,
        )
        .toSet()
        .toList();

    _photoRequestQueue.addAll(toRequest);
    if (!_isReceivingImage && !_isLoadingPhoto && !_isReceivingContentStream) {
      _processNextPhotoRequest();
    }
  }

  void _processNextPhotoRequest() {
    if (_photoRequestQueue.isEmpty) return;
    if (_socket == null || _usuarioActual == null) return;
    if (_isReceivingImage || _isLoadingPhoto || _isReceivingContentStream)
      return;

    String targetUser = _photoRequestQueue.removeAt(0);
    if (_userPhotosMap.containsKey(targetUser)) {
      _processNextPhotoRequest();
      return;
    }

    _currentPhotoTarget = targetUser;
    _isLoadingPhoto = true;
    // Preparar recepción directa (sin metadata) para otros usuarios:
    // El servidor envía OK_IMAGE_FOR paquetes directamente sin FILE_SIZE previo.
    _isReceivingImage = true;
    _expectedFileSize = -1; // Tamaño desconocido (sin metadata)
    _receivedImageBytes = 0;
    _imageBuilder.clear();

    // Para otros usuarios, usar protocolo con BY
    final msg = Protocolo.armarGetOtherUserPhoto(
      targetUser,
      _usuarioActual!.username,
      _usuarioActual!.token,
    );
    _socket!.write(msg);
    _log(msg.trim(), isSent: true);
  }

  void _requestPhotosForContentDetail(ContentDetail detail) {
    Set<String> usernames = {};
    for (var review in detail.reviews) {
      usernames.add(review.username);
    }
    for (var user in detail.associatedUsers) {
      usernames.add(user.username);
    }
    requestPhotosForUsers(usernames.toList());
  }

  // --- FOTO DE USUARIO ---

  void requestUserPhoto() {
    if (_socket == null || _usuarioActual == null) return;
    _isLoadingPhoto = true;
    _userPhoto = null;
    _currentPhotoTarget = _usuarioActual!.username;
    notifyListeners();

    final msg = Protocolo.armarGetUserPhoto(
      _usuarioActual!.username,
      _usuarioActual!.token,
    );
    _socket!.write(msg);
    _log(msg.trim(), isSent: true);
  }

  // --- BUFFER TCP ---

  void _drainBuffer() {
    final header = '${Protocolo.HEADER}#';

    while (_dataBuffer.isNotEmpty) {
      int start = _dataBuffer.indexOf(header);
      if (start == -1) {
        // No hay header de protocolo — comprobar si el servidor envió
        // un error sin header (ej: "ERROR#MAX_CONNECTIONS_REACHED")
        String trimmed = _dataBuffer.trim();
        if (trimmed.startsWith('ERROR#')) {
          _dataBuffer = '';
          _handleRawError(trimmed);
        } else {
          // No descartar todo: un header puede estar partido entre chunks TCP.
          // Conservar los últimos (header.length - 1) chars para reensamblarlo.
          if (_dataBuffer.length >= header.length) {
            _dataBuffer = _dataBuffer.substring(
              _dataBuffer.length - header.length + 1,
            );
          }
          // Si es más corto, mantener todo (podría ser inicio de header)
        }
        return;
      }
      if (start > 0) {
        _dataBuffer = _dataBuffer.substring(start);
      }

      // --- 1. Intentar dividir por siguiente cabecera ---
      int next = _dataBuffer.indexOf(header, header.length);

      if (next != -1) {
        // Mensaje completo delimitado por dos cabeceras consecutivas
        String msg = _dataBuffer.substring(0, next).trim();
        _dataBuffer = _dataBuffer.substring(next);
        _handleCompleteMessage(msg);
        continue;
      }

      // --- 2. Único mensaje en buffer, detectar tipo por marcadores ---
      String trimmed = _dataBuffer.trim();

      // 2a. Paquete de STREAMING DE CONTENIDO (comprobar ANTES que imagen)
      if (trimmed.contains('#OK_CONTENT_STREAM_TO#') &&
          trimmed.contains('#BYTES#')) {
        int bytesIdx = trimmed.lastIndexOf('#BYTES#');
        String b64 = trimmed.substring(bytesIdx + 7).trim();
        if (b64.isEmpty) return; // Esperar datos base64
        final cleanB64 = b64.replaceAll(RegExp(r'\s'), '');
        if (cleanB64.length % 4 != 0) return; // Base64 incompleto
        try {
          final decoded = base64Decode(cleanB64);
          final totalExpected = _contentDetail?.content.sizeBytes ?? 0;
          // Sin siguiente cabecera no podemos saber si el paquete está completo
          // (base64 parcial puede decodificar correctamente). Solo aceptar si:
          // 1) Es el último paquete (completaría la transferencia), o
          // 2) No conocemos el tamaño total.
          // Los paquetes intermedios se delimitarán por la cabecera del siguiente (path 1).
          if (totalExpected > 0 &&
              _contentStreamReceivedBytes + decoded.length < totalExpected) {
            return; // Paquete intermedio: esperar siguiente cabecera
          }
          _dataBuffer = '';
          _handleCompleteMessage(trimmed);
        } catch (e) {
          return; // Base64 incompleto, esperar más datos
        }
        continue;
      }

      // 2b. Respuesta USER_PHOTO_RESPONSE (foto de otro usuario, single-message)
      if (trimmed.contains('#USER_PHOTO_RESPONSE#') &&
          trimmed.contains('#DATA#')) {
        int dataIdx = trimmed.indexOf('#DATA#');
        String b64 = trimmed.substring(dataIdx + 6).trim();
        if (b64.isEmpty) return; // Esperar datos base64
        final cleanB64 = b64.replaceAll(RegExp(r'\s'), '');
        if (cleanB64.length % 4 != 0) return; // Base64 incompleto
        // Verificar longitud esperada
        int lengthIdx = trimmed.indexOf('#LENGTH#');
        if (lengthIdx != -1) {
          try {
            String afterLength = trimmed.substring(lengthIdx + 8);
            int nextHash = afterLength.indexOf('#');
            if (nextHash != -1) {
              int expectedLen =
                  int.tryParse(afterLength.substring(0, nextHash)) ?? 0;
              final decoded = base64Decode(cleanB64);
              if (expectedLen > 0 && decoded.length < expectedLen) {
                return; // Datos incompletos, esperar más
              }
            }
          } catch (e) {
            return; // Base64 incompleto
          }
        }
        _dataBuffer = '';
        _handleCompleteMessage(trimmed);
        continue;
      }

      // 2c. Paquete de IMAGEN con streaming (OK_IMAGE_FOR con BYTES)
      // Cubre foto del usuario logueado (con metadata) y de otros usuarios (sin metadata).
      // Para tamaño desconocido (_expectedFileSize < 0), siempre aceptar el paquete.
      if (_isReceivingImage &&
          trimmed.contains('#OK_IMAGE_FOR#') &&
          trimmed.contains('#BYTES#')) {
        int bytesIdx = trimmed.lastIndexOf('#BYTES#');
        String b64 = trimmed.substring(bytesIdx + 7).trim();
        final cleanB64 = b64.replaceAll(RegExp(r'\s'), '');
        if (cleanB64.isEmpty || cleanB64.length % 4 != 0) {
          return; // Base64 incompleto, esperar más datos
        }
        try {
          final decoded = base64Decode(cleanB64);
          // Solo aceptar como paquete suelto si es el último (completaría la imagen).
          // Los paquetes intermedios se delimitarán por la cabecera del siguiente (path 1).
          if (_receivedImageBytes + decoded.length < _expectedFileSize) {
            return; // Paquete intermedio: esperar siguiente cabecera
          }
          _dataBuffer = '';
          _handleCompleteMessage(trimmed);
        } catch (e) {
          return; // Base64 inválido, esperar más datos
        }
        continue;
      }

      // 2d. Paquete de streaming incompleto: tiene marcador pero TCP partió #BYTES#.
      // Esperar más datos para reensamblarlo.
      if (trimmed.contains('#OK_CONTENT_STREAM_TO#') ||
          (trimmed.contains('#OK_IMAGE_FOR#') &&
              trimmed.contains('#ID_PACKAGE#'))) {
        return; // Streaming packet incompleto, esperar más datos TCP
      }

      // 2e. Cualquier otro mensaje completo (login, info, errors, etc.)
      if (_looksLikeCompleteMessage(trimmed)) {
        _dataBuffer = '';
        _handleCompleteMessage(trimmed);
        continue;
      }

      // 2f. Nada reconocido, esperar más datos
      return;
    }
  }

  /// Maneja errores enviados por el servidor SIN el header del protocolo
  /// (ej: "ERROR#MAX_CONNECTIONS_REACHED")
  void _handleRawError(String rawMessage) {
    _log(rawMessage, isSent: false);

    String errorCode = rawMessage.replaceFirst('ERROR#', '').trim();

    if (errorCode.contains("MAX_CONNECTIONS_REACHED")) {
      disconnect();
      _lastErrorMessage = "Máximo de conexiones alcanzado. Intente más tarde.";
      _loginStatus = LoginStatus.error;
      notifyListeners();
    } else {
      disconnect();
      _lastErrorMessage = errorCode.isNotEmpty
          ? errorCode
          : "Error del servidor";
      _loginStatus = LoginStatus.error;
      notifyListeners();
    }
  }

  bool _looksLikeCompleteMessage(String msg) {
    // NO incluir #OK_CONTENT_STREAM_TO# ni paquetes de datos de imagen aquí.
    // Esos mensajes deben procesarse SOLO por paths 2a/2b que validan #BYTES#.
    // Si TCP parte el mensaje justo en #BYTES#, este method los consumiría
    // y el paquete se perdería.
    return msg.contains('#WELLCOME#') ||
        msg.contains('#INFO_CLIENT') ||
        msg.contains('#SEEYOU#') ||
        msg.contains('#ERROR#') ||
        (msg.contains('#OK_IMAGE_FOR#') && msg.contains('#FILE_SIZE#')) ||
        msg.contains('#GAME_CONTENT_TO#') ||
        msg.contains('#CONTENT_INFO_TO#') ||
        (msg.contains('#NEW_REVIEW_FOR#') && msg.contains('#AVG_SCORING#'));
  }

  void _handleCompleteMessage(String message) {
    // Para paquetes de stream, loguear solo un resumen (no el base64 completo)
    if (message.contains('#OK_CONTENT_STREAM_TO#') &&
        message.contains('#BYTES#')) {
      int bytesIdx = message.indexOf('#BYTES#');
      String summary = message.substring(0, bytesIdx + 7) + '<base64_data>';
      _log(
        summary,
        isSent: false,
        notify: false,
      ); // No notificar por cada paquete
    } else if (message.contains('#OK_IMAGE_FOR#') &&
        message.contains('#BYTES#')) {
      _log(
        '<image_packet>',
        isSent: false,
        notify: false,
      ); // No notificar por cada paquete
    } else if (message.contains('#USER_PHOTO_RESPONSE#') &&
        message.contains('#DATA#')) {
      _log('<user_photo_response>', isSent: false);
    } else {
      _log(message, isSent: false);
    }
    _processProtocolResponse(message);
  }

  // --- MANEJO DE IMAGEN ---

  void _handleContentStreamPacket(String response) {
    // Ignorar paquetes si no estamos en estado de streaming activo
    if (!_isReceivingContentStream) return;

    final b64 = Protocolo.extraerContentStreamBase64(response);
    if (b64 == null || b64.isEmpty) {
      _log("Stream: base64 vacío o nulo", isSent: false);
      return;
    }

    try {
      // Limpiar base64: quitar saltos de línea y espacios (Java MIME encoder añade \r\n)
      final cleanB64 = b64.replaceAll(RegExp(r'\s'), '');
      final bytes = base64Decode(cleanB64);
      _contentStreamBuilder.add(bytes);
      _contentStreamReceivedBytes += bytes.length;
      _contentStreamPacketCount++;

      final totalExpected = _contentDetail?.content.sizeBytes ?? 0;
      print(
        "[STREAM] Paquete #$_contentStreamPacketCount recibido: ${bytes.length} bytes | "
        "Acumulado: $_contentStreamReceivedBytes / $totalExpected",
      );

      // Throttle: actualizar UI solo cada 10 paquetes (no cada uno)
      if (_contentStreamPacketCount % 10 == 0) {
        notifyListeners();
      }

      // Verificar si la descarga está completa por tamaño
      if (_contentDetail != null &&
          totalExpected > 0 &&
          _contentStreamReceivedBytes >= totalExpected) {
        _finalizeContentStream();
      }
    } catch (e) {
      _log("Error decodificando paquete de contenido: $e", isSent: false);
      print("[STREAM ERROR] $e | base64 length: ${b64.length}");
    }
  }

  /// Finaliza el streaming de contenido y envía confirmación
  void _finalizeContentStream() {
    _contentBytes = _contentStreamBuilder.toBytes();
    _isReceivingContentStream = false;
    _isContentStreamComplete = true;
    _contentStreamBuilder.clear();

    _log(
      "Contenido recibido completo: $_contentStreamReceivedBytes bytes "
      "($_contentStreamPacketCount paquetes)",
      isSent: false,
    );
    notifyListeners();

    // Enviar confirmación RECEIVED_AND_FINISHED
    if (_socket != null && _usuarioActual != null) {
      final msg = Protocolo.armarContentReceivedAndFinished(
        _usuarioActual!.username,
        _usuarioActual!.token,
      );
      _socket!.write(msg);
      _log(msg.trim(), isSent: true);
    }

    // Solicitar fotos de usuarios del contenido
    if (_contentDetail != null) {
      _requestPhotosForContentDetail(_contentDetail!);
    }
  }

  void _handleImageMetadata(String response) {
    final metadata = Protocolo.extraerImageMetadata(response);
    if (metadata == null) {
      _isLoadingPhoto = false;
      _log("Error: No se pudo extraer metadata de imagen", isSent: false);
      notifyListeners();
      return;
    }

    _expectedFileSize = metadata['fileSize']!;
    _expectedSizePackage = metadata['sizePackage']!;
    _receivedImageBytes = 0;
    _imageBuilder.clear();
    _isReceivingImage = true;

    // Extraer usuario objetivo de la respuesta
    final targetUser = Protocolo.extraerImageTargetUser(response);
    if (targetUser != null) {
      _currentPhotoTarget = targetUser;
    }

    final msg = Protocolo.armarReadyToReceive(
      _currentPhotoTarget ?? _usuarioActual!.username,
      _usuarioActual!.token,
      _expectedFileSize,
      _expectedSizePackage,
    );
    _socket!.write(msg);
    _log(msg.trim(), isSent: true);
  }

  void _handleImagePacket(String response) {
    // Ignorar paquetes si no estamos recibiendo imagen
    if (!_isReceivingImage) return;

    final b64 = Protocolo.extraerImagePacketBase64(response);
    if (b64 == null || b64.isEmpty) return;

    try {
      // Limpiar \r\n del MIME encoder de Java
      final cleanB64 = b64.replaceAll(RegExp(r'\s'), '');
      final bytes = base64Decode(cleanB64);
      _imageBuilder.add(bytes);
      _receivedImageBytes += bytes.length;

      if (_expectedFileSize > 0 && _receivedImageBytes >= _expectedFileSize) {
        // Tamaño conocido (foto propia con metadata): finalizar inmediatamente
        _photoFinalizeTimer?.cancel();
        _finalizePhotoReception(sendConfirmation: true);
      } else if (_expectedFileSize < 0) {
        // Tamaño desconocido (foto de otro usuario, sin metadata):
        // El servidor envía todos los paquetes seguidos sin FILE_SIZE.
        // Usar timer: si no llegan más paquetes en 150ms, finalizar.
        _photoFinalizeTimer?.cancel();
        _photoFinalizeTimer = Timer(const Duration(milliseconds: 150), () {
          _finalizePhotoReception(sendConfirmation: false);
        });
      }
    } catch (e) {
      _log("Error decodificando paquete de imagen: $e", isSent: false);
    }
  }

  /// Finaliza la recepción de foto (común para foto propia y de otros usuarios)
  void _finalizePhotoReception({required bool sendConfirmation}) {
    final photoBytes = _imageBuilder.toBytes();
    _isReceivingImage = false;
    _isLoadingPhoto = false;
    _imageBuilder.clear();

    // Almacenar en mapa de fotos por username
    if (_currentPhotoTarget != null) {
      _userPhotosMap[_currentPhotoTarget!] = photoBytes;
    }
    // Si es la foto del usuario autenticado, también guardar en _userPhoto
    if (_currentPhotoTarget == _usuarioActual?.username) {
      _userPhoto = photoBytes;
    }

    _log(
      "Imagen de ${_currentPhotoTarget ?? 'usuario'} recibida: $_receivedImageBytes bytes",
      isSent: false,
    );
    notifyListeners();

    // Enviar confirmación solo para fotos propias (con metadata/handshake)
    if (sendConfirmation && _socket != null && _usuarioActual != null) {
      final msg = Protocolo.armarReceivedAndFinished(
        _currentPhotoTarget ?? _usuarioActual!.username,
        _usuarioActual!.token,
      );
      _socket!.write(msg);
      _log(msg.trim(), isSent: true);
    }

    // Procesar siguiente foto en cola
    _currentPhotoTarget = null;
    _processNextPhotoRequest();
  }

  // --- MANEJO DE USER_PHOTO_RESPONSE (foto de otro usuario) ---

  void _handleUserPhotoResponse(String response) {
    final data = Protocolo.parsearUserPhotoResponse(response);
    if (data == null) {
      _isLoadingPhoto = false;
      _currentPhotoTarget = null;
      notifyListeners();
      _processNextPhotoRequest();
      return;
    }

    try {
      String targetUser = data['targetUser'];
      String b64 = data['base64'];
      final cleanB64 = b64.replaceAll(RegExp(r'\s'), '');
      final bytes = base64Decode(cleanB64);

      _userPhotosMap[targetUser] = Uint8List.fromList(bytes);
      _isLoadingPhoto = false;

      _log(
        "Foto de $targetUser recibida: ${bytes.length} bytes",
        isSent: false,
      );
      notifyListeners();
    } catch (e) {
      _log("Error decodificando foto de usuario: $e", isSent: false);
      _isLoadingPhoto = false;
    }

    _currentPhotoTarget = null;
    _processNextPhotoRequest();
  }

  // --- MANEJO DE BROADCAST DE REVIEW ---

  void _handleNewReviewBroadcast(String response) {
    final data = Protocolo.parsearNewReviewBroadcast(response);
    if (data == null) return;

    String contentId = data['contentId'];

    // Solo actualizar si tenemos este contenido abierto
    if (_contentDetail != null && _contentDetail!.content.id == contentId) {
      // Crear nueva review
      final newReview = Review(
        username: data['username'],
        fecha: data['date'],
        texto: data['reviewText'],
        calificacion: (data['scoring'] as int).toDouble(),
      );

      // Crear contenido actualizado con nueva media
      final updatedContent = Content(
        id: _contentDetail!.content.id,
        nombre: _contentDetail!.content.nombre,
        avgValoracion: data['avgScoring'],
        sizeBytes: _contentDetail!.content.sizeBytes,
        format: _contentDetail!.content.format,
      );

      // Actualizar detalle
      _contentDetail = ContentDetail(
        content: updatedContent,
        reviews: [..._contentDetail!.reviews, newReview],
        associatedUsers: _contentDetail!.associatedUsers,
      );

      _log(
        "Nueva review de ${data['username']} para contenido $contentId (media: ${data['avgScoring']})",
        isSent: false,
      );
      notifyListeners();

      // Solicitar foto del reviewer si no la tenemos
      if (!_userPhotosMap.containsKey(data['username'])) {
        requestPhotosForUsers([data['username']]);
      }
    }
  }

  // --- PROCESAMIENTO DE PROTOCOLO ---

  void _processProtocolResponse(String response) {
    // 0. PAQUETE DE STREAMING DE CONTENIDO
    if (Protocolo.esContentStreamPacket(response)) {
      _handleContentStreamPacket(response);
      return;
    }
    // 1. USER_PHOTO_RESPONSE (respuesta directa de foto de otro usuario)
    if (Protocolo.esUserPhotoResponse(response)) {
      _handleUserPhotoResponse(response);
      return;
    }
    // 2. PAQUETE DE IMAGEN con streaming (verificar ANTES que metadata)
    if (Protocolo.esImagePacket(response)) {
      _handleImagePacket(response);
      return;
    }
    // 3. METADATA DE IMAGEN (OK_IMAGE_FOR con FILE_SIZE)
    if (Protocolo.esOkImageMetadata(response)) {
      _handleImageMetadata(response);
      return;
    }
    // 4. BROADCAST DE NUEVA REVIEW
    if (Protocolo.esNewReviewBroadcast(response)) {
      _handleNewReviewBroadcast(response);
      return;
    }
    // 5. LOGIN EXITOSO -> PEDIR PERFIL
    if (Protocolo.esBienvenida(response)) {
      String token = Protocolo.extraerToken(response);
      final partes = response.split("#");
      String userLogin = partes.length > 3 ? partes[3] : "unknown";

      _loginStatus = LoginStatus.fetchingProfile;
      notifyListeners();

      final msgInfo = Protocolo.armarGetInfoCliente(userLogin, token);
      _socket!.write(msgInfo);
      _log(msgInfo.trim(), isSent: true);
    }
    // 6. RECIBIR INFO CLIENTE (PERFIL + CONTENIDOS)
    else if (Protocolo.esInfoCliente(response)) {
      final user = Protocolo.parsearUsuario(response);
      if (user != null) {
        _usuarioActual = user;
        _loginStatus = LoginStatus.success;
        notifyListeners();
        // Pedir foto del usuario automáticamente
        requestUserPhoto();
      } else {
        _lastErrorMessage = "Error al procesar datos del usuario";
        _loginStatus = LoginStatus.error;
        notifyListeners();
      }
    }
    // 7. DETALLE DE CONTENIDO
    else if (Protocolo.esGameContent(response)) {
      final detail = Protocolo.parsearContentDetail(response);
      if (detail != null) {
        _contentDetail = detail;
        _isLoadingContentDetail = false;
        _contentDetailError = '';
        notifyListeners();

        // Iniciar streaming: enviar OK_INFO_CONTENT_RECEIVED
        _contentStreamReceivedBytes = 0;
        _contentStreamPacketCount = 0;
        _contentStreamBuilder.clear();
        _contentBytes = null;
        _isReceivingContentStream = true;
        _isContentStreamComplete = false;

        print(
          "[STREAM] Iniciando streaming para content ${detail.content.id} "
          "| sizeBytes esperado: ${detail.content.sizeBytes}",
        );

        final msg = Protocolo.armarOkInfoContentReceived(
          detail.content.id,
          _usuarioActual!.username,
          _usuarioActual!.token,
        );
        _socket!.write(msg);
        _log(msg.trim(), isSent: true);
      } else {
        _isLoadingContentDetail = false;
        _contentDetailError = 'Error al procesar datos del contenido';
        notifyListeners();
      }
    }
    // 8. CONFIRMACIÓN DE LOGOUT
    else if (Protocolo.esDespedida(response)) {
      _log("Servidor confirmó salida (SEEYOU). Cerrando...", isSent: false);
      disconnect();
    }
    // 9. ERRORES
    else if (Protocolo.esError(response)) {
      String errorCode = Protocolo.extraerMensajeError(response);

      if (errorCode.contains("PHOTO_NOT_FOUND")) {
        // Sin foto para este usuario, usar avatar por defecto
        _photoFinalizeTimer?.cancel();
        _isReceivingImage = false;
        _isLoadingPhoto = false;
        _imageBuilder.clear();
        _receivedImageBytes = 0;
        _log(
          "Sin foto para ${_currentPhotoTarget ?? 'usuario'}",
          isSent: false,
        );
        _currentPhotoTarget = null;
        notifyListeners();
        _processNextPhotoRequest();
      } else if (_isReceivingImage || _isLoadingPhoto) {
        _photoFinalizeTimer?.cancel();
        _isReceivingImage = false;
        _isLoadingPhoto = false;
        _imageBuilder.clear();
        _receivedImageBytes = 0;
        if (_currentPhotoTarget == _usuarioActual?.username ||
            _currentPhotoTarget == null) {
          _lastErrorMessage = errorCode;
        }
        _log(
          "Error al recibir imagen de ${_currentPhotoTarget ?? 'usuario'}: $errorCode",
          isSent: false,
        );
        _currentPhotoTarget = null;
        notifyListeners();
        // Procesar siguiente foto en cola
        _processNextPhotoRequest();
      } else if (errorCode.contains("GAME_NOT_FOUND") ||
          errorCode.contains("CONTENT_NOT_FOUND")) {
        _isReceivingContentStream = false;
        if (_contentDetail != null) {
          // El detalle ya fue cargado, solo marcar que el stream falló
          _contentStreamFailed = true;
          _isLoadingContentDetail = false;
          notifyListeners();
          // Solicitar fotos de usuarios
          _requestPhotosForContentDetail(_contentDetail!);
        } else {
          _isLoadingContentDetail = false;
          _contentDetailError = 'Contenido no encontrado.';
          notifyListeners();
        }
      } else if (errorCode.contains("STOP_HACKERS") ||
          errorCode.contains("MAX_CONNECTIONS_REACHED")) {
        // Errores que requieren desconexión forzosa
        disconnect();
        // Establecer mensaje de error DESPUÉS de disconnect para preservarlo
        if (errorCode.contains("MAX_CONNECTIONS_REACHED")) {
          _lastErrorMessage =
              "Máximo de conexiones alcanzado. Intente más tarde.";
        } else {
          _lastErrorMessage = "Acceso bloqueado.";
        }
        _loginStatus = LoginStatus.error;
        notifyListeners();
      } else if (errorCode.contains("CANT_SET_REVIEW")) {
        _reviewSubmitError = 'No se pudo enviar la valoración';
        notifyListeners();
      } else {
        _lastErrorMessage = errorCode;
        _loginStatus = LoginStatus.error;
        notifyListeners();
      }
    }
  }

  // Utilidades
  void _log(String msg, {required bool isSent, bool notify = true}) {
    _logs.add(LogMessage(msg, isSent));
    if (notify) notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  void resetLoginStatus() {
    _loginStatus = LoginStatus.none;
    _lastErrorMessage = "";
    notifyListeners();
  }
}
