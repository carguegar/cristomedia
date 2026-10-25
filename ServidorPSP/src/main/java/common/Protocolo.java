package common;

import controlador.ContenidoDAO;
import controlador.UsuarioDAO;
import controlador.ValoracionDAO;
import modelo.Contenido;
import modelo.Usuario;
import modelo.Valoracion;
import server.ManejadorCliente;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;

public class Protocolo {

    private static final String PROTOCOLO = "PROTOCOLCRISTOMEDIA1.0";
    private static final int MAX_CONECTIONS = 3;
    private static final int TAMANO_PAQUETE = 1024;

    private UsuarioDAO usuarioDAO;
    private ContenidoDAO contenidoDAO;
    private ValoracionDAO valoracionDAO;

    public Protocolo() {
        this.usuarioDAO = new UsuarioDAO();
        this.contenidoDAO = new ContenidoDAO();
        this.valoracionDAO = new ValoracionDAO();
    }

    public String procesarEntrada(String input, ManejadorCliente sesion) {
        if (input == null || input.trim().isEmpty()) return null;

        String[] partes = input.split("#");
        if (partes.length < 3 || !partes[0].equals(PROTOCOLO)) {
            return PROTOCOLO + "#" + getTime() + "#ERROR#BAD_PROTOCOL";
        }

        // --- PASO 5: CLIENTE CONFIRMA FIN DE TRANSACCIÓN ---
        if (input.contains("RECEIVED_AND_FINISHED")) {
            sesion.logDesdeProtocolo("Transferencia finalizada con éxito.");
            return PROTOCOLO + "#" + getTime() + "#OK#TRANSFER_COMPLETED";
        }

        String comando = partes[2];

        switch (comando) {
            case "LOGIN":
                return procesarLogin(partes, sesion);
            case "GET_INFO_CLIENT":
                return procesarGetInfoClient(partes, sesion);

            case "GET_INFO_CONTENT_ID":
                return procesarGetInfoContentId(partes, sesion);

            case "OK_INFO_CONTENT_RECEIVED":
                if (partes[partes.length - 1].equals("NOW_READY_TO_RECEIVE_CONTENT_STREAM")) {
                    return procesarInicioStreamContenido(partes, sesion);
                }
                return null;

            case "NEW_REVIEW_FOR":
                return procesarNuevaReview(partes, sesion);

            case "BYEBYE":
                return procesarLogout(partes, sesion);

            case "GET_USER_PHOTO":
                if (partes.length >= 8 && partes[4].equals("BY")) {
                    return procesarFotoDeOtroUsuario(partes, sesion);
                }
                else {
                    return procesarGetUserPhoto(partes, sesion);
                }

            case "READY_TO_RECEIVE_IMAGE_FOR":
                return procesarEnvioDePaquetes(partes, sesion);

            default:
                return PROTOCOLO + "#" + getTime() + "#ERROR#UNKNOWN_COMMAND";
        }
    }

