import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'socket_service.dart';
import 'models/content.dart';
import 'models/review.dart';
import 'models/associated_user.dart';

class ContentDetailScreen extends StatefulWidget {
  final Content content;

  const ContentDetailScreen({super.key, required this.content});

  @override
  State<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Pedir detalle al servidor al entrar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final socketService = Provider.of<SocketService>(context, listen: false);
      socketService.requestContentDetail(widget.content.id);
    });
  }

  @override
  void dispose() {
    // Limpiar detalle al salir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // No podemos usar context en dispose, usamos directamente
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final socketService = Provider.of<SocketService>(context);
    final detail = socketService.contentDetail;
    final isLoading = socketService.isLoadingContentDetail;
    final error = socketService.contentDetailError;

    // Mostrar error de review si existe
    if (socketService.reviewSubmitError.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(socketService.reviewSubmitError),
              backgroundColor: Colors.red,
            ),
          );
          socketService.clearReviewError();
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        title: Text(widget.content.nombre),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            socketService.clearContentDetail();
            Navigator.pop(context);
          },
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    error,
                    style: TextStyle(color: Colors.red[700], fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () =>
                        socketService.requestContentDetail(widget.content.id),
                    icon: const Icon(Icons.refresh),
                    label: const Text("Reintentar"),
                  ),
                ],
              ),
            )
          : detail == null
          ? const Center(child: Text("Cargando..."))
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 800) {
                  return _buildMobileLayout(
                    context,
                    socketService,
                    detail.content,
                    detail.reviews,
                    detail.associatedUsers,
                  );
                } else {
                  return _buildDesktopLayout(
                    context,
                    socketService,
                    detail.content,
                    detail.reviews,
                    detail.associatedUsers,
                  );
                }
              },
            ),
    );
  }

  // ============================
  // LAYOUT ESCRITORIO
  // ============================
  Widget _buildDesktopLayout(
    BuildContext context,
    SocketService socketService,
    Content content,
    List<Review> reviews,
    List<AssociatedUser> associatedUsers,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- FILA SUPERIOR: Info + Thumbnail + Acciones ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info del contenido (IP, Puerto, Tamaño, Ruta)
              SizedBox(
                width: 200,
                child: _buildContentInfo(content, socketService),
              ),
              const SizedBox(width: 24),

              // Thumbnail central
              Expanded(child: _buildThumbnail(content, socketService)),
              const SizedBox(width: 24),

              // Acciones a la derecha
              SizedBox(
                width: 180,
                child: _buildActions(content, socketService),
              ),
            ],
          ),
          const SizedBox(height: 30),

          // --- FILA INFERIOR: Valoraciones + Usuarios Asociados ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Valoraciones
              Expanded(
                flex: 3,
                child: _buildReviewsSection(reviews, content.id, socketService),
              ),
              const SizedBox(width: 20),
              // Usuarios Asociados
              Expanded(
                flex: 2,
                child: _buildAssociatedUsersSection(
                  associatedUsers,
                  socketService,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================
  // LAYOUT MÓVIL
  // ============================
  Widget _buildMobileLayout(
    BuildContext context,
    SocketService socketService,
    Content content,
    List<Review> reviews,
    List<AssociatedUser> associatedUsers,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          _buildThumbnail(content, socketService),
          const SizedBox(height: 16),

          // Info
          _buildContentInfo(content, socketService),
          const SizedBox(height: 16),

          // Acciones
          _buildActions(content, socketService),
          const SizedBox(height: 24),

          // Valoraciones
          _buildReviewsSection(reviews, content.id, socketService),
          const SizedBox(height: 24),

          // Usuarios Asociados
          _buildAssociatedUsersSection(associatedUsers, socketService),
          const SizedBox(height: 80), // Extra padding para scroll
        ],
      ),
    );
  }

  // ============================
  // COMPONENTES REUTILIZABLES
  // ============================

  /// Título del contenido + Preview según formato
  Widget _buildThumbnail(Content content, SocketService socketService) {
    final format = content.format.toLowerCase();
    final bytes = socketService.contentBytes;
    final isComplete = socketService.isContentStreamComplete;
    final isReceiving = socketService.isReceivingContentStream;
    final progress = socketService.contentStreamProgress;

    return Column(
      children: [
        Text(
          content.nombre,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          height: 220,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildPreviewContent(
              format,
              bytes,
              isComplete,
              isReceiving,
              progress,
            ),
          ),
        ),
      ],
    );
  }

  /// Contenido de preview según formato
  Widget _buildPreviewContent(
    String format,
    Uint8List? bytes,
    bool isComplete,
    bool isReceiving,
    double progress,
  ) {
    if (['png', 'jpg', 'jpeg'].contains(format)) {
      // Imágenes: se muestran directamente cuando están completas
      if (isComplete && bytes != null) {
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 220,
          errorBuilder: (context, error, stackTrace) {
            return _buildDownloadPlaceholder(
              Icons.broken_image,
              'Error al mostrar imagen',
              false,
              0,
            );
          },
        );
      }
      return _buildDownloadPlaceholder(
        Icons.image,
        format.toUpperCase(),
        isReceiving,
        progress,
      );
    } else if (format == 'mp4') {
      // Video: solo indicador de texto, sin botón de play
      return _buildDownloadPlaceholder(
        Icons.movie,
        'Video MP4',
        isReceiving,
        progress,
      );
    } else if (format == 'pdf') {
      // PDF: icono genérico
      return _buildDownloadPlaceholder(
        Icons.picture_as_pdf,
        'PDF',
        isReceiving,
        progress,
      );
    } else {
      // Formato no soportado
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'Formato no soportado',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }
  }

  /// Placeholder con progreso de descarga
  Widget _buildDownloadPlaceholder(
    IconData icon,
    String label,
    bool isReceiving,
    double progress,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 60,
            color: icon == Icons.picture_as_pdf
                ? Colors.red[300]
                : Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
            ),
          ),
          if (isReceiving) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.indigo),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  /// Info del servidor y contenido (IP, Puerto, Tamaño, Ruta)
  Widget _buildContentInfo(Content content, SocketService socketService) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoField(label: "IP", value: socketService.serverIP),
            const SizedBox(height: 10),
            _InfoField(label: "Puerto", value: socketService.serverPort),
            const SizedBox(height: 10),
            _InfoField(label: "Tamaño", value: content.sizeLegible),
            const SizedBox(height: 10),
            _InfoField(label: "Formato", value: content.format.toUpperCase()),
          ],
        ),
      ),
    );
  }

  /// Botones de acción según formato
  Widget _buildActions(Content content, SocketService socketService) {
    final format = content.format.toLowerCase();
    final isComplete = socketService.isContentStreamComplete;
    final isReceiving = socketService.isReceivingContentStream;
    final streamFailed = socketService.contentStreamFailed;
    final isSupported = ['mp4', 'png', 'jpg', 'jpeg', 'pdf'].contains(format);
    // Mostrar botón para video, PDF e imágenes
    final showButton = ['mp4', 'pdf', 'png', 'jpg', 'jpeg'].contains(format);

    return Column(
      children: [
        if (showButton && streamFailed)
          SizedBox(
            width: double.infinity,
            child: Card(
              elevation: 0,
              color: Colors.orange[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.orange.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Contenido\nNo Disponible",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (showButton)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isComplete ? Colors.indigo : Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: isComplete
                  ? () => _viewContent(format, socketService)
                  : null,
              icon: Icon(
                format == 'mp4'
                    ? Icons.play_arrow
                    : ['png', 'jpg', 'jpeg'].contains(format)
                    ? Icons.image
                    : Icons.visibility,
              ),
              label: const Text("Ver\nContenido", textAlign: TextAlign.center),
            ),
          )
        else if (!isSupported)
          SizedBox(
            width: double.infinity,
            child: Card(
              elevation: 0,
              color: Colors.red[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.red.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  "Formato no soportado",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        if (isReceiving) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: socketService.contentStreamProgress,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.indigo,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Descargando... ${(socketService.contentStreamProgress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        // Valoración media
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  "Valoración Media",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ...List.generate(5, (i) {
                      return Icon(
                        i < content.avgValoracion.round()
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                        size: 20,
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  content.avgValoracion.toStringAsFixed(1),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Abrir contenido según formato
  Future<void> _viewContent(String format, SocketService socketService) async {
    final bytes = socketService.contentBytes;
    if (bytes == null) return;
    final contentId = socketService.contentDetail?.content.id ?? 'unknown';

    try {
      final dir = await getTemporaryDirectory();

      if (format == 'mp4') {
        final file = File('${dir.path}/content_$contentId.mp4');
        await file.writeAsBytes(bytes);

        // Abrir con reproductor del sistema
        if (Platform.isWindows) {
          await Process.run('cmd', ['/c', 'start', '', file.path]);
        } else if (Platform.isMacOS) {
          await Process.run('open', [file.path]);
        } else if (Platform.isLinux) {
          await Process.run('xdg-open', [file.path]);
        }
      } else if (format == 'pdf') {
        final file = File('${dir.path}/content_$contentId.pdf');
        await file.writeAsBytes(bytes);

        // Abrir con visor del sistema
        if (Platform.isWindows) {
          await Process.run('cmd', ['/c', 'start', '', file.path]);
        } else if (Platform.isMacOS) {
          await Process.run('open', [file.path]);
        } else if (Platform.isLinux) {
          await Process.run('xdg-open', [file.path]);
        }
      } else if (['png', 'jpg', 'jpeg'].contains(format)) {
        final file = File('${dir.path}/content_$contentId.$format');
        await file.writeAsBytes(bytes);

        // Abrir con visor de imágenes del sistema
        if (Platform.isWindows) {
          await Process.run('cmd', ['/c', 'start', '', file.path]);
        } else if (Platform.isMacOS) {
          await Process.run('open', [file.path]);
        } else if (Platform.isLinux) {
          await Process.run('xdg-open', [file.path]);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al abrir contenido: $e")));
    }
  }

  /// Diálogo para añadir una nueva reseña
  void _showNewReviewDialog(BuildContext context, String contentId) {
    final textCtrl = TextEditingController();
    int selectedScore = 3;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Nueva Reseña"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: textCtrl,
                    maxLength: 256,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: "Escribe tu reseña...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("Puntuación:"),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      return IconButton(
                        icon: Icon(
                          i < selectedScore ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            selectedScore = i + 1;
                          });
                        },
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (textCtrl.text.trim().isNotEmpty) {
                      final socketService = Provider.of<SocketService>(
                        context,
                        listen: false,
                      );
                      socketService.sendNewReview(
                        contentId,
                        textCtrl.text.trim(),
                        selectedScore,
                      );
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: const Text("Enviar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Sección de valoraciones/reviews
  Widget _buildReviewsSection(
    List<Review> reviews,
    String contentId,
    SocketService socketService,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Valoraciones",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _showNewReviewDialog(context, contentId),
                  icon: const Icon(Icons.rate_review, size: 18),
                  label: const Text("Añadir Reseña"),
                ),
              ],
            ),
            const Divider(),
            if (reviews.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    "Sin valoraciones",
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ),
              )
            else
              ...reviews.map(
                (review) => _ReviewTile(
                  review: review,
                  userPhoto: socketService.userPhotosMap[review.username],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Sección de usuarios asociados
  Widget _buildAssociatedUsersSection(
    List<AssociatedUser> users,
    SocketService socketService,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Usuarios Asociados",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            if (users.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    "Sin usuarios asociados",
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ),
              )
            else
              ...users.map(
                (user) => _AssociatedUserTile(
                  user: user,
                  userPhoto: socketService.userPhotosMap[user.username],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================
// WIDGETS AUXILIARES
// ============================

/// Campo de info con label y valor
class _InfoField extends StatelessWidget {
  final String label;
  final String value;

  const _InfoField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(value, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}

/// Tile de una review/valoración
class _ReviewTile extends StatelessWidget {
  final Review review;
  final Uint8List? userPhoto;

  const _ReviewTile({required this.review, this.userPhoto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.indigo.shade50,
                backgroundImage: userPhoto != null
                    ? MemoryImage(userPhoto!)
                    : null,
                child: userPhoto != null
                    ? null
                    : Text(
                        review.username.isNotEmpty
                            ? review.username[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  review.username,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              // Estrellas
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < review.calificacion.round()
                        ? Icons.star
                        : Icons.star_border,
                    color: Colors.amber,
                    size: 16,
                  );
                }),
              ),
              const SizedBox(width: 10),
              Text(
                review.fecha,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              review.texto,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tile de un usuario asociado
class _AssociatedUserTile extends StatelessWidget {
  final AssociatedUser user;
  final Uint8List? userPhoto;

  const _AssociatedUserTile({required this.user, this.userPhoto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: userPhoto != null ? MemoryImage(userPhoto!) : null,
            child: userPhoto != null
                ? null
                : Text(
                    user.username.isNotEmpty
                        ? user.username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  "${user.apellido1} ${user.apellido2}",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  user.email,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
