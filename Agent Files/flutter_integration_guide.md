# Commutas — Flutter Integration Guide

> **Document Purpose**: This is the **single source of truth** for the Flutter development agent. Every endpoint, payload, header, error code, and architectural decision documented here is derived directly from the finalized backend implementation. No guessing — follow this document exactly.

---

## Table of Contents

1. [Server Connection](#1-server-connection)
2. [Authentication — Student App](#2-authentication--student-app)
3. [Wallet Module](#3-wallet-module)
4. [Bus Routes & Schedules](#4-bus-routes--schedules)
5. [Live Bus Tracking (REST + WebSocket)](#5-live-bus-tracking-rest--websocket)
6. [NFC Fare Payment — Host Card Emulation](#6-nfc-fare-payment--host-card-emulation)
7. [Push Notifications — Firebase FCM](#7-push-notifications--firebase-fcm)
8. [Vehicle/Driver App Integration](#8-vehicledriver-app-integration)
9. [Error Handling Contract](#9-error-handling-contract)
10. [Required Flutter Dependencies](#10-required-flutter-dependencies)
11. [Android Manifest Configuration](#11-android-manifest-configuration)
12. [Appendix: Complete JSON Payload Reference](#appendix-complete-json-payload-reference)

---

## 1. Server Connection

| Property | Value |
|---|---|
| **Base URL** | To be configured per environment (e.g. `https://commutas-server.onrender.com`) |
| **Protocol** | HTTPS for REST, WSS for WebSocket |
| **Content-Type** | `application/json` for all requests |
| **Auth Scheme** | `Bearer` token in `Authorization` header |
| **Health Check** | `GET /` → `{"status":"ok","service":"Commutas API","version":"0.1.0"}` |

> [!IMPORTANT]
> All authenticated endpoints expect the header: `Authorization: Bearer <jwt_token>`.
> The server uses `HTTPBearer` scheme from FastAPI — do NOT send the token as a query parameter.

---

## 2. Authentication — Student App

The student app has its own isolated authentication flow. Tokens carry no `role` claim (implicit student identity). Vehicle tokens carry `role: "vehicle"` and are **explicitly rejected** by all student endpoints.

### 2.1 Register Student

Creates a new student account. The server verifies the student's identity against the COMSATS university portal before registration.

```
POST /auth/register
Content-Type: application/json
(No Authorization header required)
```

**Request Body:**
```json
{
  "reg_no": "FA23-BCS-065",
  "portal_password": "student_portal_password",
  "app_password": "commutas_app_password"
}
```

**Validation Rules:**
- `reg_no`: Must match pattern `XX00-XXX-000` (e.g. `FA23-BCS-065`). Auto-uppercased and trimmed.
- `app_password`: Must be 8–32 characters.
- `portal_password`: The student's actual COMSATS portal password. Used ONLY for verification, never stored.

**Success Response (201):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "token_type": "bearer",
  "student": {
    "reg_no": "FA23-BCS-065",
    "full_name": "MUHAMMAD MUBASHAR"
  }
}
```

**Error Responses:**

| Status | Condition | Detail |
|---|---|---|
| `409` | Already registered | `"An account with this registration number already exists. Please log in."` |
| `401` | Bad portal creds | `"Portal verification failed."` or specific portal error |
| `422` | Validation fail | Pydantic validation error (bad reg_no format, password too short) |

---

### 2.2 Login Student

```
POST /auth/login
Content-Type: application/json
(No Authorization header required)
```

**Request Body:**
```json
{
  "reg_no": "FA23-BCS-065",
  "app_password": "commutas_app_password"
}
```

**Success Response (200):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "token_type": "bearer",
  "student": {
    "reg_no": "FA23-BCS-065",
    "full_name": "MUHAMMAD MUBASHAR"
  }
}
```

**Error Responses:**

| Status | Condition | Detail |
|---|---|---|
| `404` | Student not found | `"No account found with this registration number."` |
| `401` | Wrong password | `"Incorrect password."` |

---

### 2.3 Get Current Profile

```
GET /auth/me
Authorization: Bearer <student_jwt>
```

**Success Response (200):**
```json
{
  "reg_no": "FA23-BCS-065",
  "full_name": "MUHAMMAD MUBASHAR"
}
```

---

### 2.4 Reset Password

Requires portal re-verification (proving identity through COMSATS portal).

```
POST /auth/reset-password
Content-Type: application/json
(No Authorization header required)
```

**Request Body:**
```json
{
  "reg_no": "FA23-BCS-065",
  "portal_password": "portal_pass",
  "new_password": "new_app_pass_8chars"
}
```

**Success Response (200):**
```json
{
  "detail": "Password has been reset successfully."
}
```

---

### 2.5 Token Handling Best Practices

- **Token Lifetime**: 60 minutes by default (configurable server-side via `ACCESS_TOKEN_EXPIRE_MINUTES`).
- **Algorithm**: HS256.
- **Storage**: Store securely using `flutter_secure_storage`. Never persist in `SharedPreferences`.
- **Refresh Strategy**: There is **no refresh token endpoint**. On 401, redirect the user to the login screen.
- **Student Token Payload**: `{ "sub": "FA23-BCS-065", "exp": <unix_timestamp> }` — no `role` field.
- **Vehicle Token Payload**: `{ "sub": "ABC-32", "role": "vehicle", "exp": <unix_timestamp> }`.

---

## 3. Wallet Module

### 3.1 Get Wallet Balance

```
GET /api/wallet/balance
Authorization: Bearer <student_jwt>
```

**Success Response (200):**
```json
{
  "balance": 435.00,
  "currency": "PKR"
}
```

> [!NOTE]
> If the student has never topped up, the server returns `{"balance": 0.00, "currency": "PKR"}` (not a 404).

---

### 3.2 Initiate Top-Up (Safepay Checkout)

This starts a payment session with Safepay. The server returns a URL which must be opened in a WebView or external browser.

```
POST /api/wallet/topup
Content-Type: application/json
(No Authorization header required for this endpoint — user_id is in the body)
```

**Request Body:**
```json
{
  "user_id": "FA23-BCS-065",
  "amount": 500.00
}
```

**Success Response (201):**
```json
{
  "transaction_id": "a1b2c3d4-e5f6-...",
  "checkout_url": "https://sandbox.api.safepay.com/..."
}
```

**Flutter Implementation Notes:**
1. After receiving the `checkout_url`, open it in a `WebView` or `url_launcher`.
2. Safepay handles the payment UI entirely. The student enters card/account details there.
3. On completion, Safepay sends a **webhook** to the server (`POST /api/webhooks/safepay`).
4. The server processes the webhook, credits the wallet atomically, and sends a push notification.
5. **The Flutter app does NOT need to poll for payment status.** It will receive an FCM push notification when the wallet is credited.

---

### 3.3 Get Transaction History

```
GET /api/wallet/transactions
Authorization: Bearer <student_jwt>
```

**Success Response (200):**
```json
[
  {
    "transaction_id": "a1b2c3d4-...",
    "amount": 500.00,
    "status": "SUCCESS",
    "created_at": "2026-07-10T09:30:00+00:00"
  },
  {
    "transaction_id": "e5f6g7h8-...",
    "amount": 65.00,
    "status": "PENDING",
    "created_at": "2026-07-10T10:00:00+00:00"
  }
]
```

**Transaction Status Values:**
- `PENDING` — Payment initiated, not yet confirmed by Safepay.
- `SUCCESS` — Payment confirmed and wallet credited.
- `FAILED` — Payment failed or rejected.

---

### 3.4 Generate NFC Payment Token

This is the **critical** endpoint for the NFC fare payment flow. The student app calls this to generate a short-lived, one-time payment token that will be broadcast via HCE to the driver's phone.

```
POST /api/wallet/generate-payment-token
Authorization: Bearer <student_jwt>
Content-Type: application/json
```

**Request Body:**
```json
{
  "amount": 65.00
}
```

**Success Response (201):**
```json
{
  "token_id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "expires_at": "2026-07-10T10:05:00+00:00"
}
```

> [!CAUTION]
> The `token_id` is a UUID v4. It expires in **exactly 5 minutes** from generation. It can only be used **once** — the atomic `collect_bus_fare` server-side RPC marks it as `USED` immediately. If the token expires before being scanned, it is marked `EXPIRED` and cannot be used. The student must generate a new token.

**Error Responses:**

| Status | Condition | Detail |
|---|---|---|
| `400` | Insufficient balance | `"Insufficient wallet balance to generate this ticket."` |
| `401` | Bad/expired token | `"Invalid or expired token."` |

**Flutter Implementation Notes:**
1. Call this endpoint when the student presses "Pay Fare" / "Generate Ticket".
2. On success, immediately store the `token_id` string and start broadcasting it via HCE (see Section 6).
3. Display a countdown timer to the user (5 minutes from `expires_at`).
4. The fare `amount` should be a fixed value presented in the UI (e.g. Rs. 65). The student does NOT choose the amount — it's determined by the app configuration.

---

## 4. Bus Routes & Schedules

### 4.1 Get All Routes

Returns all static bus routes (both morning to-campus and reverse from-campus paths).

```
GET /api/routes
Authorization: Bearer <student_jwt>
```

**Success Response (200):**
```json
[
  {
    "id": "ROUTE-MURREE",
    "name": "Main Camp -> Murree Chowk -> Academic Campus",
    "start_location": "Main Camp",
    "via": "Murree Chowk",
    "end_location": "Academic Campus",
    "created_at": "2026-07-10T08:00:00+00:00"
  },
  {
    "id": "ROUTE-MURREE-REV",
    "name": "Academic Campus -> Murree Chowk -> Main Camp",
    "start_location": "Academic Campus",
    "via": "Murree Chowk",
    "end_location": "Main Camp",
    "created_at": "2026-07-10T08:00:00+00:00"
  }
]
```

**Known Route IDs:**

| Route ID | Direction | Via |
|---|---|---|
| `ROUTE-MURREE` | Morning (to campus) | Murree Chowk |
| `ROUTE-PMA` | Morning (to campus) | PMA Road |
| `ROUTE-FAWARA` | Morning (to campus) | Fawara Chowk |
| `ROUTE-NAWASHER` | Morning (to campus) | Nawasher |
| `ROUTE-MURREE-REV` | Reverse (from campus) | Murree Chowk |
| `ROUTE-PMA-REV` | Reverse (from campus) | PMA Road |
| `ROUTE-FAWARA-REV` | Reverse (from campus) | Fawara Chowk |
| `ROUTE-NAWASHER-REV` | Reverse (from campus) | Nawasher |

---

### 4.2 Set Preferred Route

```
POST /api/student/preferred-route
Authorization: Bearer <student_jwt>
Content-Type: application/json
```

**Request Body:**
```json
{
  "route_id": "ROUTE-MURREE"
}
```

**Success Response (200):**
```json
{
  "status": "success",
  "message": "Preferred route updated successfully."
}
```

> [!IMPORTANT]
> **Students select ROUTES, not time slots.** Time slots exist only for display and internal scheduling. The student's preferred route determines which live bus updates are most relevant, but the student can view all active buses regardless of preference.

---

## 5. Live Bus Tracking (REST + WebSocket)

### 5.1 Get Active Buses (REST — Dashboard Snapshot)

Returns a real-time snapshot of **all** currently active vehicle sessions with GPS coordinates, route details, and seat capacity.

```
GET /api/buses/active
Authorization: Bearer <student_jwt>
```

**Success Response (200):**
```json
[
  {
    "session_id": "d290f1ee-6c54-4b01-90e6-d701748f0851",
    "vehicle_no": "ABC-32",
    "route_schedule_id": "SCH-M1",
    "route_id": "ROUTE-MURREE",
    "route_name": "Main Camp -> Murree Chowk -> Academic Campus",
    "start_location": "Main Camp",
    "via": "Murree Chowk",
    "end_location": "Academic Campus",
    "departure_time": "08:15:00",
    "latitude": 34.0155,
    "longitude": 73.1344,
    "max_capacity": 45,
    "passengers_boarded": 12,
    "capacity_remaining": 33,
    "last_ping_at": "2026-07-10T08:20:00+00:00"
  }
]
```

**Flutter Implementation Notes:**
- `latitude`/`longitude` may be `null` if the driver hasn't started broadcasting GPS yet (session is `active` but no WebSocket pings received yet).
- `departure_time` is in `HH:MM:SS` format (24h). Parse it for display.
- `passengers_boarded` is the count of completed fare payments for this session.
- Use this endpoint for the initial dashboard load and periodic refresh. For real-time updates, connect to the WebSocket (5.2).

---

### 5.2 Real-Time Location Updates (WebSocket)

After loading the initial dashboard via REST, connect to a WebSocket to receive **live GPS coordinate updates** from buses on a specific route.

```
WSS /ws/student/route/{route_id}
```

**Connection:** No Authorization header is needed on the WebSocket connection (by current implementation). Simply connect to the path with the desired `route_id`.

**Example:**
```
wss://commutas-server.onrender.com/ws/student/route/ROUTE-MURREE
```

**Incoming Messages (server → client):**

The server pushes a JSON message every time a vehicle on this route sends a GPS coordinate update:

```json
{
  "vehicle_no": "ABC-32",
  "route_id": "ROUTE-MURREE",
  "latitude": 34.0155,
  "longitude": 73.1344,
  "last_ping_at": "2026-07-10T08:21:15+00:00"
}
```

**Flutter Implementation Notes:**
1. Use the `web_socket_channel` package: `WebSocketChannel.connect(Uri.parse(wsUrl))`.
2. Parse incoming JSON and update the map marker position for the matching `vehicle_no`.
3. The student socket is **read-only** — you do NOT send any data, just keep the connection alive.
4. Handle `WebSocketChannelException` for auto-reconnection with exponential backoff.
5. You may subscribe to **multiple route WebSockets** simultaneously (e.g. if viewing all routes).
6. The server will close the socket on the vehicle side when the trip ends. You'll receive a `WebSocketChannelException` — on this event, refresh the REST dashboard to see if the bus has completed its trip.

```dart
// Example Flutter WebSocket Connection
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

final channel = WebSocketChannel.connect(
  Uri.parse('wss://your-server.com/ws/student/route/ROUTE-MURREE'),
);

channel.stream.listen(
  (message) {
    final data = jsonDecode(message);
    final vehicleNo = data['vehicle_no'];
    final lat = data['latitude'];
    final lng = data['longitude'];
    // Update map marker for vehicleNo at (lat, lng)
  },
  onDone: () {
    // Server closed the connection — trip may have ended
    // Refresh dashboard via REST
  },
  onError: (error) {
    // Reconnect with exponential backoff
  },
);
```

---

## 6. NFC Fare Payment — Host Card Emulation

> [!IMPORTANT]
> This is the most critical and complex part of the integration. Read this entire section carefully.

### 6.1 Architecture Overview

The NFC fare payment uses **Host Card Emulation (HCE)** — a standard Android capability that allows a phone to act as a contactless smart card. In this system:

- **Student Phone (Emitter)**: Runs HCE service, broadcasting the payment `token_id` as an NFC payload.
- **Driver Phone (Reader)**: Uses NFC Reader mode to scan the student's phone and read the `token_id`.
- **Server**: The driver app sends the scanned `token_id` + `session_id` to the backend, which atomically deducts the fare.

```
┌─────────────────┐          NFC TAP          ┌─────────────────┐
│   Student Phone  │ ──── physical touch ────▶ │   Driver Phone   │
│   (HCE Emitter)  │       (contactless)       │   (NFC Reader)   │
│                  │                           │                  │
│  Broadcasting:   │                           │  Reads payload:  │
│  token_id (UUID) │                           │  token_id (UUID) │
└────────┬─────────┘                           └────────┬─────────┘
         │                                              │
         │ 1. POST /api/wallet/generate-payment-token   │ 3. POST /vehicles/session/fare-collect
         │    ← Response: token_id                     │    Body: { session_id, token_id }
         │                                              │
         └──────────────────┐    ┌──────────────────────┘
                            │    │
                            ▼    ▼
                    ┌──────────────────┐
                    │   Commutas Server │
                    │                  │
                    │  collect_bus_fare │
                    │  (atomic RPC)    │
                    │                  │
                    │  • Validates     │
                    │    token         │
                    │  • Checks expiry │
                    │  • Deducts       │
                    │    wallet        │
                    │  • Records       │
                    │    fare_payment  │
                    └──────────────────┘
```

### 6.2 Student App — HCE Emitter Implementation

#### Step 1: Generate Payment Token

Call the REST endpoint (documented in Section 3.4):

```dart
final response = await http.post(
  Uri.parse('$baseUrl/api/wallet/generate-payment-token'),
  headers: {
    'Authorization': 'Bearer $studentToken',
    'Content-Type': 'application/json',
  },
  body: jsonEncode({'amount': 65.00}),
);

final data = jsonDecode(response.body);
final String tokenId = data['token_id'];       // UUID to broadcast
final String expiresAt = data['expires_at'];    // ISO 8601 timestamp
```

#### Step 2: Start HCE Broadcasting

Use the `flutter_nfc_hce` plugin to broadcast the `token_id` string via HCE.

```dart
import 'package:flutter_nfc_hce/flutter_nfc_hce.dart';

final _hcePlugin = FlutterNfcHce();

// Check hardware support
bool isSupported = await _hcePlugin.isNfcHceSupported();
bool isEnabled = await _hcePlugin.isNfcEnabled();

if (!isSupported) {
  // Show error: device doesn't support HCE
  return;
}
if (!isEnabled) {
  // Prompt user to enable NFC in settings
  return;
}

// Start broadcasting the token_id
var result = await _hcePlugin.startNfcHce(
  tokenId,                        // The UUID string to broadcast
  mimeType: 'text/plain',        // NDEF MIME type
  persistMessage: true,           // Keep broadcasting until explicitly stopped
);

// result contains "success" if broadcasting started
```

#### Step 3: Show Countdown Timer

Display a 5-minute countdown from `expiresAt`. If the timer reaches zero, stop broadcasting and prompt the student to generate a new token.

```dart
// Stop broadcasting
await _hcePlugin.stopNfcHce();
```

#### Step 4: After Successful Scan

When the driver scans the student's phone, the server deducts the fare. The student receives this feedback through:
1. **Wallet balance change**: Poll `GET /api/wallet/balance` after a brief delay.
2. **Transaction history**: The fare payment appears in `GET /api/wallet/transactions`.
3. (Future) Push notification confirming the fare deduction.

> [!NOTE]
> The student app has **no direct callback** from the NFC tap. The HCE service simply broadcasts. The student knows the tap was successful when:
> - The driver's screen shows success, or
> - The student checks their wallet balance.
>
> **Design Recommendation**: After starting HCE broadcast, show a "waiting for scan" state. Periodically (every 5s) poll the wallet balance or check if the token status has changed from PENDING to USED. Stop polling after 5 minutes (token expiry).

---

### 6.3 HCE Technical Details (from POC Validation)

These details are derived from the working HCE proof-of-concept ([HCE-Validation-Phone-to-Phone-Transmission](https://github.com/dev-mubi/HCE-Validation-Phone-to-Phone-Transmission-)) located at `C:\Users\HOME\Desktop\HCE Idea Validation`.

#### Flutter Dependencies for HCE

```yaml
dependencies:
  flutter_nfc_hce: ^0.1.8    # HCE Emitter (student side)
  nfc_manager: ^3.3.0         # NFC Reader (driver side)
```

#### APDU Service Configuration

The HCE service must be declared in the Android manifest and configured with an AID (Application ID).

**AID Used**: `D2760000850101` (standard NFC Type 4 tag AID for NDEF).

**File**: `android/app/src/main/res/xml/apduservice.xml`
```xml
<?xml version="1.0" encoding="utf-8"?>
<host-apdu-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:description="@string/servicedesc"
    android:requireDeviceUnlock="false">
    <aid-group android:description="@string/aiddescription"
        android:category="other">
        <aid-filter android:name="D2760000850101"/>
    </aid-group>
</host-apdu-service>
```

#### NFC Payload Decoding (Driver/Reader Side)

The driver app reads the NFC tag using `nfc_manager`. The payload is encoded as NDEF by the `flutter_nfc_hce` plugin. Decoding logic:

```dart
import 'dart:convert';
import 'package:nfc_manager/nfc_manager.dart';

// Start NFC session to read tags
NfcManager.instance.startSession(
  onDiscovered: (NfcTag tag) async {
    String tokenId = '';

    // 1. Try NDEF extraction (standard path for flutter_nfc_hce)
    final ndef = Ndef.from(tag);
    if (ndef != null) {
      final message = ndef.cachedMessage ?? await ndef.read();
      for (var record in message.records) {
        tokenId = _decodeNdefRecord(record);
        if (tokenId.isNotEmpty) break;
      }
    }

    // 2. If NDEF empty, try raw byte extraction fallback
    if (tokenId.isEmpty) {
      tokenId = _extractRawBytes(tag);
    }

    if (tokenId.isEmpty) {
      // Show error: could not read payment token
      return;
    }

    // tokenId now contains the student's payment UUID
    // Send it to the server for fare collection (see Section 8)
  },
);

// NDEF record decoder
String _decodeNdefRecord(NdefRecord record) {
  final payload = record.payload;
  if (payload.isEmpty) return '';

  // NFC Well-Known Text type (TNF=1, Type='T')
  if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
      record.type.length == 1 &&
      record.type[0] == 0x54) {
    int status = payload[0];
    int langLen = status & 0x3F;
    if (langLen + 1 <= payload.length) {
      return utf8.decode(payload.sublist(1 + langLen));
    }
  }

  // MIME / fallback raw decode
  final text = utf8.decode(payload, allowMalformed: true);
  return text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '').trim();
}

// Raw bytes fallback extractor
String _extractRawBytes(NfcTag tag) {
  final Map<dynamic, dynamic> tagData = tag.data;
  for (var tech in tagData.keys) {
    final techData = tagData[tech];
    if (techData is Map && techData.containsKey('payload')) {
      final raw = techData['payload'];
      if (raw is List<int>) {
        final text = utf8.decode(raw, allowMalformed: true);
        return text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '').trim();
      }
    }
  }
  return '';
}
```

---

## 7. Push Notifications — Firebase FCM

### 7.1 Register Device Token

After the student logs in and obtains FCM permissions, register the device token with the server.

```
POST /api/notifications/register-token
Authorization: Bearer <student_jwt>
Content-Type: application/json
```

**Request Body:**
```json
{
  "device_token": "dGhpcyBpcyBhIHRlc3QgdG9rZW4..."
}
```

**Success Response (200):**
```json
{
  "status": "success",
  "message": "Device token registered successfully."
}
```

**Flutter Implementation Notes:**
1. Use `firebase_messaging` package.
2. Call `FirebaseMessaging.instance.getToken()` to get the device token.
3. Register the token immediately after login.
4. Listen for token refresh via `FirebaseMessaging.instance.onTokenRefresh` and re-register.
5. The server uses this token to send notifications for:
   - Wallet top-up success/failure
   - (Future) Fare deduction confirmations

---

## 8. Vehicle/Driver App Integration

> [!WARNING]
> The vehicle app is a **completely separate Flutter application** with its own authentication flow. Student tokens CANNOT access vehicle endpoints and vice versa. The JWT `role` claim enforces this at the dependency level.

### 8.1 Vehicle Login

```
POST /vehicles/login
Content-Type: application/json
(No Authorization header required)
```

**Request Body:**
```json
{
  "registration_no": "ABC-32",
  "password": "commutas_driver"
}
```

**Validation**: `registration_no` must match `X{1,4}-0{1,4}` pattern (1-4 uppercase letters, hyphen, 1-4 digits).

**Success Response (200):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "token_type": "bearer",
  "vehicle": {
    "registration_no": "ABC-32",
    "max_capacity": 45,
    "current_driver": "Saeed Khan"
  }
}
```

---

### 8.2 Vehicle Session Lifecycle

The driver session has a 3-phase state machine:

```
created → active → completed
         ↘ cancelled
```

#### Phase 1: Start Session (Boarding)

Driver selects a route schedule and starts a boarding session.

```
POST /vehicles/session/start
Authorization: Bearer <vehicle_jwt>
Content-Type: application/json
```

**Request Body:**
```json
{
  "route_schedule_id": "SCH-M1"
}
```

**Success Response (201):**
```json
{
  "session_id": "d290f1ee-6c54-4b01-90e6-d701748f0851",
  "vehicle_no": "ABC-32",
  "route_schedule_id": "SCH-M1",
  "status": "created"
}
```

> [!NOTE]
> Starting a new session automatically cancels any existing `created` or `active` sessions for this vehicle. This prevents orphaned sessions.

**Known Route Schedule IDs:**

| Schedule ID | Route | Time Slot |
|---|---|---|
| `SCH-M1` | ROUTE-MURREE (to campus) | 08:15 AM |
| `SCH-M2` | ROUTE-PMA (to campus) | 08:15 AM |
| `SCH-M3` | ROUTE-FAWARA (to campus) | 08:15 AM |
| `SCH-M4` | ROUTE-NAWASHER (to campus) | 08:15 AM |
| `SCH-E1-MURREE` | ROUTE-MURREE-REV (from campus) | 01:45 PM |
| `SCH-E1-FAWARA` | ROUTE-FAWARA-REV (from campus) | 01:45 PM |
| `SCH-E2-MURREE` | ROUTE-MURREE-REV (from campus) | 03:15 PM |
| `SCH-E2-PMA` | ROUTE-PMA-REV (from campus) | 03:15 PM |
| `SCH-E2-FAWARA` | ROUTE-FAWARA-REV (from campus) | 03:15 PM |
| `SCH-E2-NAWASHER` | ROUTE-NAWASHER-REV (from campus) | 03:15 PM |
| `SCH-E3-*` | Reverse routes | 04:45 PM |
| `SCH-E4-*` | Reverse routes | 06:15 PM |

> [!IMPORTANT]
> Not all routes are available in all time slots. At 01:45 PM, only Murree Chowk and Fawara Chowk reverse routes run. The driver app should fetch available schedules from the server or use a hardcoded list matching the database seed.

---

#### Phase 2: Collect Fares (NFC Scanning)

During the `created` (boarding) phase, the driver scans students' phones to collect fares.

```
POST /vehicles/session/fare-collect
Authorization: Bearer <vehicle_jwt>
Content-Type: application/json
```

**Request Body:**
```json
{
  "session_id": "d290f1ee-6c54-4b01-90e6-d701748f0851",
  "token_id": "f47ac10b-58cc-4372-a567-0e02b2c3d479"
}
```

**Success Response (200):**
```json
{
  "status": "success",
  "message": "Fare successfully collected."
}
```

**Error Responses:**

| Status | Condition | Detail |
|---|---|---|
| `400` | Invalid/expired/used token, or insufficient student balance | `"Fare collection failed. Either the token is invalid/expired, or the student has insufficient balance."` |
| `403` | Session doesn't belong to this vehicle | `"You do not own this session."` |
| `404` | Session not found | `"Session not found."` |

**Server-side Atomic Logic (`collect_bus_fare` RPC):**
1. Verify session is `created` or `active`.
2. Lock the token row (`FOR UPDATE`) — prevents double-spend.
3. Verify token is `PENDING` and not expired.
4. Lock the wallet row (`FOR UPDATE`) — prevents overdraft.
5. Verify sufficient balance.
6. Deduct fare from wallet.
7. Mark token as `USED`.
8. Insert record into `fare_payments` ledger.

> [!CAUTION]
> Fare collection works in BOTH `created` and `active` session states. This allows passengers to board both during the boarding phase and during the active trip.

---

#### Phase 3: Start Trip (Go On-Route)

Transitions the session from `created` → `active`. This enables GPS broadcasting.

```
POST /vehicles/session/start-trip
Authorization: Bearer <vehicle_jwt>
Content-Type: application/json
```

**Request Body:**
```json
{
  "session_id": "d290f1ee-6c54-4b01-90e6-d701748f0851"
}
```

**Success Response (200):**
```json
{
  "status": "success",
  "message": "Trip started. Location broadcasting is now active."
}
```

---

#### Phase 4: Broadcast GPS (WebSocket)

After the trip is started (`active`), the driver app connects to a WebSocket to stream GPS coordinates in real-time.

```
WSS /ws/vehicle/{session_id}
```

**Connection**: The server verifies the session is `active` before accepting the WebSocket. If the session is not active, the server closes the socket with code `1008` (Policy Violation).

**Outgoing Messages (client → server):**

Send a JSON payload with the current GPS coordinates. Recommended frequency: every 3–5 seconds.

```json
{
  "latitude": 34.0155,
  "longitude": 73.1344
}
```

**Server Actions on Each Ping:**
1. Broadcasts the coordinates to all student WebSockets subscribed to the same `route_id`.
2. Updates the `vehicle_sessions` table with the latest coordinates and timestamp.

```dart
// Driver app WebSocket example
final channel = WebSocketChannel.connect(
  Uri.parse('wss://your-server.com/ws/vehicle/$sessionId'),
);

// Stream GPS every 3 seconds
Timer.periodic(Duration(seconds: 3), (timer) async {
  Position pos = await Geolocator.getCurrentPosition(
    locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
  );
  channel.sink.add(jsonEncode({
    'latitude': pos.latitude,
    'longitude': pos.longitude,
  }));
});
```

---

#### Phase 5: End Trip

```
POST /vehicles/session/end
Authorization: Bearer <vehicle_jwt>
Content-Type: application/json
```

**Request Body:**
```json
{
  "session_id": "d290f1ee-6c54-4b01-90e6-d701748f0851"
}
```

**Success Response (200):**
```json
{
  "status": "success",
  "message": "Trip ended. Location broadcasting deactivated."
}
```

After this call, close the vehicle WebSocket connection and return to the session selection screen.

---

## 9. Error Handling Contract

All server errors follow a consistent pattern:

### Standard Error Response Body
```json
{
  "detail": "Human-readable error description."
}
```

### Validation Error (422)
```json
{
  "detail": [
    {
      "type": "value_error",
      "loc": ["body", "reg_no"],
      "msg": "Invalid registration number format. Expected: FA23-BCS-065",
      "input": "invalid",
      "ctx": {}
    }
  ]
}
```

### HTTP Status Code Map

| Code | Meaning | Action |
|---|---|---|
| `200` | Success | Process response |
| `201` | Created | Resource created successfully |
| `400` | Bad request | Display `detail` to user |
| `401` | Unauthorized | Clear stored token, redirect to login |
| `403` | Forbidden | You don't own this resource |
| `404` | Not found | Resource doesn't exist |
| `409` | Conflict | Duplicate resource |
| `422` | Validation error | Display field-level errors |
| `500` | Server error | Show generic error, retry |

---

## 10. Required Flutter Dependencies

```yaml
dependencies:
  # HTTP & Networking
  http: ^1.6.0
  web_socket_channel: ^3.0.0

  # NFC
  flutter_nfc_hce: ^0.1.8        # HCE Emitter (student app)
  nfc_manager: ^3.3.0              # NFC Reader (driver app only)

  # Location Services (driver app only)
  geolocator: ^14.0.3

  # Firebase Push Notifications
  firebase_core: ^latest
  firebase_messaging: ^latest

  # Secure Storage
  flutter_secure_storage: ^latest

  # Maps (for live tracking UI)
  google_maps_flutter: ^latest     # Or mapbox_maps_flutter

  # State Management (recommended)
  provider: ^latest                # Or riverpod/bloc

  # URL Launcher (for Safepay checkout redirect)
  url_launcher: ^latest
```

---

## 11. Android Manifest Configuration

### Student App Manifest Requirements

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- NFC Permissions -->
    <uses-permission android:name="android.permission.NFC" />
    <uses-feature android:name="android.hardware.nfc" android:required="false" />
    <uses-feature android:name="android.hardware.nfc.hce" android:required="false" />

    <!-- Internet -->
    <uses-permission android:name="android.permission.INTERNET" />

    <application ...>
        <!-- Flutter Activity (standard) -->
        <activity android:name=".MainActivity" ...>
            ...
        </activity>

        <!-- HCE Service Registration -->
        <service
            android:name="com.novice.flutter_nfc_hce.KHostApduService"
            android:exported="true"
            android:enabled="true"
            android:permission="android.permission.BIND_NFC_SERVICE">
            <intent-filter>
                <action android:name="android.nfc.cardemulation.action.HOST_APDU_SERVICE" />
                <category android:name="android.intent.category.DEFAULT" />
            </intent-filter>
            <meta-data
                android:name="android.nfc.cardemulation.host_apdu_service"
                android:resource="@xml/apduservice" />
        </service>
    </application>
</manifest>
```

### APDU Service XML

**File**: `android/app/src/main/res/xml/apduservice.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<host-apdu-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:description="@string/servicedesc"
    android:requireDeviceUnlock="false">
    <aid-group android:description="@string/aiddescription"
        android:category="other">
        <aid-filter android:name="D2760000850101"/>
    </aid-group>
</host-apdu-service>
```

### Required String Resources

**File**: `android/app/src/main/res/values/strings.xml`

```xml
<resources>
    <string name="servicedesc">Commutas NFC Payment Service</string>
    <string name="aiddescription">Commutas Payment AID</string>
</resources>
```

### Driver App Additional Manifest Requirements

```xml
<!-- Location permission for GPS broadcasting -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<!-- Background location if needed -->
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

> [!NOTE]
> The driver app does NOT need HCE service registration. It only uses `nfc_manager` in Reader mode, which requires just the basic `android.permission.NFC` permission.

---

## Appendix: Complete JSON Payload Reference

### A. Student App Endpoints Summary

| Method | Endpoint | Auth | Purpose |
|---|---|---|---|
| `POST` | `/auth/register` | ✗ | Register new student |
| `POST` | `/auth/login` | ✗ | Login student |
| `GET` | `/auth/me` | ✓ | Get current profile |
| `POST` | `/auth/reset-password` | ✗ | Reset password |
| `GET` | `/api/wallet/balance` | ✓ | Get wallet balance |
| `POST` | `/api/wallet/topup` | ✗ | Initiate Safepay checkout |
| `GET` | `/api/wallet/transactions` | ✓ | Transaction history |
| `POST` | `/api/wallet/generate-payment-token` | ✓ | Generate NFC fare token |
| `GET` | `/api/routes` | ✓ | List all routes |
| `POST` | `/api/student/preferred-route` | ✓ | Set preferred route |
| `GET` | `/api/buses/active` | ✓ | Active buses snapshot |
| `WSS` | `/ws/student/route/{route_id}` | ✗ | Live GPS updates |
| `POST` | `/api/notifications/register-token` | ✓ | Register FCM token |

### B. Vehicle/Driver App Endpoints Summary

| Method | Endpoint | Auth | Purpose |
|---|---|---|---|
| `POST` | `/vehicles/login` | ✗ | Login vehicle |
| `POST` | `/vehicles/session/start` | ✓ | Start boarding session |
| `POST` | `/vehicles/session/start-trip` | ✓ | Transition to active |
| `POST` | `/vehicles/session/fare-collect` | ✓ | NFC fare collection |
| `POST` | `/vehicles/session/end` | ✓ | End trip |
| `WSS` | `/ws/vehicle/{session_id}` | ✗ | GPS coordinate streaming |

### C. Complete NFC Fare Payment Sequence Diagram

```
Student Phone                    Driver Phone                     Server
     │                               │                              │
     │ 1. POST /generate-payment-token                              │
     │──────────────────────────────────────────────────────────────▶│
     │◀──────────────────────────────────────── { token_id } ───────│
     │                               │                              │
     │ 2. Start HCE broadcast        │                              │
     │     (token_id via NFC)         │                              │
     │ ═══════════════╗               │                              │
     │   BROADCASTING  ║              │                              │
     │ ═══════════════╝               │                              │
     │                               │                              │
     │         ╔══ NFC TAP ══╗        │                              │
     │ ◀━━━━━━━║  PHYSICAL   ║━━━━━▶  │                              │
     │         ╚═════════════╝        │                              │
     │                               │                              │
     │                               │ 3. Reads token_id from NDEF  │
     │                               │                              │
     │                               │ 4. POST /fare-collect        │
     │                               │    { session_id, token_id }  │
     │                               │─────────────────────────────▶│
     │                               │                              │
     │                               │              ┌───────────────┤
     │                               │              │ ATOMIC RPC:   │
     │                               │              │ • Lock token  │
     │                               │              │ • Lock wallet │
     │                               │              │ • Deduct fare │
     │                               │              │ • Mark USED   │
     │                               │              │ • Record pay  │
     │                               │              └───────────────┤
     │                               │                              │
     │                               │◀──── { status: "success" } ──│
     │                               │                              │
     │ 5. Stop HCE broadcast         │                              │
     │ 6. Check balance              │                              │
     │──────────────────────────────────────────────────────────────▶│
     │◀──────────────────────── { balance: 435.00 } ────────────────│
     │                               │                              │
```

---

> [!TIP]
> **Testing the NFC flow** requires two physical Android devices (NFC emulation does not work in emulators). Use `flutter run -d <device_id>` on each device. The driver and student apps MUST be separate Flutter projects with separate `ApplicationId`s.
