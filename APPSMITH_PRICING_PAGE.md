# Appsmith page blueprint: Pricing

## Goal
Allow `admin` and `support` to inspect and update commission/pricing settings from Appsmith.

---

## Backend endpoints used

### Get settings
`GET /commissions/settings`

### Update settings
`POST /commissions/settings`

---

## Page name
`Pricing`

---

## Layout
Single-page form with current settings, edit fields, and save action.

---

## Widgets

### Header
- `Text_Title`
  - value: `Pricing`
- `Button_Refresh`
  - onClick:
```javascript
{{getPricingSettings.run()}}
```

---

## Current settings display
- `Text_CommissionPerLb_Current`
```javascript
{{getPricingSettings.data?.commissionPerLb || '-'}}
```

- `Text_GroundCommissionPercent_Current`
```javascript
{{getPricingSettings.data?.groundCommissionPercent || '-'}}
```

---

## Editable form

### Commission per lb
- `Input_CommissionPerLb`
  - input type: number
  - default text:
```javascript
{{getPricingSettings.data?.commissionPerLb || ''}}
```

### Ground commission percent
- `Input_GroundCommissionPercent`
  - input type: number
  - default text:
```javascript
{{getPricingSettings.data?.groundCommissionPercent || ''}}
```

### Save button
- `Button_SavePricing`
  - onClick:
```javascript
{{updatePricingSettings.run()}}
```

### Disabled state
```javascript
{{
!Input_CommissionPerLb.text ||
!Input_GroundCommissionPercent.text
}}
```

---

## Raw JSON block
- `JSON_PricingRaw`
  - source:
```javascript
{{getPricingSettings.data}}
```

---

## Queries

### Query 1: `getPricingSettings`
Method: `GET`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/commissions/settings
```
Headers:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}"
}
```
Run on page load: yes

---

### Query 2: `updatePricingSettings`
Method: `POST`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/commissions/settings
```
Body:
```json
{
  "commissionPerLb": {{Number(Input_CommissionPerLb.text)}},
  "groundCommissionPercent": {{Number(Input_GroundCommissionPercent.text)}}
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
showAlert('Pricing actualizado', 'success');
getPricingSettings.run();
}}
```

---

## Page events

### On page load
```javascript
{{getPricingSettings.run()}}
```

---

## Operational notes
- Keep this page very simple in v1.
- Use numbers exactly as backend expects them. If the API later expects decimal strings, switch payload fields accordingly.
- Leave the raw JSON block visible in first rollout to verify live response shape.
- Consider restricting edit access to `admin` later if business policy requires it.

## Definition of done
- current pricing settings load
- operator can edit both values
- save works
- refreshed values display after save
