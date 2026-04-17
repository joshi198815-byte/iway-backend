# Appsmith page blueprint: Disputes

## Goal
Allow `admin` and `support` to review open disputes and resolve them from Appsmith.

---

## Backend endpoints used

### Queue
`GET /disputes/queue`

### Resolve dispute
`POST /disputes/:disputeId/resolve`

---

## Page name
`Disputes`

---

## Layout
Two-column layout.

### Left column
Dispute queue.

### Right column
Shipment/dispute detail and resolution form.

---

## Widgets

### Top bar
- `Text_Title`
  - value: `Disputes`
- `Button_Refresh`
  - onClick:
```javascript
{{getDisputesQueue.run()}}
```
- `Text_QueueCount`
  - value:
```javascript
{{`${getDisputesQueue.data?.length || 0} disputas`}}
```

---

## Left column

### Search input
- `Input_SearchDispute`
  - placeholder: `Buscar por shipment, usuario, motivo o estado`

### Table
- `Table_DisputesQueue`
  - data:
```javascript
{{
(getDisputesQueue.data || []).filter(item => {
  const q = (Input_SearchDispute.text || '').toLowerCase().trim();
  if (!q) return true;

  const shipmentId = (item.shipmentId || '').toLowerCase();
  const reason = (item.reason || '').toLowerCase();
  const status = (item.status || '').toLowerCase();
  const openerName = (item.opener?.fullName || '').toLowerCase();

  return shipmentId.includes(q) || reason.includes(q) || status.includes(q) || openerName.includes(q);
})
}}
```

### Suggested columns
- shipmentId
- openedBy / opener name
- reason
- status
- createdAt
- updatedAt

---

## Right column

### Dispute summary
- `Text_DisputeId`
```javascript
{{Table_DisputesQueue.selectedRow.id || '-'}}
```

- `Text_ShipmentId`
```javascript
{{Table_DisputesQueue.selectedRow.shipmentId || '-'}}
```

- `Text_OpenedBy`
```javascript
{{Table_DisputesQueue.selectedRow.opener?.fullName || Table_DisputesQueue.selectedRow.openedBy || '-'}}
```

- `Text_DisputeStatus`
```javascript
{{Table_DisputesQueue.selectedRow.status || '-'}}
```

- `Text_DisputeReason`
```javascript
{{Table_DisputesQueue.selectedRow.reason || '-'}}
```

- `Text_CreatedAt`
```javascript
{{Table_DisputesQueue.selectedRow.createdAt || '-'}}
```

---

### Shipment / dispute raw payload
- `JSON_DisputeRaw`
  - source:
```javascript
{{Table_DisputesQueue.selectedRow}}
```

This is useful during first rollout because queue payload may include shipment and participant details inline.

---

## Resolution panel

### Resolution selector
- `Select_DisputeResolution`
  - options:
```javascript
{{[
  { label: 'Resolver a favor del cliente', value: 'customer_favor' },
  { label: 'Resolver a favor del traveler', value: 'traveler_favor' },
  { label: 'Ajuste manual / conciliado', value: 'manual_resolution' },
  { label: 'Sin mérito / cerrar', value: 'dismissed' }
]}}
```

### Resolution notes
- `Input_DisputeResolution`
  - type: multiline
  - placeholder: `Escribe la resolución y notas operativas`

### Resolve button
- `Button_ResolveDispute`
  - onClick:
```javascript
{{resolveDispute.run()}}
```

### Disabled state
```javascript
{{
!Table_DisputesQueue.selectedRow.id ||
!Select_DisputeResolution.selectedOptionValue ||
!Input_DisputeResolution.text.trim()
}}
```

---

## Queries

### Query 1: `getDisputesQueue`
Method: `GET`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/disputes/queue
```
Headers:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}"
}
```
Run on page load: yes

---

### Query 2: `resolveDispute`
Method: `POST`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/disputes/{{Table_DisputesQueue.selectedRow.id}}/resolve
```
Body:
```json
{
  "resolution": "{{Select_DisputeResolution.selectedOptionValue}}",
  "notes": "{{Input_DisputeResolution.text}}"
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
showAlert('Disputa resuelta', 'success');
getDisputesQueue.run();
}}
```

---

## Page events

### On page load
```javascript
{{getDisputesQueue.run()}}
```

---

## Operational notes
- Start with queue + resolution only. Do not overcomplicate the first version.
- If queue already includes shipment/customer/traveler details, show them directly from `selectedRow`.
- If later you need a deeper case view, add a second page `DisputeDetail` fed by selected dispute id.
- Keep `JSON_DisputeRaw` visible initially until you confirm the live payload shape.

## Definition of done
- disputes queue loads
- operator can inspect dispute detail
- resolution requires notes
- dispute can be resolved from Appsmith
- queue refreshes after resolution
