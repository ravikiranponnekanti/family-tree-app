package com.familytree.app.relationship;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;

@Entity
@Table(name = "relationships")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Relationship {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // References person ids (kept loosely coupled — no JPA join to Person here)
    @Column(nullable = false)
    private Long personAId;

    @Column(nullable = false)
    private Long personBId;

    @Enumerated(EnumType.STRING)
    private RelationType type;

    private LocalDate startDate;

    private LocalDate endDate;

    public enum RelationType { MARRIED, PARTNER, DIVORCED, ENGAGED }
}
