import Link from 'next/link';
import {
  formatDate,
  formatMoney,
  getCollection,
  getObject,
  getShipmentDetail,
  getShipmentOffers,
  getTrackingTimeline,
} from '@/lib/api';
import { requireSession } from '@/lib/auth';
import { DataTable } from '@/components/data-table';
import { KeyValueList } from '@/components/key-value-list';
import { updateShipmentStatusAction } from '@/app/(protected)/mutations';

const STATUSES = ['published', 'assigned', 'picked_up', 'in_transit', 'in_delivery', 'delivered', 'cancelled', 'disputed'];

export default async function ShipmentDetailPage({ params }: { params: Promise<{ shipmentId: string }> }) {
  const session = await requireSession();
  const token = session.token as string;
  const { shipmentId } = await params;

  const [shipmentPayload, offersPayload, timelinePayload] = await Promise.all([
    getShipmentDetail(token, shipmentId),
    getShipmentOffers(token, shipmentId),
    getTrackingTimeline(token, shipmentId),
  ]);

  const shipment = getObject<Record<string, any>>(shipmentPayload);
  const offers = getCollection<Record<string, any>>(offersPayload);
  const timeline = getCollection<Record<string, any>>(timelinePayload);

  return (
    <div className="stack">
      <div className="toolbar">
        <div>
          <h2 style={{ margin: 0 }}>Shipment {shipmentId}</h2>
          <div className="muted">Vista operativa completa</div>
        </div>
        <Link className="button secondary hero-link" href="/shipments">
          Volver a Shipments
        </Link>
      </div>

      <div className="grid cols-2">
        <section className="card panel">
          <h3>Resumen</h3>
          {shipment ? (
            <KeyValueList
              items={[
                { label: 'Estado', value: shipment.status || '-' },
                { label: 'Dirección', value: shipment.direction || '-' },
                { label: 'Origen', value: shipment.originCity || '-' },
                { label: 'Destino', value: shipment.destinationCity || '-' },
                { label: 'Creado', value: formatDate(shipment.createdAt) },
                { label: 'Monto', value: formatMoney(shipment.price || shipment.quotedAmount || shipment.offeredPrice) },
                { label: 'Customer', value: shipment.customer?.fullName || '-' },
                { label: 'Tel customer', value: shipment.customer?.phone || '-' },
                { label: 'Traveler', value: shipment.assignedTraveler?.fullName || '-' },
                { label: 'Tel traveler', value: shipment.assignedTraveler?.phone || '-' },
              ]}
            />
          ) : (
            <div className="muted">No se pudo cargar el shipment.</div>
          )}
        </section>

        <section className="card panel">
          <h3>Actualizar estado</h3>
          <form action={updateShipmentStatusAction} className="filters">
            <input type="hidden" name="shipmentId" value={shipmentId} />
            <input type="hidden" name="path" value={`/shipments/${shipmentId}`} />
            <select name="status" defaultValue={shipment?.status || 'published'}>
              {STATUSES.map((status) => (
                <option key={status} value={status}>{status}</option>
              ))}
            </select>
            <button className="button primary" type="submit">Guardar estado</button>
          </form>
        </section>
      </div>

      <section className="card panel">
        <h3>Offers</h3>
        <DataTable
          rows={offers}
          empty="Sin offers"
          columns={[
            { key: 'id', header: 'ID', render: (row) => row.id || '-' },
            { key: 'traveler', header: 'Traveler', render: (row) => row.traveler?.fullName || '-' },
            { key: 'price', header: 'Precio', render: (row) => formatMoney(row.offeredPrice || row.price) },
            { key: 'status', header: 'Estado', render: (row) => row.status || '-' },
            { key: 'createdAt', header: 'Creado', render: (row) => formatDate(row.createdAt) },
          ]}
        />
      </section>

      <section className="card panel">
        <h3>Tracking timeline</h3>
        <DataTable
          rows={timeline}
          empty="Sin eventos de tracking"
          columns={[
            { key: 'status', header: 'Estado', render: (row) => row.status || '-' },
            { key: 'lat', header: 'Lat', render: (row) => row.latitude || '-' },
            { key: 'lng', header: 'Lng', render: (row) => row.longitude || '-' },
            { key: 'note', header: 'Nota', render: (row) => row.note || '-' },
            { key: 'createdAt', header: 'Creado', render: (row) => formatDate(row.createdAt) },
          ]}
        />
      </section>

      <section className="card panel">
        <h3>Payload</h3>
        <pre className="code">{shipment ? JSON.stringify(shipment, null, 2) : 'Sin payload'}</pre>
      </section>
    </div>
  );
}
