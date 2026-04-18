import Link from 'next/link';
import { ErrorPanel } from '@/components/error-panel';
import { StatCard } from '@/components/stat-card';
import { getAntiFraudReviewQueue, getCollection, getDisputesQueue, getShipments, getTransfersReviewQueue, getTravelersReviewQueue } from '@/lib/api';
import { requireSession } from '@/lib/auth';

const shortcuts = [
  {
    href: '/travelers-review',
    title: 'Travelers Review',
    description: 'Aprobación KYC, payout hold y revisión operativa.',
  },
  {
    href: '/transfers-review',
    title: 'Transfers Review',
    description: 'Validación de comprobantes y decisiones de settlement.',
  },
  {
    href: '/shipments',
    title: 'Shipments',
    description: 'Seguimiento general, filtros y cambios rápidos de estado.',
  },
  {
    href: '/disputes',
    title: 'Disputes',
    description: 'Cola operativa, resolución y contexto del conflicto.',
  },
  {
    href: '/antifraud',
    title: 'Anti-Fraud',
    description: 'Cola de riesgo, resumen por usuario y flags manuales.',
  },
  {
    href: '/finance-dashboard',
    title: 'Finance Dashboard',
    description: 'KPIs, deuda, settlements y lectura ejecutiva.',
  },
];

function countOf(value: unknown) {
  return getCollection(value).length;
}

export default async function DashboardPage() {
  const session = await requireSession();
  const token = session.token as string;

  const [travelers, transfers, shipments, disputes, antiFraud] = await Promise.allSettled([
    getTravelersReviewQueue(token),
    getTransfersReviewQueue(token),
    getShipments(token),
    getDisputesQueue(token),
    getAntiFraudReviewQueue(token),
  ]);

  const travelersCount = travelers.status === 'fulfilled' ? countOf(travelers.value) : 0;
  const transfersCount = transfers.status === 'fulfilled' ? countOf(transfers.value) : 0;
  const shipmentsCount = shipments.status === 'fulfilled' ? countOf(shipments.value) : 0;
  const disputesCount = disputes.status === 'fulfilled' ? countOf(disputes.value) : 0;
  const antiFraudCount = antiFraud.status === 'fulfilled' ? countOf(antiFraud.value) : 0;

  const errors = [travelers, transfers, shipments, disputes, antiFraud]
    .filter((result) => result.status === 'rejected')
    .map((result) => (result as PromiseRejectedResult).reason?.message || 'Error cargando dashboard');

  return (
    <div className="grid" style={{ gap: 24 }}>
      <section className="grid cols-4">
        <StatCard label="Travelers por revisar" value={String(travelersCount)} />
        <StatCard label="Transfers en cola" value={String(transfersCount)} />
        <StatCard label="Shipments" value={String(shipmentsCount)} />
        <StatCard label="Disputes activas" value={String(disputesCount)} />
        <StatCard label="Anti-fraud queue" value={String(antiFraudCount)} />
      </section>

      {errors.length ? <ErrorPanel message={errors.join(' | ')} /> : null}

      <section className="card panel">
        <h2>Operación principal</h2>
        <div className="grid cols-2">
          {shortcuts.map((item) => (
            <Link key={item.href} href={item.href} className="card panel" style={{ minHeight: 160 }}>
              <div className="badge">Abrir</div>
              <h3 style={{ margin: '12px 0 8px' }}>{item.title}</h3>
              <p className="muted" style={{ margin: 0 }}>{item.description}</p>
            </Link>
          ))}
        </div>
      </section>

      <section className="card panel">
        <h2>Dirección del proyecto</h2>
        <ul style={{ margin: 0, paddingLeft: 20 }}>
          <li>Admin web en Next.js es la única superficie administrativa vigente.</li>
          <li>El dashboard ya contempla KYC, transfers, shipments, disputes y antifraud.</li>
          <li>Lo siguiente es validar login y payloads reales, luego pulir UX y roles.</li>
        </ul>
      </section>
    </div>
  );
}
