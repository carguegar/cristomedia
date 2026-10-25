package modelo;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.ManyToMany;
import jakarta.persistence.OneToMany;
import jakarta.persistence.Table;

@Entity
@Table(name = "contenido")
public class Contenido {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "idcontent")
    private Long idContent;

    @Column(name = "namecontent", nullable = false)
    private String nameContent;

    @Column(name = "pathcontent", nullable = false)
    private String pathContent;

    @Column(name = "sizebytes")
    private Long sizeBytes;

    @Column(name = "avgvaloracion", precision = 3, scale = 2)
    private BigDecimal avgValoracion;

    @Column(name = "format", length = 10)
    private String format;

    // RELACIÓN N:M
    // mappedBy = "contenidos" indica que en la clase Usuario hay un atributo llamado "contenidos"
    // que es el dueño de la relación.
    @ManyToMany(mappedBy = "contenidos", fetch = FetchType.LAZY)
    private Set<Usuario> usuarios = new HashSet<>();

    // NUEVA relación: Un contenido tiene muchas reviews
    @OneToMany(mappedBy = "contenido", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<Valoracion> valoraciones = new ArrayList<>();

    // Getter y Setter para la lista...
    public List<Valoracion> getValoraciones() { return valoraciones; }
    public void setValoraciones(List<Valoracion> valoraciones) { this.valoraciones = valoraciones; }

    // --- CONSTRUCTORES ---

    public Contenido(){}

    public Contenido(String nameContent, String pathContent) {
        this.nameContent = nameContent;
        this.pathContent = pathContent;
    }

    public Contenido(String nameContent, String pathContent, Long sizeBytes, String format) {
        this.nameContent = nameContent;
        this.pathContent = pathContent;
        this.sizeBytes = sizeBytes;
        this.format = format;
    }

    // Getters y Setters
    public Long getIdContent() { return idContent; }
    public void setIdContent(Long idContent) { this.idContent = idContent; }

    public String getNameContent() { return nameContent; }
    public void setNameContent(String nameContent) { this.nameContent = nameContent; }

    public String getPathContent() { return pathContent; }
    public void setPathContent(String pathContent) { this.pathContent = pathContent; }

    public Long getSizeBytes() { return sizeBytes; }
    public void setSizeBytes(Long sizeBytes) { this.sizeBytes = sizeBytes; }

    public BigDecimal getAvgValoracion() { return avgValoracion; }
    public void setAvgValoracion(BigDecimal avgValoracion) { this.avgValoracion = avgValoracion; }

    public String getFormat() { return format; }
    public void setFormat(String format) { this.format = format; }

    public Set<Usuario> getUsuarios() { return usuarios; }
    public void setUsuarios(Set<Usuario> usuarios) { this.usuarios = usuarios; }

    // IMPORTANTE: Modificamos el toString para evitar recursividad infinita
    @Override
    public String toString() {
        return "Contenido [id=" + idContent + ", name=" + nameContent + ", sizeBytes=" + sizeBytes + "]";
    }
}