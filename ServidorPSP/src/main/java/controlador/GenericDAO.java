package controlador;

import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityTransaction;
import modelo.HibernateUtil; // Asegúrate de importar tu HibernateUtil
import java.util.List;

// <T> significa que funciona para cualquier clase (Usuario, Contenido, etc.)
public abstract class GenericDAO<T> {

    private Class<T> entityClass;

    public GenericDAO(Class<T> entityClass) {
        this.entityClass = entityClass;
    }

    // --- CREATE (Guardar) ---
    public Boolean create(T entity) {
        EntityManager em = HibernateUtil.getEntityManager();
        EntityTransaction tx = null;
        try {
            tx = em.getTransaction();
            tx.begin();
            em.persist(entity);
            tx.commit();
            return true;
        } catch (Exception e) {
            if (tx != null && tx.isActive()) tx.rollback();
            e.printStackTrace();
            return false;
        } finally {
            em.close();
        }
    }

    // --- READ (Buscar por ID) ---
    public T find(Long id) {
        EntityManager em = HibernateUtil.getEntityManager();
        try {
            return em.find(entityClass, id);
        } finally {
            em.close();
        }
    }

    // --- READ ALL (Listar todos) ---
    public List<T> findAll() {
        EntityManager em = HibernateUtil.getEntityManager();
        try {
            // Usamos JPQL dinámico: "SELECT t FROM NombreClase t"
            String jpql = "SELECT t FROM " + entityClass.getSimpleName() + " t";
            return em.createQuery(jpql, entityClass).getResultList();
        } finally {
            em.close();
        }
    }

    // --- UPDATE (Actualizar) ---
    public void update(T entity) {
        EntityManager em = HibernateUtil.getEntityManager();
        EntityTransaction tx = null;
        try {
            tx = em.getTransaction();
            tx.begin();
            em.merge(entity); // 'merge' actualiza si existe, o guarda si es nuevo (cuidado con duplicados si no hay ID)
            tx.commit();
        } catch (Exception e) {
            if (tx != null && tx.isActive()) tx.rollback();
            e.printStackTrace();
        } finally {
            em.close();
        }
    }

    // --- DELETE (Borrar) ---
    public void delete(Long id) {
        EntityManager em = HibernateUtil.getEntityManager();
        EntityTransaction tx = null;
        try {
            tx = em.getTransaction();
            tx.begin();
            // Primero hay que traer el objeto al contexto de persistencia para borrarlo
            T entity = em.find(entityClass, id);
            if (entity != null) {
                em.remove(entity);
            }
            tx.commit();
        } catch (Exception e) {
            if (tx != null && tx.isActive()) tx.rollback();
            e.printStackTrace();
        } finally {
            em.close();
        }
    }

    public void delete(T entity) {
        EntityManager em = HibernateUtil.getEntityManager();
        EntityTransaction tx = null;
        try {
            tx = em.getTransaction();
            tx.begin();
            // Asegurarse de que la entidad está gestionada antes de eliminar
            T managedEntity = em.merge(entity);
            em.remove(managedEntity);
            tx.commit();
        } catch (Exception e) {
            if (tx != null && tx.isActive()) tx.rollback();
            e.printStackTrace();
        } finally {
            em.close();
        }
    }
}