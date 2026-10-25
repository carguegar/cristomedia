package client;

import java.io.BufferedReader;
import java.io.IOException;

public class TareaEscuchar implements Runnable {
    private BufferedReader in;
    private ControladorCliente controlador;
    private volatile boolean ejecutando;

    public TareaEscuchar(BufferedReader in, ControladorCliente controlador) {
        this.in = in;
        this.controlador = controlador;
        this.ejecutando = true;
    }

    @Override
    public void run() {
        String linea;
        try {
            // Bucle de lectura constante
            while (ejecutando && (linea = in.readLine()) != null) {
                // Cuando llega un mensaje, avisamos al controlador
                controlador.onMensajeRecibido(linea);
            }
        } catch (IOException e) {
            // Si el error ocurre porque nosotros cerramos la conexión intencionadamente, no es un error real.
            if (ejecutando) {
                controlador.onErrorEscucha("Error leyendo datos: " + e.getMessage());
            }
        } finally {
            // Aseguramos que el controlador sepa que la escucha terminó
            controlador.onConexionCerrada();
        }
    }

    public void detener() {
        this.ejecutando = false;
    }
}