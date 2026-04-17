# Admin migration to Appsmith (I-WAY)

## Goal
Migrate the operational/admin surface from Flutter mobile UI to Appsmith web using the existing production backend.

Base API:
- Primary: `https://api.iway.one/api`
- Fallback if routing returns 404 on `/api`: `https://api.iway.one`

## What is already backed by real API
Verified frontend-to-backend route match exists for:
- travelers review / KYC
- transfers review
- anti-fraud queue and manual flags
- commissions ledger / traveler summary / pricing settings
- disputes queue and resolution
- shipments list / shipment detail / status update
- offers by shipment
- tracking timeline
- notifications by user
- auth login / me

## Appsmith app structure
Recommended pages:
1. Login
2. Dashboard
3. Travelers Review
4. Transfers Review
5. Anti-Fraud
6. Ledger
7. Pricing
8. Disputes
9. Shipments
10. Shipment Detail

---

## 1. Login page

### Purpose
Authenticate admin users and store JWT for subsequent API calls.

### Query: `loginAdmin`
Method: `POST`
URL:
`{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/auth/login`

Body:
```json
{
  "email": "{{InputEmail.text}}",
  "password": "{{InputPassword.text}}"
}
```

### On success
Store:
- `jwt` = `{{loginAdmin.data.accessToken}}`
- `currentUser` = `{{loginAdmin.data.user}}`
- `apiBase` = `https://api.iway.one/api`

Suggested JS on success:
```javascript
{{
storeValue('jwt', loginAdmin.data.accessToken);
storeValue('currentUser', loginAdmin.data.user);
storeValue('apiBase', 'https://api.iway.one/api');
navigateTo('Dashboard');
}}
```

### Access rule
Only allow users with role `admin` or `support`.

---

## Shared datasource setup
For all authenticated queries:

Headers:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}",
  "Content-Type": "application/json"
}
```

Base URL helper:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}
```

If you want automatic 404 fallback, implement a JSObject wrapper that retries the same request against `https://api.iway.one`.

---

## 2. Dashboard

### Purpose
Landing page with links and queue counts.

### Suggested widgets
- Stat cards
- Navigation buttons
- Optional recent queues table

### Queries
- `GET /travelers/review-queue`
- `GET /transfers/review-queue`
- `GET /anti-fraud/review-queue`
- `GET /disputes/queue`
- `GET /shipments`
- `GET /commissions/settings`

Use counts only for top cards if you want speed.

---

## 3. Travelers Review

### Query: `getTravelerReviewQueue`
`GET /travelers/review-queue`

### Actions
#### Approve / reject traveler
Query: `reviewTraveler`
`POST /travelers/{{TableTravelers.selectedRow.userId}}/review`

Body:
```json
{
  "action": "{{SelectReviewAction.selectedOptionValue}}",
  "reason": "{{InputReviewReason.text}}"
}
```

#### Toggle payout hold
Query: `updatePayoutHold`
`POST /travelers/{{TableTravelers.selectedRow.userId}}/payout-hold`

Body:
```json
{
  "enabled": {{SwitchPayoutHold.isSwitchedOn}},
  "reason": "{{InputPayoutReason.text}}"
}
```

#### Run KYC analysis
Query: `runKycAnalysis`
`POST /travelers/{{TableTravelers.selectedRow.userId}}/run-kyc-analysis`

Body:
```json
{}
```

### Important note on document/selfie preview
Evidence URLs are protected and require `Authorization` header.
To make this easier for Appsmith, the backend now exposes an admin-friendly preview endpoint:
- `GET /api/storage/file-preview/:bucket/:ownerId/:fileName`

Response includes:
- `contentType`
- `sizeBytes`
- `dataUrl`

Bind `dataUrl` directly to the Image widget when you need to preview KYC/selfie/package evidence without relying on browser-level auth headers.

---

## 4. Transfers Review

### Query: `getTransferQueue`
`GET /transfers/review-queue`

### Action: `reviewTransfer`
`PUT /transfers/{{TableTransfers.selectedRow.id}}/review`

Body:
```json
{
  "status": "{{SelectTransferStatus.selectedOptionValue}}",
  "reason": "{{InputTransferReason.text}}"
}
```

Suggested statuses:
- `approved`
- `rejected`
- `needs_review`

---

## 5. Anti-Fraud

