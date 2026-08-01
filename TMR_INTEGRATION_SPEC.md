# Sanlam × TMR Telehealth — Integration Specification

**Document version:** 1.0  
**Prepared by:** Sanlam Health (SanCare+ App Team)  
**Intended audience:** TMR Technical Team  

---

## 1. Purpose

This document describes how the **SanCare+ mobile app** (Sanlam's member health app) will integrate with the **TMR Telehealth platform** so that Sanlam members can book a telehealth consultation directly from the Sanlam app — without ever having to open the TMR app or re-verify their insurance.

---

## 2. What changes for the member

| Before integration | After integration |
|---|---|
| Member opens TMR app | Member stays in SanCare+ app |
| TMR verifies Sanlam insurance | Already verified — member goes straight to consultation |
| Member re-enters personal details | Sanlam sends all details automatically |
| Member books and waits | Booking confirmed instantly in the Sanlam app |

---

## 3. High-level process flow

```
┌──────────────────────────────────────────────────────────────────┐
│  SANLAM MEMBER DEVICE (SanCare+ App)                             │
│                                                                  │
│  1. Member selects TMR as hospital in the Appointments screen    │
│  2. Fills in: Condition → Date & Time → Reason for visit         │
│  3. App reaches CONFIRM step                                     │
│                                                                  │
│  4. ── BENEFIT CHECK (happens automatically) ──────────────────  │
│     App calls Sanlam API: GetMemberPlanBenefit                   │
│     ✅  Outpatient balance > 0  → member can proceed             │
│     ❌  Outpatient balance = 0  → booking blocked, message shown │
│                                                                  │
│  5. Member taps "Confirm Booking"                                │
└──────────────────────────┬───────────────────────────────────────┘
                           │ HTTPS POST (see Section 5)
                           ▼
┌──────────────────────────────────────────────────────────────────┐
│  SANLAM BACKEND (SanCare+ API Server)                            │
│                                                                  │
│  6. Receives booking request                                     │
│  7. Looks up member details from Sanlam database                 │
│     (name, phone, email, member number)                          │
│  8. Confirms outpatient_balance > 0 server-side (second guard)   │
│  9. Calls TMR Booking Endpoint (see Section 5)                   │
│     Includes: insuranceVerified = true                           │
│               insurer = "Sanlam"                                 │
│               outpatientBalance = <UGX amount>                   │
└──────────────────────────┬───────────────────────────────────────┘
                           │ HTTPS POST  →  TMR responds with bookingId
                           ▼
┌──────────────────────────────────────────────────────────────────┐
│  TMR TELEHEALTH SYSTEM                                           │
│                                                                  │
│  10. Receives booking payload                                    │
│  11. Reads insuranceVerified = true                              │
│      → SKIPS internal Sanlam benefits verification               │
│      → Creates appointment record in TMR system                  │
│      → Assigns to available doctor / call queue                  │
│  12. Returns booking confirmation (bookingId, status, time)      │
└──────────────────────────┬───────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────────┐
│  SANLAM BACKEND                                                  │
│                                                                  │
│  13. Saves appointment with status = "confirmed"                 │
│      Stores TMR bookingId as external reference                  │
│  14. Sends push notification + SMS + email to member             │
└──────────────────────────┬───────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────────┐
│  MEMBER SEES IN APP                                              │
│                                                                  │
│  "✅ Appointment Confirmed — TMR Telehealth"                     │
│  Date · Time · Booking reference                                 │
└──────────────────────────────────────────────────────────────────┘
```

---

## 4. What Sanlam guarantees before calling TMR

By the time a request reaches TMR, Sanlam has already:

| Guarantee | How |
|---|---|
| Member is authenticated | Sanlam JWT session is active |
| Member is a valid Sanlam policyholder | Verified at login via Sanlam core API |
| Member has outpatient benefit available | `GetMemberPlanBenefit` checked live — balance > 0 confirmed **twice** (client + server) |
| Member details are accurate | Pulled directly from Sanlam member database |

TMR **does not need to re-verify insurance**. The `insuranceVerified: true` flag in the request body is your signal to skip that step.

---

## 5. Endpoints Sanlam needs from TMR

> **Please provide the following.** Sanlam will plug these into its integration service and test end-to-end.

---

### 5.1 Book appointment — PRIMARY ENDPOINT

**Method:** `POST`  
**Path:** `[TMR to provide]` — e.g. `/appointments/book`

#### Request headers

| Header | Value |
|---|---|
| `Authorization` | `Bearer <API_KEY>` — TMR to provide the key |
| `Content-Type` | `application/json` |

#### Request body (what Sanlam will send)

```json
{
  "memberNo":          "SL-001234",
  "memberName":        "John Doe",
  "phone":             "+256700000000",
  "email":             "john.doe@example.com",
  "appointmentDate":   "2026-07-01",
  "preferredTime":     "09:00",
  "complaint":         "Hypertension follow-up",
  "insuranceVerified": true,
  "insurer":           "Sanlam",
  "outpatientBalance": 1500000
}
```

#### Field descriptions

| Field | Type | Required | Description |
|---|---|---|---|
| `memberNo` | string | yes | Sanlam member number — unique identifier |
| `memberName` | string | yes | Member's full name |
| `phone` | string | yes | Mobile number (E.164 format) |
| `email` | string | no | Member's email address |
| `appointmentDate` | string | yes | Preferred date in `YYYY-MM-DD` format |
| `preferredTime` | string | no | Preferred time in `HH:MM` (24hr) format |
| `complaint` | string | no | Condition or reason for the consultation |
| `insuranceVerified` | boolean | yes | **Always `true`** — Sanlam has pre-verified benefits. TMR should skip its own insurance check |
| `insurer` | string | yes | Always `"Sanlam"` |
| `outpatientBalance` | number | yes | Member's remaining outpatient balance in UGX at the time of booking |

#### Expected success response — `HTTP 200` or `201`

```json
{
  "bookingId":     "TMR-78901",
  "status":        "confirmed",
  "confirmedTime": "09:00"
}
```

> **Note:** Field names in the response can differ — please document the exact names used in your system so Sanlam can map them correctly.

#### Expected error response

```json
{
  "error":   "SLOT_UNAVAILABLE",
  "message": "No doctors available at the requested time. Please try a different slot."
}
```

---

### 5.2 Health check — OPTIONAL BUT RECOMMENDED

Sanlam calls this before a booking to detect TMR outages and show the member a friendly message instead of a generic error.

**Method:** `GET`  
**Path:** `[TMR to provide]` — e.g. `/health`  
**Auth:** none (public)

#### Expected response — `HTTP 200`

```json
{ "status": "ok" }
```

---

### 5.3 Cancel appointment — NICE TO HAVE

If a member cancels their appointment in the Sanlam app, Sanlam will call this to cancel it in TMR's system too.

**Method:** `DELETE` or `PATCH`  
**Path:** `[TMR to provide]` — e.g. `/appointments/{bookingId}/cancel`  
**Auth:** Bearer token (same API key)

#### Expected response — `HTTP 200`

```json
{ "status": "cancelled" }
```

---

## 6. Authentication

Sanlam will store the credentials you provide securely in environment variables on the server. They are never stored in the mobile app.

> **Please provide:**
> 1. API base URL (e.g. `https://api.tmr.co.ug`)
> 2. API key (or let us know if you use a different auth scheme — OAuth 2.0, HMAC, etc.)
> 3. Any IP addresses we should whitelist on the TMR side

---

## 7. Data TMR receives — summary

This is the complete picture of what a member's booking payload looks like:

```
┌─────────────────────────────────────────┐
│  MEMBER IDENTITY                        │
│  memberNo:    SL-001234                 │
│  memberName:  John Doe                  │
│  phone:       +256700000000             │
│  email:       john.doe@example.com      │
├─────────────────────────────────────────┤
│  APPOINTMENT REQUEST                    │
│  appointmentDate:  2026-07-01           │
│  preferredTime:    09:00                │
│  complaint:        Hypertension         │
├─────────────────────────────────────────┤
│  INSURANCE PRE-VERIFICATION             │
│  insuranceVerified:  true  ← KEY FIELD  │
│  insurer:            Sanlam             │
│  outpatientBalance:  1,500,000 UGX      │
└─────────────────────────────────────────┘
```

---

## 8. What Sanlam needs from TMR — checklist

| # | Item | Notes |
|---|---|---|
| 1 | API base URL | e.g. `https://api.tmr.co.ug` |
| 2 | API key / auth credentials | Sanlam stores securely server-side |
| 3 | Booking endpoint path | e.g. `/appointments/book` |
| 4 | Exact request field names | If different from Section 5.1 above |
| 5 | Exact response field names | Especially the booking ID field name |
| 6 | Cancel endpoint path | Optional — for member cancellations |
| 7 | Health check endpoint | Optional — for outage detection |
| 8 | TMR IP whitelist requirements | If TMR restricts inbound IPs |
| 9 | Test / sandbox environment URL | For integration testing before go-live |

---

## 9. Test scenario

Once TMR provides the sandbox URL, Sanlam will run the following test:

1. Log in as a test Sanlam member with outpatient balance > 0
2. Select TMR in the Appointments screen
3. Complete the booking wizard
4. Confirm the benefit check shows the correct balance
5. Submit booking — verify TMR receives the correct payload
6. Confirm the booking appears as "Confirmed" in the Sanlam app
7. Repeat with a member whose outpatient balance = 0 — confirm booking is blocked **before** reaching TMR

---

## 10. Contact

| Party | Contact |
|---|---|
| Sanlam integration queries | eddyregan4@gmail.com |
| TMR integration queries | [TMR to fill in] |

---

*End of document.*
