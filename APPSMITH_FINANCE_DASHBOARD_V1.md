# Appsmith blueprint: Finance Dashboard v1

## Goal
Build a real Appsmith finance dashboard using the finance endpoints that already exist in backend:
- `GET /finance/overview`
- `GET /finance/debtors`

This v1 is meant to answer:
- cuánto ganamos hoy / semana / mes / año
- cuánto sigue pendiente
- cuánto está vencido
- cuántos travelers deben
- quiénes deben más

---

## Page name
`FinanceDashboard`

---

## Layout
Three sections:
1. top KPI cards
2. filters row
3. debtors table

---

## Filters row

### Range selector
- `Select_FinanceRange`
  - options:
```javascript
{{[
  { label: 'Hoy', value: 'today' },
  { label: 'Semana', value: 'week' },
  { label: 'Mes', value: 'month' },
  { label: 'Año', value: 'year' }
]}}
```
  - default: `month`

### Country selector
- `Select_FinanceCountry`
  - options:
```javascript
{{[
  { label: 'Todos', value: '' },
  { label: 'GT', value: 'GT' },
  { label: 'US', value: 'US' }
]}}
```

### Direction selector
- `Select_FinanceDirection`
  - options:
```javascript
{{[
  { label: 'Todas', value: '' },
  { label: 'GT -> US', value: 'gt_to_us' },
  { label: 'US -> GT', value: 'us_to_gt' }
]}}
```

### Refresh button
- `Button_RefreshFinance`
  - onClick:
```javascript
{{FinanceDashboardActions.refreshAll()}}
```

---

## KPI cards

### Revenue generated
- `Stat_GrossCommission`
```javascript
{{getFinanceOverview.data?.grossCommission || 0}}
```

### Collected commission
- `Stat_CommissionCollected`
```javascript
{{getFinanceOverview.data?.commissionCollected || 0}}
```

### Outstanding debt
- `Stat_OutstandingDebt`
```javascript
{{getFinanceOverview.data?.outstandingDebt || 0}}
```

### Overdue debt
- `Stat_OverdueDebt`
```javascript
{{getFinanceOverview.data?.overdueDebt || 0}}
```

### Travelers with debt
- `Stat_TravelersWithDebt`
```javascript
{{getFinanceOverview.data?.travelersWithDebt || 0}}
```

### Blocked travelers with debt
- `Stat_BlockedTravelers`
```javascript
{{getFinanceOverview.data?.blockedTravelersWithDebt || 0}}
```

### Payout hold travelers
- `Stat_PayoutHoldTravelers`
```javascript
{{getFinanceOverview.data?.payoutHoldTravelers || 0}}
```

### Pending settlements amount
- `Stat_PendingTransfers`
```javascript
{{getFinanceOverview.data?.pendingTransfersAmount || 0}}
```

### Approved transfers amount
- `Stat_ApprovedTransfers`
```javascript
{{getFinanceOverview.data?.approvedTransfersAmount || 0}}
```

### Rejected transfers amount
- `Stat_RejectedTransfers`
```javascript
{{getFinanceOverview.data?.rejectedTransfersAmount || 0}}
```

---

## Debtors filters

### Only overdue
- `Switch_OnlyOverdue`

### Only blocked
- `Switch_OnlyBlocked`

### Only payout hold
- `Switch_OnlyPayoutHold`

### Sort by
- `Select_DebtorsSortBy`
  - options:
```javascript
{{[
  { label: 'Deuda actual', value: 'currentDebt' },
  { label: 'Deuda vencida', value: 'overdueDebt' },
  { label: 'Último settlement', value: 'lastSettlementAt' }
]}}
```

### Sort dir
- `Select_DebtorsSortDir`
  - options:
```javascript
{{[
  { label: 'Desc', value: 'desc' },
  { label: 'Asc', value: 'asc' }
]}}
```

---

## Debtors table
- `Table_Debtors`
  - data:
```javascript
{{getFinanceDebtors.data?.items || []}}
```

### Suggested columns
- fullName
- email
- phone
- country
- travelerStatus
- currentDebt
- overdueDebt
- weeklyBlockEnabled
- payoutHoldEnabled
- lastSettlementAt

### Optional row action
Add a button column:
- label: `Open Ledger`
- action:
```javascript
{{navigateTo('Ledger', { travelerId: currentRow.travelerId })}}
```

---

## Raw JSON blocks
During first rollout, keep these visible.

### Overview raw
- `JSON_FinanceOverviewRaw`
```javascript
{{getFinanceOverview.data}}
```

### Debtors raw
- `JSON_FinanceDebtorsRaw`
```javascript
{{getFinanceDebtors.data}}
```

---

## Queries

### Query 1: `getFinanceOverview`
Method: `GET`
URL:
```javascript
{{
`${appsmith.store.apiBase || 'https://api.iway.one/api'}/finance/overview?range=${Select_FinanceRange.selectedOptionValue || 'month'}${Select_FinanceCountry.selectedOptionValue ? `&country=${Select_FinanceCountry.selectedOptionValue}` : ''}${Select_FinanceDirection.selectedOptionValue ? `&direction=${Select_FinanceDirection.selectedOptionValue}` : ''}`
}}
```
Headers:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}"
}
```

---

### Query 2: `getFinanceDebtors`
Method: `GET`
URL:
```javascript
{{
`${appsmith.store.apiBase || 'https://api.iway.one/api'}/finance/debtors?limit=50${Select_FinanceCountry.selectedOptionValue ? `&country=${Select_FinanceCountry.selectedOptionValue}` : ''}${Switch_OnlyOverdue.isSwitchedOn ? '&onlyOverdue=true' : ''}${Switch_OnlyBlocked.isSwitchedOn ? '&onlyBlocked=true' : ''}${Switch_OnlyPayoutHold.isSwitchedOn ? '&onlyPayoutHold=true' : ''}&sortBy=${Select_DebtorsSortBy.selectedOptionValue || 'currentDebt'}&sortDir=${Select_DebtorsSortDir.selectedOptionValue || 'desc'}`
}}
```
Headers:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}"
}
```

---

## JSObject helper
Create `FinanceDashboardActions`:
```javascript
export default {
  async refreshAll() {
    await getFinanceOverview.run();
    await getFinanceDebtors.run();
  }
}
```

---

## Page events

### On page load
```javascript
{{FinanceDashboardActions.refreshAll()}}
```

### On filter change
Run:
```javascript
{{FinanceDashboardActions.refreshAll()}}
```

---

## Operational notes
- This is v1 and already useful for owner/admin visibility.
- Revenue and debt come from the real backend aggregates just added.
- Country and direction filters affect some metrics more directly than others because the current model mixes period-based aggregates and current debt snapshots.
- Keep the raw JSON visible in the first rollout to validate live production values.
- Later versions should add `/finance/settlements`, `/finance/countries`, `/finance/revenue-series`, and `/finance/debt-aging`.

## Definition of done
- finance overview loads
- filters work
- debtors table loads
- sorting works
- admin can jump from debtor row to Ledger
- page answers owner questions in under a minute
