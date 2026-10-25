package server;

import javax.swing.*;
import javax.swing.text.DefaultCaret;
import java.awt.*;

public class VistaServidor extends JFrame {

    private JTextArea areaLog;
    private JLabel lblContador;
    private JToggleButton btnDebug; // Nuevo botón interruptor

    public VistaServidor() {
        super("Servidor Cristomedia - Monitor de Tráfico");
        configurarVentana();
        inicializarComponentes();

        // Sincronizar estado inicial del botón con la variable estática del Servidor
        actualizarEstiloBoton();
    }

    private void configurarVentana() {
        setSize(900, 600); // Un poco más grande para ver mejor los logs
        setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        setLocationRelativeTo(null);
        setLayout(new BorderLayout());
    }

    private void inicializarComponentes() {
        // --- CABECERA: ESTADO Y CONTROLES ---
        JPanel panelInfo = new JPanel(new FlowLayout(FlowLayout.LEFT, 20, 10));
        panelInfo.setBackground(new Color(30, 30, 30));

        // 1. Contador de Clientes
        lblContador = new JLabel("Clientes conectados: 0");
        lblContador.setForeground(Color.CYAN);
        lblContador.setFont(new Font("SansSerif", Font.BOLD, 14));

        // 2. Botón de Debug (Interruptor)
        btnDebug = new JToggleButton("DEBUG: OFF");
        btnDebug.setFocusPainted(false);
        btnDebug.setFont(new Font("SansSerif", Font.BOLD, 12));
        btnDebug.setSelected(Servidor.MODO_DEBUG); // Toma el valor inicial de la clase Servidor

        // Acción del botón
        btnDebug.addActionListener(e -> {
            // Cambiamos la variable estática global
            Servidor.MODO_DEBUG = btnDebug.isSelected();

            // Actualizamos la estética del botón
            actualizarEstiloBoton();

            // Avisamos en el log
            String estado = Servidor.MODO_DEBUG ? "ACTIVADO" : "DESACTIVADO";
            log("--- SYSTEM: MODO DEBUG " + estado + " ---");
        });

        panelInfo.add(lblContador);
        panelInfo.add(btnDebug);
        add(panelInfo, BorderLayout.NORTH);

        // --- CUERPO: LOGS ---
        areaLog = new JTextArea();
        areaLog.setEditable(false);
        areaLog.setFont(new Font("Consolas", Font.PLAIN, 12));
        areaLog.setBackground(Color.BLACK);
        areaLog.setForeground(Color.GREEN);

        // Auto-scroll: Siempre baja al final
        DefaultCaret caret = (DefaultCaret)areaLog.getCaret();
        caret.setUpdatePolicy(DefaultCaret.ALWAYS_UPDATE);

        JScrollPane scroll = new JScrollPane(areaLog);
        scroll.setVerticalScrollBarPolicy(JScrollPane.VERTICAL_SCROLLBAR_ALWAYS);
        add(scroll, BorderLayout.CENTER);
    }

    // Método auxiliar para cambiar el color del botón según el estado
    private void actualizarEstiloBoton() {
        if (btnDebug.isSelected()) {
            btnDebug.setText("DEBUG: ON");
            btnDebug.setBackground(new Color(220, 100, 0)); // Naranja alerta
            btnDebug.setForeground(Color.WHITE);
        } else {
            btnDebug.setText("DEBUG: OFF");
            btnDebug.setBackground(Color.GRAY);
            btnDebug.setForeground(Color.BLACK);
        }
    }

    public void mostrar() {
        setVisible(true);
    }

    // --- MÉTODOS PÚBLICOS (Thread-Safe) ---

    public void log(String texto) {
        SwingUtilities.invokeLater(() -> areaLog.append(texto + "\n"));
    }

    public void setContadorClientes(int n) {
        SwingUtilities.invokeLater(() -> {
            lblContador.setText("Clientes conectados: " + n);
            if (n > 0) lblContador.setForeground(Color.GREEN);
            else lblContador.setForeground(Color.CYAN);
        });
    }
}