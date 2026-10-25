package modelo;

import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityManagerFactory;
import jakarta.persistence.Persistence;

public class HibernateUtil {

    private static final EntityManagerFactory entityManagerFactory = buildEntityManagerFactory();

    private static EntityManagerFactory buildEntityManagerFactory() {
        try {
            // "MiUnidadPersistencia" debe coincidir con el nombre en persistence.xml
            return Persistence.createEntityManagerFactory("MiUnidadPersistencia");
        } catch (Throwable ex) {
            System.err.println("Error al crear la factoría de EntityManager: " + ex);
            throw new ExceptionInInitializerError(ex);
        }
    }

    /**
     * Devuelve un EntityManager nuevo para cada operación.
     *
     * La versión original compartía un único EntityManager estático entre todos
     * los hilos del servidor. Como los DAO cierran el EntityManager al terminar,
     * dos peticiones concurrentes podían romperse entre sí. Crear uno por
     * operación es la forma correcta de trabajar con JPA en un servidor
     * multihilo.
     */
    public static EntityManager getEntityManager() {
        return entityManagerFactory.createEntityManager();
    }

    /**
     * Cierra la factoría de conexiones al finalizar la aplicación.
     */
    public static void close() {
        if (entityManagerFactory != null && entityManagerFactory.isOpen()) {
            entityManagerFactory.close();
        }
    }
}
