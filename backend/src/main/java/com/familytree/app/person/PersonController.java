package com.familytree.app.person;

import com.familytree.app.person.PersonDtos.PersonRequest;
import com.familytree.app.person.PersonDtos.PersonResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/persons")
@RequiredArgsConstructor
public class PersonController {

    private final PersonService service;

    @GetMapping
    public List<PersonResponse> getAll() {
        return service.findAll();
    }

    @GetMapping("/{id}")
    public PersonResponse getOne(@PathVariable Long id) {
        return service.findById(id);
    }

    @GetMapping("/{id}/children")
    public List<PersonResponse> getChildren(@PathVariable Long id) {
        return service.findChildren(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public PersonResponse create(@Valid @RequestBody PersonRequest req) {
        return service.create(req);
    }

    @PutMapping("/{id}")
    public PersonResponse update(@PathVariable Long id, @Valid @RequestBody PersonRequest req) {
        return service.update(id, req);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        service.delete(id);
        return ResponseEntity.noContent().build();
    }
}
