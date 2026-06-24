package com.familytree.app.insights;

import com.familytree.app.person.Person;
import com.familytree.app.person.PersonRepository;
import com.familytree.app.relationship.Relationship;
import com.familytree.app.relationship.RelationshipRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.Comparator;
import java.util.List;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class AnniversaryService {

    private final RelationshipRepository relationshipRepository;
    private final PersonRepository personRepository;

    private static final Set<String> MARRIAGE_TYPES =
            Set.of("MARRIED", "PARTNER", "ENGAGED");

    public record AnniversaryItem(Long relationshipId, String coupleNames,
                                  int day, int month, Integer years) {}

    /** Marriages whose wedding date falls in the current month. */
    @Transactional(readOnly = true)
    public List<AnniversaryItem> upcomingThisMonth() {
        int month = LocalDate.now().getMonthValue();
        int year = LocalDate.now().getYear();
        return relationshipRepository.findAll().stream()
                .filter(r -> r.getType() != null
                        && MARRIAGE_TYPES.contains(r.getType().name()))
                .filter(r -> r.getStartDate() != null)
                .filter(r -> r.getStartDate().getMonthValue() == month)
                .map(r -> toItem(r, year))
                .sorted(Comparator.comparingInt(AnniversaryItem::day))
                .toList();
    }

    private AnniversaryItem toItem(Relationship r, int year) {
        LocalDate d = r.getStartDate();
        String a = nameOf(r.getPersonAId());
        String b = nameOf(r.getPersonBId());
        Integer years = d.getYear() > 0 ? (year - d.getYear()) : null;
        return new AnniversaryItem(
                r.getId(),
                a + " & " + b,
                d.getDayOfMonth(),
                d.getMonthValue(),
                years);
    }

    private String nameOf(Long personId) {
        return personRepository.findById(personId)
                .map(p -> p.getFirstName()
                        + (p.getLastName() != null ? " " + p.getLastName() : ""))
                .orElse("?");
    }
}