    private String procesarNuevaReview(String[] partes, ManejadorCliente sesion) {
        // Estructura esperada:
        // [0]PROTO#[1]TIME#[2]CMD#[3]ID_CONTENT#[4]BY#[5]USER#[6]WITH_TOKEN#[7]TOKEN
        // #[8]REVIEW_TEXT#[9]MSG#[10]SCORING#[11]INT

        if (partes.length < 12) return PROTOCOLO + "#" + getTime() + "#ERROR#BAD_ARGUMENTS";

        String idContentStr = partes[3];
        String user = partes[5];
        String token = partes[7];
        String reviewText = partes[9];
        String scoreStr = partes[11];

        //Validar Sesión
        if (!validarSesion(sesion, user, token)) {
            return PROTOCOLO + "#" + getTime() + "#ERROR#BAD_CREDENTIALS";
        }

        try {
            int idContent = Integer.parseInt(idContentStr);
            int score = Integer.parseInt(scoreStr);

            // Validaciones de negocio
            if (score < 0 || score > 5) return PROTOCOLO + "#" + getTime() + "#ERROR#CANT_SET_REVIEW";
            if (reviewText.length() > 256) reviewText = reviewText.substring(0, 256); // Recortar si excede

            // 3. Obtener Contenido y Usuario
            Usuario usuario = sesion.getUsuarioLogueado();
            Contenido contenido = contenidoDAO.traerContenidoCompleto(idContent);

            if (contenido == null) return PROTOCOLO + "#" + getTime() + "#ERROR#CANT_SET_REVIEW";

            //Crear y Guardar la Valoración
            Valoracion nuevaValoracion = new Valoracion();
            nuevaValoracion.setUsuario(usuario);
            nuevaValoracion.setContenido(contenido);
            nuevaValoracion.setComment(reviewText);
            nuevaValoracion.setScore(score);
            nuevaValoracion.setTimestamp(LocalDateTime.now());

            // Guardamos en BD
            boolean guardado = valoracionDAO.create(nuevaValoracion);

            if (!guardado) {
                return PROTOCOLO + "#" + getTime() + "#ERROR#CANT_SET_REVIEW";
            }

            // La columna timestamp se genera en la base de datos, así que la
            // entidad recién insertada puede no tenerlo todavía. Lo fijamos
            // para poder incluirlo en el mensaje de broadcast.
            if (nuevaValoracion.getTimestamp() == null) {
                nuevaValoracion.setTimestamp(LocalDateTime.now());
            }

            // Recalcular la media
            BigDecimal nuevaMedia = contenidoDAO.recalcularYGuardarMedia(idContent);


            // CONSTRUIR MENSAJE BROADCAST

            String mensajeBroadcast = PROTOCOLO + "#" + getTime() +
                    "#NEW_REVIEW_FOR#" + idContent +
                    "#BY#" + user +
                    "#WITH_TOKEN#" + token + // Nota: En broadcast, los otros usuarios verán este token, pero no les sirve de nada porque no coincide con su usuario.
                    "#REVIEW_TEXT#" + reviewText +
                    "#SCORING#" + score +
                    "#DATE#" + nuevaValoracion.getTimestamp() +
                    "#CONTENT_NAME#" + contenido.getNameContent() +
                    "#AVG_SCORING#" + nuevaMedia;

            sesion.getServidor().broadcast(mensajeBroadcast);

            return null;

        } catch (NumberFormatException e) {
            return PROTOCOLO + "#" + getTime() + "#ERROR#CANT_SET_REVIEW";
        } catch (Exception e) {
            e.printStackTrace();
            return PROTOCOLO + "#" + getTime() + "#ERROR#SERVER_ERROR";
        }
    }

    private String procesarGetInfoContentId(String[] partes, ManejadorCliente sesion) {
        if (partes.length < 8) return PROTOCOLO + "#" + getTime() + "#ERROR#BAD_ARGUMENTS";

        String idContentStr = partes[3];
        String user = partes[5];
        String token = partes[7];

        if (!validarSesion(sesion, user, token)) {
            return PROTOCOLO + "#" + getTime() + "#ERROR#BAD_CREDENTIALS";
        }

        int idContent;
        try {
            idContent = Integer.parseInt(idContentStr);
        } catch (NumberFormatException e) {
            return PROTOCOLO + "#" + getTime() + "#ERROR#INVALID_ID_FORMAT";
        }

        Contenido contenido = contenidoDAO.traerContenidoCompleto(idContent);
        if (contenido == null) {
            return PROTOCOLO + "#" + getTime() + "#ERROR#CONTENT_NOT_FOUND";
        }

        // 2. Obtener Valoraciones (Recuerda usar JOIN FETCH en el DAO)
        ArrayList<Valoracion> valoraciones = valoracionDAO.obtenerValoracionesDeContenido(idContent);
        if (valoraciones == null) valoraciones = new ArrayList<>();

        StringBuilder sbReviews = new StringBuilder();
        for (Valoracion v : valoraciones) {
            sbReviews.append(v.getUsuario().getUserName()).append("#")
                    .append(v.getTimestamp()).append("#")
                    .append(v.getComment()).append("#")
                    .append(v.getScore()).append("#");
        }

        // 3. Obtener Propietarios (Usuarios que tienen el juego)
        StringBuilder sbUsers = new StringBuilder();
        Set<Usuario> propietarios = contenido.getUsuarios();
        if (propietarios != null) {
            for (Usuario u : propietarios) {
                sbUsers.append(u.getUserName()).append("#")
                        .append(u.getSurname1()).append("#")
                        .append(u.getSurname2()).append("#")
                        .append(u.getEmail()).append("#");
            }
        }

        // 4. Construir Info del Contenido
        String infoContent = contenido.getIdContent() + "#" +
                contenido.getNameContent() + "#" +
                contenido.getSizeBytes() + "#" +
                contenido.getFormat() + "#" +
                contenido.getAvgValoracion() + "#";

        // Respuesta Tipo II
        return PROTOCOLO + "#" + getTime() + "#CONTENT_INFO_TO#" + user +
                "#WITH_TOKEN#" + token + "#" +
                infoContent +
                valoraciones.size() + "#" +
                sbReviews.toString() +
                sbUsers.toString();
    }

