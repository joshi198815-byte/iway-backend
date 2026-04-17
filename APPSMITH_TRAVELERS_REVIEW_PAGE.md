# Appsmith page blueprint: Travelers Review

## Goal
Build the first admin page in Appsmith for reviewing traveler onboarding, KYC evidence, payout hold, and manual approval/rejection.

Base API:
- Primary: `https://api.iway.one/api`
- Fallback: `https://api.iway.one`

Requires JWT from the Login page.

---

## Page name
`TravelersReview`

---

## Layout
Use a 2-column layout.

### Left column
Operational queue list.

### Right column
Traveler detail, evidence preview, KYC summary, and action panel.

---

## Widgets

### Top bar
- `Text_Title`
  - value: `Travelers Review`
- `Button_Refresh`
  - label: `Refresh`
  - onClick: `{{getTravelerReviewQueue.run()}}`
- `Text_QueueCount`
  - value: `{{getTravelerReviewQueue.data?.length || 0}} por revisar`

---

## Left column widgets

### 1. Search input
- `Input_SearchTraveler`
  - placeholder: `Buscar por nombre, email, teléfono o documento`

### 2. Queue table
- `Table_TravelerQueue`
  - source:
```javascript
{{
(getTravelerReviewQueue.data || []).filter(item => {
  const q = (Input_SearchTraveler.text || '').toLowerCase().trim();
  if (!q) return true;

  const fullName = (item.fullName || item.user?.fullName || '').toLowerCase();
  const email = (item.email || item.user?.email || '').toLowerCase();
  const phone = (item.phone || item.user?.phone || '').toLowerCase();
  const documentNumber = (item.documentNumber || item.travelerProfile?.dpiOrPassport || '').toLowerCase();

  return fullName.includes(q) || email.includes(q) || phone.includes(q) || documentNumber.includes(q);
})
}}
```

### Suggested visible columns
- full name
- email
- phone
- traveler type
- KYC score / risk score if present
- review status
- createdAt

### Row action
On row selected:
```javascript
{{
showAlert('Traveler seleccionado', 'info');
loadTravelerEvidence.run();
}}
```

---

## Right column widgets

### 3. Traveler summary card
Use text widgets bound to selected row.

Examples:
- Name:
```javascript
{{Table_TravelerQueue.selectedRow.fullName || Table_TravelerQueue.selectedRow.user?.fullName || '-'}}
```
- Email:
```javascript
{{Table_TravelerQueue.selectedRow.email || Table_TravelerQueue.selectedRow.user?.email || '-'}}
```
- Phone:
```javascript
{{Table_TravelerQueue.selectedRow.phone || Table_TravelerQueue.selectedRow.user?.phone || '-'}}
```
- Traveler type:
```javascript
{{Table_TravelerQueue.selectedRow.travelerType || Table_TravelerQueue.selectedRow.travelerProfile?.travelerType || '-'}}
```
- Document number:
```javascript
{{Table_TravelerQueue.selectedRow.documentNumber || Table_TravelerQueue.selectedRow.travelerProfile?.dpiOrPassport || '-'}}
```
- Current status:
```javascript
{{Table_TravelerQueue.selectedRow.status || Table_TravelerQueue.selectedRow.user?.status || '-'}}
```

---

### 4. KYC / evidence summary JSON block
- `JSON_KycSummary`
  - source:
```javascript
{{Table_TravelerQueue.selectedRow}}
```

Use this at first, then replace with curated fields once production data shape is stable.

---

### 5. Evidence preview area

#### Document image widget
- `Image_Document`
  - image source:
```javascript
{{loadTravelerEvidence.data?.documentDataUrl || ''}}
```

#### Selfie image widget
- `Image_Selfie`
  - image source:
```javascript
{{loadTravelerEvidence.data?.selfieDataUrl || ''}}
```

#### File metadata text
- `Text_EvidenceMeta`
  - value:
```javascript
{{loadTravelerEvidence.data ? `Documento: ${loadTravelerEvidence.data.documentContentType || '-'} | Selfie: ${loadTravelerEvidence.data.selfieContentType || '-'}` : 'Sin previews cargados'}}
```

---

### 6. Action panel

#### Review action selector
- `Select_ReviewAction`
  - options:
```javascript
{{[
  { label: 'Aprobar', value: 'approved' },
  { label: 'Rechazar', value: 'rejected' },
  { label: 'Pendiente / manual review', value: 'manual_review' }
]}}
```

#### Reason textarea
- `Input_ReviewReason`
  - type: multiline
  - placeholder: `Motivo o nota operativa`

#### Approve / reject button
- `Button_SubmitReview`
  - label: `Guardar revisión`
  - onClick:
```javascript
{{reviewTraveler.run()}}
```

---

### 7. Payout hold controls
- `Switch_PayoutHold`
- `Input_PayoutHoldReason`
- `Button_SavePayoutHold`
  - onClick:
```javascript
{{updatePayoutHold.run()}}
```

---

### 8. Run KYC button
- `Button_RunKyc`
  - label: `Run KYC analysis`
  - onClick:
```javascript
{{runKycAnalysis.run()}}
```

---

## Queries

### Query 1: `getTravelerReviewQueue`
Method: `GET`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/travelers/review-queue
```
Headers:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}"
}
```

