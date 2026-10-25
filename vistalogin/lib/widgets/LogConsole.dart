import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../socket_service.dart'; // Ajusta la ruta si es necesario

class LogConsole extends StatefulWidget {
  const LogConsole({super.key});

  @override
  State<LogConsole> createState() => _LogConsoleState();
}

class _LogConsoleState extends State<LogConsole> {
  bool _isExpanded = false; // Empieza cerrado

  @override
  Widget build(BuildContext context) {
    final socketService = Provider.of<SocketService>(context);
    final screenSize = MediaQuery.of(context).size;
    final double height = _isExpanded ? 300 : 40; // Alto expandido vs cerrado

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Material( // Necesario porque estamos fuera del Scaffold
        type: MaterialType.transparency,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: height,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, -2))
            ],
          ),
          child: Column(
            children: [
              // --- BARRA DE TÍTULO (Click para abrir/cerrar) ---
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(_isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          const Text("CONSOLE LOG", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 10),
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: socketService.isConnected ? Colors.green : Colors.red,
                            ),
                          )
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.white54, size: 18),
                        onPressed: () => socketService.clearLogs(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    ],
                  ),
                ),
              ),

              // --- LISTA DE LOGS ---
              if (_isExpanded)
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: socketService.logs.length,
                    itemBuilder: (context, index) {
                      // Mostramos los logs más recientes abajo (hacemos reverse visual o scroll)
                      // Aquí usamos el orden natural
                      final log = socketService.logs[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontFamily: 'Courier', fontSize: 11),
                            children: [
                              TextSpan(
                                text: "[${DateFormat('HH:mm:ss').format(log.timestamp)}] ",
                                style: const TextStyle(color: Colors.grey),
                              ),
                              TextSpan(
                                text: log.isSent ? "TX >> " : "RX << ",
                                style: TextStyle(color: log.isSent ? Colors.greenAccent : Colors.orangeAccent, fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: log.message,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}