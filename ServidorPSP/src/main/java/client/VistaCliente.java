package client;

import javax.swing.*;
import javax.swing.border.EmptyBorder;
import javax.swing.border.TitledBorder;
import java.awt.*;
import java.awt.event.ActionListener;

public class VistaCliente extends JFrame {

    // --- Componentes de Conexión y Login ---
    private JTextField txtIp;
    private JTextField txtPuerto;
    private JTextField txtUsuario;
    private JPasswordField txtPassword;
    private JButton btnLogin;
    private JButton btnLogout;

    // --- Componentes de Chat ---
    private JTextArea areaLog;
    private JTextField txtMensaje;
    private JButton btnEnviar;
    private JLabel lblEstado; // Barra de estado inferior

    public VistaCliente() {
        super("Cliente Cristomedia");
        configurarVentana();
        inicializarComponentes();
        pack(); // Ajusta la ventana al contenido
        setLocationRelativeTo(null); // Centrar en pantalla
        setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
    }

    private void configurarVentana() {
        setLayout(new BorderLayout(10, 10)); // Espaciado entre zonas
        ((JPanel)getContentPane()).setBorder(new EmptyBorder(10, 10, 10, 10)); // Margen externo
    }

    private void inicializarComponentes() {
        // --- PANEL NORTE: CONFIGURACIÓN Y LOGIN ---
        JPanel panelNorte = new JPanel(new GridLayout(2, 1, 5, 5));

        // Fila 1: Servidor
        JPanel panelRed = new JPanel(new FlowLayout(FlowLayout.LEFT));
        panelRed.setBorder(new TitledBorder("Configuración Servidor"));
        txtIp = new JTextField("localhost", 10);
        txtPuerto = new JTextField("4444", 5);
        panelRed.add(new JLabel("IP:"));
        panelRed.add(txtIp);
        panelRed.add(new JLabel("Puerto:"));
        panelRed.add(txtPuerto);

        // Fila 2: Credenciales
        JPanel panelAuth = new JPanel(new FlowLayout(FlowLayout.LEFT));
        panelAuth.setBorder(new TitledBorder("Credenciales Usuario"));
        txtUsuario = new JTextField("demo1", 10);
        txtPassword = new JPasswordField("demo123", 10);
        btnLogin = new JButton("Conectar & Login");
        btnLogout = new JButton("Desconectar");
        btnLogout.setEnabled(false); // Empieza deshabilitado

        panelAuth.add(new JLabel("User:"));
        panelAuth.add(txtUsuario);
        panelAuth.add(new JLabel("Pass:"));
        panelAuth.add(txtPassword);
        panelAuth.add(btnLogin);
        panelAuth.add(btnLogout);

        panelNorte.add(panelRed);
        panelNorte.add(panelAuth);
        add(panelNorte, BorderLayout.NORTH);

        // --- PANEL CENTRAL: LOGS Y CHAT ---
        areaLog = new JTextArea(15, 50);
        areaLog.setEditable(false);
        areaLog.setFont(new Font("Monospaced", Font.PLAIN, 12));
        JScrollPane scroll = new JScrollPane(areaLog);
        scroll.setBorder(new TitledBorder("Consola / Chat"));
        add(scroll, BorderLayout.CENTER);

        // --- PANEL SUR: ENVÍO DE MENSAJES ---
        JPanel panelSur = new JPanel(new BorderLayout(5, 5));
        txtMensaje = new JTextField();
        btnEnviar = new JButton("Enviar Mensaje");
        lblEstado = new JLabel("Estado: Desconectado");
        lblEstado.setForeground(Color.RED);

        // Inicialmente deshabilitados hasta que haya login correcto
        txtMensaje.setEnabled(false);
        btnEnviar.setEnabled(false);

        JPanel panelEnvio = new JPanel(new BorderLayout());
        panelEnvio.add(txtMensaje, BorderLayout.CENTER);
        panelEnvio.add(btnEnviar, BorderLayout.EAST);

        panelSur.add(panelEnvio, BorderLayout.CENTER);
        panelSur.add(lblEstado, BorderLayout.SOUTH);

        add(panelSur, BorderLayout.SOUTH);
    }

    // --- MÉTODOS DE ACCESO (GETTERS) ---
    public String getIp() { return txtIp.getText(); }
    public int getPuerto() {
        try { return Integer.parseInt(txtPuerto.getText()); }
        catch (NumberFormatException e) { return 0; }
    }
    public String getUsuario() { return txtUsuario.getText(); }
    public String getPassword() { return new String(txtPassword.getPassword()); }
    public String getMensaje() { return txtMensaje.getText(); }

    // --- MÉTODOS DE MODIFICACIÓN VISUAL ---

    public void limpiarCampoMensaje() {
        txtMensaje.setText("");
        txtMensaje.requestFocus();
    }

    public void agregarLog(String texto) {
        areaLog.append(texto + "\n");
        // Auto-scroll hacia abajo
        areaLog.setCaretPosition(areaLog.getDocument().getLength());
    }

    /**
     * Cambia el estado visual de la interfaz según si estamos logueados o no.
     */
    public void setSesionIniciada(boolean activo) {
        // Controles de conexión
        txtIp.setEnabled(!activo);
        txtPuerto.setEnabled(!activo);
        txtUsuario.setEnabled(!activo);
        txtPassword.setEnabled(!activo);
        btnLogin.setEnabled(!activo);
        btnLogout.setEnabled(activo);

        // Controles de chat (Solo activos si hay sesión)
        txtMensaje.setEnabled(activo);
        btnEnviar.setEnabled(activo);

        if (activo) {
            lblEstado.setText("Estado: CONECTADO Y AUTENTICADO");
            lblEstado.setForeground(new Color(0, 150, 0)); // Verde oscuro
            txtMensaje.requestFocus();
        } else {
            lblEstado.setText("Estado: Desconectado");
            lblEstado.setForeground(Color.RED);
        }
    }

    // --- LISTENERS (Para el Controlador) ---
    public void setLoginListener(ActionListener l) { btnLogin.addActionListener(l); }
    public void setLogoutListener(ActionListener l) { btnLogout.addActionListener(l); }
    public void setEnviarListener(ActionListener l) {
        btnEnviar.addActionListener(l);
        txtMensaje.addActionListener(l); // Permitir enviar con ENTER
    }
}