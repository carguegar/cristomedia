import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'socket_service.dart';
import 'content_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final socketService = Provider.of<SocketService>(context);
    final user = socketService.usuarioActual;

    // --- 1. PROTECCIÓN DE NAVEGACIÓN ---
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // --- 2. LAYOUT RESPONSIVO ---
    // Usamos LayoutBuilder para saber el ancho de la pantalla
    return LayoutBuilder(
      builder: (context, constraints) {
        // Consideramos "Móvil" si el ancho es menor a 800px
        bool isMobile = constraints.maxWidth < 800;

        if (isMobile) {
          // --- VISTA MÓVIL (Con Drawer/Menú desplegable) ---
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text("CristoMedia"),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            // Aquí está la magia: El menú lateral se convierte en un Drawer
            drawer: Drawer(
              child: _ProfilePanel(user: user, socketService: socketService),
            ),
            body: _ContentArea(user: user),
          );
        } else {
          // --- VISTA ESCRITORIO (Dos columnas fijas) ---
          return Scaffold(
            backgroundColor: Colors.white,
            body: Row(
              children: [
                // Columna Izquierda (Fija)
                SizedBox(
                  width: 300,
                  child: Container(
                    color: Colors.grey[50],
                    child: _ProfilePanel(
                      user: user,
                      socketService: socketService,
                    ),
                  ),
                ),
                // Línea divisoria vertical
                VerticalDivider(width: 1, color: Colors.grey[300]),
                // Columna Derecha (Contenido)
                Expanded(child: _ContentArea(user: user)),
              ],
            ),
          );
        }
      },
    );
  }
}

// =================================================================
// WIDGET 1: PANEL DE PERFIL (Reutilizable para Sidebar y Drawer)
// =================================================================
class _ProfilePanel extends StatelessWidget {
  final dynamic user; // Tipar como 'Usuario' si tienes el import a mano
  final SocketService socketService;

  const _ProfilePanel({required this.user, required this.socketService});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Parte superior Scrollable (Datos)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.indigo.shade50,
                      backgroundImage: socketService.userPhoto != null
                          ? MemoryImage(socketService.userPhoto!)
                          : null,
                      child: socketService.userPhoto != null
                          ? null
                          : socketService.isLoadingPhoto
                          ? const SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.indigo,
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              size: 45,
                              color: Colors.indigo,
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    "PERFIL DE USUARIO",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Divider(),
                  _DataRow(label: "Username", value: user.username),
                  const SizedBox(height: 10),
                  _DataRow(label: "Nombre", value: user.nombre),
                  _DataRow(
                    label: "Apellidos",
                    value: "${user.apellido1} ${user.apellido2}",
                  ),

                  const SizedBox(height: 25),
                  const Text(
                    "ESTADÍSTICAS",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Divider(),
                  _DataRow(
                    label: "Contenidos Totales",
                    value: "${user.contenidos.length}",
                  ),
                  _DataRow(
                    label: "Servidor",
                    value:
                        "${socketService.serverIP}:${socketService.serverPort}",
                  ),
                ],
              ),
            ),
          ),

          // Parte inferior (Botón de salida)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red,
                    minimumSize: const Size(double.infinity, 50),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    socketService.logout();
                    // Si estamos en movil (Drawer abierto), lo cerramos antes de salir
                    if (Scaffold.of(context).hasDrawer) {
                      Navigator.pop(context);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Cerrando sesión..."),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text("Cerrar Sesión"),
                ),
                // Espacio de seguridad por si hay barras de navegación de iOS/Android
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// WIDGET 2: ÁREA DE CONTENIDO (Buscador + Grid)
// =================================================================
class _ContentArea extends StatefulWidget {
  final dynamic user;

  const _ContentArea({required this.user});

  @override
  State<_ContentArea> createState() => _ContentAreaState();
}

class _ContentAreaState extends State<_ContentArea> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Contenidos del usuario (grid por defecto) y del sistema (búsqueda)
    final userContents = widget.user.contenidos as List;
    final systemContents = widget.user.contenidosSistema as List;

    // Sin búsqueda: mostrar contenidos del usuario
    // Con búsqueda: buscar en TODOS los contenidos del sistema
    final sourceList = _searchQuery.isEmpty ? userContents : systemContents;
    final filtered = _searchQuery.isEmpty
        ? sourceList
        : sourceList.where((c) {
            final nombre = c.nombre.toString().toLowerCase();
            final id = c.id.toString().toLowerCase();
            final format = c.format.toString().toLowerCase();
            final query = _searchQuery.toLowerCase();
            return nombre.contains(query) || id.contains(query) || format.contains(query);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Buscador ---
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (value) {
              setState(() { _searchQuery = value; });
            },
            decoration: InputDecoration(
              hintText: "Buscar contenido...",
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() { _searchQuery = ''; });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            ),
          ),
        ),

        // --- Título y Contador ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _searchQuery.isEmpty ? "Mis Contenidos" : "Resultados (Sistema)",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${filtered.length}",
                  style: const TextStyle(
                    color: Colors.indigo,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // --- Grid ---
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isEmpty ? Icons.folder_off : Icons.search_off,
                        size: 60,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _searchQuery.isEmpty
                            ? "Sin contenidos disponibles"
                            : "Sin resultados para \"$_searchQuery\"",
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final content = filtered[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ContentDetailScreen(content: content),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    content.format.toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.grey[300],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      content.nombre,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          content.sizeLegible,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            const Icon(Icons.star, size: 12, color: Colors.amber),
                                            Text(
                                              " ${content.avgValoracion}",
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// Widget auxiliar para filas de datos
class _DataRow extends StatelessWidget {
  final String label;
  final String value;
  const _DataRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          SelectableText(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
