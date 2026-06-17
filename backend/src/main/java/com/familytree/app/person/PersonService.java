package com.familytree.app.person;

import com.familytree.app.common.NotFoundException;
import com.familytree.app.person.PersonDtos.PersonRequest;
import com.familytree.app.person.PersonDtos.PersonResponse;
import com.familytree.app.relationship.Relationship;
import com.familytree.app.relationship.RelationshipRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class PersonService {

    private final PersonRepository repository;
    private final RelationshipRepository relationshipRepository;

    @Transactional(readOnly = true)
    public List<PersonResponse> findAll() {
        return repository.findAll().stream().map(PersonResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public PersonResponse findById(Long id) {
        return PersonResponse.from(getOrThrow(id));
    }

    @Transactional(readOnly = true)
    public List<PersonResponse> findChildren(Long parentId) {
        return repository.findChildren(parentId).stream().map(PersonResponse::from).toList();
    }

    @Transactional
    public PersonResponse create(PersonRequest req) {
        Person person = Person.builder()
                .firstName(req.firstName())
                .lastName(req.lastName())
                .gender(req.gender())
                .birthDate(req.birthDate())
                .deathDate(req.deathDate())
                .bio(req.bio())
                .photoUrl(req.photoUrl())
                .father(resolveParent(req.fatherId()))
                .mother(resolveParent(req.motherId()))
                .build();
        return PersonResponse.from(repository.save(person));
    }

    @Transactional
    public PersonResponse update(Long id, PersonRequest req) {
        Person person = getOrThrow(id);
        person.setFirstName(req.firstName());
        person.setLastName(req.lastName());
        person.setGender(req.gender());
        person.setBirthDate(req.birthDate());
        person.setDeathDate(req.deathDate());
        person.setBio(req.bio());
        person.setPhotoUrl(req.photoUrl());
        person.setFather(resolveParent(req.fatherId()));
        person.setMother(resolveParent(req.motherId()));
        return PersonResponse.from(repository.save(person));
    }

    @Transactional
    public void delete(Long id) {
        Person person = repository.findById(id)
                .orElseThrow(() -> new NotFoundException("Person not found: " + id));

        // 1) Detach this person from any children who reference them
        //    as father or mother, so the foreign keys don't block deletion.
        List<Person> children = repository.findChildren(id);
        for (Person child : children) {
            if (child.getFather() != null && child.getFather().getId().equals(id)) {
                child.setFather(null);
            }
            if (child.getMother() != null && child.getMother().getId().equals(id)) {
                child.setMother(null);
            }
            repository.save(child);
        }
        // ensure the detach updates hit the DB before we delete
        repository.flush();

        // 2) Remove any spouse/partner relationships involving this person.
        List<Relationship> rels =
                relationshipRepository.findByPersonAIdOrPersonBId(id, id);
        if (!rels.isEmpty()) {
            relationshipRepository.deleteAll(rels);
            relationshipRepository.flush();
        }

        // 3) Now it's safe to delete the person.
        repository.delete(person);
    }

    private Person resolveParent(Long parentId) {
        if (parentId == null) return null;
        return getOrThrow(parentId);
    }

    private Person getOrThrow(Long id) {
        return repository.findById(id)
                .orElseThrow(() -> new NotFoundException("Person not found: " + id));
    }
}
