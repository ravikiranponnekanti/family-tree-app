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
 * Finds how two people are connected by walking PARENT, CHILD, SPOUSE and
 * SIBLING edges. Siblings come from BOTH explicit sibling relationships AND
 * shared-parent detection. Uses BFS for the shortest path, then derives a
 * human label (blood + in-law + step relations) from the edge sequence.
 */
@Service
@RequiredArgsConstructor
public class RelationshipFinderService {

    private final PersonRepository personRepository;
    private final RelationshipRepository relationshipRepository;

    public record RelationshipResult(String label, String detail, List<String> path) {}

    private enum Edge { FATHER, MOTHER, CHILD, SPOUSE, SIBLING }

    private record Step(Long personId, Edge viaEdge) {}

    private static final Set<String> MARRIAGE_TYPES =
            Set.of("MARRIED", "PARTNER", "ENGAGED", "DIVORCED");
    private static final Set<String> SIBLING_TYPES =
            Set.of("SIBLING", "BROTHER", "SISTER");

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

        // Build spouse and sibling adjacency from relationships
        Map<Long, Set<Long>> spouses = new HashMap<>();
        Map<Long, Set<Long>> siblings = new HashMap<>();
        for (Relationship r : relationshipRepository.findAll()) {
            String t = r.getType() != null ? r.getType().name() : "";
            if (MARRIAGE_TYPES.contains(t)) {
                spouses.computeIfAbsent(r.getPersonAId(), k -> new HashSet<>()).add(r.getPersonBId());
                spouses.computeIfAbsent(r.getPersonBId(), k -> new HashSet<>()).add(r.getPersonAId());
            } else if (SIBLING_TYPES.contains(t)) {
                siblings.computeIfAbsent(r.getPersonAId(), k -> new HashSet<>()).add(r.getPersonBId());
                siblings.computeIfAbsent(r.getPersonBId(), k -> new HashSet<>()).add(r.getPersonAId());
            }
        }
        // Shared-parent sibling detection: anyone sharing a father or mother
        for (Person a : byId.values()) {
            for (Person b : byId.values()) {
                if (a.getId().equals(b.getId())) continue;
                if (shareAParent(a, b)) {
                    siblings.computeIfAbsent(a.getId(), k -> new HashSet<>()).add(b.getId());
                }
            }
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

            addNeighbor(cur.getFather(), Edge.FATHER, curId, cameFrom, queue);
            addNeighbor(cur.getMother(), Edge.MOTHER, curId, cameFrom, queue);
            for (Person child : findChildren(curId, byId.values())) {
                addNeighborId(child.getId(), Edge.CHILD, curId, cameFrom, queue);
            }
            for (Long sp : spouses.getOrDefault(curId, Set.of())) {
                addNeighborId(sp, Edge.SPOUSE, curId, cameFrom, queue);
            }
            for (Long sib : siblings.getOrDefault(curId, Set.of())) {
                addNeighborId(sib, Edge.SIBLING, curId, cameFrom, queue);
            }
        }

