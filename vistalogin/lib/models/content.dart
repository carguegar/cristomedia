class Content {
  final String id;
  final String nombre;
  final double avgValoracion;
  final int sizeBytes;
  final String format;

  Content({
    required this.id,
    required this.nombre,
    required this.avgValoracion,
    required this.sizeBytes,
    required this.format,
  });

  // Helper para mostrar tamaño legible
  String get sizeLegible {
    if (sizeBytes < 1024) return "$sizeBytes B";
    if (sizeBytes < 1048576)
      return "${(sizeBytes / 1024).toStringAsFixed(1)} KB";
    return "${(sizeBytes / 1048576).toStringAsFixed(1)} MB";
  }
}
