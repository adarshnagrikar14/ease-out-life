# Ease Out Life

Ease Out Life is a unified AI life-load assistant designed for working women.
It combines:
- Smart daily routine (timetable) that adapts to energy level + feedback
- Meal tracking (manual + photo scan) with nutrition calculation
- Grocery planning (day-wise list) from selected Indian dishes
- Professional task prioritization (AI recommends what to do now)
- Optional Google Calendar sync for the timetable

The UI is intentionally minimal and low-effort: users mainly provide a few inputs (energy, meal selections, tasks), and the app handles the rest using AI + local storage.

---

## High-level Architecture
- UI Screens: `lib/screens/*`
- AI/External Services:
  - `lib/services/gemini_service.dart` (Gemini text + vision)
  - `lib/services/food_service.dart` (OpenFoodFacts + Gemini fallback)
  - `lib/services/calendar_service.dart` (Google Calendar sync)
- Auth & Calendar permission: `lib/services/auth_service.dart`
- Local persistence (offline-friendly): `lib/services/storage_service.dart`

---

## 1) Auth and Firebase Flow
Files:
- `lib/main.dart` (`AuthGate`)
- `lib/screens/login_screen.dart`
- `lib/screens/signup_screen.dart`
- `lib/screens/calendar_permission_screen.dart`
- `lib/services/auth_service.dart`

### Auth Gate
`AuthGate` listens to `FirebaseAuth.instance.authStateChanges()`:
- If signed in -> shows `AppShell`
- If signed out -> shows `LoginScreen`

### Email/Password Sign-in + Sign-up
- Sign in: `AuthService.signInWithEmail()`
- Sign up: `AuthService.signUpWithEmail()`
- Sign-up updates the Firebase display name (`updateDisplayName`)

### Google Sign-in
- Google sign-in is handled by `AuthService.signInWithGoogle()`
- Google sign-in cancellation is handled by `AuthCancelledException`

### Calendar Permission Screen
After auth success, users are navigated to `CalendarPermissionScreen`:
- It calls `AuthService.requestCalendarPermission()`
- If denied, a snackbar is shown, but the user can proceed with "Skip for now"

---

## 2) Home Timetable (Smart Routine)
File: `lib/screens/home_screen.dart`
AI: `lib/services/gemini_service.dart`
Storage: `lib/services/storage_service.dart`

### Inputs
- Selected date (via date picker)
- Energy level (1 to 5)
- Feedback history (saved from the feedback section)

### Outputs
- A full day timetable made of time slots from the AI
- Cached locally per date for fast reload

### Timetable generation and caching
On load or energy change:
1. Try cache:
   - `StorageService.getTimetable(dateKey)`
2. If missing:
   - `GeminiService.generateTimetable(date, dayOfWeek, energyLevel, feedbackHistory)`
3. Save:
   - `StorageService.saveTimetable(timetable)`

### Timetable editing
Low-effort editing:
- Tap any slot -> edit activity and category
- Supported categories:
  - `work, meal, exercise, break, selfcare, household, personal, health, learning`
- Save persists locally:
  - `StorageService.saveTimetable(updated)`

### Feedback loop
The feedback section at the bottom:
- Rating (1..5)
- Comment
- Saved to:
  - `StorageService.saveFeedback(DayFeedback)`
- Next timetable generation sends feedback context into Gemini:
  - `StorageService.getFeedbackHistory()`

---

## 3) Google Calendar Sync (Only from Home)
Files:
- `lib/screens/home_screen.dart` (sync button in header)
- `lib/services/calendar_service.dart`
- `lib/services/auth_service.dart` (calendar scope + session recovery)

### What sync does
- Converts the timetable into 1-hour events (one event per slot)
- Each event is tagged so the app can delete and re-create on re-sync:
  - Event summary prefix: `[EOL] `
- Before creating new events:
  - it deletes previously inserted tagged events for that day

### Category -> Event color
`CalendarService` maps timetable categories to Google Calendar color IDs.

### Access recovery (important)
`AuthService.ensureCalendarAccess()`:
- Tries to restore Google session silently using `signInSilently()`
- Falls back to interactive `signIn()` if needed
- Requests calendar scopes if missing
- Returns an authenticated `CalendarApi` client to `CalendarService`

---

## 4) Meal Tracking (Nutrition + Macros)
File: `lib/screens/meal_planning_screen.dart`
Nutrition engine: `lib/services/food_service.dart`
Gemini fallback: `GeminiService`
Storage: `lib/services/storage_service.dart`

### Manual meal entry
User enters:
- Dish name
- Meal type: `breakfast, lunch, dinner, snack`

