package com.familytree.app.insights;

import com.familytree.app.common.NotFoundException;
import com.familytree.app.person.Person;
import com.familytree.app.person.PersonRepository;
import com.familytree.app.relationship.Relationship;
import com.familytree.app.relationship.RelationshipRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

/**
 * Finds how two people are connected by walking PARENT, CHILD, and SPOUSE edges.
 * Uses BFS to find the shortest connection path, then derives a human label
 * (including in-laws and step-relations) from the sequence of edges.
 */
@Service
@RequiredArgsConstructor
public class RelationshipFinderService {

    private final PersonRepository personRepository;
    private final RelationshipRepository relationshipRepository;

    public record RelationshipResult(String label, String detail, List<String> path) {}

    private enum Edge { FATHER, MOTHER, CHILD, SPOUSE }

    private record Step(Long personId, Edge viaEdge) {}

    @Transactional(readOnly = true)
    public RelationshipResult findRelationship(Long fromId, Long toId) {
        Person from = personRepository.findById(fromId)
                .orElseThrow(() -> new NotFoundException("Person not found: " + fromId));
        Person to = personRepository.findById(toId)
                .orElseThrow(() -> new NotFoundException("Person not found: " + toId));

        if (fromId.equals(toId)) {
            return new RelationshipResult("Same person", "That's the same person.", List.of());
        }

        Map<Long, Person> byId = new HashMap<>();
        for (Person p : personRepository.findAll()) byId.put(p.getId(), p);

        // spouse adjacency
        Map<Long, Set<Long>> spouses = new HashMap<>();
        for (Relationship r : relationshipRepository.findAll()) {
            spouses.computeIfAbsent(r.getPersonAId(), k -> new HashSet<>()).add(r.getPersonBId());
            spouses.computeIfAbsent(r.getPersonBId(), k -> new HashSet<>()).add(r.getPersonAId());
        }

        // BFS storing the edge taken to reach each node
        Map<Long, Step> cameFrom = new HashMap<>();
        Deque<Long> queue = new ArrayDeque<>();
        queue.add(fromId);
        cameFrom.put(fromId, new Step(null, null));

        while (!queue.isEmpty()) {
            Long curId = queue.poll();
            if (curId.equals(toId)) break;
            Person cur = byId.get(curId);
            if (cur == null) continue;

            // up: parents
            addNeighbor(cur.getFather(), Edge.FATHER, curId, cameFrom, queue);
            addNeighbor(cur.getMother(), Edge.MOTHER, curId, cameFrom, queue);
            // down: children
            for (Person child : findChildren(curId, byId.values())) {
                addNeighborId(child.getId(), Edge.CHILD, curId, cameFrom, queue);
            }
            // sideways: spouses
            for (Long sp : spouses.getOrDefault(curId, Set.of())) {
                addNeighborId(sp, Edge.SPOUSE, curId, cameFrom, queue);
            }
        }

        if (!cameFrom.containsKey(toId)) {
            return new RelationshipResult("Not connected",
                    "No connection found in the recorded tree yet. Add the missing parent or marriage links to connect them.",
                    List.of());
        }

        // reconstruct edge path from->to
        List<Edge> edges = new ArrayList<>();
        List<Long> nodes = new ArrayList<>();
        Long cur = toId;
        while (cur != null && !cur.equals(fromId)) {
            Step st = cameFrom.get(cur);
            edges.add(st.viaEdge());
            nodes.add(cur);
            cur = st.personId();
        }
        Collections.reverse(edges);
        Collections.reverse(nodes);

        String label = deriveLabel(edges, to.getGender());
        List<String> pathNames = new ArrayList<>();
        pathNames.add(displayName(from));
        for (Long id : nodes) pathNames.add(displayName(byId.get(id)));

        String detail = pathNames.size() <= 2
                ? displayName(to) + " is the " + label.toLowerCase() + " of " + from.getFirstName() + "."
                : "Connected through: " + String.join(" → ", pathNames);

        return new RelationshipResult(label, detail, pathNames);
    }

    private void addNeighbor(Person p, Edge e, Long fromNode,
                             Map<Long, Step> cameFrom, Deque<Long> queue) {
        if (p != null) addNeighborId(p.getId(), e, fromNode, cameFrom, queue);
    }

    private void addNeighborId(Long id, Edge e, Long fromNode,
                               Map<Long, Step> cameFrom, Deque<Long> queue) {
        if (id != null && !cameFrom.containsKey(id)) {
            cameFrom.put(id, new Step(fromNode, e));
            queue.add(id);
        }
    }

