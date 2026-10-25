package client;

import javax.swing.SwingUtilities;

public class ClienteApp {
    public static void main(String[] args) {
        SwingUtilities.invokeLater(() -> {
            VistaCliente vista = new VistaCliente();
            new ControladorCliente(vista); // Vincula vista y lógica
            vista.setVisible(true);
        });
    }
}