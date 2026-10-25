package controlador;
import jakarta.persistence.EntityManager;
import modelo.HibernateUtil;
import modelo.Valoracion;

import java.util.ArrayList;

public class ValoracionDAO extends GenericDAO<Valoracion> {
    public ValoracionDAO() {
        super(Valoracion.class);
    }

    public ArrayList<Valoracion> obtenerValoracionesDeContenido(int idContenido) {
        EntityManager em = HibernateUtil.getEntityManager();
        try {
            return new ArrayList<>(
                    em.createQuery(
                                    "SELECT v FROM Valoracion v " +
                                            "JOIN FETCH v.contenido c " +
                                            "JOIN FETCH v.usuario u " +
                                            "WHERE c.idContent = :idContenido",
                                    Valoracion.class )
                            .setParameter("idContenido", idContenido)
                            .getResultList()
            );
        } finally {
            em.close();
        }
    }
}