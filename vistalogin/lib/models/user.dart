import 'content.dart';

class Usuario {
  final String username;
  final String nombre;
  final String apellido1; // Separado
  final String apellido2; // Separado
  final String token;

  final List<Content> contenidos; // Contenidos del usuario
  final List<Content> contenidosSistema; // TODOS los contenidos del sistema

  Usuario({
    required this.username,
    required this.nombre,
    required this.apellido1,
    required this.apellido2,
    required this.token,
    required this.contenidos,
    required this.contenidosSistema,
  });

  factory Usuario.create({
    required String username,
    required String nombre,
    required String apellido1,
    required String apellido2,
    required String token,
    required List<Content> contenidos,
    required List<Content> contenidosSistema,
  }) {
    return Usuario(
      username: username,
      nombre: nombre,
      apellido1: apellido1,
      apellido2: apellido2,
      token: token,
      contenidos: contenidos,
      contenidosSistema: contenidosSistema,
    );
  }
}
