package controlador;
import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityTransaction;
import jakarta.persistence.TypedQuery;
import modelo.Contenido;
import modelo.HibernateUtil;

import java.math.BigDecimal;

public class ContenidoDAO extends GenericDAO<Contenido> {

    public ContenidoDAO() {
        super(Contenido.class);
    }

    /**
     * Busca un contenido y carga sus usuarios asociados (Dueños)
     * para evitar LazyInitializationException.
     */
    public Contenido buscarPorIdConUsuarios(Long id) {
        EntityManager em = HibernateUtil.getEntityManager();
        try {
            // "LEFT JOIN FETCH c.usuarios" obliga a Hibernate a traer la lista ya rellena.
            String jpql = "SELECT c FROM Contenido c LEFT JOIN FETCH c.usuarios WHERE c.idContent = :id";

            TypedQuery<Contenido> query = em.createQuery(jpql, Contenido.class);
            query.setParameter("id", id);

            return query.getResultStream().findFirst().orElse(null);

        } finally {
            em.close();
        }
    }

    /**
     * Busca un contenido y carga sus valoraciones (reseñas recibidas)
     * Necesario para mantener la coherencia bidireccional al añadir una nueva.
     */
    public Contenido buscarPorIdConValoraciones(Long id) {
        EntityManager em = HibernateUtil.getEntityManager();
        try {
            String jpql = "SELECT c FROM Contenido c LEFT JOIN FETCH c.valoraciones WHERE c.idContent = :id";
            TypedQuery<Contenido> query = em.createQuery(jpql, Contenido.class);
            query.setParameter("id", id);
            return query.getResultStream().findFirst().orElse(null);
        } finally {
            em.close();
        }
    }

    public Contenido traerContenidoCompleto(int id) {
        EntityManager em = HibernateUtil.getEntityManager();
        try {
            String jpql = "SELECT c FROM Contenido c " +
                    "LEFT JOIN FETCH c.usuarios " + // Carga los usuarios asociados
                    "LEFT JOIN FETCH c.valoraciones " + // Carga las valoraciones asociadas
                    "WHERE c.idContent = :id";
            TypedQuery<Contenido> query = em.createQuery(jpql, Contenido.class);
            query.setParameter("id", id);
            return query.getResultStream().findFirst().orElse(null);
        } finally {
            em.close();
        }
    }

    public BigDecimal recalcularYGuardarMedia(int idContent) {
        EntityManager em = null;
        EntityTransaction tx = null;
        BigDecimal mediaCalculada = BigDecimal.ZERO;

        try {
            em = HibernateUtil.getEntityManager();

            tx = em.getTransaction();
            tx.begin();

            // Calcular la media con JPQL ---
            String jpql = "SELECT AVG(v.score) FROM Valoracion v WHERE v.contenido.idContent = :id";
            TypedQuery<Double> query = em.createQuery(jpql, Double.class);
            query.setParameter("id", idContent);

            Double resultado = query.getSingleResult();

            if (resultado != null) {
                // Redondeo a 1 decimal
                mediaCalculada = BigDecimal.valueOf(resultado).setScale(1, BigDecimal.ROUND_HALF_UP);
            }

            //Actualizar la entidad Contenido
            Contenido c = em.find(Contenido.class, idContent);
            if (c != null) {
                c.setAvgValoracion(mediaCalculada);
                //para asegurar los datos con la bbdd
                em.merge(c);
            }

            tx.commit();

        } catch (Exception e) {
            if (tx != null && tx.isActive()) {
                tx.rollback();
            }
            e.printStackTrace();
        } finally {
            if (em != null) {
                em.close();
            }
        }

        return mediaCalculada;
    }
}
