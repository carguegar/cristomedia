package modelo;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

@Entity
@Table(name = "valora")
public class Valoracion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "idvaloracion")
    private Long idValoracion;

    @Column(name = "score")
    private Integer score;

    @Column(name = "comment")
    private String comment;

    @Column(name = "timestamp", insertable = false, updatable = false)
    private LocalDateTime timestamp;

    // --- RELACIONES ---

    @ManyToOne(fetch = FetchType.LAZY) // Lazy es mejor por rendimiento
    @JoinColumn(name = "iduser", nullable = false)
    private Usuario usuario;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "idcontent", nullable = false)
    private Contenido contenido;

    // --- CONSTRUCTORES ---
    public Valoracion() {}

    public Valoracion(Usuario usuario, Contenido contenido, Integer score, String comment) {
        this.usuario = usuario;
        this.contenido = contenido;
        this.score = score;
        this.comment = comment;
    }

    // --- GETTERS Y SETTERS ---

    public Long getIdValoracion() { return idValoracion; }
    public void setIdValoracion(Long idValoracion) { this.idValoracion = idValoracion; }

    public Integer getScore() { return score; }
    public void setScore(Integer score) { this.score = score; }

    public String getComment() { return comment; }
    public void setComment(String comment) { this.comment = comment; }

    public LocalDateTime getTimestamp() { return timestamp; }
    public void setTimestamp(LocalDateTime timestamp) { this.timestamp = timestamp; }

    public Usuario getUsuario() { return usuario; }
    public void setUsuario(Usuario usuario) { this.usuario = usuario; }

    public Contenido getContenido() { return contenido; }
    public void setContenido(Contenido contenido) { this.contenido = contenido; }

    @Override
    public String toString() {
        return "Valoracion{" +
                "id=" + idValoracion +
                ", score=" + score +
                ", comment='" + comment + '\'' +
                ", timestamp=" + timestamp +
                '}'; // ¡OJO! No imprimas 'usuario' ni 'contenido' aquí para evitar bucle infinito
    }
}