# Commutas App — Comprehensive Widget, Functionality & Navigation Guide

This document provides a detailed, file-by-file breakdown of the entire **Commutas** codebase. For each file, we cover its **detailed functionality**, the specific **widgets** used to build it, and the **navigation/routing** systems it implements.

---

## 1. App Root & Navigation Hub

### `lib/main.dart`
* **Functionality**:
  - App entry point (`main()` function) initializing Flutter bindings.
  - Asynchronously initializes **Firebase Core** for handling live database configurations and push notifications.
  - Wraps the entire application inside the base `MaterialApp`.
* **Widgets & UI Architecture**:
  - `MyApp` (`StatelessWidget`): Root widget setting up the global theme and title.
  - `MaterialApp`: Provides the core material design layout, debug banner configuration, and base configurations.
* **Navigation & Routing**:
  - Configures `navigatorKey` as a global `GlobalKey<NavigatorState>` to facilitate navigation without context if needed.
  - Sets the initial route/home screen to `SplashScreen()` (`home: const SplashScreen()`).
  - Implements the custom design theme via `CommutasThemes.lightTheme` defined in `theme.dart`.

### `lib/screens/main_screen.dart`
* **Functionality**:
  - Serves as the main shell or layout frame after login.
  - Dynamically switches user layouts between **Student Mode** and **Vehicle (Driver/Conductor) Mode** depending on the role saved during session initialization.
  - Prevents screens from rebuilding when switching tabs to preserve inputs and scrolled lists.
* **Widgets & UI Architecture**:
  - `IndexedStack`: Holds the list of screens in memory, swapping visible child indices using `_selectedIndex` without destroying their local state.
  - `SafeArea`: Ensures bottom navigation layout avoids device hardware cutouts.
  - `GestureDetector`: Handles click inputs for navigation tab changes.
  - Custom bottom nav layout structured using `Row`, `Container`, `Column`, `Icon`, `Text`, and custom borders.
  - Dedicated custom pay indicator (`_buildNfcNavItem`) using a square container decoration.
* **Navigation & Routing**:
  - **Student Views Routing**: Switches between `HomeScreen`, `ScheduleScreen`, `NFCPayScreen`, `WalletScreen`, and `ProfileScreen`.
  - **Vehicle Views Routing**: Switches between `VehicleHomeScreen`, `VehicleMapScreen`, `VehiclePaymentCheckScreen`, `VehicleHistoryScreen`, and `VehicleProfileScreen`.
  - Passing arguments (e.g., studentName, registration numbers, session variables, initial avatars) directly down to child widgets.

---

## 2. Authentication & Setup Flow

### `lib/screens/splash_screen.dart`
* **Functionality**:
  - Displays the initial visual branding logo.
  - Evaluates saved session tokens and active user records in `SharedPreferences` to determine if a login session is already active.
* **Widgets & UI Architecture**:
  - `FadeTransition` & `AnimationController`: Animates the opacity of the logo on screen startup over a 1200ms duration.
  - `Image.asset`: Renders the transparent themed logo asset.
  - `_ThreeDotLoader` (`StatefulWidget`): An animated bouncing horizontal dots loader utilizing a custom `Matrix4.translationValues` transition combined with a sine wave function (`math.sin`) to calculate vertical offsets.
* **Navigation & Routing**:
  - Uses `Timer` to hold the splash layout for 2500ms.
  - Uses `Navigator.of(context).pushReplacement` with a custom `PageRouteBuilder` that executes a `FadeTransition` transition animation of 800ms duration.
  - Routes to `MainScreen` (if session token is found and active) or `LoginSignupScreen` (if no session exists).

### `lib/screens/login_signup_screen.dart`
* **Functionality**:
  - Handles the dual input flows for logging in or signing up.
  - Interacts with `AuthService` to register students on the portal or authenticate user credentials.
  - Manages validation logic (like password safety, length rules, matching confirmations, roll number formats, and terms validation).
  - Handles lockout timers for failed login attempts (e.g., locking input after 5 failed attempts for 60 seconds).
  - Uses `BiometricService` to authenticate with biometric fingerprints/face recognition.
* **Widgets & UI Architecture**:
  - `SingleChildScrollView`: Allows content to be scrolled when the soft keyboard appears.
  - `TextFormField` & `InputDecoration`: Customized input fields using `CommutasShapes` border configurations.
  - Custom Dropdowns: Dropdowns constructed using lists of sessions and departments to format registration entries (e.g. `FA23`, `BCS`).
  - `RichText` & `TapGestureRecognizer`: Embeds clickable links inside standard text paragraphs (e.g., Terms & Conditions and Privacy Policy links).
  - `_AnimatedHeader`: Uses custom painters to create visual backgrounds.
  - `_MarqueeText`: Horizontal scrolling message board ticker.
