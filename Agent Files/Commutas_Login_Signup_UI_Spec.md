# Commutas — Login & Signup Page UI Specification

**Source:** Commutas SRS, Module 1 — Identity, Authentication & Authorization
**Reference sections:** §9 (UI/UX Design System), §10.2–10.5 (Screen Specifications)
**Scope:** Student Signup (3 steps), Login (shared layout, all roles)

---

## 1. Design Tokens (per SRS §9.2–9.4)

These tokens are non-negotiable for both pages — every other visual decision derives from this table.

### 1.1 Color

| Token | Hex | Usage on these pages |
|---|---|---|
| Primary / Navy Ink | `#1A1B33` | Title bar, context strip, primary button fill, selected role chip |
| Primary Dark | `#0E0F1F` | Context strip, pressed-button state |
| Sage Tint | `#E7E9DE` | Disabled-section backgrounds |
| Accent (Cobalt) | `#3B4CCB` | Focus ring on inputs/buttons, links ("Forgot password?", "Create account") |
| Accent Dark | `#2935A0` | Link text default state |
| Ink (Text) | `#1A1B22` | Card titles, field values, button labels |
| Slate (Muted Text) | `#6B6F66` | Field labels, eyebrows, helper text |
| Line (Border) | `#B9BDAF` | 1.5px borders on every card, input, button, role chip |
| Surface | `#EDEFE3` | Page/app canvas background |
| Danger | `#B3261E` | Validation errors, lockout messages |
| Success | `#3D6B3D` | "Verified" badge (Step 3 of signup) |

### 1.2 Typography

| Token | Font / Weight | Size | Usage |
|---|---|---|---|
| App Title | JetBrains Mono, Bold | 22sp | "Commutas" in title bar |
| Context Strip Label | JetBrains Mono, Regular | 14sp | e.g. "Student Login", "Step 1 of 3" |
| Context Strip Meta | JetBrains Mono, Regular, +0.5 spacing, all caps | 12sp | Right-aligned, e.g. "SIGN IN", "STEP 1 OF 3" |
| Section Eyebrow | Inter, Medium, all caps, +1 spacing | 12sp | "WELCOME BACK", "STUDENT VERIFICATION" |
| Card Title | Inter, Bold | 20sp | "Sign in to your account" |
| Field Label | Inter, Regular | 15sp | "Registration No. or Email" |
| Field Value | Inter, Medium | 15sp | Text typed into inputs |
| Button Label | Inter, SemiBold, all caps, +0.5 spacing | 14sp | "SIGN IN", "CONTINUE", "CREATE ACCOUNT" |
| OTP Digit | JetBrains Mono, Medium | 22–24sp | 6-box OTP input (Step 2 of signup) |
| Identity Bar | Inter, Medium | 14sp | Bottom-fixed bar (post-auth screens only) |

### 1.3 Shape Rule (hard constraint)

> **Zero corner radius on every component.** Buttons, cards, inputs, OTP boxes, role chips, and badges are true rectangles — no rounded corners anywhere, per SRS §9.1 and §9.5.2.

### 1.4 Spacing (per SRS §9.4)

- Base unit: 4dp · Scale: 4 / 8 / 12 / 16 / 24 / 32
- Screen horizontal padding: 20dp
- Card internal padding: 20dp all sides
- Gap between stacked cards: 16dp
- Header: None (completely removed on pre-login/auth screens)
- Bottom identity bar: 56dp (pre-auth shows "COMMUTAS  •  CAMPUS TRANSPORT", post-auth shows active profile)

---

## 2. Page: Login (shared layout, all 3 roles) — SRS §10.5

### 2.1 Structure (top to bottom)

```
┌─────────────────────────────────────┐
│                                       │
│  [Student] [Vehicle]                 │ ← Tab switcher (rectangular, 2-up)
│                                       │
│  ┌─────────────────────────────┐    │
│  │           [LOGO]            │    │ ← Centered Brand Logo (70dp)
│  │                             │    │
│  │ WELCOME BACK                │    │ ← Section Eyebrow
│  │                             │    │
│  │ Sign in to your account      │    │ ← Card Title
│  │                             │    │
│  │ Registration No. or Email    │    │
│  │ [_____________________]      │    │
│  │                             │    │
│  │ Password                     │    │
│  │ [_____________________] 👁    │    │
│  └─────────────────────────────┘    │
│                                       │
│  Trouble signing in?  Forgot pass.?  │ ← row-between (helper + link)
│                                       │
│  [          SIGN IN          ]       │ ← Primary Button, full width
│                                       │
│  ─────────────  OR  ─────────────    │ ← divider
│                                       │
│  New student?  Create account        │ ← signup redirect link
│                                       │
├─────────────────────────────────────┤
│    COMMUTAS  •  CAMPUS TRANSPORT     │ ← Identity bar placeholder
└─────────────────────────────────────┘
```

### 2.2 Component Detail

