package com.familytree.app.insights;

import com.familytree.app.person.Person;
import com.familytree.app.person.PersonRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.Comparator;
import java.util.List;

@Service
@RequiredArgsConstructor
public class BirthdayService {

    private final PersonRepository repository;

    public record BirthdayItem(Long id, String name, String photoUrl,
                               int day, int month, Integer turningAge) {}

    /** People with a birthday in the current month, sorted by day. Skips deceased. */
    @Transactional(readOnly = true)
    public List<BirthdayItem> upcomingThisMonth() {
        int month = LocalDate.now().getMonthValue();
        int year = LocalDate.now().getYear();
        return repository.findAll().stream()
                .filter(p -> p.getBirthDate() != null)
                .filter(p -> p.getDeathDate() == null)
                .filter(p -> p.getBirthDate().getMonthValue() == month)
                .map(p -> toItem(p, year))
                .sorted(Comparator.comparingInt(BirthdayItem::day))
                .toList();
    }

    private BirthdayItem toItem(Person p, int year) {
        LocalDate bd = p.getBirthDate();
        Integer age = bd.getYear() > 0 ? (year - bd.getYear()) : null;
        return new BirthdayItem(
                p.getId(),
                p.getFirstName() + (p.getLastName() != null ? " " + p.getLastName() : ""),
                p.getPhotoUrl(),
                bd.getDayOfMonth(),
                bd.getMonthValue(),
                age);
    }
}
