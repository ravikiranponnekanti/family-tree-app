package com.familytree.app.insights;

import com.familytree.app.common.NotFoundException;
import com.familytree.app.person.Person;
import com.familytree.app.person.PersonRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

/**
 * Computes how two people are related by walking parent links.
 * Strategy: build each person's ancestor map (ancestor id -> distance up the tree),
 * find the closest common ancestor, then translate the two distances into a label
 * (parent, sibling, cousin, aunt/uncle, etc.).
 */
@Service
@RequiredArgsConstructor
public class RelationshipFinderService {

    private final PersonRepository repository;

    public record RelationshipResult(String label, String detail) {}

    @Transactional(readOnly = true)
    public RelationshipResult findRelationship(Long fromId, Long toId) {
        Person from = repository.findById(fromId)
                .orElseThrow(() -> new NotFoundException("Person not found: " + fromId));
        Person to = repository.findById(toId)
                .orElseThrow(() -> new NotFoundException("Person not found: " + toId));

        if (fromId.equals(toId)) {
            return new RelationshipResult("Same person", "That's the same person.");
        }

        // Direct descendant/ancestor checks first
        Map<Long, Integer> fromAnc = ancestors(from);
        Map<Long, Integer> toAnc = ancestors(to);

        // Is 'to' an ancestor of 'from'?
        if (fromAnc.containsKey(toId)) {
            int d = fromAnc.get(toId);
            return new RelationshipResult(ancestorLabel(d, to.getGender()),
                    descLine(from, to, d, 0));
        }
        // Is 'from' an ancestor of 'to'?
        if (toAnc.containsKey(fromId)) {
            int d = toAnc.get(fromId);
            return new RelationshipResult(descendantLabel(d, to.getGender()),
                    descLine(from, to, 0, d));
        }

        // Find lowest common ancestor with smallest combined distance
        Long bestAncestor = null;
        int bestFrom = Integer.MAX_VALUE, bestTo = Integer.MAX_VALUE;
        int bestSum = Integer.MAX_VALUE;
        for (var e : fromAnc.entrySet()) {
            if (toAnc.containsKey(e.getKey())) {
                int sum = e.getValue() + toAnc.get(e.getKey());
                if (sum < bestSum) {
                    bestSum = sum;
                    bestAncestor = e.getKey();
                    bestFrom = e.getValue();
                    bestTo = toAnc.get(e.getKey());
                }
            }
        }

        if (bestAncestor == null) {
            return new RelationshipResult("No blood relation found",
                    "No common ancestor was found in the recorded tree. "
                            + "They may be related by marriage or the link isn't recorded yet.");
        }

        String label = cousinLabel(bestFrom, bestTo, to.getGender());
        return new RelationshipResult(label,
                from.getFirstName() + " and " + to.getFirstName()
                        + " share a common ancestor.");
    }

    /** Map of ancestorId -> generations above the person (1 = parent). Includes nothing for self. */
    private Map<Long, Integer> ancestors(Person p) {
        Map<Long, Integer> result = new HashMap<>();
        Deque<Map.Entry<Person, Integer>> queue = new ArrayDeque<>();
        if (p.getFather() != null) queue.add(Map.entry(p.getFather(), 1));
        if (p.getMother() != null) queue.add(Map.entry(p.getMother(), 1));
        while (!queue.isEmpty()) {
            var cur = queue.poll();
            Person person = cur.getKey();
            int dist = cur.getValue();
            // keep the smallest distance if reached multiple ways
            result.merge(person.getId(), dist, Math::min);
            if (person.getFather() != null)
                queue.add(Map.entry(person.getFather(), dist + 1));
            if (person.getMother() != null)
                queue.add(Map.entry(person.getMother(), dist + 1));
        }
        return result;
    }

    private String ancestorLabel(int d, Person.Gender g) {
        return switch (d) {
            case 1 -> g == Person.Gender.FEMALE ? "Mother" : g == Person.Gender.MALE ? "Father" : "Parent";
            case 2 -> g == Person.Gender.FEMALE ? "Grandmother" : g == Person.Gender.MALE ? "Grandfather" : "Grandparent";
            case 3 -> "Great-grandparent";
            default -> (d - 2) + "x great-grandparent";
        };
    }

    private String descendantLabel(int d, Person.Gender g) {
        return switch (d) {
            case 1 -> g == Person.Gender.FEMALE ? "Daughter" : g == Person.Gender.MALE ? "Son" : "Child";
            case 2 -> g == Person.Gender.FEMALE ? "Granddaughter" : g == Person.Gender.MALE ? "Grandson" : "Grandchild";
            case 3 -> "Great-grandchild";
            default -> (d - 2) + "x great-grandchild";
        };
    }

    private String cousinLabel(int dFrom, int dTo, Person.Gender g) {
        // Siblings: both one step from common ancestor
        if (dFrom == 1 && dTo == 1) {
            return g == Person.Gender.FEMALE ? "Sister" : g == Person.Gender.MALE ? "Brother" : "Sibling";
        }
        // Aunt/Uncle or Niece/Nephew: one is a direct child, other is deeper
        if (dFrom == 1) {
            // 'to' is dTo steps down from ancestor, 'from' is sibling-level
            return g == Person.Gender.FEMALE ? "Niece" : g == Person.Gender.MALE ? "Nephew" : "Niece/Nephew";
        }
        if (dTo == 1) {
            return g == Person.Gender.FEMALE ? "Aunt" : g == Person.Gender.MALE ? "Uncle" : "Aunt/Uncle";
        }
        // Cousins: degree = min - 1, removed = |dFrom - dTo|
        int degree = Math.min(dFrom, dTo) - 1;
        int removed = Math.abs(dFrom - dTo);
        String base = ordinal(degree) + " cousin";
        if (removed > 0) base += " " + removed + "x removed";
        return base;
    }

    private String ordinal(int n) {
        return switch (n) {
            case 1 -> "1st";
            case 2 -> "2nd";
            case 3 -> "3rd";
            default -> n + "th";
        };
    }

    private String descLine(Person from, Person to, int upFrom, int downTo) {
        return to.getFirstName() + " is the " +
                (upFrom > 0 ? "ancestor" : "descendant") + " of " + from.getFirstName() + ".";
    }
}