    private String procesarInicioStreamContenido(String[] partes, ManejadorCliente sesion) {
        // Estructura: [0]PROTO#[1]TIME#[2]CMD#[3]ID_CONTENT#[4]BY#[5]USER#[6]WITH_TOKEN#[7]TOKEN#[8]FLAG
        if (partes.length < 8) return null;

        String idContentStr = partes[3];
        String user = partes[5];
        String token = partes[7];

        if (!validarSesion(sesion, user, token)) {
            return PROTOCOLO + "#" + getTime() + "#ERROR#BAD_CREDENTIALS";
        }

        Long idContent;
        try {
            idContent = Long.parseLong(idContentStr);
        } catch (NumberFormatException e) {
            return null; // O enviar error
        }

        Contenido contenido = contenidoDAO.find(idContent);
        if (contenido == null) {
            return PROTOCOLO + "#" + getTime() + "#ERROR#CONTENT_NOT_FOUND";
        }


        String rutaArchivo = contenido.getPathContent();
        File file = new File(rutaArchivo);

        if (!file.exists()) {
            sesion.logDesdeProtocolo("ERROR CRÍTICO: El archivo físico no existe en " + rutaArchivo);
            return PROTOCOLO + "#" + getTime() + "#ERROR#CONTENT_NOT_FOUND";
        }

        // --- BUCLE DE ENVÍO ---
        try (FileInputStream fis = new FileInputStream(file)) {
            byte[] buffer = new byte[TAMANO_PAQUETE];
            int leidos;
            int idPack = 0;

            sesion.logDesdeProtocolo("Iniciando transmisión de archivo: " + file.getName());

            while ((leidos = fis.read(buffer)) != -1) {
                // Verificar si el hilo fue interrumpido (cliente desconectado)
                if (Thread.currentThread().isInterrupted()) {
                    sesion.logDesdeProtocolo("Transmisión cancelada.");
                    return null;
                }

                // Ajustar buffer si el último paquete es más pequeño
                byte[] bytesUtiles = (leidos == TAMANO_PAQUETE) ? buffer : Arrays.copyOf(buffer, leidos);

                // Codificar a Base64
                String b64 = Base64.getEncoder().encodeToString(bytesUtiles);

                // Construir Mensaje Tipo II
                String msg = PROTOCOLO + "#" + getTime() + "#OK_CONTENT_STREAM_TO#" + user +
                        "#WITH_TOKEN#" + token + "#ID_PACKAGE#" + idPack + "#BYTES#" + b64;

                // Enviar inmediatamente
                sesion.enviarMensaje(msg);
                idPack++;

            }
            sesion.logDesdeProtocolo("Transmisión finalizada. Paquetes enviados: " + idPack);

        } catch (IOException e) {
            sesion.logDesdeProtocolo("Error leyendo archivo: " + e.getMessage());
            return PROTOCOLO + "#" + getTime() + "#ERROR#IO_EXCEPTION_STREAMING";
        }

        // Retornamos null porque ya hemos enviado los mensajes por el socket dentro del while
        return null;
    }