**Role Indicator Row**
- 2 equal-width rectangular chips sharing borders edge-to-edge, 1.5px Line border
- Active chip (matches the role tapped on the prior Role Selector screen): navy fill, white text, 2px Accent-blue inset focus ring
- Inactive chips: white fill, Slate text

**Data Card**
- White fill, 1.5px Line border, 20dp padding
- Card Title: "Sign in to your account"
- Two stacked Text Input Fields per SRS §9.5.6:
  - Identifier field — label and placeholder vary by role:
    | Role | Label | Placeholder |
    |---|---|---|
    | Student | Registration No. or Email | `FA23-BCS-065` |
    | Vehicle | Vehicle Registration No. | `ABT-4471` |
  - Password field — type `password`, trailing eye-icon toggle, default hidden

**Input Field States**
| State | Border |
|---|---|
| Rest | 1.5px `#B9BDAF` |
| Focus | 2px `#3B4CCB` |
| Error | 1.5px `#B3261E` + 13sp Danger message beneath, left-aligned, no icon |

**Secondary Row (below card)**
- Left: plain Slate helper text, e.g. "Trouble signing in?"
- Right: Accent-blue underlined link "Forgot password?" (**Student only** — Vehicle shows static Slate text "Contact your administrator" instead, per AUTH-FR-023, since their resets are admin-issued)

**Primary Button**
- Full width, 52dp height, navy fill `#1A1B33`, white Button Label text, label "SIGN IN"
- Pressed state: fill darkens to `#0E0F1F`
- Disabled/lockout state: Sage-tint fill, Slate text, label replaced with countdown text e.g. "TRY AGAIN IN 04:58" (monospace) per AUTH-NFR-002

**Footer / Signup Redirect**
- Divider row: thin Line rule — "OR" (monospace, Slate) — thin Line rule
- "New student?" (Ink) + "Create account" (Accent-blue underlined link) → routes to Signup Step 1

**Identity Bar**
- Pre-authentication: fixed bottom bar, white fill, 1.5px top border, centered Slate text "COMMUTAS  •  CAMPUS TRANSPORT"
- Post-login: Bottom-fixed bar (56dp height, white fill, 1.5px top border) is visible showing "{Full Name}  {Registration No.}" per §9.5.9.

### 2.3 Validation Rules Applied Here (SRS §11)

| Field | Rule | Error shown |
|---|---|---|
| Registration No. | Format `FA\d{2}-[A-Z]{3}-\d{3}` | "Enter a valid registration number, e.g., FA23-BCS-065" |
| Password | Non-empty | "Enter your password" |
| Both (on submit) | Wrong credentials | Generic: "Incorrect identifier or password" — never reveals which field is wrong (AUTH-FR-015) |
| Both (after 5 fails) | Escalating lockout 1 / 5 / 30 min | "Too many attempts. Try again in {countdown}." |

---

## 3. Page: Student Signup — Step 1 of 3 (Identity) — SRS §10.2

### 3.1 Structure

```
┌─────────────────────────────────────┐
│                                       │
│  [Student] [Vehicle]                 │ ← Tab switcher (rectangular, 2-up)
│                                       │
│  ┌─────────────────────────────┐    │
│  │           [LOGO]            │    │ ← Centered Brand Logo (70dp)
│  │                             │    │
│  │ STUDENT VERIFICATION        │    │ ← Section Eyebrow
│  │                             │    │
│  │ Create student account      │    │ ← Card Title
│  │                             │    │
│  │ Registration No.              │    │
│  │ [FA23-BCS-065_________]      │    │
│  │                               │    │
│  │ Full Name                    │    │
│  │ [____________________]       │    │
│  │                               │    │
│  │ University Email             │    │
│  │ [____________________]       │    │
│  └─────────────────────────────┘    │
│                                       │
│  [          CONTINUE          ]      │ ← Primary Button (disabled until valid)
│                                       │
│  Already have an account?  Log in    │
├─────────────────────────────────────┤
│    COMMUTAS  •  CAMPUS TRANSPORT     │
└─────────────────────────────────────┘
```

### 3.2 Component Detail

- Single Data Card, three stacked Text Input Fields: Registration No., Full Name, University Email
- **CONTINUE** button: disabled (Sage-tint fill, Slate text) until all three fields pass validation (§11), enabled (navy fill) once valid
- Secondary link beneath button: "Already have an account? Log in" → routes to §2 Login

### 3.3 Field Validation (SRS §11)

| Field | Rule | Error shown |
|---|---|---|
| Registration No. | Format `FA\d{2}-[A-Z]{3}-\d{3}` | "Enter a valid registration number, e.g., FA23-BCS-065" |
| Full Name | 2–60 chars, letters/spaces/hyphens only | "Name should only contain letters and spaces" |
| University Email | Valid email format | "Enter a valid university email address" |

---

## 4. Page: Student Signup — Step 2 of 3 (Portal Verification) — SRS §10.3

### 4.1 Structure

