# Appsmith blueprint: Finance Dashboard / Wallet

## Goal
Give admin a finance cockpit to answer questions like:
- cuánto ganamos hoy
- cuánto ganamos esta semana / mes / año
- cuánto está pendiente por cobrar
- quiénes deben dinero
- cuánto debemos transferir o liquidar
- desglose por país / ruta / tipo de traveler

This is the closest thing to an admin wallet / treasury dashboard.

---

## Important reality check
Current backend coverage already supports pieces of this through:
- traveler commission summary
- traveler ledger
- manual ledger adjustments
- pricing settings
- transfer reviews

But a full global finance dashboard likely needs either:
1. aggregation queries in Appsmith over multiple endpoints, or
2. new backend finance-report endpoints for performance and accuracy.

Recommendation: add dedicated backend reporting endpoints for v2.

---

## Page name
`FinanceDashboard`

---

## Metrics the admin should see

### Revenue metrics
- gross commissions today
- gross commissions this week
- gross commissions this month
- gross commissions this year

### Debt metrics
- total outstanding traveler debt
- total overdue debt
- number of travelers with debt
- top debtors

### Transfer / settlement metrics
- transfers submitted today
- approved transfers this week
- rejected transfers this week
- pending settlement amount

### Geography metrics
- commissions by country
- debt by country
- shipments by route or corridor

### Risk-finance crossover
- debtors currently blocked
- debtors on payout hold
- debt trend over time

---

## Ideal backend endpoints for v2

### 1. Finance overview
`GET /finance/overview?range=today|week|month|year`

Suggested response:
```json
{
  "range": "month",
  "grossCommission": 12000.50,
  "netCollected": 8700.25,
  "outstandingDebt": 3300.25,
  "overdueDebt": 1500.00,
  "travelersWithDebt": 42,
  "pendingTransfersAmount": 2200.00,
  "approvedTransfersAmount": 5600.00,
  "rejectedTransfersAmount": 350.00
}
```

### 2. Revenue over time
`GET /finance/revenue-series?granularity=day&range=month`

### 3. Debt leaderboard
`GET /finance/debtors?limit=50&country=GT`

### 4. Country breakdown
`GET /finance/countries?range=month`

### 5. Settlements overview
`GET /finance/settlements?range=week`

---

## If backend stays as-is for v1
You can still build a partial finance dashboard using:
- `/commissions/traveler/:travelerId/summary`
- `/commissions/traveler/:travelerId/ledger`
- `/transfers/review-queue`
- `/commissions/settings`

But it will not be a true global wallet unless you:
- have a traveler master list to iterate over, and
- accept heavier Appsmith-side aggregation.

That is okay for a first internal version, but not my favorite long-term solution.

---

## Recommended page layout

### Top KPIs row
Cards:
- Revenue Today
- Revenue Week
- Revenue Month
- Outstanding Debt
- Overdue Debt
- Pending Settlements

### Middle row
- line chart: revenue over time
- bar chart: commissions by country
- donut chart: transfer review status

### Bottom row
- table: top debtors
- table: blocked debtors / payout hold

---

## Useful filters
- date range
- country
- traveler type
- role corridor: GT->US or US->GT
- debt status: current / overdue / blocked

---

## Debtors table fields
- traveler name
- traveler email
- traveler phone
- country
- current debt
- overdue amount
- payout hold enabled
- weekly block enabled
- traveler status
- last settlement date
- quick link to Ledger

---

## Country breakdown table fields
- country
- gross commission
- outstanding debt
- shipments count
- transfers approved
- transfers rejected

---

## Appsmith navigation links
From this page, admin should be able to jump to:
- Ledger
- TransfersReview
- TravelersReview
- Shipments

---

## Recommendation
Yes, you should absolutely have this page.

If your real business question is:
"how much are we earning, who owes us, and where is the money stuck?"
then this dashboard is one of the most important admin pages.

I would place it near the top of the roadmap, just after the operational MVP.

---

## Suggested delivery order
1. operational MVP first
2. FinanceDashboard second wave
3. dedicated backend reporting endpoints third

---

## Definition of done
This page is done when admin can answer, in under one minute:
- cuánto ganó iWay hoy / semana / mes / año
- cuánto sigue pendiente por cobrar
- quiénes deben más
- en qué país / corredor se concentra la deuda
- cuánto está pendiente de aprobar o liquidar
