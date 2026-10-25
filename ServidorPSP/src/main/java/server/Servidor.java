package server;

import common.Protocolo;
import java.io.IOException;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.concurrent.atomic.AtomicInteger;


public class Servidor {
    // MODO DEBUG: Si es true, se mostrarán logs detallados en la consola y la UI.
    public static volatile boolean MODO_DEBUG = false;

    private static final int PUERTO = 4444;

    private VistaServidor vista;
    private ArrayList<ManejadorCliente> clientesConectados;
    private boolean ejecutando;
    private AtomicInteger contadorClientes;

    // --- INSTANCIA ÚNICA COMPARTIDA ---
    private Protocolo protocoloCompartido;

    public Servidor(VistaServidor vista) {
        this.vista = vista;
        this.clientesConectados = new ArrayList<>();
        this.ejecutando = true;
        this.contadorClientes = new AtomicInteger(0);

        this.protocoloCompartido = new Protocolo();
        protocoloCompartido.resetearConexionesBBDD();
    }

    public void iniciar() {
        try (ServerSocket serverSocket = new ServerSocket(PUERTO)) {
            vista.log("[SISTEMA] Servidor iniciado. Protocolo cargado.");

            while (ejecutando) {
                Socket socketCliente = serverSocket.accept();

                //PASAMOS EL PROTOCOLO COMPARTIDO AL MANEJADOR
                ManejadorCliente tarea = new ManejadorCliente(
                        socketCliente,
                        vista,
                        this,
                        this.protocoloCompartido
                );

                Thread hilo = new Thread(tarea);
                agregarCliente(tarea);
                hilo.start();
                vista.log("Hilos activos en memoria: " + clientesConectados.size());
            }
        } catch (IOException e) {
            vista.log("[ERROR] " + e.getMessage());
        }
    }

    private void agregarCliente(ManejadorCliente manejador) {
        synchronized (clientesConectados) {
            clientesConectados.add(manejador);
            // Actualizamos la vista con el tamaño real de la lista
            vista.setContadorClientes(clientesConectados.size());
        }
    }

    /**
     * Envía un mensaje a todos los clientes conectados actualmente.
     */
    public void broadcast(String mensaje) {
        synchronized (clientesConectados) {
            for (ManejadorCliente cliente : clientesConectados) {
                cliente.enviarMensaje(mensaje);
            }
        }
        if (MODO_DEBUG) {
            vista.log("SYSTEM [BROADCAST] -> Enviado a " + clientesConectados.size() + " clientes.");
        }
    }

    // --- Callbacks para el Manejador ---

    public void notificarDesconexion(ManejadorCliente manejador) {
        synchronized (clientesConectados) {
            clientesConectados.remove(manejador);
            // Al borrar, el ArrayList se compacta solo (no deja huecos)
            vista.setContadorClientes(clientesConectados.size());

            if (MODO_DEBUG) {
                vista.log("SYSTEM: Cliente eliminado de la lista. Quedan: " + clientesConectados.size());
            }
        }
    }


    public static void main(String[] args) {
        VistaServidor vista = new VistaServidor();
        vista.mostrar();
        new Servidor(vista).iniciar();
    }
}