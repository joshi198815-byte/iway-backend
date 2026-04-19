import { getCollection, getProtectedFilePreview, getTransfersReviewQueue, formatDate, formatMoney } from '@/lib/api';
import { requireSession } from '@/lib/auth';
import { DataTable } from '@/components/data-table';
import { KeyValueList } from '@/components/key-value-list';
import { reviewTransferAction } from '@/app/(protected)/mutations';

type SearchParams = Promise<Record<string, string | string[] | undefined>>;

function getParam(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] || '' : value || '';
}

export default async function TransfersReviewPage({ searchParams }: { searchParams: SearchParams }) {
  const session = await requireSession();
  const token = session.token as string;
  const params = await searchParams;
  const query = getParam(params.q).toLowerCase().trim();
  const selectedId = getParam(params.transferId);

  const payload = await getTransfersReviewQueue(token);
  const transfers = getCollection<Record<string, any>>(payload).filter((item) => {
    if (!query) return true;
    return [
      item.traveler?.fullName,
      item.traveler?.email,
      item.bankReference,
      item.transferredAmount,
    ]
      .filter(Boolean)
      .some((value) => String(value).toLowerCase().includes(query));
  });

  const selected = transfers.find((item) => String(item.id) === selectedId) || transfers[0] || null;
  const proofPreview = selected ? await getProtectedFilePreview(token, selected.proofUrl) : null;
  const selectedTransferId = selected ? String(selected.id) : '';

  return (
    <div className="stack">
      <div className="toolbar">
        <div>
          <h2 style={{ margin: 0 }}>Transfers Review</h2>
          <div className="muted">{transfers.length} transferencias pendientes</div>
        </div>
        <form className="filters" method="get">
          <input name="q" defaultValue={query} placeholder="Buscar por traveler, referencia o monto" />
          <button className="button secondary" type="submit">Buscar</button>
        </form>
      </div>

      <div className="grid cols-2">
        <section className="card panel">
          <DataTable
            rows={transfers}
            empty="No hay transferencias pendientes"
            rowLink={(row) => `/transfers-review?transferId=${row.id}${query ? `&q=${encodeURIComponent(query)}` : ''}`}
            columns={[
              { key: 'name', header: 'Traveler', render: (row) => row.traveler?.fullName || '-' },
              { key: 'email', header: 'Correo', render: (row) => row.traveler?.email || '-' },
              { key: 'amount', header: 'Monto', render: (row) => formatMoney(row.transferredAmount) },
              { key: 'reference', header: 'Referencia', render: (row) => row.bankReference || '-' },
              { key: 'createdAt', header: 'Creado', render: (row) => formatDate(row.createdAt) },
            ]}
          />
        </section>

        <section className="stack">
          <div className="card panel">
            <h3>Resumen</h3>
            {selected ? (
              <KeyValueList
                items={[
                  { label: 'Transfer ID', value: selected.id || '-' },
                  { label: 'Traveler ID', value: selected.travelerId || '-' },
                  { label: 'Traveler', value: selected.traveler?.fullName || '-' },
                  { label: 'Correo', value: selected.traveler?.email || '-' },
                  { label: 'Teléfono', value: selected.traveler?.phone || '-' },
                  { label: 'Monto transferido', value: formatMoney(selected.transferredAmount) },
                  { label: 'Referencia bancaria', value: selected.bankReference || '-' },
                  { label: 'Estado', value: selected.status || '-' },
                ]}
              />
            ) : (
              <div className="muted">Selecciona una transferencia.</div>
            )}
          </div>

          <div className="card panel">
            <h3>Comprobante</h3>
            {proofPreview?.dataUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={proofPreview.dataUrl} alt="Comprobante" style={{ maxWidth: '100%', borderRadius: 12, border: '1px solid var(--line)' }} />
            ) : (
              <div className="muted">Sin preview disponible</div>
            )}
            <div className="muted" style={{ marginTop: 12 }}>
              {proofPreview ? `${proofPreview.contentType || '-'} · ${proofPreview.sizeBytes || 0} bytes` : ''}
            </div>
          </div>

          <div className="card panel">
            <h3>Decisión</h3>
            {selected ? (
              <form action={reviewTransferAction} className="filters">
                <input type="hidden" name="transferId" value={selectedTransferId} />
                <input type="hidden" name="path" value={`/transfers-review?transferId=${selectedTransferId}${query ? `&q=${encodeURIComponent(query)}` : ''}`} />
                <select name="action" defaultValue="approved">
                  <option value="approved">Aprobar pago</option>
                  <option value="rejected">Rechazar pago</option>
                </select>
                <textarea name="reason" placeholder="Nota interna o motivo del rechazo" />
                <button className="button primary" type="submit">Guardar decisión</button>
              </form>
            ) : (
              <div className="muted">No hay transferencia seleccionada.</div>
            )}
          </div>

          <div className="card panel">
            <h3>Paquetes cubiertos por la deuda</h3>
            {selected && Array.isArray(selected.relatedShipments) && selected.relatedShipments.length > 0 ? (
              <pre className="code">{JSON.stringify(selected.relatedShipments, null, 2)}</pre>
            ) : (
              <pre className="code">{selected ? JSON.stringify(selected, null, 2) : 'Sin selección'}</pre>
            )}
          </div>
        </section>
      </div>
    </div>
  );
}
