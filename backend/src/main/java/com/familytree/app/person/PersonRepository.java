package com.familytree.app.person;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;

public interface PersonRepository extends JpaRepository<Person, Long> {

    List<Person> findByLastNameIgnoreCase(String lastName);

    @Query("SELECT p FROM Person p WHERE p.father.id = :parentId OR p.mother.id = :parentId")
    List<Person> findChildren(Long parentId);

    @Query("SELECT p FROM Person p WHERE " +
           "LOWER(p.firstName) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
           "LOWER(p.lastName) LIKE LOWER(CONCAT('%', :q, '%'))")
    List<Person> searchByName(String q);
}
