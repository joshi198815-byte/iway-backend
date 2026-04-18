import {
  getAntiFraudReviewQueue,
  getCollection,
} from '@/lib/api';
import { requireSession } from '@/lib/auth';
import { DataTable } from '@/components/data-table';
import { EmptyState } from '@/components/empty-state';
import { KeyValueList } from '@/components/key-value-list';
import { createAntiFraudFlagAction, recomputeAntiFraudSummaryAction } from '@/app/(protected)/mutations';

type SearchParams = Promise<Record<string, string | string[] | undefined>>;

function getParam(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] || '' : value || '';
}

export default async function AntiFraudPage({ searchParams }: { searchParams: SearchParams }) {
  const session = await requireSession();
  const token = session.token as string;
  const params = await searchParams;
  const selectedUserId = getParam(params.userId);

  const payload = await getAntiFraudReviewQueue(token);
  const queue = getCollection<Record<string, any>>(payload);
  const selected = queue.find((item) => item.userId === selectedUserId) || queue[0] || null;
  const userId = selected?.userId || '';

  return (
    <div className="stack">
      <div className="toolbar">
        <div>
          <h2 style={{ margin: 0 }}>Anti-Fraud</h2>
          <div className="muted">Usuarios con señales de riesgo y flags manuales</div>
        </div>
      </div>

      <div className="grid cols-2">
        <section className="card panel">
          <DataTable
            rows={queue}
            empty="Sin cola antifraude"
            rowLink={(row) => `/antifraud?userId=${row.userId}`}
            columns={[
              { key: 'user', header: 'Usuario', render: (row) => row.fullName || '-' },
              { key: 'email', header: 'Correo', render: (row) => row.email || '-' },
              { key: 'status', header: 'Traveler', render: (row) => row.travelerStatus || '-' },
              { key: 'risk', header: 'Risk', render: (row) => String(row.summary?.riskScore ?? 0) },
              { key: 'level', header: 'Level', render: (row) => row.summary?.recommendedRiskLevel || '-' },
            ]}
          />
        </section>

        <section className="stack">
          <div className="card panel">
            <h3>Resumen</h3>
            {selected ? (
              <KeyValueList
                items={[
                  { label: 'Usuario', value: selected.fullName || '-' },
                  { label: 'Correo', value: selected.email || '-' },
                  { label: 'Traveler status', value: selected.travelerStatus || '-' },
                  { label: 'Risk score', value: String(selected.summary?.riskScore ?? 0) },
                  { label: 'Risk level', value: selected.summary?.recommendedRiskLevel || '-' },
                  { label: 'Recommended action', value: selected.summary?.recommendedAction || '-' },
                ]}
              />
            ) : (
              <EmptyState title="Sin selección" description="No hay usuario seleccionado." />
            )}
          </div>

          <div className="card panel">
            <h3>Acciones</h3>
            {selected ? (
              <div className="stack">
                <form action={recomputeAntiFraudSummaryAction}>
                  <input type="hidden" name="userId" value={userId} />
                  <input type="hidden" name="path" value={`/antifraud?userId=${userId}`} />
                  <button className="button secondary" type="submit">Recalcular resumen</button>
                </form>
                <form action={createAntiFraudFlagAction} className="filters">
                  <input type="hidden" name="userId" value={userId} />
                  <input type="hidden" name="path" value={`/antifraud?userId=${userId}`} />
                  <input name="flagType" placeholder="flag_type" required />
                  <select name="severity" defaultValue="medium">
                    <option value="low">Low</option>
                    <option value="medium">Medium</option>
                    <option value="high">High</option>
                  </select>
                  <textarea name="details" placeholder="Detalles internos" />
                  <button className="button primary" type="submit">Crear flag manual</button>
                </form>
              </div>
            ) : (
              <div className="muted">No hay usuario seleccionado.</div>
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