    private String procesarLogin(String[] partes, ManejadorCliente sesion) {
        if (partes.length < 5) return PROTOCOLO + "#" + getTime() + "#ERROR#BAD_ARGUMENTS";
        String user = partes[3];
        String pass = partes[4];

        Usuario u = usuarioDAO.validarLogin(user, pass);

        if (u != null) {
            boolean pudoEntrar = usuarioDAO.intentarIncrementarConexion(user, MAX_CONECTIONS);
            if (pudoEntrar) {
                String token = UUID.randomUUID().toString();
                sesion.setUsuarioLogueado(u);
                sesion.setTokenSesion(token);
                return PROTOCOLO + "#" + getTime() + "#WELLCOME#" + user + "#WITH_TOKEN#" + token + "#";
            } else {
                return "ERROR#MAX_CONNECTIONS_REACHED";
            }
        }
        return PROTOCOLO + "#" + getTime() + "#ERROR#BAD_CREDENTIALS";
    }

    private String procesarLogout(String[] partes, ManejadorCliente sesion) {
        if (partes.length < 6) return PROTOCOLO + "#" + getTime() + "#ERROR#BAD_ARGUMENTS";
        String user = partes[3];
        String token = partes[5];
        if (!validarSesion(sesion, user, token)) return PROTOCOLO + "#" + getTime() + "#ERROR#STOP_HACKERS";

        liberarRecursosSiEsNecesario(sesion);
        return PROTOCOLO + "#" + getTime() + "#SEEYOU#" + user + "#WITH_TOKEN#" + token + "#";
    }

    private String procesarGetInfoClient(String[] partes, ManejadorCliente sesion) {
        String user = partes[3];
        String token = partes[5];

        if (!validarSesion(sesion, user, token)) return PROTOCOLO + "#" + getTime() + "#ERROR#CANT_GET_INFO";

        Usuario u = usuarioDAO.buscarPorIdConContenidos(sesion.getUsuarioLogueado().getIdUser());
        if (u == null) return PROTOCOLO + "#" + getTime() + "#ERROR#INTERNAL_ERROR";

        String dataUser = u.getUserName() + "#" + u.getName() + "#" + u.getSurname1() + "#" + u.getSurname2() + "#";

        ArrayList<Contenido> todos = new ArrayList<>(contenidoDAO.findAll());
        StringBuilder sbSys = new StringBuilder();
        for (Contenido c : todos) {
            sbSys.append(c.getIdContent()).append("#")
                    .append(c.getNameContent()).append("#")
                    .append(c.getAvgValoracion()).append("#")
                    .append(c.getSizeBytes()).append("#")
                    .append(c.getFormat()).append("#");
        }

        StringBuilder sbUser = new StringBuilder();
        for (Contenido c : u.getContenidos()) {
            sbUser.append(c.getIdContent()).append("#");
        }

        return PROTOCOLO + "#" + getTime() + "#INFO_CLIENT_TO#" + user + "#WITH_TOKEN#" + token + "#" +
                dataUser + todos.size() + "#" + sbSys.toString() + u.getContenidos().size() + "#" + sbUser.toString();
    }

    private String procesarGetUserPhoto(String[] partes, ManejadorCliente sesion) {
        if (partes.length < 6) return PROTOCOLO + "#" + getTime() + "#ERROR#BAD_ARGUMENTS";
        String user = partes[3];
        String token = partes[5];

        if (!validarSesion(sesion, user, token)) return PROTOCOLO + "#" + getTime() + "#ERROR#CANT_GET_IMAGE";

        String rutaImagen = sesion.getUsuarioLogueado().getUserImagePath();
        if (rutaImagen == null || rutaImagen.isEmpty()) return PROTOCOLO + "#" + getTime() + "#ERROR#CANT_GET_IMAGE";

        File file = new File(rutaImagen);
        if (!file.exists()) return PROTOCOLO + "#" + getTime() + "#ERROR#CANT_GET_IMAGE";

        return PROTOCOLO + "#" + getTime() + "#OK_IMAGE_FOR#" + user +
                "#WITH_TOKEN#" + token + "#FILE_SIZE#" + file.length() + "#SIZE_PACKAGE#" + TAMANO_PAQUETE;
    }

