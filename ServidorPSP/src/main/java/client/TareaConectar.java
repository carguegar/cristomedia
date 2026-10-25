package client;

import java.io.*;
import java.net.Socket;

public class TareaConectar implements Runnable {
    private String ip;
    private int puerto;
    private ControladorCliente controlador;

    public TareaConectar(String ip, int puerto, ControladorCliente controlador) {
        this.ip = ip;
        this.puerto = puerto;
        this.controlador = controlador;
    }

    @Override
    public void run() {
        try {
            // Operación bloqueante de red
            Socket socket = new Socket(ip, puerto);

            // Si llegamos aquí, la conexión fue exitosa
            PrintWriter out = new PrintWriter(socket.getOutputStream(), true);
            BufferedReader in = new BufferedReader(new InputStreamReader(socket.getInputStream()));

            // Notificamos al controlador que ya tenemos los recursos listos
            controlador.onConexionExitosa(socket, out, in);

        } catch (IOException e) {
            // Notificamos el error
            controlador.onConexionFallida(e.getMessage());
        }
    }
}