* **Navigation & Routing**:
  - Swaps states internally using simple boolean flags (`_isRegisterTab`) to display register or login forms.
  - Pushes `VerificationScreen` upon registration requests.
  - Transitions to `MainScreen` on success via `Navigator.pushReplacement` with a standard `MaterialPageRoute`.
  - Opens external website URLs (e.g., terms policy pages) in the browser using `url_launcher`.
  - Pushes `ResetPasswordScreen` when the user clicks "Forgot Password".

### `lib/screens/verification_screen.dart`
* **Functionality**:
  - Communicates with the student enrollment API in the background.
  - Displays a visual registration/password-reset verification card while showing dynamic status progress.
* **Widgets & UI Architecture**:
  - `AnimationController`: Operates timing for average network delays (8-second average time animation).
  - Custom Bus Progress: An animated bus indicator that travels horizontally across the progress line as verification proceeds.
  - Custom painters for drawing abstract status indicators.
* **Navigation & Routing**:
  - Backed by `AuthService` to run asynchronous registration or reset methods.
  - Pushes replacement screen `LoginSignupScreen` on back navigation or upon verification completion/error.

### `lib/screens/reset_password_screen.dart`
* **Functionality**:
  - Allows users to change their account password.
  - Validates portal credentials against department/session lists.
* **Widgets & UI Architecture**:
  - Custom dropdowns and password fields with obscurity controls (`obscureText: true`).
  - Validation error popups utilizing animated opacity alerts.
* **Navigation & Routing**:
  - Calls verification API by pushing `VerificationScreen` with `isReset: true` parameter.
  - Navigates back using `Navigator.pop(context)`.

---

## 3. Student Features

### `lib/screens/home_screen.dart`
* **Functionality**:
  - Represents the central workspace for student riders.
  - Displays active balance, quick links, active notifications, and details about the next scheduled bus ride.
  - Refreshes wallet balances dynamically by making checks with `WalletService`.
* **Widgets & UI Architecture**:
  - `Scaffold` & `AppBar`: Structural setup with action notifications icon.
  - `SingleChildScrollView` & `Column`: Organizes components vertically.
  - Custom Wallet Card (`_buildCombinedHeaderWalletCard`): Highlights current balance, student profile emoji, and a transaction status warning if needed.
  - Dynamic NFC Card (`_buildNfcPaymentCard`): Custom action component containing bus navigation details and shortcut pay buttons.
  - Bus Tracking Simulator: Renders progress trackers and bus animation routes.
  - `_AddFundsSheet` (`StatefulWidget`): Bottom modal sheet layout containing deposit simulators.
* **Navigation & Routing**:
  - Opens `_AddFundsSheet` using `showModalBottomSheet(isScrollControlled: true)`.
  - Redirects users directly to specific tabs on `MainScreen` (such as the NFC or Wallet tabs) by updating parent parameters.

### `lib/screens/schedule_screen.dart`
* **Functionality**:
  - Lists campus transport schedules segregated by ride sessions (morning vs evening).
* **Widgets & UI Architecture**:
  - `TabBar` & `TabController`: Segment selectors representing session tabs.
  - `TabBarView`: Houses pages for `_buildMorningSchedule()` and `_buildEveningSchedule()`.
  - `ListView` & `_buildScheduleCard`: Scrollable card widgets showing departures, destinations, and recommended routes with distinct shapes.
* **Navigation & Routing**:
  - Controlled by tab controllers internally. No external push routing is registered here.

### `lib/screens/nfc_pay_screen.dart`
* **Functionality**:
  - Displays Host Card Emulation (HCE) payment simulator.
  - Displays transaction states and logs for security verification.
* **Widgets & UI Architecture**:
  - Concentric square indicators matching the theme.
  - Status Indicators: Colored banners displaying device NFC status and connection stability.
  - Transaction History Cards: Summary card displaying details (e.g. Route Fare and transaction amount).
* **Navigation & Routing**:
  - Purely informational screen designed as an independent page inside the navigation stack.

### `lib/screens/wallet_screen.dart`
* **Functionality**:
  - Detailed wallet ledger showing current balance, historical credit/debit logs, and digital receipts.
  - Initiates payment options (Credit Card / Top-Up systems) with form fields and loading verification spinners.
* **Widgets & UI Architecture**:
  - Custom Card background animations (`_bgController` controls gradients).
  - Scrollable transactions list using custom transaction cards.
  - `_TopUpSheet`: Implements custom keyboard listener controllers, text form layouts, dynamic currency filters, and OTP confirmation codes panels.
* **Navigation & Routing**:
  - Uses `showModalBottomSheet` for custom transaction receipts or top-up payment checkout sheets.
  - Dynamically triggers callback operations (`onPaymentInitiated()`) to update home screen values.

