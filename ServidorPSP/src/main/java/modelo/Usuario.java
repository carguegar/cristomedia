package modelo;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.JoinTable;
import jakarta.persistence.ManyToMany;
import jakarta.persistence.OneToMany;
import jakarta.persistence.Table;

@Entity
@Table(name = "Usuario")
public class Usuario {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "idUser")
    private Long idUser;

    @Column(name = "userName", unique = true, nullable = false)
    private String userName;

    @Column(name = "name", nullable = false)
    private String name;

    @Column(name = "surname1", nullable = false)
    private String surname1;

    @Column(name = "surname2", nullable = false)
    private String surname2;

    @Column(name = "email", unique = true, nullable = false)
    private String email;

    @Column(name = "conectionsCounter", nullable = false)
    private Integer conectionsCounter;

    @Column(name = "password", nullable = false)
    private String password;

    @Column(name = "userImagePath")
    private String userImagePath;

    // --- RELACIÓN N:M con Contenido usando la tabla intermedia Poseer (idUser,idContent)
    @ManyToMany(cascade = { CascadeType.PERSIST, CascadeType.MERGE })
    @JoinTable(
            name = "Poseer",
            joinColumns = @JoinColumn(name = "idUser"),
            inverseJoinColumns = @JoinColumn(name = "idContent")
    )
    private Set<Contenido> contenidos = new HashSet<>();

    // Relación 1:N con Valoracion
    @OneToMany(mappedBy = "usuario", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<Valoracion> valoraciones = new ArrayList<>();

    // Getter y Setter para la lista...
    public List<Valoracion> getValoraciones() { return valoraciones; }
    public void setValoraciones(List<Valoracion> valoraciones) { this.valoraciones = valoraciones; }

    // --- CONSTRUCTORES ---

    public Usuario() {}

    public Usuario(String userName, String name, String surname1, String surname2,
                   String email, Integer conectionsCounter, String password, String userImagePath) {
        this.userName = userName;
        this.name = name;
        this.surname1 = surname1;
        this.surname2 = surname2;
        this.email = email;
        this.conectionsCounter = conectionsCounter;
        this.password = password;
        this.userImagePath = userImagePath;
    }

    // --- MÉTODOS HELPER (BUENA PRÁCTICA) ---
    public void agregarContenido(Contenido contenido) {
        this.contenidos.add(contenido);
        contenido.getUsuarios().add(this);
    }

    public void eliminarContenido(Contenido contenido) {
        this.contenidos.remove(contenido);
        contenido.getUsuarios().remove(this);
    }

    /**
     * Helper para crear una valoración vinculando ambos lados.
     */
    public void valorarContenido(Contenido contenido, int score, String comment) {
        Valoracion nuevaValoracion = new Valoracion(this, contenido, score, comment);
        this.valoraciones.add(nuevaValoracion);
        contenido.getValoraciones().add(nuevaValoracion);
    }

    // --- GETTERS Y SETTERS ---

    public Long getIdUser() { return idUser; }
    public void setIdUser(Long idUser) { this.idUser = idUser; }

    public String getUserName() { return userName; }
    public void setUserName(String userName) { this.userName = userName; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getSurname1() { return surname1; }
    public void setSurname1(String surname1) { this.surname1 = surname1; }

    public String getSurname2() { return surname2; }
    public void setSurname2(String surname2) { this.surname2 = surname2; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public Integer getConectionsCounter() { return conectionsCounter; }
    public void setConectionsCounter(Integer conectionsCounter) { this.conectionsCounter = conectionsCounter; }

    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }

    public String getUserImagePath() { return userImagePath; }
    public void setUserImagePath(String userImagePath) { this.userImagePath = userImagePath; }

    public Set<Contenido> getContenidos() { return contenidos; }
    public void setContenidos(Set<Contenido> contenidos) { this.contenidos = contenidos; }

    @Override
    public String toString() {
        return "Usuario [id=" + idUser + ", userName=" + userName + ", email=" + email + "]";
    }
}