    /**
     * Permite a un usuario logueado pedir la foto de CUALQUIER otro usuario.
     */
    private String procesarFotoDeOtroUsuario(String[] partes, ManejadorCliente sesion) {
        // Estructura:
        // [0]PROTO#[1]TIME#[2]CMD#[3]TARGET_USER#[4]BY#[5]REQUESTOR_USER#[6]WITH_TOKEN#[7]TOKEN

        String targetUser = partes[3];    // El usuario de la foto
        String requestorUser = partes[5]; // El usuario que pide
        String token = partes[7];

        // Validar Seguridad: Validamos al que PIDE
        if (!validarSesion(sesion, requestorUser, token)) {
            return PROTOCOLO + "#" + getTime() + "#ERROR#BAD_CREDENTIALS";
        }

        return procesarEnvioDePaquetes(partes,sesion);
    }

    private String procesarEnvioDePaquetes(String[] partes, ManejadorCliente sesion) {
        // [0]PROTO#[1]TIME#[2]CMD#[3]TARGET_USER#[4]BY#[5]REQ_USER...

        //DETECTAR USUARIO OBJETIVO
        String targetUser;
        String requestorUser;
        String token;

        if (partes.length >= 8 && partes[4].equals("BY")) {
            // Caso: Pido foto de otro (valoracion)
            targetUser = partes[3];
            requestorUser = partes[5];
            token = partes[7];
        } else {
            // Caso: Pido mi foto (Login)
            targetUser = partes[3];
            requestorUser = partes[3];
            token = partes[5];
        }

        // VALIDAR AL QUE PIDE
        if (!validarSesion(sesion, requestorUser, token))
            return PROTOCOLO + "#" + getTime() + "#ERROR#CANT_GET_IMAGE";

        //OBTENER RUTA
        String rutaImagen = usuarioDAO.obtenerRutaFotoDeUsuario(targetUser);

        if (rutaImagen == null) return PROTOCOLO + "#" + getTime() + "#ERROR#CANT_GET_IMAGE";

        File file = new File(rutaImagen);
        if (!file.exists()) return PROTOCOLO + "#" + getTime() + "#ERROR#CANT_GET_IMAGE";

        // ENVÍO (Sincronizado para que no se mezclen los paquetes de varias fotos) ya que uso hebras y un contenido puede pedir la foto de varios usaurios
        // Bloqueamos al cliente mientras le enviamos la foto, para evitar que reciba paquetes mezclados de varias fotos si hace varias peticiones seguidas.
        synchronized (sesion) {
            try (FileInputStream fis = new FileInputStream(file)) {
                byte[] buffer = new byte[TAMANO_PAQUETE];
                int leidos;
                int idPack = 0;

                while ((leidos = fis.read(buffer)) != -1) {
                    byte[] bytesUtiles = (leidos == TAMANO_PAQUETE) ? buffer : Arrays.copyOf(buffer, leidos);
                    String b64 = Base64.getEncoder().encodeToString(bytesUtiles);

                    String msg = PROTOCOLO + "#" + getTime() + "#OK_IMAGE_FOR#" + targetUser +
                            "#ID_PACKAGE#" + idPack + "#BYTES#" + b64;

                    sesion.enviarMensaje(msg);
                    idPack++;
                }

            } catch (IOException e) {
                return PROTOCOLO + "#" + getTime() + "#ERROR#CANT_GET_IMAGE";
            }
        }
        return null;
    }

    public void liberarRecursosSiEsNecesario(ManejadorCliente sesion) {
        Usuario u = sesion.getUsuarioLogueado();
        if (u != null) {
            sesion.logDesdeProtocolo("Liberando recursos BD para: " + u.getUserName());
            usuarioDAO.decrementarConexion(u.getUserName());
            sesion.setUsuarioLogueado(null);
            sesion.setTokenSesion(null);
        }
    }

    private boolean validarSesion(ManejadorCliente sesion, String user, String token) {
        String tReal = sesion.getTokenSesion();
        Usuario uReal = sesion.getUsuarioLogueado();
        return tReal != null && uReal != null && tReal.equals(token) && uReal.getUserName().equals(user);
    }

    private String getTime() { return LocalDateTime.now().toString(); }

    public void resetearConexionesBBDD() {
        usuarioDAO.resetearContadoresDeConexion();
    }
}