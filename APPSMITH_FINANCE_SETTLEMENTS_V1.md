# Appsmith blueprint: Finance Settlements v1

## Goal
Show treasury / settlement visibility using the live backend endpoint:
- `GET /finance/settlements`

This page helps answer:
- cuánto está pendiente de revisar
- cuánto fue aprobado
- cuánto fue rechazado
- quién mandó cada transferencia
- qué monto está atorado

---

## Page name
`FinanceSettlements`

---

## Filters
- `Select_SettlementsRange`
  - today / week / month / year
- `Select_SettlementsCountry`
  - all / GT / US
- `Select_SettlementsStatus`
  - all / submitted / approved / rejected
- `Button_RefreshSettlements`
  - `{{getFinanceSettlements.run()}}`

---

## KPI cards
- submittedCount -> `{{getFinanceSettlements.data?.summary?.submittedCount || 0}}`
- approvedCount -> `{{getFinanceSettlements.data?.summary?.approvedCount || 0}}`
- rejectedCount -> `{{getFinanceSettlements.data?.summary?.rejectedCount || 0}}`
- submittedAmount -> `{{getFinanceSettlements.data?.summary?.submittedAmount || 0}}`
- approvedAmount -> `{{getFinanceSettlements.data?.summary?.approvedAmount || 0}}`
- rejectedAmount -> `{{getFinanceSettlements.data?.summary?.rejectedAmount || 0}}`

---

## Table
- `Table_FinanceSettlements`
  - data:
```javascript
{{getFinanceSettlements.data?.items || []}}
```

Suggested columns:
- transferId
- travelerName
- travelerEmail
- country
- status
- transferredAmount
- bankReference
- createdAt
- reviewedAt

Optional action button:
- `Open Transfers Review`
- `{{navigateTo('TransfersReview')}}`

---

## Query
### `getFinanceSettlements`
Method: `GET`
URL:
```javascript
{{
`${appsmith.store.apiBase || 'https://api.iway.one/api'}/finance/settlements?range=${Select_SettlementsRange.selectedOptionValue || 'month'}${Select_SettlementsCountry.selectedOptionValue ? `&country=${Select_SettlementsCountry.selectedOptionValue}` : ''}${Select_SettlementsStatus.selectedOptionValue ? `&status=${Select_SettlementsStatus.selectedOptionValue}` : ''}`
}}
```
Headers:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}"
}
```

---

## Raw JSON block
- `JSON_FinanceSettlementsRaw`
```javascript
{{getFinanceSettlements.data}}
```

---

## Definition of done
- settlements KPI cards load
- settlements table loads
- range/country/status filters work
- operator can identify pending money quickly