Run on page load: yes

---

### Query 2: `reviewTraveler`
Method: `POST`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/travelers/{{Table_TravelerQueue.selectedRow.userId || Table_TravelerQueue.selectedRow.user?.id}}/review
```
Body:
```json
{
  "action": "{{Select_ReviewAction.selectedOptionValue}}",
  "reason": "{{Input_ReviewReason.text}}"
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
showAlert('Revisión guardada', 'success');
getTravelerReviewQueue.run();
}}
```

---

### Query 3: `updatePayoutHold`
Method: `POST`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/travelers/{{Table_TravelerQueue.selectedRow.userId || Table_TravelerQueue.selectedRow.user?.id}}/payout-hold
```
Body:
```json
{
  "enabled": {{Switch_PayoutHold.isSwitchedOn}},
  "reason": "{{Input_PayoutHoldReason.text}}"
}
```
On success:
```javascript
{{
showAlert('Payout hold actualizado', 'success');
getTravelerReviewQueue.run();
}}
```

---

### Query 4: `runKycAnalysis`
Method: `POST`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/travelers/{{Table_TravelerQueue.selectedRow.userId || Table_TravelerQueue.selectedRow.user?.id}}/run-kyc-analysis
```
Body:
```json
{}
```
On success:
```javascript
{{
showAlert('Análisis KYC ejecutado', 'success');
getTravelerReviewQueue.run();
}}
```

---

## Evidence preview loading
Because Appsmith image widgets are awkward with auth-protected file URLs, use the backend preview endpoint.

### Create JSObject: `TravelerEvidence`
```javascript
export default {
  getDocumentPath() {
    const row = Table_TravelerQueue.selectedRow || {};
    return row.summary?.evidence?.documentUrl || row.evidence?.documentUrl || row.documentUrl || '';
  },

  getSelfiePath() {
    const row = Table_TravelerQueue.selectedRow || {};
    return row.summary?.evidence?.selfieUrl || row.evidence?.selfieUrl || row.selfieUrl || '';
  },

  parseParts(protectedUrl) {
    if (!protectedUrl) return null;
    const parts = protectedUrl.split('/').filter(Boolean);
    const idx = parts.indexOf('file-preview') >= 0 ? parts.indexOf('file-preview') : parts.indexOf('file');
    if (idx === -1 || parts.length < idx + 4) return null;
    return {
      bucket: parts[idx + 1],
      ownerId: parts[idx + 2],
      fileName: parts.slice(idx + 3).join('/'),
    };
  }
}
```

### Query 5: `getDocumentPreview`
Method: `GET`
URL:
```javascript
{{
(() => {
  const p = TravelerEvidence.parseParts(TravelerEvidence.getDocumentPath());
  if (!p) return '';
  return `${appsmith.store.apiBase || 'https://api.iway.one/api'}/storage/file-preview/${p.bucket}/${p.ownerId}/${p.fileName}`;
})()
}}
```

### Query 6: `getSelfiePreview`
Method: `GET`
URL:
```javascript
{{
(() => {
  const p = TravelerEvidence.parseParts(TravelerEvidence.getSelfiePath());
  if (!p) return '';
  return `${appsmith.store.apiBase || 'https://api.iway.one/api'}/storage/file-preview/${p.bucket}/${p.ownerId}/${p.fileName}`;
})()
}}
```

Headers for both:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}"
}
```

### Query 7: `loadTravelerEvidence`
Type: JSObject function or run both queries sequentially.

Suggested JSObject: `TravelerActions`
```javascript
export default {
  async loadTravelerEvidence() {
    const doc = await getDocumentPreview.run();
    const selfie = await getSelfiePreview.run();
    return {
      documentDataUrl: doc?.dataUrl || '',
      documentContentType: doc?.contentType || '',
      selfieDataUrl: selfie?.dataUrl || '',
      selfieContentType: selfie?.contentType || '',
    };
  }
}
```

If your Appsmith version makes shared state easier with `storeValue`, you can instead store:
- `selectedTravelerDocumentDataUrl`
- `selectedTravelerSelfieDataUrl`

---

## Page events

### On page load
Run:
```javascript
{{getTravelerReviewQueue.run()}}
```

### On table row selected
Run:
```javascript
{{loadTravelerEvidence.run()}}
```

---

## Validation rules

### Review action
Do not send empty action.

### Rejection reason
If action is `rejected`, require a reason.

Suggested button disabled state:
```javascript
{{
!Select_ReviewAction.selectedOptionValue ||
(
  Select_ReviewAction.selectedOptionValue === 'rejected' &&
  !Input_ReviewReason.text.trim()
)
}}
```

---

## Operational notes
- This page is ideal for desktop first.
- Start with raw JSON visibility, then refine field-by-field once you see live payloads.
- If production data shape differs slightly, the table and detail bindings should be adjusted after the first real login.
- This is the best first Appsmith page because it exercises auth, queues, actions, and protected files in one place.

## Definition of done
You can consider this page done when:
- admin login works
- queue loads
- selecting a traveler shows summary
- DPI and selfie preview render
- approve/reject works
- payout hold works
- run KYC works
- queue refreshes after each action
