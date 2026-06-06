package com.familytree.app.relationship;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface RelationshipRepository extends JpaRepository<Relationship, Long> {
    List<Relationship> findByPersonAIdOrPersonBId(Long personAId, Long personBId);
}