    private List<Person> findChildren(Long parentId, Collection<Person> all) {
        List<Person> kids = new ArrayList<>();
        for (Person p : all) {
            if ((p.getFather() != null && p.getFather().getId().equals(parentId)) ||
                (p.getMother() != null && p.getMother().getId().equals(parentId))) {
                kids.add(p);
            }
        }
        return kids;
    }

    /**
     * Translate the edge sequence into a relationship word.
     * Handles direct lines, siblings, aunts/uncles, cousins, grandparents,
     * and marriage-based in-law relations.
     */
    private String deriveLabel(List<Edge> edges, Person.Gender g) {
        // Count consecutive UP (parent) then DOWN (child) with optional spouse hops.
        boolean male = g == Person.Gender.MALE;
        boolean female = g == Person.Gender.FEMALE;

        // Pure spouse
        if (edges.size() == 1 && edges.get(0) == Edge.SPOUSE) {
            return female ? "Wife" : male ? "Husband" : "Spouse";
        }

        long ups = edges.stream().filter(e -> e == Edge.FATHER || e == Edge.MOTHER).count();
        long downs = edges.stream().filter(e -> e == Edge.CHILD).count();
        long spousesHops = edges.stream().filter(e -> e == Edge.SPOUSE).count();

        // Detect a trailing or leading spouse hop => in-law
        boolean inLaw = spousesHops > 0;

        // Pure ancestor (all ups)
        if (downs == 0 && spousesHops == 0) {
            return switch ((int) ups) {
                case 1 -> female ? "Mother" : male ? "Father" : "Parent";
                case 2 -> female ? "Grandmother" : male ? "Grandfather" : "Grandparent";
                case 3 -> "Great-grandparent";
                default -> (ups - 2) + "x great-grandparent";
            };
        }
        // Pure descendant (all downs)
        if (ups == 0 && spousesHops == 0) {
            return switch ((int) downs) {
                case 1 -> female ? "Daughter" : male ? "Son" : "Child";
                case 2 -> female ? "Granddaughter" : male ? "Grandson" : "Grandchild";
                case 3 -> "Great-grandchild";
                default -> (downs - 2) + "x great-grandchild";
            };
        }

        // Sibling: up to a parent then down to a child (ups==1, downs==1)
        if (ups == 1 && downs == 1 && spousesHops == 0) {
            return female ? "Sister" : male ? "Brother" : "Sibling";
        }
        // Sibling-in-law: sibling + spouse, or spouse + sibling
        if (ups == 1 && downs == 1 && spousesHops == 1) {
            return female ? "Sister-in-law" : male ? "Brother-in-law" : "Sibling-in-law";
        }
        // Aunt/Uncle: up 2, down 1
        if (ups == 2 && downs == 1 && spousesHops == 0) {
            return female ? "Aunt" : male ? "Uncle" : "Aunt/Uncle";
        }
        if (ups == 2 && downs == 1 && spousesHops == 1) {
            return female ? "Aunt (by marriage)" : male ? "Uncle (by marriage)" : "Aunt/Uncle (by marriage)";
        }
        // Niece/Nephew: up 1, down 2
        if (ups == 1 && downs == 2 && spousesHops == 0) {
            return female ? "Niece" : male ? "Nephew" : "Niece/Nephew";
        }
        // Parent-in-law: spouse then up
        if (ups == 1 && downs == 0 && spousesHops == 1) {
            return female ? "Mother-in-law" : male ? "Father-in-law" : "Parent-in-law";
        }
        // Child-in-law: down then spouse
        if (ups == 0 && downs == 1 && spousesHops == 1) {
            return female ? "Daughter-in-law" : male ? "Son-in-law" : "Child-in-law";
        }
        // Cousins: up N, down M, both >=2
        if (ups >= 2 && downs >= 2 && spousesHops == 0) {
            int degree = (int) Math.min(ups, downs) - 1;
            int removed = (int) Math.abs(ups - downs);
            String base = ordinal(degree) + " cousin";
            if (removed > 0) base += " " + removed + "x removed";
            return base;
        }

        // Fallback for anything with marriage hops
        if (inLaw) return "Related by marriage";
        return "Relative";
    }

    private String ordinal(int n) {
        return switch (n) {
            case 1 -> "1st";
            case 2 -> "2nd";
            case 3 -> "3rd";
            default -> n + "th";
        };
    }

    private String displayName(Person p) {
        if (p == null) return "?";
        return p.getFirstName() + (p.getLastName() != null ? " " + p.getLastName() : "");
    }
}