### Query: `getAntiFraudQueue`
`GET /anti-fraud/review-queue`

### Query: `recomputeRisk`
`POST /anti-fraud/user/{{TableFraud.selectedRow.userId}}/recompute`

Body:
```json
{}
```

### Query: `createManualFlag`
`POST /anti-fraud/user/{{TableFraud.selectedRow.userId}}/flags`

Body:
```json
{
  "flagType": "{{SelectFlagType.selectedOptionValue}}",
  "severity": "{{SelectSeverity.selectedOptionValue}}",
  "details": {
    "note": "{{InputFlagNote.text}}"
  }
}
```

---

## 6. Ledger

### Query: `getTravelerSummary`
`GET /commissions/traveler/{{InputTravelerId.text}}/summary`

### Query: `getTravelerLedger`
`GET /commissions/traveler/{{InputTravelerId.text}}/ledger`

### Query: `createLedgerAdjustment`
`POST /commissions/traveler/{{InputTravelerId.text}}/ledger-adjustments`

Body:
```json
{
  "direction": "{{SelectDirection.selectedOptionValue}}",
  "amount": {{NumberAmount.text}},
  "description": "{{InputAdjustmentDescription.text}}",
  "weeklySettlementId": "{{InputSettlementId.text}}"
}
```

---

## 7. Pricing

### Query: `getPricingSettings`
`GET /commissions/settings`

### Query: `updatePricingSettings`
`PUT /commissions/settings`

Body:
```json
{
  "commissionPerLb": {{NumberCommissionPerLb.text}},
  "groundCommissionPercent": {{NumberGroundPercent.text / 100}},
  "actorId": "{{appsmith.store.currentUser.id}}"
}
```

---

## 8. Disputes

### Query: `getDisputeQueue`
`GET /disputes/queue`

### Query: `resolveDispute`
`PUT /disputes/{{TableDisputes.selectedRow.id}}/resolve`

Body:
```json
{
  "status": "{{SelectDisputeStatus.selectedOptionValue}}",
  "resolution": "{{InputResolution.text}}"
}
```

Useful statuses seen in admin flow:
- `resolved`
- `escalated`
- `rejected`

---

## 9. Shipments

### Query: `getAllShipments`
`GET /shipments`

### Query: `updateShipmentStatus`
`PATCH /shipments/{{TableShipments.selectedRow.id}}/status`

Body:
```json
{
  "status": "{{SelectShipmentStatus.selectedOptionValue}}"
}
```

Suggested filters in Appsmith:
- status
- route
- receiver name
- receiver phone
- shipment id

---

## 10. Shipment Detail

### Query: `getShipmentById`
`GET /shipments/{{appsmith.URL.queryParams.shipmentId}}`

### Query: `getShipmentOffers`
`GET /offers/shipment/{{appsmith.URL.queryParams.shipmentId}}`

### Query: `getShipmentTimeline`
`GET /tracking/shipment/{{appsmith.URL.queryParams.shipmentId}}/timeline`

This page is useful for support/admin operations.

---

## Suggested JSObject for API fallback
If `/api` returns 404 in Appsmith, use a wrapper like this:

```javascript
export default {
  async request(method, path, body) {
    const bases = ['https://api.iway.one/api', 'https://api.iway.one'];
    let lastError = null;

    for (const base of bases) {
      try {
        const response = await fetch(`${base}${path}`, {
          method,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${appsmith.store.jwt}`,
          },
          body: body ? JSON.stringify(body) : undefined,
        });

        if (response.status === 404 && base.endsWith('/api')) {
          continue;
        }

        return await response.json();
      } catch (error) {
        lastError = error;
      }
    }

    throw lastError;
  }
}
```

---

## Migration priority
Build in this order:
1. Login
2. Travelers Review
3. Transfers Review
4. Anti-Fraud
5. Ledger
6. Pricing
7. Disputes
8. Shipments
9. Shipment Detail

---

## What still needs real runtime validation
Static review confirms route match, but you still need live validation for:
- admin auth role behavior
- protected image preview in browser/Appsmith
- CORS from the Appsmith domain
- exact payload/status enums in production data
- final 404 behavior on `https://api.iway.one/api`

## Bottom line
The admin is already structurally suitable for Appsmith migration.
You are not starting from zero, you are re-skinning existing operational flows on top of live endpoints.
