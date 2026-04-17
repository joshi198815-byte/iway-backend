# Appsmith blueprint: Finance Debt Aging v1

## Goal
Render debt aging buckets using:
- `GET /finance/debt-aging`

This page answers:
- cuánto de la deuda está reciente
- cuánto ya está envejecida
- cuántos travelers están dentro de cada tramo

---

## Page name
`FinanceDebtAging`

---

## Filters
- `Select_DebtAgingCountry`
  - all / GT / US
- `Button_RefreshDebtAging`
  - `{{getFinanceDebtAging.run()}}`

---

## Query
### `getFinanceDebtAging`
Method: `GET`
URL:
```javascript
{{`${appsmith.store.apiBase || 'https://api.iway.one/api'}/finance/debt-aging${Select_DebtAgingCountry.selectedOptionValue ? `?country=${Select_DebtAgingCountry.selectedOptionValue}` : ''}`}}
```
Headers:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}"
}
```

---

## Table
- `Table_DebtAging`
  - data:
```javascript
{{getFinanceDebtAging.data?.buckets || []}}
```

Columns:
- label
- amount
- travelers

---

## Chart
Bar chart:
- labels -> `{{(getFinanceDebtAging.data?.buckets || []).map(b => b.label)}}`
- amount series -> `{{(getFinanceDebtAging.data?.buckets || []).map(b => b.amount)}}`
- travelers series -> `{{(getFinanceDebtAging.data?.buckets || []).map(b => b.travelers)}}`

---

## Raw JSON block
- `JSON_DebtAgingRaw`
```javascript
{{getFinanceDebtAging.data}}
```

---

## Definition of done
- aging buckets load
- country filter works
- chart shows concentration of old debt clearly
