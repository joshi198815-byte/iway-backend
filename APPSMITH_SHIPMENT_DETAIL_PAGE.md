# Appsmith page blueprint: Shipment Detail

## Goal
Give `admin` and `support` a deeper operational view for one shipment, including offers, tracking timeline, and status management.

---

## Backend endpoints used

### Shipment detail
`GET /shipments/:id`

### Offers for shipment
`GET /offers/shipment/:shipmentId`

### Tracking timeline
`GET /tracking/shipment/:shipmentId/timeline`

### Shipment status update
`POST /shipments/:id/status`

---

## Page name
`ShipmentDetail`

Route parameter expected:
- `shipmentId`

---

## Layout
Single detailed page with stacked sections.

Sections:
1. shipment summary
2. participants
3. offers
4. tracking timeline
5. status actions
6. raw payload

---

## Widgets

### Header
- `Text_Title`
  - value:
```javascript
{{`Shipment ${appsmith.URL.queryParams.shipmentId || ''}`}}
```
- `Button_Back`
  - onClick:
```javascript
{{navigateTo('Shipments')}}
```
- `Button_Refresh`
  - onClick:
```javascript
{{ShipmentDetailActions.refreshAll()}}
```

---

## Shipment summary section
- `Text_Status`
```javascript
{{getShipmentDetail.data?.status || '-'}}
```
- `Text_Direction`
```javascript
{{getShipmentDetail.data?.direction || '-'}}
```
- `Text_Origin`
```javascript
{{getShipmentDetail.data?.originCity || '-'}}
```
- `Text_Destination`
```javascript
{{getShipmentDetail.data?.destinationCity || '-'}}
```
- `Text_CreatedAt`
```javascript
{{getShipmentDetail.data?.createdAt || '-'}}
```

---

## Participants section
- `Text_Customer`
```javascript
{{getShipmentDetail.data?.customer?.fullName || '-'}}
```
- `Text_CustomerPhone`
```javascript
{{getShipmentDetail.data?.customer?.phone || '-'}}
```
- `Text_Traveler`
```javascript
{{getShipmentDetail.data?.assignedTraveler?.fullName || '-'}}
```
- `Text_TravelerPhone`
```javascript
{{getShipmentDetail.data?.assignedTraveler?.phone || '-'}}
```

---

## Offers section
- `Table_ShipmentOffers`
  - data:
```javascript
{{getShipmentOffers.data || []}}
```

### Suggested columns
- id
- traveler name
- offeredPrice
- status
- createdAt

---

## Tracking timeline section
- `Table_TrackingTimeline`
  - data:
```javascript
{{getTrackingTimeline.data || []}}
```

### Suggested columns
- status
- latitude
- longitude
- note if present
- createdAt

---

## Status action section
- `Select_ShipmentDetailStatus`
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
- `Button_UpdateShipmentDetailStatus`
  - onClick:
```javascript
{{updateShipmentDetailStatus.run()}}
```

---

## Raw JSON
- `JSON_ShipmentDetailRaw`
  - source:
```javascript
{{getShipmentDetail.data}}
```

---

## Queries

### Query 1: `getShipmentDetail`
Method: `GET`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/shipments/{{appsmith.URL.queryParams.shipmentId}}
```
Headers:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}"
}
```

---

### Query 2: `getShipmentOffers`
Method: `GET`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/offers/shipment/{{appsmith.URL.queryParams.shipmentId}}
```
Headers:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}"
}
```

---

### Query 3: `getTrackingTimeline`
Method: `GET`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/tracking/shipment/{{appsmith.URL.queryParams.shipmentId}}/timeline
```
Headers:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}"
}
```

---

### Query 4: `updateShipmentDetailStatus`
Method: `POST`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/shipments/{{appsmith.URL.queryParams.shipmentId}}/status
```
Body:
```json
{
  "status": "{{Select_ShipmentDetailStatus.selectedOptionValue}}"
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
ShipmentDetailActions.refreshAll();
}}
```

---

## JSObject helper
Create `ShipmentDetailActions`:
```javascript
export default {
  async refreshAll() {
    await getShipmentDetail.run();
    await getShipmentOffers.run();
    await getTrackingTimeline.run();
  }
}
```

---

## Page events

### On page load
```javascript
{{ShipmentDetailActions.refreshAll()}}
```

---

## Operational notes
- This page is the best place to expand later with chat preview, dispute shortcuts, and proof-of-delivery evidence.
- If timeline payload includes map-ready coordinates, later you can add a map widget.
- Keep the raw JSON visible during first rollout to stabilize bindings against the real payload shape.

## Definition of done
- shipment detail loads by query param
- offers load
- tracking timeline loads
- status can be changed
- refresh reloads all sections
