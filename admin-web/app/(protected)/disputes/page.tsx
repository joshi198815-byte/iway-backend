import {
  formatDate,
  getCollection,
  getDisputesQueue,
} from '@/lib/api';
import { requireSession } from '@/lib/auth';
import { DataTable } from '@/components/data-table';
import { EmptyState } from '@/components/empty-state';
import { KeyValueList } from '@/components/key-value-list';
import { resolveDisputeAction } from '@/app/(protected)/mutations';

type SearchParams = Promise<Record<string, string | string[] | undefined>>;

function getParam(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] || '' : value || '';
}

export default async function DisputesPage({ searchParams }: { searchParams: SearchParams }) {
  const session = await requireSession();
  const token = session.token as string;
  const params = await searchParams;
  const selectedDisputeId = getParam(params.disputeId);

  const payload = await getDisputesQueue(token);
  const disputes = getCollection<Record<string, any>>(payload);
  const selected = disputes.find((item) => item.id === selectedDisputeId) || disputes[0] || null;
  const disputeId = selected?.id || '';

  return (
    <div className="stack">
      <div className="toolbar">
        <div>
          <h2 style={{ margin: 0 }}>Disputes</h2>
          <div className="muted">Cola operativa de disputas abiertas o escaladas</div>
        </div>
      </div>

      <div className="grid cols-2">
        <section className="card panel">
          <DataTable
            rows={disputes}
            empty="Sin disputas activas"
            rowLink={(row) => `/disputes?disputeId=${row.id}`}
            columns={[
              { key: 'id', header: 'ID', render: (row) => row.id || '-' },
              { key: 'shipment', header: 'Shipment', render: (row) => row.shipmentId || '-' },
              { key: 'status', header: 'Estado', render: (row) => row.status || '-' },
              { key: 'openedBy', header: 'Abierta por', render: (row) => row.opener?.fullName || row.openedBy || '-' },
              { key: 'updatedAt', header: 'Actualizada', render: (row) => formatDate(row.updatedAt) },
            ]}
          />
        </section>

        <section className="stack">
          <div className="card panel">
            <h3>Detalle</h3>
            {selected ? (
              <KeyValueList
                items={[
                  { label: 'Disputa', value: selected.id || '-' },
                  { label: 'Shipment', value: selected.shipmentId || '-' },
                  { label: 'Estado', value: selected.status || '-' },
                  { label: 'Motivo', value: selected.reason || '-' },
                  { label: 'Resolución', value: selected.resolution || '-' },
                  { label: 'Customer', value: selected.shipment?.customerId || '-' },
                  { label: 'Traveler', value: selected.shipment?.assignedTravelerId || '-' },
                ]}
              />
            ) : (
              <EmptyState title="Sin selección" description="No hay disputa seleccionada." />
            )}
          </div>

          <div className="card panel">
            <h3>Resolver</h3>
            {selected ? (
              <form action={resolveDisputeAction} className="filters">
                <input type="hidden" name="disputeId" value={disputeId} />
                <input type="hidden" name="path" value={`/disputes?disputeId=${disputeId}`} />
                <select name="status" defaultValue="resolved">
                  <option value="resolved">Resolved</option>
                  <option value="rejected">Rejected</option>
                  <option value="escalated">Escalated</option>
                </select>
                <textarea name="resolution" placeholder="Nota operativa o resolución" />
                <button className="button primary" type="submit">Guardar decisión</button>
              </form>
            ) : (
              <div className="muted">No hay disputa seleccionada.</div>
            )}
          </div>

          <div className="card panel">
            <h3>Payload</h3>
            <pre className="code">{selected ? JSON.stringify(selected, null, 2) : 'Sin selección'}</pre>
          </div>
        </section>
      </div>
    </div>
  );
}
