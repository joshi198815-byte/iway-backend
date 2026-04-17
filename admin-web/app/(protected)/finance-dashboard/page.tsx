import { DataTable } from '@/components/data-table';
import { StatCard } from '@/components/stat-card';
import {
  formatMoney,
  getCollection,
  getFinanceCountries,
  getFinanceDebtAging,
  getFinanceDebtors,
  getFinanceOverview,
  getFinanceRevenueSeries,
  getFinanceSettlements,
  getObject,
} from '@/lib/api';
import { requireSession } from '@/lib/auth';

type SearchParams = Promise<Record<string, string | string[] | undefined>>;

function getParam(value: string | string[] | undefined, fallback = '') {
  const result = Array.isArray(value) ? value[0] || '' : value || '';
  return result || fallback;
}

function buildQuery(params: Record<string, string>) {
  const search = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    if (value) search.set(key, value);
  });
  const query = search.toString();
  return query ? `?${query}` : '';
}

export default async function FinanceDashboardPage({ searchParams }: { searchParams: SearchParams }) {
  const session = await requireSession();
  const token = session.token as string;
  const params = await searchParams;

  const range = getParam(params.range, 'month');
  const country = getParam(params.country);
  const direction = getParam(params.direction);

  const overviewQuery = buildQuery({ range, country, direction });
  const settlementsQuery = buildQuery({ range, country });
  const debtorsQuery = buildQuery({ limit: '20', country, sortBy: 'currentDebt', sortDir: 'desc' });
  const countriesQuery = buildQuery({ range });
  const revenueQuery = buildQuery({ range, granularity: 'day', country, direction });
  const debtAgingQuery = buildQuery({ country });

  const [overviewPayload, debtorsPayload, settlementsPayload, countriesPayload, revenuePayload, debtAgingPayload] =
    await Promise.all([
      getFinanceOverview(token, overviewQuery),
      getFinanceDebtors(token, debtorsQuery),
      getFinanceSettlements(token, settlementsQuery),
      getFinanceCountries(token, countriesQuery),
      getFinanceRevenueSeries(token, revenueQuery),
      getFinanceDebtAging(token, debtAgingQuery),
    ]);

  const overview = getObject<Record<string, any>>(overviewPayload) || {};
  const debtors = getCollection<Record<string, any>>(debtorsPayload);
  const settlements = getCollection<Record<string, any>>(settlementsPayload);
  const countries = getCollection<Record<string, any>>(countriesPayload);
  const revenuePoints = getCollection<Record<string, any>>((getObject(revenuePayload) as any)?.points || revenuePayload);
  const debtBuckets = getCollection<Record<string, any>>((getObject(debtAgingPayload) as any)?.buckets || debtAgingPayload);

  return (
    <div className="stack">
      <div className="toolbar">
        <div>
          <h2 style={{ margin: 0 }}>Finance Dashboard</h2>
          <div className="muted">Vista ejecutiva financiera</div>
        </div>
        <form className="filters" method="get">
          <select name="range" defaultValue={range}>
            <option value="today">Hoy</option>
            <option value="week">Semana</option>
            <option value="month">Mes</option>
            <option value="year">Año</option>
          </select>
          <select name="country" defaultValue={country}>
            <option value="">Todos los países</option>
            <option value="GT">GT</option>
            <option value="US">US</option>
          </select>
          <select name="direction" defaultValue={direction}>
            <option value="">Todas las direcciones</option>
            <option value="gt_to_us">GT → US</option>
            <option value="us_to_gt">US → GT</option>
          </select>
          <button className="button secondary" type="submit">Actualizar</button>
        </form>
      </div>

      <section className="grid cols-4">
        <StatCard label="Gross Commission" value={formatMoney(overview.grossCommission)} />
        <StatCard label="Commission Collected" value={formatMoney(overview.commissionCollected)} />
        <StatCard label="Outstanding Debt" value={formatMoney(overview.outstandingDebt)} />
        <StatCard label="Overdue Debt" value={formatMoney(overview.overdueDebt)} />
        <StatCard label="Travelers con deuda" value={String(overview.travelersWithDebt || 0)} />
        <StatCard label="Bloqueados con deuda" value={String(overview.blockedTravelersWithDebt || 0)} />
        <StatCard label="Payout hold" value={String(overview.payoutHoldTravelers || 0)} />
        <StatCard label="Pending settlements" value={formatMoney(overview.pendingTransfersAmount)} />
      </section>

      <div className="grid cols-2">
        <section className="card panel">
          <h3>Revenue trend</h3>
          <pre className="code">{JSON.stringify(revenuePoints.slice(0, 20), null, 2)}</pre>
        </section>
        <section className="card panel">
          <h3>Debt aging</h3>
          <pre className="code">{JSON.stringify(debtBuckets, null, 2)}</pre>
        </section>
      </div>

      <section className="card panel">
        <h3>Top debtors</h3>
        <DataTable
          rows={debtors}
          empty="Sin deudores"
          columns={[
            { key: 'name', header: 'Nombre', render: (row) => row.fullName || '-' },
            { key: 'email', header: 'Correo', render: (row) => row.email || '-' },
            { key: 'country', header: 'País', render: (row) => row.country || '-' },
            { key: 'status', header: 'Estado', render: (row) => row.travelerStatus || '-' },
            { key: 'debt', header: 'Deuda actual', render: (row) => formatMoney(row.currentDebt) },
            { key: 'overdue', header: 'Vencida', render: (row) => formatMoney(row.overdueDebt) },
          ]}
        />
      </section>

      <section className="card panel">
        <h3>Settlement activity</h3>
        <DataTable
          rows={settlements}
          empty="Sin settlements"
          columns={[
            { key: 'id', header: 'Transfer', render: (row) => row.transferId || row.id || '-' },
            { key: 'traveler', header: 'Traveler', render: (row) => row.travelerName || row.traveler?.fullName || '-' },
            { key: 'country', header: 'País', render: (row) => row.country || '-' },
            { key: 'status', header: 'Estado', render: (row) => row.status || '-' },
            { key: 'amount', header: 'Monto', render: (row) => formatMoney(row.transferredAmount) },
          ]}
        />
      </section>

      <section className="card panel">
        <h3>Country finance</h3>
        <DataTable
          rows={countries}
          empty="Sin datos por país"
          columns={[
            { key: 'country', header: 'País', render: (row) => row.country || '-' },
            { key: 'gross', header: 'Gross', render: (row) => formatMoney(row.grossCommission) },
            { key: 'collected', header: 'Cobrado', render: (row) => formatMoney(row.commissionCollected) },
            { key: 'debt', header: 'Pendiente', render: (row) => formatMoney(row.outstandingDebt) },
            { key: 'shipments', header: 'Shipments', render: (row) => String(row.shipmentsCount || 0) },
          ]}
        />
      </section>
    </div>
  );
}
