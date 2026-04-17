# Finance reporting API plan

## Goal
Define backend endpoints for a real admin finance dashboard that answers:
- cuánto ganó iWay hoy / semana / mes / año
- cuánto está pendiente por cobrar
- quiénes deben y cuánto
- deuda por país o corredor
- cuánto está pendiente de liquidación
- qué transferencias fueron aprobadas / rechazadas

These endpoints are intended for Appsmith admin use.

---

## Access policy
All `/finance/*` endpoints should be restricted to:
- `admin`
- optionally `support` for read-only views

Recommendation:
- `admin`: full finance dashboard access
- `support`: overview + debtors, but maybe no sensitive margin totals if you want tighter control

---

## Proposed endpoints

### 1. Finance overview
`GET /finance/overview`

### Query params
- `range=today|week|month|year|custom`
- `from=<ISO>` optional for custom
- `to=<ISO>` optional for custom
- `country=GT|US` optional
- `direction=gt_to_us|us_to_gt` optional

### Response
```json
{
  "range": "month",
  "from": "2026-04-01T00:00:00.000Z",
  "to": "2026-04-30T23:59:59.999Z",
  "grossCommission": 12450.75,
  "commissionCollected": 8320.00,
  "outstandingDebt": 4130.75,
  "overdueDebt": 1200.00,
  "travelersWithDebt": 37,
  "blockedTravelersWithDebt": 5,
  "payoutHoldTravelers": 4,
  "pendingTransfersAmount": 2300.00,
  "approvedTransfersAmount": 5400.00,
  "rejectedTransfersAmount": 180.00
}
```

---

### 2. Revenue time series
`GET /finance/revenue-series`

### Query params
- `range=week|month|year|custom`
- `granularity=day|week|month`
- `from=<ISO>` optional
- `to=<ISO>` optional
- `country=` optional
- `direction=` optional

### Response
```json
{
  "range": "month",
  "granularity": "day",
  "points": [
    {
      "bucket": "2026-04-01",
      "grossCommission": 240.50,
      "commissionCollected": 150.00,
      "newDebt": 90.50
    }
  ]
}
```

---

### 3. Debtors leaderboard
`GET /finance/debtors`

### Query params
- `limit=50`
- `country=GT|US` optional
- `onlyOverdue=true|false` optional
- `onlyBlocked=true|false` optional
- `onlyPayoutHold=true|false` optional
- `sortBy=currentDebt|overdueDebt|lastSettlementAt`
- `sortDir=asc|desc`

### Response
```json
{
  "items": [
    {
      "travelerId": "uuid",
      "fullName": "Juan Pérez",
      "email": "juan@example.com",
      "phone": "+502...",
      "country": "GT",
      "travelerStatus": "verified",
      "currentDebt": 320.00,
      "overdueDebt": 150.00,
      "weeklyBlockEnabled": true,
      "payoutHoldEnabled": false,
      "lastSettlementAt": "2026-04-10T12:00:00.000Z"
    }
  ],
  "total": 37
}
```

---

### 4. Country breakdown
`GET /finance/countries`

### Query params
- `range=today|week|month|year|custom`
- `from=<ISO>` optional
- `to=<ISO>` optional

### Response
```json
{
  "items": [
    {
      "country": "GT",
      "grossCommission": 6000.00,
      "commissionCollected": 4200.00,
      "outstandingDebt": 1800.00,
      "travelersWithDebt": 14,
      "shipmentsCount": 220,
      "approvedTransfersAmount": 3000.00,
      "rejectedTransfersAmount": 80.00
    }
  ]
}
```

---

### 5. Settlements / transfers overview
`GET /finance/settlements`

### Query params
- `range=today|week|month|year|custom`
- `from=<ISO>` optional
- `to=<ISO>` optional
- `status=submitted|approved|rejected` optional

### Response
```json
{
  "summary": {
    "submittedCount": 12,
    "approvedCount": 30,
    "rejectedCount": 2,
    "submittedAmount": 2400.00,
    "approvedAmount": 5100.00,
    "rejectedAmount": 150.00
  },
  "items": [
    {
      "transferId": "uuid",
      "travelerId": "uuid",
      "travelerName": "María López",
      "status": "submitted",
      "transferredAmount": 210.00,
      "bankReference": "ABC123",
      "createdAt": "2026-04-17T10:00:00.000Z"
    }
  ]
}
```

---

### 6. Finance health / aging buckets
`GET /finance/debt-aging`

### Response
```json
{
  "buckets": [
    { "label": "0-7", "amount": 500.00, "travelers": 8 },
    { "label": "8-30", "amount": 900.00, "travelers": 11 },
    { "label": "31-60", "amount": 400.00, "travelers": 4 },
    { "label": "61+", "amount": 250.00, "travelers": 2 }
  ]
}
```

---

## Suggested NestJS module
Create a dedicated module:
- `src/finance/finance.module.ts`
- `src/finance/finance.controller.ts`
- `src/finance/finance.service.ts`
- `src/finance/dto/*.ts`

Why separate:
- cleaner reporting code
- easier permission policy
- avoids stuffing reporting logic into commissions/transfers controllers

---

## Data sources likely needed
These endpoints will probably aggregate from:
- `TravelerCommission`
- `TravelerLedgerEntry`
- `TransferPayment`
- `WeeklySettlement`
- `TravelerProfile`
- `User`
- maybe `Shipment` for route/country dimensions

---

## Business definitions to lock down
Before implementing, agree on these definitions:

### grossCommission
Is it:
- all commission accrued in period, or
- only posted commission, or
- only collected commission?

### outstandingDebt
Is it:
- current traveler debt total, regardless of age, or
- only due + overdue?

### overdueDebt
Need exact overdue rule, for example:
- debt older than cutoff day, or
- debt tied to unpaid weekly settlement after grace period

### country dimension
Should country mean:
- traveler detected country
- route origin country
- destination country
- customer country

Recommendation:
start with traveler country + shipment direction, because that is operationally useful.

---

## Appsmith mapping
These endpoints map directly to `APPSMITH_FINANCE_DASHBOARD.md`:
- KPI cards -> `/finance/overview`
- line chart -> `/finance/revenue-series`
- debtor table -> `/finance/debtors`
- country chart/table -> `/finance/countries`
- transfer KPI panel -> `/finance/settlements`
- aging chart -> `/finance/debt-aging`

---

## Recommended implementation order
1. `/finance/overview`
2. `/finance/debtors`
3. `/finance/settlements`
4. `/finance/countries`
5. `/finance/revenue-series`
6. `/finance/debt-aging`

That gives the fastest business value.

---

## Minimum v1
If you want the smallest useful first version, build only:
- `/finance/overview`
- `/finance/debtors`
- `/finance/settlements`

That already answers most founder/operator questions.
