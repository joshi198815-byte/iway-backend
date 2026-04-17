import Link from 'next/link';
import { getCollection, getShipments, formatDate, formatMoney } from '@/lib/api';
import { requireSession } from '@/lib/auth';
import { DataTable } from '@/components/data-table';
import { KeyValueList } from '@/components/key-value-list';
import { updateShipmentStatusAction } from '@/app/(protected)/mutations';

type SearchParams = Promise<Record<string, string | string[] | undefined>>;

function getParam(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] || '' : value || '';
}

const STATUSES = ['published', 'assigned', 'picked_up', 'in_transit', 'in_delivery', 'delivered', 'cancelled', 'disputed'];

export default async function ShipmentsPage({ searchParams }: { searchParams: SearchParams }) {
  const session = await requireSession();
  const token = session.token as string;
  const params = await searchParams;
  const query = getParam(params.q).toLowerCase().trim();
  const statusFilter = getParam(params.status);
  const selectedId = getParam(params.shipmentId);

  const payload = await getShipments(token);
  const shipments = getCollection<Record<string, any>>(payload).filter((item) => {
    if (statusFilter && item.status !== statusFilter) return false;
    if (!query) return true;
    return [
      item.id,
      item.customer?.fullName,
      item.assignedTraveler?.fullName,
      item.status,
      item.originCity,
      item.destinationCity,
      item.direction,
    ]
      .filter(Boolean)
      .some((value) => String(value).toLowerCase().includes(query));
  });

  const selected = shipments.find((item) => String(item.id) === selectedId) || shipments[0] || null;
  const selectedShipmentId = selected ? String(selected.id) : '';

  return (
    <div className="stack">
      <div className="toolbar">
        <div>
          <h2 style={{ margin: 0 }}>Shipments</h2>
          <div className="muted">{shipments.length} envíos</div>
        </div>
        <form className="filters" method="get">
          <input name="q" defaultValue={query} placeholder="Buscar por id, customer, traveler, estado o ruta" />
          <select name="status" defaultValue={statusFilter}>
            <option value="">Todos los estados</option>
            {STATUSES.map((status) => (
              <option key={status} value={status}>{status}</option>
            ))}
          </select>
          <button className="button secondary" type="submit">Filtrar</button>
        </form>
      </div>

      <div className="grid cols-2">
        <section className="card panel">
          <DataTable
            rows={shipments}
            empty="No hay envíos para este filtro"
            rowLink={(row) => `/shipments?shipmentId=${row.id}${query ? `&q=${encodeURIComponent(query)}` : ''}${statusFilter ? `&status=${statusFilter}` : ''}`}
            columns={[
              { key: 'id', header: 'ID', render: (row) => row.id || '-' },
              { key: 'customer', header: 'Customer', render: (row) => row.customer?.fullName || '-' },
              { key: 'traveler', header: 'Traveler', render: (row) => row.assignedTraveler?.fullName || '-' },
              { key: 'status', header: 'Estado', render: (row) => row.status || '-' },
              { key: 'amount', header: 'Monto', render: (row) => formatMoney(row.price || row.quotedAmount || row.offeredPrice) },
            ]}
          />
        </section>

        <section className="stack">
          <div className="card panel">
            <h3>Resumen</h3>
            {selected ? (
              <KeyValueList
                items={[
                  { label: 'ID', value: selected.id || '-' },
                  { label: 'Customer', value: selected.customer?.fullName || '-' },
                  { label: 'Traveler asignado', value: selected.assignedTraveler?.fullName || '-' },
                  { label: 'Estado', value: selected.status || '-' },
                  { label: 'Ruta', value: `${selected.originCity || '-'} → ${selected.destinationCity || '-'}` },
                  { label: 'Creado', value: formatDate(selected.createdAt) },
                ]}
              />
            ) : (
              <div className="muted">Selecciona un envío.</div>
            )}
          </div>

          <div className="card panel">
            <h3>Acción rápida</h3>
            {selected ? (
              <div className="stack">
                <form action={updateShipmentStatusAction} className="filters">
                  <input type="hidden" name="shipmentId" value={selectedShipmentId} />
                  <input type="hidden" name="path" value={`/shipments?shipmentId=${selectedShipmentId}${query ? `&q=${encodeURIComponent(query)}` : ''}${statusFilter ? `&status=${statusFilter}` : ''}`} />
                  <select name="status" defaultValue={selected.status || 'published'}>
                    {STATUSES.map((status) => (
                      <option key={status} value={status}>{status}</option>
                    ))}
                  </select>
                  <button className="button primary" type="submit">Actualizar estado</button>
                </form>
                <Link className="button secondary hero-link" href={`/shipments/${selectedShipmentId}`}>
                  Ver detalle completo
                </Link>
              </div>
            ) : (
              <div className="muted">No hay envío seleccionado.</div>
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
