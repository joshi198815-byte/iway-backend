# Appsmith blueprint: Finance Countries v1

## Goal
Show country-level finance visibility using:
- `GET /finance/countries`

Questions this page answers:
- en qué país se concentra el negocio
- en qué país se concentra la deuda
- en qué país se están aprobando más transferencias

---

## Page name
`FinanceCountries`

---

## Filters
- `Select_CountriesRange`
  - today / week / month / year
- `Button_RefreshCountries`
  - `{{getFinanceCountries.run()}}`

---

## Table / chart
- `Table_FinanceCountries`
  - data:
```javascript
{{getFinanceCountries.data?.items || []}}
```

Suggested columns:
- country
- grossCommission
- commissionCollected
- outstandingDebt
- travelersWithDebt
- shipmentsCount
- approvedTransfersAmount
- rejectedTransfersAmount

Optional chart:
- bar chart by `country`
- series:
  - `grossCommission`
  - `outstandingDebt`

---

## Query
### `getFinanceCountries`
Method: `GET`
URL:
```javascript
{{`${appsmith.store.apiBase || 'https://api.iway.one/api'}/finance/countries?range=${Select_CountriesRange.selectedOptionValue || 'month'}`}}
```
Headers:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}"
}
```

---

## Raw JSON block
- `JSON_FinanceCountriesRaw`
```javascript
{{getFinanceCountries.data}}
```

---

## Definition of done
- countries finance table loads
- admin can compare countries quickly
- admin can identify where debt is concentrated
