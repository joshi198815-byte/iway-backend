import { getReviewQueue, getShipments, getTransfersQueue } from '@/lib/api';
import { requireSession } from '@/lib/auth';

function countOf(value: unknown) {
  return Array.isArray(value) ? value.length : 0;
}

export default async function DashboardPage() {
  const session = await requireSession();
  const token = session.token as string;

  const [travelers, transfers, shipments] = await Promise.allSettled([
    getReviewQueue(token),
    getTransfersQueue(token),
    getShipments(token),
  ]);

  const travelersCount = travelers.status === 'fulfilled' ? countOf(travelers.value) : 0;
  const transfersCount = transfers.status === 'fulfilled' ? countOf(transfers.value) : 0;
  const shipmentsCount = shipments.status === 'fulfilled' ? countOf(shipments.value) : 0;

  const errors = [travelers, transfers, shipments]
    .filter((result) => result.status === 'rejected')
    .map((result) => (result as PromiseRejectedResult).reason?.message || 'Error cargando dashboard');

  return (
    <div className="grid" style={{ gap: 24 }}>
      <section className="grid cols-3">
        <div className="card kpi">
          <div className="label">Travelers por revisar</div>
          <div className="value">{travelersCount}</div>
        </div>
        <div className="card kpi">
          <div className="label">Transfers en cola</div>
          <div className="value">{transfersCount}</div>
        </div>
        <div className="card kpi">
          <div className="label">Shipments</div>
          <div className="value">{shipmentsCount}</div>
        </div>
      </section>

      {errors.length ? (
        <section className="alert error">
          {errors.join(' | ')}
        </section>
      ) : null}

      <section className="card panel">
        <h2 style={{ marginTop: 0 }}>Siguiente fase sugerida</h2>
        <ol style={{ margin: '12px 0 0', paddingLeft: 20 }}>
          <li>Agregar tabla real de Travelers Review</li>
          <li>Agregar revisión de transfers con preview de evidencia</li>
          <li>Agregar shipments y detalle</li>
          <li>Agregar finance dashboard</li>
          <li>Agregar gestión de colaboradores</li>
        </ol>
      </section>
    </div>
  );
}
