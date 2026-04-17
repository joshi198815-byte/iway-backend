# Appsmith blueprint: Finance Dashboard Final

## Goal
Unify the finance admin experience into one executive dashboard using the live backend endpoints:
- `GET /finance/overview`
- `GET /finance/debtors`
- `GET /finance/settlements`
- `GET /finance/countries`
- `GET /finance/revenue-series`
- `GET /finance/debt-aging`

This page should let admin answer, from one screen:
- cuánto ganamos hoy / semana / mes / año
- cuánto se ha cobrado
- cuánto está pendiente
- cuánto está vencido
- quiénes deben más
- en qué país está la deuda
- cuánto dinero está atorado en settlement review
- cómo evoluciona el ingreso en el tiempo

---

## Page name
`FinanceDashboard`

---

## Layout
Recommended 4 sections in a long desktop page.

### Section 1: Global filters
### Section 2: KPI cards
### Section 3: Charts
### Section 4: Operational finance tables

---

## Section 1: Global filters

### Widgets
- `Select_FinanceRange`
  - today / week / month / year
- `Select_FinanceCountry`
  - all / GT / US
- `Select_FinanceDirection`
  - all / gt_to_us / us_to_gt
- `Button_RefreshFinance`
  - onClick:
```javascript
{{FinanceDashboardFinalActions.refreshAll()}}
```

### Notes
- `country` should apply to overview, debtors, settlements, countries, debt-aging
- `direction` should apply to overview and revenue series

---

## Section 2: KPI cards
Use large stat cards.

### Main KPIs
- Gross Commission
```javascript
{{getFinanceOverview.data?.grossCommission || 0}}
```
- Commission Collected
```javascript
{{getFinanceOverview.data?.commissionCollected || 0}}
```
- Outstanding Debt
```javascript
{{getFinanceOverview.data?.outstandingDebt || 0}}
```
- Overdue Debt
```javascript
{{getFinanceOverview.data?.overdueDebt || 0}}
```
- Travelers With Debt
```javascript
{{getFinanceOverview.data?.travelersWithDebt || 0}}
```
- Blocked Travelers
```javascript
{{getFinanceOverview.data?.blockedTravelersWithDebt || 0}}
```
- Payout Hold Travelers
```javascript
{{getFinanceOverview.data?.payoutHoldTravelers || 0}}
```
- Pending Settlements Amount
```javascript
{{getFinanceOverview.data?.pendingTransfersAmount || 0}}
```
- Approved Transfers Amount
```javascript
{{getFinanceOverview.data?.approvedTransfersAmount || 0}}
```
- Rejected Transfers Amount
```javascript
{{getFinanceOverview.data?.rejectedTransfersAmount || 0}}
```

---

## Section 3: Charts

### Chart A: Revenue trend
Source:
- `getFinanceRevenueSeries`

Labels:
```javascript
{{(getFinanceRevenueSeries.data?.points || []).map(p => p.bucket)}}
```
Series:
- grossCommission
- commissionCollected
- newDebt

---

### Chart B: Debt aging
Source:
- `getFinanceDebtAging`

Labels:
```javascript
{{(getFinanceDebtAging.data?.buckets || []).map(b => b.label)}}
```
Series:
- amount
- travelers

---

### Chart C: Country comparison
Source:
- `getFinanceCountries`

Labels:
```javascript
{{(getFinanceCountries.data?.items || []).map(i => i.country)}}
```
Series:
- grossCommission
- outstandingDebt
- approvedTransfersAmount

---

## Section 4: Operational finance tables

### Table 1: Top debtors
Source:
- `getFinanceDebtors`

Columns:
- fullName
- email
- country
- travelerStatus
- currentDebt
- overdueDebt
- payoutHoldEnabled
- lastSettlementAt

Optional row action:
```javascript
{{navigateTo('Ledger', { travelerId: currentRow.travelerId })}}
```

---

### Table 2: Settlement activity
Source:
- `getFinanceSettlements`

