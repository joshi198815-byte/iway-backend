# Appsmith page blueprint: Anti-Fraud

## Goal
Give `admin` and `support` a browser-based queue to inspect risky users, review flags, and recompute fraud signals.

---

## Backend endpoints used

### Review queue
`GET /anti-fraud/review-queue`

### User flags
`GET /anti-fraud/user/:userId/flags`

### Recompute signals
`POST /anti-fraud/user/:userId/recompute`

---

## Page name
`AntiFraud`

---

## Layout
Two-column layout.

### Left column
Risk queue table.

### Right column
Selected user detail, flags, and operator actions.

---

## Widgets

### Top bar
- `Text_Title`
  - value: `Anti-Fraud`
- `Button_Refresh`
  - onClick:
```javascript
{{getAntiFraudQueue.run()}}
```
- `Text_QueueCount`
  - value:
```javascript
{{`${getAntiFraudQueue.data?.length || 0} casos`}}
```

---

## Left column

### Search input
- `Input_SearchRisk`
  - placeholder: `Buscar por nombre, email, teléfono o score`

### Queue table
- `Table_AntiFraudQueue`
  - data:
```javascript
{{
(getAntiFraudQueue.data || []).filter(item => {
  const q = (Input_SearchRisk.text || '').toLowerCase().trim();
  if (!q) return true;

  const name = (item.user?.fullName || item.fullName || '').toLowerCase();
  const email = (item.user?.email || item.email || '').toLowerCase();
  const phone = (item.user?.phone || item.phone || '').toLowerCase();
  const score = String(item.riskScore || item.trustScore || '').toLowerCase();

  return name.includes(q) || email.includes(q) || phone.includes(q) || score.includes(q);
})
}}
```

### Suggested columns
- full name
- email
- phone
- role
- riskScore or trustScore
- status
- createdAt or updatedAt

### Row selected action
```javascript
{{getUserFlags.run()}}
```

---

## Right column

### User summary
- `Text_UserName`
```javascript
{{Table_AntiFraudQueue.selectedRow.user?.fullName || Table_AntiFraudQueue.selectedRow.fullName || '-'}}
```

- `Text_UserEmail`
```javascript
{{Table_AntiFraudQueue.selectedRow.user?.email || Table_AntiFraudQueue.selectedRow.email || '-'}}
```

- `Text_UserPhone`
```javascript
{{Table_AntiFraudQueue.selectedRow.user?.phone || Table_AntiFraudQueue.selectedRow.phone || '-'}}
```

- `Text_UserRole`
```javascript
{{Table_AntiFraudQueue.selectedRow.user?.role || Table_AntiFraudQueue.selectedRow.role || '-'}}
```

- `Text_RiskScore`
```javascript
{{Table_AntiFraudQueue.selectedRow.riskScore || Table_AntiFraudQueue.selectedRow.trustScore || '-'}}
```

- `Text_UserStatus`
```javascript
{{Table_AntiFraudQueue.selectedRow.status || Table_AntiFraudQueue.selectedRow.user?.status || '-'}}
```

---

### Raw JSON block
- `JSON_AntiFraudRaw`
  - source:
```javascript
{{Table_AntiFraudQueue.selectedRow}}
```

---

### Flags section
- `Table_UserFlags`
  - data:
```javascript
{{getUserFlags.data?.flags || getUserFlags.data || []}}
```

### Suggested flag columns
- flagType
- severity
- details
- createdAt

---

### Recompute panel
- `Button_RecomputeSignals`
  - label: `Recompute signals`
  - onClick:
```javascript
{{recomputeUserSignals.run()}}
```

- `Text_RecomputeHelp`
  - value: `Úsalo cuando cambien evidencias, validaciones o comportamiento sospechoso.`

---

## Queries

### Query 1: `getAntiFraudQueue`
Method: `GET`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/anti-fraud/review-queue
```
Headers:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}"
}
```
Run on page load: yes

---

### Query 2: `getUserFlags`
Method: `GET`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/anti-fraud/user/{{Table_AntiFraudQueue.selectedRow.userId || Table_AntiFraudQueue.selectedRow.user?.id}}/flags
```
Headers:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}"
}
```

---

### Query 3: `recomputeUserSignals`
Method: `POST`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/anti-fraud/user/{{Table_AntiFraudQueue.selectedRow.userId || Table_AntiFraudQueue.selectedRow.user?.id}}/recompute
```
Body:
```json
{}
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
showAlert('Se recomputaron las señales de riesgo', 'success');
getAntiFraudQueue.run();
getUserFlags.run();
}}
```

---

## Optional severity helper
If you want a colored severity badge, create a JSObject or use inline expressions.

Example for background color:
```javascript
{{
currentRow.severity === 'high' ? '#ffebee' :
currentRow.severity === 'medium' ? '#fff8e1' :
'#e8f5e9'
}}
```

---

## Page events

### On page load
```javascript
{{getAntiFraudQueue.run()}}
```

### On table row selected
```javascript
{{getUserFlags.run()}}
```

---

## Operational notes
- This page is intentionally read-heavy plus a single action: recompute.
- If the queue payload already includes flags inline, you can skip the second query and bind directly.
- If risk data shape differs in production, keep the raw JSON block visible during first rollout and refine bindings after live inspection.
- This page works well before a future deeper case-management UI.

## Definition of done
- anti-fraud queue loads
- operator can inspect selected user details
- flags table loads
- recompute works
- queue refreshes after recompute
