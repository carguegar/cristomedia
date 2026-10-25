package client;

import javax.swing.*;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.PrintWriter;
import java.net.Socket;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

public class ControladorCliente {

    private final VistaCliente vista;

    // Estado de la conexión
    private Socket socket;
    private PrintWriter out;
    private TareaEscuchar tareaEscuchar;

    // Constantes del Protocolo
    private static final String HEADER = "PROTOCOLCRISTOMEDIA1.0";
    private static final DateTimeFormatter FORMATO_HORA = DateTimeFormatter.ofPattern("HH:mm:ss");

    public ControladorCliente(VistaCliente vista) {
        this.vista = vista;
        initListeners();
    }

    private void initListeners() {
        // 1. Botón Login
        vista.setLoginListener(e -> iniciarProcesoLogin());

        // 2. Botón Logout
        vista.setLogoutListener(e -> desconectar("Cierre de sesión manual"));

        // 3. Botón Enviar
        vista.setEnviarListener(e -> enviarMensajeChat());
    }

    // --- LÓGICA DE CONEXIÓN (Paso 1) ---
    private void iniciarProcesoLogin() {
        String ip = vista.getIp();
        int puerto = vista.getPuerto();

        // Validaciones básicas
        if (ip.isEmpty() || puerto == 0) {
            vista.agregarLog("[ERROR] IP o Puerto inválidos.");
            return;
        }
        if (vista.getUsuario().isEmpty()) {
            vista.agregarLog("[ERROR] Debes introducir un usuario.");
            return;
        }

        vista.agregarLog("[SISTEMA] Conectando al servidor...");

        // Creamos la tarea Runnable para no congelar la UI
        TareaConectar tarea = new TareaConectar(ip, puerto, this);
        new Thread(tarea).start();
    }

    // --- CALLBACKS DE RED (Llamados por TareaConectar y TareaEscuchar) ---

    public void onConexionExitosa(Socket s, PrintWriter out, BufferedReader in) {
        this.socket = s;
        this.out = out;

        SwingUtilities.invokeLater(() -> vista.agregarLog("[SISTEMA] Conexión establecida."));

        // Preparamos la trama
        String user = vista.getUsuario();
        String pass = vista.getPassword();
        String trama = HEADER + "#" + LocalDateTime.now() + "#LOGIN#" + user + "#" + pass;

        // --- LOG DE SALIDA ---
        vista.agregarLog("--> [OUT]: " + trama);
        // ---------------------

        out.println(trama);

        iniciarEscucha(in);
    }

    public void onConexionFallida(String error) {
        SwingUtilities.invokeLater(() -> vista.agregarLog("[ERROR FATAL] No se pudo conectar: " + error));
    }

    // Paso 3: Recibimos mensajes del servidor
    public void onMensajeRecibido(String mensaje) {
        SwingUtilities.invokeLater(() -> {

            // --- LOG DE ENTRADA (Lo primero de todo) ---
            vista.agregarLog("<-- [IN]: " + mensaje);
            // -------------------------------------------

            // Luego sigue tu lógica normal...
            if (mensaje.contains("#WELLCOME#")) {
                vista.setSesionIniciada(true);
                vista.agregarLog("[SISTEMA] ¡Login correcto!");
            } else if (mensaje.contains("#ERROR#")) {
                // ...
                if (mensaje.contains("BAD_CREDENTIALS")) {
                    desconectar("Credenciales incorrectas");
                }
            } else {
                // Mensajes de chat normales, ya se han logueado arriba con el [IN]
                // pero si quieres que salga bonito también:
                // vista.agregarLog("[CHAT]: " + mensaje);
            }
        });
    }

    public void onErrorEscucha(String error) {
        SwingUtilities.invokeLater(() -> {
            vista.agregarLog("[RED] Error de conexión: " + error);
            desconectar("Pérdida de conexión");
        });
    }

    public void onConexionCerrada() {
        SwingUtilities.invokeLater(() -> {
            vista.setSesionIniciada(false); // Bloqueamos la interfaz
            vista.agregarLog("[SISTEMA] Desconectado.");
        });
    }

    // --- MÉTODOS INTERNOS ---

    private void iniciarEscucha(BufferedReader in) {
        tareaEscuchar = new TareaEscuchar(in, this);
        new Thread(tareaEscuchar, "Hilo-Escucha-Cliente").start();
    }

    private void enviarMensajeChat() {
        String texto = vista.getMensaje();
        if (texto.isEmpty()) return;

        if (out != null) {
            // --- LOG DE SALIDA ---
            vista.agregarLog("--> [OUT]: " + texto);
            // ---------------------

            out.println(texto);
            vista.limpiarCampoMensaje();
        }
    }

    private void desconectar(String motivo) {
        try {
            if (tareaEscuchar != null) tareaEscuchar.detener();
            if (socket != null && !socket.isClosed()) socket.close();
        } catch (IOException e) {
            e.printStackTrace();
        } finally {
            SwingUtilities.invokeLater(() -> {
                vista.agregarLog("[SISTEMA] " + motivo);
                vista.setSesionIniciada(false);
            });
        }
    }
}