Columns:
- transferId
- travelerName
- country
- status
- transferredAmount
- bankReference
- createdAt
- reviewedAt

Optional action:
```javascript
{{navigateTo('TransfersReview')}}
```

---

### Table 3: Country finance table
Source:
- `getFinanceCountries`

Columns:
- country
- grossCommission
- commissionCollected
- outstandingDebt
- travelersWithDebt
- shipmentsCount
- approvedTransfersAmount
- rejectedTransfersAmount

---

## Queries

### 1. getFinanceOverview
```javascript
{{
`${appsmith.store.apiBase || 'https://api.iway.one/api'}/finance/overview?range=${Select_FinanceRange.selectedOptionValue || 'month'}${Select_FinanceCountry.selectedOptionValue ? `&country=${Select_FinanceCountry.selectedOptionValue}` : ''}${Select_FinanceDirection.selectedOptionValue ? `&direction=${Select_FinanceDirection.selectedOptionValue}` : ''}`
}}
```

### 2. getFinanceDebtors
```javascript
{{
`${appsmith.store.apiBase || 'https://api.iway.one/api'}/finance/debtors?limit=20${Select_FinanceCountry.selectedOptionValue ? `&country=${Select_FinanceCountry.selectedOptionValue}` : ''}&sortBy=currentDebt&sortDir=desc`
}}
```

### 3. getFinanceSettlements
```javascript
{{
`${appsmith.store.apiBase || 'https://api.iway.one/api'}/finance/settlements?range=${Select_FinanceRange.selectedOptionValue || 'month'}${Select_FinanceCountry.selectedOptionValue ? `&country=${Select_FinanceCountry.selectedOptionValue}` : ''}`
}}
```

### 4. getFinanceCountries
```javascript
{{
`${appsmith.store.apiBase || 'https://api.iway.one/api'}/finance/countries?range=${Select_FinanceRange.selectedOptionValue || 'month'}`
}}
```

### 5. getFinanceRevenueSeries
```javascript
{{
`${appsmith.store.apiBase || 'https://api.iway.one/api'}/finance/revenue-series?range=${Select_FinanceRange.selectedOptionValue || 'month'}&granularity=day${Select_FinanceCountry.selectedOptionValue ? `&country=${Select_FinanceCountry.selectedOptionValue}` : ''}${Select_FinanceDirection.selectedOptionValue ? `&direction=${Select_FinanceDirection.selectedOptionValue}` : ''}`
}}
```

### 6. getFinanceDebtAging
```javascript
{{
`${appsmith.store.apiBase || 'https://api.iway.one/api'}/finance/debt-aging${Select_FinanceCountry.selectedOptionValue ? `?country=${Select_FinanceCountry.selectedOptionValue}` : ''}`
}}
```

All with header:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}"
}
```

---

## JSObject helper
Create `FinanceDashboardFinalActions`:
```javascript
export default {
  async refreshAll() {
    await getFinanceOverview.run();
    await getFinanceDebtors.run();
    await getFinanceSettlements.run();
    await getFinanceCountries.run();
    await getFinanceRevenueSeries.run();
    await getFinanceDebtAging.run();
  }
}
```

---

## Page events

### On page load
```javascript
{{FinanceDashboardFinalActions.refreshAll()}}
```

### On filter change
Run refreshAll.

---

## Recommended visual priority
1. KPI cards first
2. revenue trend chart second
3. top debtors third
4. settlements table fourth
5. country chart/table fifth
6. debt aging chart sixth

That order mirrors the questions an owner/operator asks first.

---

## Raw JSON blocks
Keep small collapsible raw JSON widgets during first rollout for:
- overview
- debtors
- settlements
- countries
- revenue-series
- debt-aging

Remove later when stable.

---

## Definition of done
This page is done when an admin can answer in under one minute:
- cuánto ganamos
- cuánto cobramos
- cuánto falta cobrar
- quiénes deben más
- dónde está concentrada la deuda
- cuánto dinero está atorado en revisión
- si la tendencia mejora o empeora
