# iWay Storage Policy

## Goal
Keep uploaded evidence durable, protected, and operationally manageable across staging and production.

## Buckets
- `documents`
- `shipment-images`
- `transfer-proofs`

## Access rules
- All uploaded files are stored as protected files.
- Access is only granted to:
  - file owner
  - `admin`
  - `support`
- Files are served through `GET /api/storage/file/:bucket/:ownerId/:fileName` with JWT auth.

## Production recommendation
- Default local-disk mode is acceptable for early staging only.
- Production should mount a durable volume or migrate to object storage.
- Keep uploads on a separate persistent volume from application container lifecycle.

## Retention recommendation
- `documents`: retain while account is active and for required compliance period after closure.
- `transfer-proofs`: retain for financial audit window.
- `shipment-images`: retain for customer support and dispute window.

## Operational rules
- Back up DB and uploads together for consistent restore drills.
- Run `scripts/backup_uploads.sh` on the same cadence as database backups.
- Test `scripts/restore_uploads.sh` during staging restore drills.

## Security recommendations
- Never expose `/uploads` directly in production without auth.
- Keep `APP_BASE_URL` aligned with the reverse proxy domain.
- Use admin/support access sparingly and rely on audit logs for sensitive review work.
