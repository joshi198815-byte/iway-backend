# Appsmith build checklist

## Goal
Turn the prepared Appsmith blueprints into a real Appsmith app with the least guesswork possible.

Use this in order.

---

## Prerequisites
- production backend reachable
- first admin user created
- Appsmith origin added to `CORS_ORIGINS`
- admin login credentials ready

---

## Phase 1: create the app shell

### 1. Create Appsmith application
- create a new Appsmith app
- name it `iWay Admin`

### 2. Create pages
Create these pages in this order:
1. `Login`
2. `Dashboard`
3. `FinanceDashboard`
4. `TravelersReview`
5. `TransfersReview`
6. `Shipments`
7. `ShipmentDetail`
8. `Disputes`
9. `AntiFraud`
10. `Ledger`
11. `Pricing`
12. `AdminCollaborators`
13. `FinanceSettlements`
14. `FinanceCountries`
15. `FinanceRevenueSeries`
16. `FinanceDebtAging`

---

## Phase 2: global state and auth

### 3. Add login page
Follow:
- `APPSMITH_LOGIN_DASHBOARD.md`

Create and verify:
- `Input_Email`
- `Input_Password`
- `Input_ApiBase`
- `Button_Login`
- query `login`

### 4. Save global state after login
Must store:
- `jwt`
- `me`
- `apiBase`
- `isLoggedIn`

### 5. Add protected page guards
On every page except Login:
- redirect to `Login` when `jwt` missing

### 6. Add admin-only guard
On `AdminCollaborators`:
- redirect to `Dashboard` if role is not `admin`

---

## Phase 3: dashboard

### 7. Build Dashboard page
Follow:
- `APPSMITH_LOGIN_DASHBOARD.md`

Add:
- welcome card
- role display
- navigation buttons/cards
- logout button

---

## Phase 4: finance first

### 8. Build FinanceDashboard
Follow:
- `APPSMITH_FINANCE_DASHBOARD_FINAL.md`

Add queries:
- `getFinanceOverview`
- `getFinanceDebtors`
- `getFinanceSettlements`
- `getFinanceCountries`
- `getFinanceRevenueSeries`
- `getFinanceDebtAging`

Add JSObject:
- `FinanceDashboardFinalActions`

Verify:
- KPI cards load
- charts render
- debtors table renders
- settlements table renders
- country table renders

### 9. Optional separate finance subpages
If you want decomposed finance pages too, implement:
- `APPSMITH_FINANCE_SETTLEMENTS_V1.md`
- `APPSMITH_FINANCE_COUNTRIES_V1.md`
- `APPSMITH_FINANCE_REVENUE_SERIES_V1.md`
- `APPSMITH_FINANCE_DEBT_AGING_V1.md`

---

## Phase 5: operational review pages

### 10. Build TravelersReview
Follow:
- `APPSMITH_TRAVELERS_REVIEW_PAGE.md`

Critical verification:
- queue loads
- file preview works
- approve/reject works
- payout hold works
- run KYC works

### 11. Build TransfersReview
Follow:
- `APPSMITH_TRANSFERS_REVIEW_PAGE.md`

Critical verification:
- queue loads
- proof preview works
- approve/reject works

### 12. Build Shipments
Follow:
- `APPSMITH_SHIPMENTS_PAGE.md`

### 13. Build ShipmentDetail
Follow:
- `APPSMITH_SHIPMENT_DETAIL_PAGE.md`

Verify:
- shipment loads by `shipmentId`
- offers load
- tracking loads
- status update works

### 14. Build Disputes
Follow:
- `APPSMITH_DISPUTES_PAGE.md`

### 15. Build AntiFraud
Follow:
- `APPSMITH_ANTI_FRAUD_PAGE.md`

---

## Phase 6: internal admin and finance ops

### 16. Build Ledger
Follow:
- `APPSMITH_LEDGER_PAGE.md`

### 17. Build Pricing
Follow:
- `APPSMITH_PRICING_PAGE.md`

### 18. Build AdminCollaborators
Follow:
- `APPSMITH_ADMIN_COLLABORATORS_PAGE.md`

Critical verification:
- create collaborator works
- role update works
- reset password works

---

## Phase 7: verification checklist

### Auth
- login works
- `/auth/me` works
- logout works
- admin vs support visibility works

### File previews
- traveler document preview works
- traveler selfie preview works
- transfer proof preview works

### Finance
- all finance queries return data
- debtors table sorts correctly
- revenue chart renders
- country comparison renders

### Operations
- traveler review actions persist
- transfer review actions persist
- shipment status changes persist
- disputes resolve correctly
- anti-fraud recompute works

---

## Recommended first production rollout
If you want the smallest strong rollout, enable these pages first:
1. Login
2. Dashboard
3. FinanceDashboard
4. TravelersReview
5. TransfersReview
6. Shipments
7. ShipmentDetail

Then add:
- Disputes
- AntiFraud
- Ledger
- Pricing
- AdminCollaborators

---

## If you want me to build it directly
You need to give me one of these:

### Option A
- Appsmith URL
- admin credentials

### Option B
- a browser session already logged into Appsmith that I can control

Without one of those, I can prepare everything, but I cannot click around inside your real Appsmith workspace.