### `lib/screens/profile_screen.dart`
* **Functionality**:
  - Student profile customization interface.
  - Settings for user notification settings, changing login passwords, and modifying avatars.
* **Widgets & UI Architecture**:
  - Emoji selection grids (`GridView.builder`) for custom avatars.
  - `SwitchListTile`: Toggle switches for managing biometrics and push notifications.
  - `ListTile`: Links to configure credentials or log out.
* **Navigation & Routing**:
  - Pushes `ResetPasswordScreen` when changing passwords.
  - Pushes `LoginSignupScreen` on logout using `Navigator.pushAndRemoveUntil` to completely clear the navigation stack.
  - Uses `image_picker` package to open the native photo gallery.

---

## 4. Vehicle Features (Driver/Conductor View)

### `lib/screens/vehicle/vehicle_home_screen.dart`
* **Functionality**:
  - Main operational display for drivers/conductors.
  - Displays calculations for cumulative daily earnings and passenger counts.
  - Toggles driver modules like location tracking (GPS) and active route switches.
* **Widgets & UI Architecture**:
  - Analytics boxes structured using custom cards and grid layouts.
  - Switch controls for managing active GPS tracking.
* **Navigation & Routing**:
  - Swaps states using internal listeners. Provides shortcuts to open vehicle details.

### `lib/screens/vehicle/vehicle_map_screen.dart`
* **Functionality**:
  - Displays active bus routes, turn-by-turn navigation lists, and simulated GPS telemetry data.
* **Widgets & UI Architecture**:
  - Customized direction panels showing meters, street steps, and stops.
  - Turn-by-turn instruction cards inside vertical lists.
  - Directional compass graphics.
* **Navigation & Routing**:
  - Custom interactive dropdown fields to swap between assigned campus routes.

### `lib/screens/vehicle/vehicle_payment_check_screen.dart`
* **Functionality**:
  - Conductor's interface to scan and validate student tickets.
  - Displays transaction logs, validation errors (e.g., insufficient funds), and success confirmations.
* **Widgets & UI Architecture**:
  - Wave pulse indicators surrounding the active scan button.
  - Scanned passenger logs displaying lists of students verified on the current trip.
* **Navigation & Routing**:
  - Triggers modal dialogs and dynamic overlays on successful or failed scans.

### `lib/screens/vehicle/vehicle_history_screen.dart`
* **Functionality**:
  - Displays a comprehensive logs table of all scanned digital tickets, student names, reg numbers, and status indicators.
* **Widgets & UI Architecture**:
  - Segmented list structures with clear date filters.
* **Navigation & Routing**:
  - Designed as an independent tab inside `MainScreen`.

### `lib/screens/vehicle/vehicle_profile_screen.dart`
* **Functionality**:
  - Displays bus registration numbers, vehicle model specifications, fuel stats, and operations information.
* **Widgets & UI Architecture**:
  - Structured information grids.
* **Navigation & Routing**:
  - Pushes `LoginSignupScreen` on logout using `Navigator.pushAndRemoveUntil` to clear active states and routes.

---

## 5. Shared Custom Components

### `lib/widgets/transit_loader.dart`
* **Functionality**:
  - Stylized card checking component used during login, registration, and loading states.
  - Shows shifting text statuses (e.g., "Connecting to COMSATS Portal...", "Verifying enrollment status...") to keep the user engaged.
* **Widgets & UI Architecture**:
  - `CustomPaint` & `_MinimalCardPainter`: Draws a stylized transit card with a card chip and custom pulsing circular beacons.
  - `AnimatedSwitcher`: Animates text transitions.
  - Linear Progress Indicator: Custom progress bar styled without rounding.
* **Navigation & Routing**:
  - Embedded as a sub-widget inside parent page frameworks.

---

## Summary of Navigation Patterns Used

| Navigation Code pattern | Description / Use Case | File Examples |
|---|---|---|
| `Navigator.pushReplacement` | Swaps out active screen (like login) to load the main dashboard shell, removing the original screen from the history stack. | `splash_screen.dart`, `login_signup_screen.dart` |
| `Navigator.pushAndRemoveUntil` | Clears all historical routes and loads a clean screen (used on Logout). | `profile_screen.dart`, `vehicle_profile_screen.dart` |
| `showModalBottomSheet` | Opens interactive overlay cards from the bottom (used for Payment sheets and detailed digital receipts). | `home_screen.dart`, `wallet_screen.dart` |
| `IndexedStack` | Keeps child pages loaded in memory and swappable through bottom navigation index switches. | `main_screen.dart` |
| `PageRouteBuilder` with `FadeTransition` | Creates custom smooth fade animations when transitioning between pages. | `splash_screen.dart` |
