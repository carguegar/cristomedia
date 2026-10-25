package controlador;

import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityTransaction;
import jakarta.persistence.NoResultException;
import jakarta.persistence.TypedQuery;
import modelo.HibernateUtil;
import modelo.Usuario;

import java.util.List;

public class UsuarioDAO extends GenericDAO<Usuario> {

    public UsuarioDAO() {
        super(Usuario.class);
    }

    /**
     * Busca un usuario y carga forzosamente sus contenidos en la misma transacción
     * para evitar LazyInitializationException.
     */
    public Usuario buscarPorIdConContenidos(Long id) {
        EntityManager em = HibernateUtil.getEntityManager();
        try {
            // Usamos JPQL con JOIN FETCH
            // LEFT JOIN es importante: si el usuario no tiene contenidos,
            // queremos que nos devuelva el usuario igualmente (no null).
            String jpql = "SELECT u FROM Usuario u LEFT JOIN FETCH u.contenidos WHERE u.idUser = :id";

            TypedQuery<Usuario> query = em.createQuery(jpql, Usuario.class);
            query.setParameter("id", id);

            // getSingleResult lanza excepción si no encuentra nada,
            // así que usamos getResultList().stream().findFirst() o un try-catch
            return query.getResultStream().findFirst().orElse(null);

        } finally {
            em.close();
        }
    }

    /**
     * Busca un usuario y carga sus valoraciones (reseñas hechas)
     * Necesario para poder añadir una nueva valoración usando el método helper.
     */
    public Usuario buscarPorIdConValoraciones(Long id) {
        EntityManager em = HibernateUtil.getEntityManager();
        try {
            // LEFT JOIN FETCH u.valoraciones obliga a traer la lista
            String jpql = "SELECT u FROM Usuario u LEFT JOIN FETCH u.valoraciones WHERE u.idUser = :id";

            TypedQuery<Usuario> query = em.createQuery(jpql, Usuario.class);
            query.setParameter("id", id);

            return query.getResultStream().findFirst().orElse(null);

        } finally {
            em.close();
        }
    }

    /**
     * Busca un usuario por su nombre de login (necesario para la autenticación).
     * Devuelve null si no existe.
     */
    public Usuario buscarPorLogin(String login) {
        EntityManager em = HibernateUtil.getEntityManager();
        try {

            String jpql = "SELECT u FROM Usuario u WHERE u.userName = :login";

            TypedQuery<Usuario> query = em.createQuery(jpql, Usuario.class);
            query.setParameter("login", login);

            return query.getSingleResult();
        } catch (NoResultException e) {
            return null; // Usuario no encontrado
        } finally {
            em.close();
        }
    }

    public Usuario validarLogin(String login, String password) {
        EntityManager em = HibernateUtil.getEntityManager();
        try {
            // Traemos el usuario y su colección de contenidos en la misma consulta
            String jpql = "SELECT DISTINCT u FROM Usuario u LEFT JOIN FETCH u.contenidos " +
                          "WHERE u.userName = :login AND u.password = :password";

            TypedQuery<Usuario> query = em.createQuery(jpql, Usuario.class);
            query.setParameter("login", login);
            query.setParameter("password", password);

            return query.getSingleResult();
        } catch (NoResultException e) {
            return null; // Credenciales incorrectas
        } finally {
            em.close();
        }
    }

    public boolean intentarIncrementarConexion(String nombreUsuario, int maximoPermitido) {
        EntityManager em = HibernateUtil.getEntityManager();
        EntityTransaction tx = em.getTransaction();
        boolean exito = false;

        try {
            tx.begin();
            // Suma 1 SOLO SI el contador actual es menor que el máximo.
            // Devuelve el número de filas modificadas (1 si tuvo éxito, 0 si estaba lleno).
            int filasAfectadas = em.createQuery(
                            "UPDATE Usuario u SET u.conectionsCounter = u.conectionsCounter + 1 " +
                                    "WHERE u.userName = :nombre AND u.conectionsCounter < :max")
                    .setParameter("nombre", nombreUsuario)
                    .setParameter("max", maximoPermitido)
                    .executeUpdate();

            if (filasAfectadas > 0) {
                exito = true;
            }

            tx.commit();
        } catch (Exception e) {
            if (tx.isActive()) tx.rollback();
            e.printStackTrace();
        } finally {
            em.close();
        }
        return exito;
    }

    public void decrementarConexion(String nombreUsuario) {
        EntityManager em = HibernateUtil.getEntityManager();
        EntityTransaction tx = em.getTransaction();
        try {
            tx.begin();
            // Restamos 1 (asegurando no bajar de 0 por si acaso)
            em.createQuery("UPDATE Usuario u SET u.conectionsCounter = u.conectionsCounter - 1 " +
                            "WHERE u.userName = :nombre AND u.conectionsCounter > 0")
                    .setParameter("nombre", nombreUsuario)
                    .executeUpdate();
            tx.commit();
        } catch (Exception e) {
            if (tx.isActive()) tx.rollback();
        } finally {
            em.close();
        }
    }
    public void resetearContadoresDeConexion() {
        EntityManager em = HibernateUtil.getEntityManager();
        EntityTransaction tx = em.getTransaction();
        try {
            tx.begin();
            em.createQuery("UPDATE Usuario u SET u.conectionsCounter = 0 WHERE conectionsCounter>0").executeUpdate();
            tx.commit();
        } catch (Exception e) {
            if (tx.isActive()) tx.rollback();
        } finally {
            em.close();
        }
    }

    public String obtenerRutaFotoDeUsuario(String username) {
        EntityManager em = null;
        String rutaFoto = null;

        try {
            em = HibernateUtil.getEntityManager();

            //No traemos todo el objeto Usuario, solo el campo de la foto
            String jpql = "SELECT u.userImagePath FROM Usuario u WHERE u.userName = :user";

            TypedQuery<String> query = em.createQuery(jpql, String.class);
            query.setParameter("user", username);

            List<String> resultados = query.getResultList();

            if (!resultados.isEmpty()) {
                rutaFoto = resultados.get(0);
            }

        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            if (em != null) em.close();
        }

        return rutaFoto;
    }

}