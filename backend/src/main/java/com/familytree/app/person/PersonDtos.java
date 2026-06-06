package com.familytree.app.person;

import jakarta.validation.constraints.NotBlank;

import java.time.LocalDate;

public class PersonDtos {

    // Incoming payload for create/update
    public record PersonRequest(
            @NotBlank String firstName,
            String lastName,
            Person.Gender gender,
            LocalDate birthDate,
            LocalDate deathDate,
            String bio,
            String photoUrl,
            Long fatherId,
            Long motherId
    ) {}

    // Outgoing response — flattens parent ids so we don't serialize whole graphs
    public record PersonResponse(
            Long id,
            String firstName,
            String lastName,
            Person.Gender gender,
            LocalDate birthDate,
            LocalDate deathDate,
            String bio,
            String photoUrl,
            Long fatherId,
            Long motherId
    ) {
        public static PersonResponse from(Person p) {
            return new PersonResponse(
                    p.getId(),
                    p.getFirstName(),
                    p.getLastName(),
                    p.getGender(),
                    p.getBirthDate(),
                    p.getDeathDate(),
                    p.getBio(),
                    p.getPhotoUrl(),
                    p.getFather() != null ? p.getFather().getId() : null,
                    p.getMother() != null ? p.getMother().getId() : null
            );
        }
    }
}