```
┌─────────────────────────────────────┐
│  COMMUTAS                            │
├─────────────────────────────────────┤
│  Portal Check              STEP 2 OF 3│
├─────────────────────────────────────┤
│  ONE-TIME PORTAL VERIFICATION        │
│                                       │
│  ┌─────────────────────────────┐    │
│  │ COMSATS Portal Password      │    │
│  │ [____________________] 👁    │    │
│  └─────────────────────────────┘    │
│                                       │
│  ┌─────────────────────────────┐    │
│  │ ⚠ This password is used once │    │ ← Danger-bordered notice card
│  │   to verify your enrollment  │    │
│  │   and is discarded           │    │
│  │   immediately. It is never   │    │
│  │   saved.                     │    │
│  └─────────────────────────────┘    │
│                                       │
│  [          CONTINUE          ]      │ ← Loading state mid-verification
└─────────────────────────────────────┘
```

### 4.2 Component Detail

- Single password-type field, "COMSATS Portal Password", eye-icon toggle
- Inline notice card directly beneath: thin Danger-colored border (not full-saturation red fill — stays calm), Body Small text disclosing the one-time, never-stored nature of this credential (AUTH-NFR-004)
- **In-flight state:** Primary Button shows Loading (spinner replaces label, same button size — no layout shift); Context Strip right-meta temporarily changes to "VERIFYING…"
- **On failure:** Danger Toast below the context strip: "We couldn't verify this registration number. Check your number and portal password, then try again." Fields are not cleared.
- **On success:** auto-advance to Step 3 (no manual "next" tap required)

---

## 5. Page: Student Signup — Step 3 of 3 (Set App Password) — SRS §10.4

### 5.1 Structure

```
┌─────────────────────────────────────┐
│  COMMUTAS                            │
├─────────────────────────────────────┤
│  Secure Your Account        STEP 3 OF 3│
├─────────────────────────────────────┤
│  [✓ VERIFIED]                        │ ← Status Badge, Success style
│                                       │
│  ┌─────────────────────────────┐    │
│  │ Create Password              │    │
│  │ [____________________] 👁    │    │
│  │                               │    │
│  │ Confirm Password             │    │
│  │ [____________________] 👁    │    │
│  └─────────────────────────────┘    │
│                                       │
│  ✓ 8+ characters                     │ ← live checklist, turns
│  ✓ At least one letter               │   Slate → Success per rule
│  ✗ At least one digit                │
│                                       │
│  [        CREATE ACCOUNT        ]    │ ← disabled until all checks pass
└─────────────────────────────────────┘
```

### 5.2 Component Detail

- Status Badge "✓ VERIFIED" (rectangular, Success-green text, Sage-tint fill, 1px Success border) confirms Step 2 succeeded
- Two password fields: Create Password, Confirm Password — both with eye-icon toggles
- **Live password checklist** beneath the fields — plain text rows with leading check/cross glyph (no progress bar, per the flat instrumented style): "8+ characters" / "At least one letter" / "At least one digit" — each row turns from Slate to Success the instant its rule is met
- **CREATE ACCOUNT** button: disabled until both passwords match AND all three checklist rules are Success
- **On success:** navigates directly into the Student Dashboard — no separate "success" interstitial screen, consistent with the system's flat, no-frills transition style. The bottom identity bar becomes visible immediately, showing the new account's name and registration number.

### 5.3 Field Validation (SRS §11)

| Field | Rule | Error / message |
|---|---|---|
| Create Password | 8+ chars, ≥1 letter, ≥1 digit (AUTH-NFR-001) | Live checklist; on submit failure: "Password must be at least 8 characters with a letter and a number" |
| Confirm Password | Must exactly match Create Password | "Passwords do not match" |

---

## 6. Cross-Page Notes

- Pre-login pages exclude the header entirely, showing only the logo and forms inside a single compact page structure; post-login dashboards utilize a persistent brand Title Bar.
- All buttons, inputs, cards, and badges across all four pages use the same **zero-radius rectangle rule** — no exceptions.
- The **Accent-blue focus ring** (`#3B4CCB`, 2px) is the *only* color used to indicate focus/selection across inputs, buttons, and role chips — kept deliberately singular so it reads as one consistent signal throughout the flow.
- No drop shadows or elevation anywhere — depth is communicated only through the 1.5px Line border, per SRS §9.1.
- Client-side validation (shown above) mirrors backend validation exactly; the backend is always the authoritative check (per SRS §11 preamble — the mobile client is not a trusted boundary).

---

## 7. Page: Splash Screen

### 7.1 Structure
- Centered brand logo `logo_theme_transparent.png` (medium size, `height: 160`) against a clean canvas background (`#EDEFE3`).
- Large monospace title `'COMMUTAS'` (`24sp`) and helper subtitle `'CAMPUS TRANSPORT WALLET'` (`11sp`) centered beneath the logo.
- Interactive Behavior: Automatically redirects to the Login/Signup page after a 2.5-second timer.
