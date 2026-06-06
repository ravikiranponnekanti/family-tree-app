# Family Tree App

A free, full-stack family tree application.

- **Backend:** Java 17 + Spring Boot 3 (modular monolith — `person` and `relationship` modules)
- **Mobile:** Flutter (Android / iOS)
- **Database:** H2 (local dev) / PostgreSQL (production, free on Supabase or Neon)
- **Hosting:** Render free tier (backend), GitHub (code + CI)

> Note: This started as a "microservices" idea. For a family-scale app a **modular monolith**
> gives the same structure with far less operational overhead. The package layout keeps modules
> cleanly separated, so it can be split into microservices later if ever needed.

## Project structure

```
family-tree-app/
├── backend/                 # Spring Boot API
│   ├── src/main/java/com/familytree/app/
│   │   ├── person/           # Person entity, repo, service, controller, DTOs
│   │   ├── relationship/     # Spouse/partner relationships
│   │   ├── common/           # Exceptions + global error handler
│   │   ├── config/           # CORS config
│   │   └── FamilyTreeApplication.java
│   ├── src/main/resources/
│   │   ├── application.properties        # H2 local dev
│   │   └── application-prod.properties    # PostgreSQL prod
│   ├── Dockerfile
│   └── pom.xml
├── mobile/                  # Flutter app
│   └── lib/
│       ├── models/           # Person model
│       ├── services/         # API client
│       └── screens/          # Home, detail, form
├── .github/workflows/       # CI
└── render.yaml              # Deploy blueprint
```

## API endpoints

| Method | Path                          | Auth | Description            |
|--------|-------------------------------|------|------------------------|
| POST   | `/api/auth/register`          | No   | Create account, returns JWT |
| POST   | `/api/auth/login`             | No   | Log in, returns JWT    |
| GET    | `/api/persons`                | Yes  | List all people        |
| GET    | `/api/persons/{id}`           | Yes  | Get one person         |
| GET    | `/api/persons/{id}/children`  | Yes  | List a person's children |
| POST   | `/api/persons`                | Yes  | Create a person        |
| PUT    | `/api/persons/{id}`           | Yes  | Update a person        |
| DELETE | `/api/persons/{id}`           | Yes  | Delete a person        |
| GET    | `/api/relationships`          | Yes  | List relationships     |
| POST   | `/api/relationships`          | Yes  | Create a relationship  |

All `/api/persons` and `/api/relationships` routes require an
`Authorization: Bearer <token>` header. Get a token from register or login.

**Demo login (dev only):** `demo` / `demo1234` (auto-seeded on startup).

## Features

- **JWT auth:** register/login, BCrypt password hashing, stateless token auth.
  Set `JWT_SECRET` (>= 32 chars) as an env var in production.
- **Visual tree view:** tap the tree icon in the app bar. People are laid out by
  generation with parent→child connector lines; pinch to zoom, drag to pan, tap a
  node to open details. Assign parents in the add/edit form to build the graph.

## Prerequisites

- JDK 17+
- Maven 3.9+
- Flutter SDK 3+
- Git + a GitHub account

---

## Part 1 — Run the backend locally

```bash
cd backend
mvn spring-boot:run
```

The API starts on `http://localhost:8080`. It uses in-memory H2 by default (no DB setup).
H2 console: `http://localhost:8080/h2-console` (JDBC URL: `jdbc:h2:mem:familytree`, user `sa`).

Test it:

```bash
curl -X POST http://localhost:8080/api/persons \
  -H "Content-Type: application/json" \
  -d '{"firstName":"John","lastName":"Doe","gender":"MALE","birthDate":"1950-01-01"}'

curl http://localhost:8080/api/persons
```

## Part 2 — Run the Flutter app

```bash
cd mobile
flutter pub get
flutter create .          # generates android/ ios/ platform folders
flutter run
```

Set `baseUrl` in `lib/services/api_service.dart`:
- Android emulator → `http://10.0.2.2:8080/api`
- iOS simulator → `http://localhost:8080/api`
- Physical device → `http://<your-computer-LAN-IP>:8080/api`

---

## Part 3 — Put it on GitHub (step by step)

1. Create a repo at github.com named `family-tree-app` (don't initialize with README — we have one).
2. From the project root:

```bash
git init
git add .
git commit -m "Initial commit: Spring Boot backend + Flutter app"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/family-tree-app.git
git push -u origin main
```

3. The CI workflow (`.github/workflows/backend-ci.yml`) builds the backend on every push.

## Part 4 — Free PostgreSQL (Supabase or Neon)

1. Sign up at supabase.com (or neon.tech) — free tier.
2. Create a project, open the database connection settings.
3. Note the JDBC URL, username, and password. JDBC form looks like:
   `jdbc:postgresql://HOST:5432/DBNAME`

## Part 5 — Deploy backend free (Render)

1. Sign up at render.com, connect your GitHub.
2. New → Blueprint → select this repo (it reads `render.yaml`).
3. In the service's Environment settings, fill:
   - `DATABASE_URL` = your JDBC URL from Part 4
   - `DATABASE_USERNAME`
   - `DATABASE_PASSWORD`
4. Deploy. You'll get a URL like `https://family-tree-backend.onrender.com`.
   (Free tier sleeps after inactivity; first request after idle is slow.)
5. Update the Flutter `baseUrl` to the deployed URL.

## Part 6 — Build the mobile app for distribution (free)

```bash
cd mobile
flutter build apk --release        # Android APK you can share directly
```

Distribute the APK directly or via a free track. (Google Play has a one-time $25 fee;
Apple's App Store requires a $99/yr account — both optional. Direct APK sharing is free.)

## Roadmap ideas

- Auth (Spring Security + JWT)
- Photo upload (Supabase Storage — free)
- Visual tree graph view in Flutter
- Search and filtering

## License

MIT
