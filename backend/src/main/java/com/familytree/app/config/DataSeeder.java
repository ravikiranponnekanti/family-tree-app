package com.familytree.app.config;

import com.familytree.app.auth.AppUser;
import com.familytree.app.auth.AppUserRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
public class DataSeeder {

    // Only seeds in the default (dev) profile, not in prod.
    @Bean
    @Profile("!prod")
    CommandLineRunner seedUser(AppUserRepository repo, PasswordEncoder encoder) {
        return args -> {
            if (!repo.existsByUsername("demo")) {
                repo.save(AppUser.builder()
                        .username("demo")
                        .password(encoder.encode("demo1234"))
                        .role("ROLE_USER")
                        .build());
                System.out.println(">> Seeded demo user: demo / demo1234");
            }
        };
    }
}
