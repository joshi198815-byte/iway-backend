# Appsmith implementation plan

## Recommended build order

### Phase 1: foundation
1. Login
2. Dashboard
3. Session guards
4. Shared auth header pattern
5. Shared `apiBase` storage

### Phase 2: highest daily-value ops
1. Travelers Review
2. Transfers Review
3. Shipments
4. Shipment Detail

### Phase 3: operational risk and resolution
1. Anti-Fraud
2. Disputes

### Phase 4: internal admin / finance
1. Collaborators
2. Ledger
3. Pricing

---

## Minimum viable admin launch
If you want the fastest useful Appsmith release, launch these first:
- Login
- Dashboard
- Travelers Review
- Transfers Review
- Shipments
- Shipment Detail

That already covers the most operationally important workflows.

---

## Recommended permissions model

### admin
- full access
- collaborator management
- pricing changes
- ledger adjustments
- all review queues

### support
- traveler review
- transfer review
- anti-fraud review
- disputes
- shipments
- shipment detail
- read-only or limited financial access depending on policy

---

## Shared implementation rules
- use `appsmith.store.apiBase` everywhere
- use `Authorization: Bearer {{appsmith.store.jwt}}` everywhere
- keep a raw JSON block visible in first rollout pages
- prefer desktop-first layouts
- use backend preview JSON endpoints for protected evidence
- if `/api` gives 404 in browser, verify proxy routing and temporarily switch `apiBase`

---

## Files already prepared
- `ADMIN_APPSMITH_MIGRATION.md`
- `APPSMITH_LOGIN_DASHBOARD.md`
- `APPSMITH_ADMIN_COLLABORATORS_PAGE.md`
- `APPSMITH_TRAVELERS_REVIEW_PAGE.md`
- `APPSMITH_TRANSFERS_REVIEW_PAGE.md`
- `APPSMITH_ANTI_FRAUD_PAGE.md`
- `APPSMITH_DISPUTES_PAGE.md`
- `APPSMITH_SHIPMENTS_PAGE.md`
- `APPSMITH_SHIPMENT_DETAIL_PAGE.md`
- `APPSMITH_LEDGER_PAGE.md`
- `APPSMITH_PRICING_PAGE.md`

---

## Launch checklist
- production admin user exists
- Appsmith origin added to `CORS_ORIGINS`
- login works against production backend
- `/auth/me` works
- protected file preview works in browser
- top 3 operational pages work with real data
- role visibility is correct for admin vs support
- one real operator can complete a full review flow without mobile admin
