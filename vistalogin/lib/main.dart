import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'socket_service.dart';
import 'home_screen.dart';
import 'widgets/LogConsole.dart'; // Importamos el widget nuevo

void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => SocketService())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cliente Socket',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),

      // AQUÍ ESTÁ EL TRUCO: El builder envuelve cualquier ruta que navegues
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child, // La pantalla actual (Login, Home, etc.)
            const LogConsole(), // La consola siempre encima
          ],
        );
      },

      home: const LoginScreen(),
    );
  }
}

// Pantalla de Login (Limpiada, ya no necesita Stack propio para el log)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Valores por defecto para probar en local. Cámbialos desde la pantalla
  // de login si el servidor está en otra máquina.
  final _ipCtrl = TextEditingController(text: "127.0.0.1");
  final _portCtrl = TextEditingController(text: "4444");
  final _userCtrl = TextEditingController(text: "demo1");
  final _passCtrl = TextEditingController(text: "demo123");

  @override
  Widget build(BuildContext context) {
    final socketService = Provider.of<SocketService>(context);

    // Listener para navegar
    if (socketService.loginStatus == LoginStatus.success) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        socketService.resetLoginStatus();
        Navigator.pushReplacement(
          // Usamos Replacement para no volver al login con 'atrás'
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      });
    }

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text("Acceso Cliente"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      // Añadimos padding bottom para que la consola no tape el botón si está cerrada
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 60),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 20,
                  color: Colors.black12,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.security, size: 60, color: Colors.indigo),
                const SizedBox(height: 20),
                const Text(
                  "Iniciar Sesión",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),

                TextField(
                  controller: _ipCtrl,
                  decoration: const InputDecoration(
                    labelText: "IP",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _portCtrl,
                  decoration: const InputDecoration(
                    labelText: "Puerto",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _userCtrl,
                  decoration: const InputDecoration(
                    labelText: "Usuario",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Contraseña",
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),

                if (socketService.loginStatus == LoginStatus.error)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      socketService.lastErrorMessage,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    onPressed:
                        (socketService.loginStatus == LoginStatus.loading ||
                            socketService.loginStatus ==
                                LoginStatus.fetchingProfile)
                        ? null
                        : () async {
                            if (!socketService.isConnected) {
                              await socketService.connect(
                                _ipCtrl.text,
                                _portCtrl.text,
                              );
                            }
                            if (socketService.isConnected) {
                              socketService.sendLogin(
                                _userCtrl.text,
                                _passCtrl.text,
                              );
                            }
                          },
                    child:
                        (socketService.loginStatus == LoginStatus.loading ||
                            socketService.loginStatus ==
                                LoginStatus.fetchingProfile)
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )
                        : const Text("CONECTAR"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