        if (!cameFrom.containsKey(toId)) {
            return new RelationshipResult("Not connected",
                    "No connection found in the recorded tree yet. Add the missing parent, marriage or sibling links to connect them.",
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

    private boolean shareAParent(Person a, Person b) {
        Long af = a.getFather() != null ? a.getFather().getId() : null;
        Long am = a.getMother() != null ? a.getMother().getId() : null;
        Long bf = b.getFather() != null ? b.getFather().getId() : null;
        Long bm = b.getMother() != null ? b.getMother().getId() : null;
        if (af != null && (af.equals(bf) || af.equals(bm))) return true;
        if (am != null && (am.equals(bf) || am.equals(bm))) return true;
        return false;
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
     */
    private String deriveLabel(List<Edge> edges, Person.Gender g) {
        boolean male = g == Person.Gender.MALE;
        boolean female = g == Person.Gender.FEMALE;

        // Pure spouse
        if (edges.size() == 1 && edges.get(0) == Edge.SPOUSE) {
            return female ? "Wife" : male ? "Husband" : "Spouse";
        }
        // Explicit sibling edge (single hop)
        if (edges.size() == 1 && edges.get(0) == Edge.SIBLING) {
            return female ? "Sister" : male ? "Brother" : "Sibling";
        }

        long ups = edges.stream().filter(e -> e == Edge.FATHER || e == Edge.MOTHER).count();
        long downs = edges.stream().filter(e -> e == Edge.CHILD).count();
        long spousesHops = edges.stream().filter(e -> e == Edge.SPOUSE).count();
        long sibHops = edges.stream().filter(e -> e == Edge.SIBLING).count();

        // Treat a sibling hop as (up 1 + down 1) for counting cousins/aunts
        long effUps = ups + sibHops;
        long effDowns = downs + sibHops;

        boolean inLaw = spousesHops > 0;

        // Pure ancestor
        if (downs == 0 && spousesHops == 0 && sibHops == 0) {
            return switch ((int) ups) {
                case 1 -> female ? "Mother" : male ? "Father" : "Parent";
                case 2 -> female ? "Grandmother" : male ? "Grandfather" : "Grandparent";
                case 3 -> "Great-grandparent";
                default -> (ups - 2) + "x great-grandparent";
            };
        }
        // Pure descendant
        if (ups == 0 && spousesHops == 0 && sibHops == 0) {
            return switch ((int) downs) {
                case 1 -> female ? "Daughter" : male ? "Son" : "Child";
                case 2 -> female ? "Granddaughter" : male ? "Grandson" : "Grandchild";
                case 3 -> "Great-grandchild";
                default -> (downs - 2) + "x great-grandchild";
            };
        }

        // Spouse of an ancestor => step-parent / step-grandparent
        // (e.g. up to grandfather, then his other wife = step-grandmother)
        if (downs == 0 && sibHops == 0 && spousesHops == 1 && ups >= 1) {
            return switch ((int) ups) {
                case 1 -> female ? "Step-mother" : male ? "Step-father" : "Step-parent";
                case 2 -> female ? "Step-grandmother" : male ? "Step-grandfather" : "Step-grandparent";
                case 3 -> "Step-great-grandparent";
                default -> "Ancestor's spouse";
            };
        }

        // Sibling via shared parent (up1 down1) OR one sibling hop
        if ((ups == 1 && downs == 1 && spousesHops == 0 && sibHops == 0) ||
            (sibHops == 1 && ups == 0 && downs == 0 && spousesHops == 0)) {
            return female ? "Sister" : male ? "Brother" : "Sibling";
        }
        // Sibling-in-law
        if (effUps == 1 && effDowns == 1 && spousesHops == 1) {
            return female ? "Sister-in-law" : male ? "Brother-in-law" : "Sibling-in-law";
        }
        // Aunt/Uncle: up 2, down 1 (or sibling-of-parent)
        if (effUps == 2 && effDowns == 1 && spousesHops == 0) {
            return female ? "Aunt" : male ? "Uncle" : "Aunt/Uncle";
        }
        if (effUps == 2 && effDowns == 1 && spousesHops == 1) {
            return female ? "Aunt (by marriage)" : male ? "Uncle (by marriage)" : "Aunt/Uncle (by marriage)";
        }
        // Niece/Nephew: up 1, down 2
        if (effUps == 1 && effDowns == 2 && spousesHops == 0) {
            return female ? "Niece" : male ? "Nephew" : "Niece/Nephew";
        }
        // Parent-in-law
        if (ups == 1 && downs == 0 && spousesHops == 1 && sibHops == 0) {
            return female ? "Mother-in-law" : male ? "Father-in-law" : "Parent-in-law";
        }
        // Child-in-law
        if (ups == 0 && downs == 1 && spousesHops == 1 && sibHops == 0) {
            return female ? "Daughter-in-law" : male ? "Son-in-law" : "Child-in-law";
        }
        // Cousins
        if (effUps >= 2 && effDowns >= 2 && spousesHops == 0) {
            int degree = (int) Math.min(effUps, effDowns) - 1;
            int removed = (int) Math.abs(effUps - effDowns);
            String base = ordinal(degree) + " cousin";
            if (removed > 0) base += " " + removed + "x removed";
            return base;
        }

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
