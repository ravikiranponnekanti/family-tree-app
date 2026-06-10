package com.familytree.app.insights;

import com.familytree.app.person.Person;
import com.familytree.app.person.PersonDtos.PersonResponse;
import com.familytree.app.person.PersonRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/insights")
@RequiredArgsConstructor
public class InsightsController {

    private final RelationshipFinderService relationshipFinder;
    private final BirthdayService birthdayService;
    private final PersonRepository personRepository;

    @GetMapping("/relationship")
    public RelationshipFinderService.RelationshipResult relationship(
            @RequestParam Long from, @RequestParam Long to) {
        return relationshipFinder.findRelationship(from, to);
    }

    @GetMapping("/birthdays")
    public List<BirthdayService.BirthdayItem> birthdays() {
        return birthdayService.upcomingThisMonth();
    }

    @GetMapping("/search")
    public List<PersonResponse> search(
            @RequestParam(required = false, defaultValue = "") String q,
            @RequestParam(required = false) String gender) {
        List<Person> results = q.isBlank()
                ? personRepository.findAll()
                : personRepository.searchByName(q);
        return results.stream()
                .filter(p -> gender == null || gender.isBlank()
                        || (p.getGender() != null
                            && p.getGender().name().equalsIgnoreCase(gender)))
                .map(PersonResponse::from)
                .toList();
    }
}
