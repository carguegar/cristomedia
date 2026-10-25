package server;

import common.Protocolo;
import java.io.IOException;

public class TareaCliente implements Runnable {

    private final String mensajeEntrante;
    private final ManejadorCliente manejador; // Referencia al "padre" para responder
    private final Protocolo protocolo;
    private final VistaServidor vista;
    private final String idCliente;

    public TareaCliente(ManejadorCliente manejador, Protocolo protocolo, String mensajeEntrante, VistaServidor vista, String idCliente) {
        this.manejador = manejador;
        this.protocolo = protocolo;
        this.mensajeEntrante = mensajeEntrante;
        this.vista = vista;
        this.idCliente = idCliente;
    }

    @Override
    public void run() {
        String nombreHebra = Thread.currentThread().getName();
        // Log de inicio de tarea
        vista.log(idCliente + " [" + nombreHebra + "] Iniciando tarea: " + mensajeEntrante.split("#")[2]);

        try {
            //Procesamos la lógica
            String respuesta = protocolo.procesarEntrada(mensajeEntrante, manejador);

            // 2. Si hay respuesta, usamos el canal seguro del manejador para enviarla
            if (respuesta != null) {
                manejador.enviarMensaje(respuesta);

                // Si es despedida, avisamos al manejador para que cierre
                if (respuesta.contains("#SEEYOU#")) {
                    manejador.cerrarSocket();
                }
            }
        } catch (Exception e) {
            vista.log(idCliente + " [" + nombreHebra + "] Error crítico en tarea: " + e.getMessage());
            e.printStackTrace();
        } finally {
            // Log de fin de tarea
            vista.log(idCliente + " [" + nombreHebra + "] Tarea finalizada.");
        }
    }
}