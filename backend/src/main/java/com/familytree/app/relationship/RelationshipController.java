package com.familytree.app.relationship;

import com.familytree.app.common.NotFoundException;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/relationships")
@RequiredArgsConstructor
public class RelationshipController {

    private final RelationshipRepository repository;

    public record RelationshipRequest(
            @NotNull Long personAId,
            @NotNull Long personBId,
            Relationship.RelationType type,
            LocalDate startDate,
            LocalDate endDate
    ) {}

    @GetMapping
    public List<Relationship> getAll() {
        return repository.findAll();
    }

    @GetMapping("/person/{personId}")
    public List<Relationship> forPerson(@PathVariable Long personId) {
        return repository.findByPersonAIdOrPersonBId(personId, personId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Relationship create(@RequestBody RelationshipRequest req) {
        Relationship r = Relationship.builder()
                .personAId(req.personAId())
                .personBId(req.personBId())
                .type(req.type())
                .startDate(req.startDate())
                .endDate(req.endDate())
                .build();
        return repository.save(r);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        if (!repository.existsById(id)) {
            throw new NotFoundException("Relationship not found: " + id);
        }
        repository.deleteById(id);
        return ResponseEntity.noContent().build();
    }
}
