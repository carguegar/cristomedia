package server;

import common.Protocolo;
import modelo.Usuario;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.net.Socket;
import java.util.ArrayList;
import java.util.concurrent.locks.ReentrantLock;

public class ManejadorCliente implements Runnable {

    private Socket socket;
    private VistaServidor vista;
    private Servidor servidor;
    private Protocolo protocolo;
    private PrintWriter out;

    // Concurrencia manual
    private ArrayList<Thread> misHilos;
    private ReentrantLock cerrojoEnvio;
    private int contadorTareas = 0;

    // Datos de sesión
    private volatile Usuario usuarioLogueado = null;
    private volatile String tokenSesion = null;

    // --- NUEVO: FLAG PARA CONTROLAR EL CIERRE ---
    private volatile boolean salidaLimpia = false;

    public ManejadorCliente(Socket socket, VistaServidor vista, Servidor servidor, Protocolo protocolo) {
        this.socket = socket;
        this.vista = vista;
        this.servidor = servidor;
        this.protocolo = protocolo;

        this.misHilos = new ArrayList<>();
        this.cerrojoEnvio = new ReentrantLock(true);
    }

    @Override
    public void run() {
        String id = getClientId();

        try {
            BufferedReader in = new BufferedReader(new InputStreamReader(socket.getInputStream()));
            this.out = new PrintWriter(socket.getOutputStream(), true);

            vista.log(id + " --- CLIENTE CONECTADO ---");
            String linea;

            while ((linea = in.readLine()) != null) {
                logTraza("RECIBIDO", linea);

                limpiarHilosMuertos();

                TareaCliente tarea = new TareaCliente(this, protocolo, linea, vista, id);
                Thread hiloTrabajador = new Thread(tarea);

                contadorTareas++;
                hiloTrabajador.setName("Worker-" + contadorTareas);

                synchronized (misHilos) {
                    misHilos.add(hiloTrabajador);
                }

                hiloTrabajador.start();
            }
            if (!salidaLimpia) {
                vista.log(id + " [WARN] Cliente desconectado abruptamente (EOF).");
            }

        } catch (IOException e) {

            if (!salidaLimpia) {
                vista.log(id + " [WARN] Cliente desconectado abruptamente (Crash/Alt+F4).");
            } else {
                vista.log(id + " [INFO] Desconexión voluntaria completada.");
            }
        } finally {
            ejecutarCierreDeEmergencia();
        }
    }

    public void enviarMensaje(String msg) {
        cerrojoEnvio.lock();
        try {
            if (out != null && !socket.isClosed()) {
                if (out.checkError()) return;
                logTraza("ENVIADO", msg);
                out.println(msg);
            }
        } finally {
            cerrojoEnvio.unlock();
        }
    }

    private void logTraza(String direccion, String mensaje) {
        if (Servidor.MODO_DEBUG) {
            String msgFinal = mensaje;
            vista.log(getClientId() + " [" + direccion + "] " + msgFinal);
        }
    }

    private void limpiarHilosMuertos() {
        synchronized (misHilos) {
            misHilos.removeIf(t -> !t.isAlive());
        }
    }

    private void ejecutarCierreDeEmergencia() {
        if (!salidaLimpia) vista.log(getClientId() + " --- LIMPIANDO RECURSOS ---");

        synchronized (misHilos) {
            for (Thread t : misHilos) {
                if (t.isAlive()) t.interrupt();
            }
        }

        protocolo.liberarRecursosSiEsNecesario(this);

        if (socket != null && !socket.isClosed()) {
            try { socket.close(); } catch (IOException e) {}
        }

        servidor.notificarDesconexion(this);
    }

    public void cerrarSocket() {
        // Marcamos que nosotros hemos pedido el cierre
        this.salidaLimpia = true;
        try {
            if (socket != null && !socket.isClosed()) socket.close();
        } catch (IOException e) {}
    }

    public String getClientId() {
        return (socket != null) ? socket.getInetAddress().getHostAddress() + ":" + socket.getPort() : "Desc";
    }

    // Getters y Setters
    public Usuario getUsuarioLogueado() { return usuarioLogueado; }
    public void setUsuarioLogueado(Usuario u) { this.usuarioLogueado = u; }
    public String getTokenSesion() { return tokenSesion; }
    public void setTokenSesion(String t) { this.tokenSesion = t; }
    public Servidor getServidor() { return servidor; }

    public void logDesdeProtocolo(String s) {
        if(Servidor.MODO_DEBUG) vista.log(getClientId() + " [PROTO] " + s);
    }
}