Processing:
1. `FoodService.analyzeMeal(dishName, mealType)`
2. `FoodService.searchFood()` uses OpenFoodFacts first
3. If no match (or OFF fails), it falls back to Gemini:
   - `GeminiService.analyzeMealByName()`

Saved locally:
- `StorageService.addMeal(dateKey, MealEntry)`

### Photo-based meal scan
User picks image:
- camera or gallery (image picker)

Processing:
- `FoodService.analyzePhoto()` delegates to Gemini Vision:
  - `GeminiService.analyzeMealByPhoto()`

Saved locally:
- `StorageService.addMeal(dateKey, meal)`

### Outputs shown in UI
- Meals list
- Macro summary chips:
  - kcal, protein, carbs, fat
- Each meal includes nutrition values + source (`openfoodfacts` or `manual/photo`)

### Delete
- `StorageService.removeMeal(dateKey, mealId)`

---

## 5) Grocery Tracking (Day-wise list)
File: `lib/screens/grocery_screen.dart`
AI: `GeminiService.generateGroceryList()`
Storage: `StorageService.saveGroceryList()`

### User inputs
4 dropdowns (separate):
- Breakfast dish
- Lunch dish
- Dinner dish
- Snack dish
Plus week navigation and a day filter (chips).

### Output
When pressing "Generate grocery list":
- Gemini generates a JSON array of grocery items:
  - `name, quantity, category, forMealType, forDay`
- The screen wraps it as `WeeklyGroceryList` and saves:
  - `StorageService.saveGroceryList(list)`

### Day filter
- Filters by `forDay` with case-insensitive matching and 3-letter prefix matching
- Each day chip shows an item count so the user sees distribution

### Checklist behavior
- Tap a grocery item -> toggles bought/unbought
- Persisted immediately to local storage

---

## 6) Tasks (AI prioritization)
Files:
- `lib/screens/tasks_screen.dart`
- `lib/services/gemini_service.dart` (generateSmartPlan)
- `lib/models/task_model.dart`
- `lib/services/storage_service.dart`

### User inputs to create tasks
Add Task bottom sheet collects:
- Task name
- Optional deadline ("When")
- Estimated time (15m to 3h+)
- Category (work/personal/health/learning/household/errands)

Saved locally:
- `StorageService.saveTasks(List<TaskItem>)`

### AI planning output (dynamic)
Gemini output is a strict JSON contract:
- `tasks`: categorized as:
  - `focus_now` (do now)
  - `up_next` (do next)
  - `later` (can wait)
- `suggestions`: 1-2 adaptive suggestions
- `insights`:
  - productivity score
  - focused time
  - trend
  - topInsight

UI renders only headings + results:
- Focus now
- Up next
- Later
- One concise insights card

### Completion & auto rescheduling
- Checkmark -> task marked `completed` with `completedAt`
- Swipe to delete -> removed
- After any change, the screen auto refreshes planning
- Overdue tasks are prioritized as `focus_now` by the planner logic/JSON mapping

---

## Local Data Storage (SharedPreferences)
File: `lib/services/storage_service.dart`

Keys:
- Timetable: `timetable_<dateKey>`
- Feedback history: `feedback_history`
- Energy: `energy_level`
- Meals: `meals_<dateKey>`
- Grocery: `grocery_<weekKey>`
- Tasks: `user_tasks`
- Smart plan: `smart_plan_<dateKey>`

---

## Environment Variables (.env) for Gemini
Files:
- `.env` (project root)
- `lib/main.dart` loads it via `flutter_dotenv`
- `lib/services/gemini_service.dart` reads `dotenv.env['GEMINI_API_KEY']`
- `.gitignore` excludes `.env` so secrets are not committed

---

## Android Permissions (Required for MVP)
File: `android/app/src/main/AndroidManifest.xml`
- `INTERNET`
- `CAMERA`
- Storage/media read permissions for `image_picker`
- Intent query permissions for image capture / selection

---

## Gemini JSON Contracts (Predictable UI)
Gemini is asked to output JSON only, so parsing is reliable:
- Timetable (JSON object):
  - `{ date, energyLevel, slots:[{time, activity, category}] }`
- Grocery list (JSON array):
  - `[{ name, quantity, category, forMealType, forDay }]`
- Smart tasks plan (JSON object):
  - `{ tasks:[...], suggestions:[...], insights:{...} }`

---

## Error Handling Strategy
- Meal/Grocery/Sync failures surface via `SnackBar`
- Timetable generation falls back to an internal local timetable if Gemini fails
