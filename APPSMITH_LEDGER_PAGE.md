# Appsmith page blueprint: Ledger

## Goal
Allow `admin` and `support` to inspect traveler commissions, balance history, weekly settlement context, and manual ledger adjustments.

---

## Backend endpoints used

### Traveler summary
`GET /commissions/traveler/:travelerId/summary`

### Traveler ledger
`GET /commissions/traveler/:travelerId/ledger`

### Manual adjustment
`POST /commissions/traveler/:travelerId/ledger-adjustments`

---

## Page name
`Ledger`

---

## Layout
Two-column layout.

### Left column
Traveler selector / search.

### Right column
Traveler financial summary, ledger table, and manual adjustment form.

---

## Widgets

### Top bar
- `Text_Title`
  - value: `Ledger`

---

## Left column

### Traveler ID input
- `Input_TravelerId`
  - placeholder: `Traveler userId`

### Load button
- `Button_LoadTravelerLedger`
  - onClick:
```javascript
{{LedgerActions.refreshAll()}}
```

### Optional helper text
- `Text_LedgerHelp`
  - value: `En la primera versión puedes entrar con userId del traveler desde Travelers Review, Shipments o búsquedas internas.`

---

## Right column

### Summary section
- `Text_TravelerName`
```javascript
{{getTravelerCommissionSummary.data?.traveler?.fullName || '-'}}
```

- `Text_TravelerEmail`
```javascript
{{getTravelerCommissionSummary.data?.traveler?.email || '-'}}
```

- `Text_CurrentDebt`
```javascript
{{getTravelerCommissionSummary.data?.summary?.currentDebt || getTravelerCommissionSummary.data?.currentDebt || '-'}}
```

- `Text_Balance`
```javascript
{{getTravelerCommissionSummary.data?.summary?.balance || getTravelerCommissionSummary.data?.balance || '-'}}
```

- `Text_WeeklyBlock`
```javascript
{{String(getTravelerCommissionSummary.data?.summary?.weeklyBlockEnabled || getTravelerCommissionSummary.data?.weeklyBlockEnabled || false)}}
```

- `Text_LastSettlement`
```javascript
{{getTravelerCommissionSummary.data?.summary?.lastSettlementAt || '-'}}
```

---

### Raw summary block
- `JSON_LedgerSummaryRaw`
  - source:
```javascript
{{getTravelerCommissionSummary.data}}
```

---

### Ledger entries table
- `Table_LedgerEntries`
  - data:
```javascript
{{getTravelerLedger.data?.entries || getTravelerLedger.data || []}}
```

### Suggested columns
- occurredAt
- kind
- direction
- status
- amount
- balanceAfter
- description
- createdBy

---

## Manual adjustment panel

### Direction selector
- `Select_AdjustmentDirection`
  - options:
```javascript
{{[
  { label: 'Debit', value: 'debit' },
  { label: 'Credit', value: 'credit' }
]}}
```

### Amount input
- `Input_AdjustmentAmount`
  - input type: number

### Description input
- `Input_AdjustmentDescription`
  - type: multiline
  - placeholder: `Motivo del ajuste manual`

### Submit button
- `Button_CreateAdjustment`
  - onClick:
```javascript
{{createLedgerAdjustment.run()}}
```

### Disabled state
```javascript
{{
!Input_TravelerId.text.trim() ||
!Select_AdjustmentDirection.selectedOptionValue ||
!Input_AdjustmentAmount.text ||
!Input_AdjustmentDescription.text.trim()
}}
```

---

## Queries

### Query 1: `getTravelerCommissionSummary`
Method: `GET`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/commissions/traveler/{{Input_TravelerId.text.trim()}}/summary
```
Headers:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}"
}
```

---

### Query 2: `getTravelerLedger`
Method: `GET`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/commissions/traveler/{{Input_TravelerId.text.trim()}}/ledger
```
Headers:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}"
}
```

---

### Query 3: `createLedgerAdjustment`
Method: `POST`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/commissions/traveler/{{Input_TravelerId.text.trim()}}/ledger-adjustments
```
Body:
```json
{
  "direction": "{{Select_AdjustmentDirection.selectedOptionValue}}",
  "amount": {{Number(Input_AdjustmentAmount.text)}},
  "description": "{{Input_AdjustmentDescription.text}}"
}
```
Headers:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}",
  "Content-Type": "application/json"
}
```
On success:
```javascript
{{
showAlert('Ajuste aplicado', 'success');
LedgerActions.refreshAll();
}}
```

---

## JSObject helper
Create `LedgerActions`:
```javascript
export default {
  async refreshAll() {
    await getTravelerCommissionSummary.run();
    await getTravelerLedger.run();
  }
}
```

---

## Page events
- No auto-load required unless you pass a query param later.
- First version can be operator-driven with traveler userId.

Optional later:
```javascript
{{
appsmith.URL.queryParams.travelerId ? Input_TravelerId.setValue(appsmith.URL.queryParams.travelerId) : ''
}}
```

---

## Operational notes
- This first version assumes the operator already knows the traveler userId.
- Later you can add a traveler lookup table or deep-link from Travelers Review and Shipments.
- Keep raw summary visible until you confirm the exact production response shape.
- If backend uses decimals serialized as strings, keep displaying them as strings unless you need formatting.

## Definition of done
- operator enters travelerId
- summary loads
- ledger table loads
- manual adjustment works
- summary and ledger refresh after adjustment
