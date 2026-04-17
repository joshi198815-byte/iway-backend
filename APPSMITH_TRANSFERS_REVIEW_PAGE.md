# Appsmith page blueprint: Transfers Review

## Goal
Review traveler transfer proofs and approve or reject settlement submissions from the admin web.

This page is intended for:
- `admin`
- `support`

---

## Backend endpoints used

### Queue
`GET /transfers/review-queue`

### Review transfer
`POST /transfers/:transferId/review`

### Protected file preview
`GET /storage/file-preview/:bucket/:ownerId/:fileName`

Use this for transfer proof previews when proofs are protected.

---

## Page name
`TransfersReview`

---

## Layout
Two-column layout.

### Left column
Transfer review queue.

### Right column
Transfer detail, proof preview, and decision panel.

---

## Widgets

### Top bar
- `Text_Title`
  - value: `Transfers Review`
- `Button_Refresh`
  - onClick:
```javascript
{{getTransferReviewQueue.run()}}
```
- `Text_QueueCount`
  - value:
```javascript
{{`${getTransferReviewQueue.data?.length || 0} transferencias pendientes`}}
```

---

## Left column

### Search input
- `Input_SearchTransfer`
  - placeholder: `Buscar por traveler, email, referencia o monto`

### Table
- `Table_TransfersQueue`
  - data:
```javascript
{{
(getTransferReviewQueue.data || []).filter(item => {
  const q = (Input_SearchTransfer.text || '').toLowerCase().trim();
  if (!q) return true;

  const name = (item.traveler?.fullName || '').toLowerCase();
  const email = (item.traveler?.email || '').toLowerCase();
  const reference = (item.bankReference || '').toLowerCase();
  const amount = String(item.transferredAmount || '').toLowerCase();

  return name.includes(q) || email.includes(q) || reference.includes(q) || amount.includes(q);
})
}}
```

### Suggested columns
- traveler name
- traveler email
- transferredAmount
- bankReference
- status
- createdAt

### Row select action
```javascript
{{loadTransferProof.run()}}
```

---

## Right column

### Transfer summary
- `Text_TravelerName`
```javascript
{{Table_TransfersQueue.selectedRow.traveler?.fullName || '-'}}
```

- `Text_TravelerEmail`
```javascript
{{Table_TransfersQueue.selectedRow.traveler?.email || '-'}}
```

- `Text_TravelerPhone`
```javascript
{{Table_TransfersQueue.selectedRow.traveler?.phone || '-'}}
```

- `Text_TransferredAmount`
```javascript
{{Table_TransfersQueue.selectedRow.transferredAmount || '-'}}
```

- `Text_BankReference`
```javascript
{{Table_TransfersQueue.selectedRow.bankReference || '-'}}
```

- `Text_TransferStatus`
```javascript
{{Table_TransfersQueue.selectedRow.status || '-'}}
```

- `Text_CreatedAt`
```javascript
{{Table_TransfersQueue.selectedRow.createdAt || '-'}}
```

---

### Raw JSON block
- `JSON_TransferRaw`
  - source:
```javascript
{{Table_TransfersQueue.selectedRow}}
```

---

### Transfer proof preview
- `Image_TransferProof`
  - image source:
```javascript
{{loadTransferProof.data?.proofDataUrl || ''}}
```

- `Text_ProofMeta`
  - value:
```javascript
{{loadTransferProof.data ? `Tipo: ${loadTransferProof.data.contentType || '-'} | Tamaño: ${loadTransferProof.data.sizeBytes || '-'} bytes` : 'Sin comprobante cargado'}}
```

---

## Review panel

### Decision selector
- `Select_TransferDecision`
  - options:
```javascript
{{[
  { label: 'Aprobar', value: 'approved' },
  { label: 'Rechazar', value: 'rejected' }
]}}
```

### Reason / note
- `Input_TransferReviewNote`
  - type: multiline
  - placeholder: `Motivo o nota interna`

### Submit button
- `Button_SubmitTransferReview`
  - onClick:
```javascript
{{reviewTransfer.run()}}
```

### Disabled state
```javascript
{{
!Select_TransferDecision.selectedOptionValue ||
(
  Select_TransferDecision.selectedOptionValue === 'rejected' &&
  !Input_TransferReviewNote.text.trim()
)
}}
```

---

## Queries

### Query 1: `getTransferReviewQueue`
Method: `GET`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/transfers/review-queue
```
Headers:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}"
}
```
Run on page load: yes

---

### Query 2: `reviewTransfer`
Method: `POST`
URL:
```javascript
{{appsmith.store.apiBase || 'https://api.iway.one/api'}}/transfers/{{Table_TransfersQueue.selectedRow.id}}/review
```
Body:
```json
{
  "action": "{{Select_TransferDecision.selectedOptionValue}}",
  "reason": "{{Input_TransferReviewNote.text}}"
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
showAlert('Transferencia revisada', 'success');
getTransferReviewQueue.run();
}}
```

---

## Transfer proof loading

### JSObject: `TransferProof`
```javascript
export default {
  getProofPath() {
    const row = Table_TransfersQueue.selectedRow || {};
    return row.proofUrl || '';
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

### Query 3: `getTransferProofPreview`
Method: `GET`
URL:
```javascript
{{
(() => {
  const p = TransferProof.parseParts(TransferProof.getProofPath());
  if (!p) return '';
  return `${appsmith.store.apiBase || 'https://api.iway.one/api'}/storage/file-preview/${p.bucket}/${p.ownerId}/${p.fileName}`;
})()
}}
```
Headers:
```json
{
  "Authorization": "Bearer {{appsmith.store.jwt}}"
}
```

### Query 4: `loadTransferProof`
Use a JSObject helper or direct query call.

Suggested JSObject: `TransferActions`
```javascript
export default {
  async loadTransferProof() {
    const proof = await getTransferProofPreview.run();
    return {
      proofDataUrl: proof?.dataUrl || '',
      contentType: proof?.contentType || '',
      sizeBytes: proof?.sizeBytes || 0,
    };
  }
}
```

---

## Page events

### On page load
```javascript
{{getTransferReviewQueue.run()}}
```

### On table row selected
```javascript
{{loadTransferProof.run()}}
```

---

## Operational notes
- This page is ideal for support ops and finance review.
- If transfer proof previews fail, inspect whether `proofUrl` is already public or protected.
- If proof URLs come in a different shape, adjust `TransferProof.parseParts()` after first live response.
- If the backend returns PDFs instead of images, replace `Image_TransferProof` with a document/embed-compatible widget or use a link button to open the `dataUrl`.

## Definition of done
- queue loads
- selecting a transfer shows traveler and payment info
- proof preview renders
- approve works
- reject works with required note
- queue refreshes after review
