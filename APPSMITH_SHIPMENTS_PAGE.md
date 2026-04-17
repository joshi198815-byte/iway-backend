# Appsmith page blueprint: Shipments

## Goal
Allow `admin` and `support` to browse shipments, inspect status, and jump into shipment detail from Appsmith.

---

## Backend endpoints used

### Shipment list
`GET /shipments`

### Shipment detail
`GET /shipments/:id`

### Shipment status update
`POST /shipments/:id/status`

---

## Page name
`Shipments`

---

## Layout
Two-column layout.

### Left column
Shipment list and filters.

### Right column
Selected shipment summary and actions.

---

## Widgets

### Top bar
- `Text_Title`
  - value: `Shipments`
- `Button_Refresh`
  - onClick:
```javascript
{{getShipments.run()}}
```
- `Text_Count`
  - value:
```javascript
{{`${getShipments.data?.length || 0} envíos`}}
```

---

## Left column

### Search input
- `Input_SearchShipment`
  - placeholder: `Buscar por id, customer, traveler, estado, ruta`

### Status filter
- `Select_ShipmentStatusFilter`
  - options:
```javascript
{{[
  { label: 'Todos', value: '' },
  { label: 'Draft', value: 'draft' },
  { label: 'Published', value: 'published' },
  { label: 'Offered', value: 'offered' },
  { label: 'Assigned', value: 'assigned' },
  { label: 'Picked Up', value: 'picked_up' },
  { label: 'In Transit', value: 'in_transit' },
  { label: 'In Delivery', value: 'in_delivery' },
  { label: 'Delivered', value: 'delivered' },
  { label: 'Cancelled', value: 'cancelled' },
  { label: 'Disputed', value: 'disputed' }
]}}
```

### Table
- `Table_Shipments`
  - data:
```javascript
{{
(getShipments.data || []).filter(item => {
  const q = (Input_SearchShipment.text || '').toLowerCase().trim();
  const statusFilter = Select_ShipmentStatusFilter.selectedOptionValue || '';

  const matchesStatus = !statusFilter || item.status === statusFilter;
  if (!matchesStatus) return false;

  if (!q) return true;

  const shipmentId = (item.id || '').toLowerCase();
  const customer = (item.customer?.fullName || '').toLowerCase();
  const traveler = (item.assignedTraveler?.fullName || '').toLowerCase();
  const status = (item.status || '').toLowerCase();
  const route = `${item.originCity || ''} ${item.destinationCity || ''}`.toLowerCase();

  return shipmentId.includes(q) || customer.includes(q) || traveler.includes(q) || status.includes(q) || route.includes(q);
})
}}
```

### Suggested columns
- id
- customer name
- assigned traveler name
- status
- direction
- price / quoted amount if present
- createdAt

### Row selected action
```javascript
{{getShipmentDetail.run()}}
```

---

## Right column

### Shipment summary
- `Text_ShipmentId`
```javascript
{{Table_Shipments.selectedRow.id || '-'}}
```

- `Text_Customer`
```javascript
{{Table_Shipments.selectedRow.customer?.fullName || '-'}}
```

- `Text_Traveler`
```javascript
{{Table_Shipments.selectedRow.assignedTraveler?.fullName || '-'}}
```

- `Text_Status`
```javascript
{{Table_Shipments.selectedRow.status || '-'}}
```

- `Text_Direction`
```javascript
{{Table_Shipments.selectedRow.direction || '-'}}
```

- `Text_Origin`
```javascript
{{Table_Shipments.selectedRow.originCity || '-'}}
```

- `Text_Destination`
```javascript
{{Table_Shipments.selectedRow.destinationCity || '-'}}
```

---

### Raw shipment payload
- `JSON_ShipmentRaw`
  - source:
```javascript
{{getShipmentDetail.data || Table_Shipments.selectedRow}}
```

---

## Status action panel

### New status selector
- `Select_NewShipmentStatus`
  - options:
```javascript
{{[
  { label: 'Published', value: 'published' },
  { label: 'Assigned', value: 'assigned' },
  { label: 'Picked Up', value: 'picked_up' },
  { label: 'In Transit', value: 'in_transit' },
  { label: 'In Delivery', value: 'in_delivery' },
  { label: 'Delivered', value: 'delivered' },
  { label: 'Cancelled', value: 'cancelled' },
  { label: 'Disputed', value: 'disputed' }
]}}
```

### Update button
- `Button_UpdateShipmentStatus`
  - onClick:
```javascript
{{updateShipmentStatus.run()}}
```

### Open detail page button
- `Button_OpenShipmentDetail`
  - onClick:
```javascript
{{navigateTo('ShipmentDetail', { shipmentId: Table_Shipments.selectedRow.id })}}
```

---

## Queries

### Query 1: `getShipments`
Method: `GET`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/shipments
```
Headers:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}"
}
```
Run on page load: yes

---

### Query 2: `getShipmentDetail`
Method: `GET`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/shipments/{{Table_Shipments.selectedRow.id}}
```
Headers:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}"
}
```

---

### Query 3: `updateShipmentStatus`
Method: `POST`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/shipments/{{Table_Shipments.selectedRow.id}}/status
```
Body:
```json
{
  "status": "{{Select_NewShipmentStatus.selectedOptionValue}}"
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
showAlert('Estado actualizado', 'success');
getShipments.run();
getShipmentDetail.run();
}}
```

---

## Page events

### On page load
```javascript
{{getShipments.run()}}
```

### On table row selected
```javascript
{{getShipmentDetail.run()}}
```

---

## Operational notes
- This page is meant for broad operational browsing.
- Keep `JSON_ShipmentRaw` visible at first until live response shape is stable.
- The true deep workflow should live in `ShipmentDetail`.
- If the backend returns paginated results later, swap `getShipments.data || []` for the correct nested path.

## Definition of done
- shipments list loads
- filters work
- selecting a shipment loads detail
- status update works
- operator can jump to ShipmentDetail
