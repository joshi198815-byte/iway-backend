# Appsmith blueprint: Finance Revenue Series v1

## Goal
Render the revenue trend chart using:
- `GET /finance/revenue-series`

This page answers:
- cómo viene evolucionando el ingreso
- qué días/semanas/meses sube o cae
- cuánto se genera vs cuánto se cobra

---

## Page name
`FinanceRevenueSeries`

---

## Filters
- `Select_RevenueRange`
  - week / month / year
- `Select_RevenueGranularity`
  - day / week / month
- `Select_RevenueCountry`
  - all / GT / US
- `Select_RevenueDirection`
  - all / gt_to_us / us_to_gt
- `Button_RefreshRevenue`
  - `{{getFinanceRevenueSeries.run()}}`

---

## Query
### `getFinanceRevenueSeries`
Method: `GET`
URL:
```javascript
{{
`${appsmith.store.apiBase || 'https://api.iway.one/api'}/finance/revenue-series?range=${Select_RevenueRange.selectedOptionValue || 'month'}&granularity=${Select_RevenueGranularity.selectedOptionValue || 'day'}${Select_RevenueCountry.selectedOptionValue ? `&country=${Select_RevenueCountry.selectedOptionValue}` : ''}${Select_RevenueDirection.selectedOptionValue ? `&direction=${Select_RevenueDirection.selectedOptionValue}` : ''}`
}}
```
Headers:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}"
}
```

---

## Chart
Use a line or area chart.

### Labels
```javascript
{{(getFinanceRevenueSeries.data?.points || []).map(p => p.bucket)}}
```

### Series 1: Gross Commission
```javascript
{{(getFinanceRevenueSeries.data?.points || []).map(p => p.grossCommission)}}
```

### Series 2: Commission Collected
```javascript
{{(getFinanceRevenueSeries.data?.points || []).map(p => p.commissionCollected)}}
```

### Series 3: New Debt
```javascript
{{(getFinanceRevenueSeries.data?.points || []).map(p => p.newDebt)}}
```

---

## Table
- `Table_RevenueSeries`
  - data:
```javascript
{{getFinanceRevenueSeries.data?.points || []}}
```

Columns:
- bucket
- grossCommission
- commissionCollected
- newDebt

---

## Raw JSON block
- `JSON_RevenueSeriesRaw`
```javascript
{{getFinanceRevenueSeries.data}}
```

---

## Definition of done
- series loads
- filters work
- chart renders trend over time
- admin can compare generated vs collected vs new debt
