import Link from 'next/link';
import { EmptyState } from '@/components/empty-state';
import { getProtectedFilePreview, getCollection, getTravelersReviewQueue, formatDate } from '@/lib/api';
import { requireSession } from '@/lib/auth';
import { DataTable } from '@/components/data-table';
import { KeyValueList } from '@/components/key-value-list';
import { payoutHoldAction, reviewTravelerAction, runKycAction } from '@/app/(protected)/mutations';

type SearchParams = Promise<Record<string, string | string[] | undefined>>;

function getParam(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] || '' : value || '';
}

function pickUserId(item: Record<string, any>) {
  return item.userId || item.user?.id || item.id || '';
}

function text(v: unknown) {
  return v ? String(v) : '-';
}

export default async function TravelersReviewPage({ searchParams }: { searchParams: SearchParams }) {
  const session = await requireSession();
  const token = session.token as string;
  const params = await searchParams;
  const query = getParam(params.q).toLowerCase().trim();
  const selectedId = getParam(params.userId);

  const payload = await getTravelersReviewQueue(token);
  const travelers = getCollection<Record<string, any>>(payload).filter((item) => {
    if (!query) return true;
    return [
      item.fullName,
      item.user?.fullName,
      item.email,
      item.user?.email,
      item.phone,
      item.user?.phone,
      item.documentNumber,
      item.travelerProfile?.dpiOrPassport,
    ]
      .filter(Boolean)
      .some((value) => String(value).toLowerCase().includes(query));
  });

  const selected = travelers.find((item) => pickUserId(item) === selectedId) || travelers[0] || null;
  const selectedUserId = selected ? pickUserId(selected) : '';
  const documentUrl = selected?.summary?.evidence?.documentUrl || selected?.evidence?.documentUrl || selected?.documentUrl;
  const selfieUrl = selected?.summary?.evidence?.selfieUrl || selected?.evidence?.selfieUrl || selected?.selfieUrl;
  const [documentPreview, selfiePreview] = selected
    ? await Promise.all([
        getProtectedFilePreview(token, documentUrl),
        getProtectedFilePreview(token, selfieUrl),
      ])
    : [null, null];

  return (
    <div className="stack">
      <div className="toolbar">
        <div>
          <h2 style={{ margin: 0 }}>Travelers Review</h2>
          <div className="muted">{travelers.length} por revisar</div>
        </div>
        <form className="filters" method="get">
          <input name="q" defaultValue={query} placeholder="Buscar por nombre, correo, teléfono o documento" />
          <button className="button secondary" type="submit">Buscar</button>
        </form>
      </div>

      <div className="grid cols-2">
        <section className="card panel">
          <DataTable
            rows={travelers}
            empty="No hay travelers pendientes"
            rowLink={(row) => `/travelers-review?userId=${pickUserId(row)}${query ? `&q=${encodeURIComponent(query)}` : ''}`}
            columns={[
              {
                key: 'name',
                header: 'Traveler',
                render: (row) => row.fullName || row.user?.fullName || '-',
              },
              {
                key: 'email',
                header: 'Correo',
                render: (row) => row.email || row.user?.email || '-',
              },
              {
                key: 'type',
                header: 'Tipo',
                render: (row) => row.travelerType || row.travelerProfile?.travelerType || '-',
              },
              {
                key: 'status',
                header: 'Estado',
                render: (row) => row.status || row.user?.status || '-',
              },
              {
                key: 'createdAt',
                header: 'Creado',
                render: (row) => formatDate(row.createdAt),
              },
            ]}
          />
        </section>

        <section className="stack">
          <div className="card panel">
            <h3>Resumen</h3>
            {selected ? (
              <KeyValueList
                items={[
                  { label: 'Nombre', value: text(selected.fullName || selected.user?.fullName) },
                  { label: 'Correo', value: text(selected.email || selected.user?.email) },
                  { label: 'Teléfono', value: text(selected.phone || selected.user?.phone) },
                  { label: 'Tipo', value: text(selected.travelerType || selected.travelerProfile?.travelerType) },
                  { label: 'Documento', value: text(selected.documentNumber || selected.travelerProfile?.dpiOrPassport) },
                  { label: 'Estado', value: text(selected.status || selected.user?.status) },
                ]}
              />
            ) : (
              <EmptyState title="Sin selección" description="Elige un traveler de la cola para revisar KYC, payout hold y evidencia." />
            )}
          </div>

          <div className="card panel">
            <h3>Previews</h3>
            <div className="grid cols-2">
              <div>
                <div className="muted" style={{ marginBottom: 8 }}>Documento</div>
                {documentPreview?.dataUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={documentPreview.dataUrl} alt="Documento" style={{ maxWidth: '100%', borderRadius: 12, border: '1px solid var(--line)' }} />
                ) : (
                  <div className="muted">Sin preview disponible</div>
                )}
              </div>
              <div>
                <div className="muted" style={{ marginBottom: 8 }}>Selfie</div>
                {selfiePreview?.dataUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={selfiePreview.dataUrl} alt="Selfie" style={{ maxWidth: '100%', borderRadius: 12, border: '1px solid var(--line)' }} />
                ) : (
                  <div className="muted">Sin preview disponible</div>
                )}
              </div>
            </div>
          </div>

          <div className="card panel">
            <h3>Acciones</h3>
            {selected ? (
              <div className="stack">
                <form action={reviewTravelerAction} className="filters">
                  <input type="hidden" name="userId" value={selectedUserId} />
                  <input type="hidden" name="path" value={`/travelers-review?userId=${selectedUserId}${query ? `&q=${encodeURIComponent(query)}` : ''}`} />
                  <select name="action" defaultValue="approved">
                    <option value="approved">Aprobar</option>
                    <option value="rejected">Rechazar</option>
                    <option value="manual_review">Manual review</option>
                  </select>
                  <textarea name="reason" placeholder="Motivo o nota operativa" />
                  <button className="button primary" type="submit">Guardar revisión</button>
                </form>

                <form action={payoutHoldAction} className="filters">
                  <input type="hidden" name="userId" value={selectedUserId} />
                  <input type="hidden" name="path" value={`/travelers-review?userId=${selectedUserId}${query ? `&q=${encodeURIComponent(query)}` : ''}`} />
                  <select name="enabled" defaultValue="true">
                    <option value="true">Activar payout hold</option>
                    <option value="false">Quitar payout hold</option>
                  </select>
                  <textarea name="reason" placeholder="Razón del payout hold" />
                  <button className="button secondary" type="submit">Guardar payout hold</button>
                </form>

                <form action={runKycAction}>
                  <input type="hidden" name="userId" value={selectedUserId} />
                  <input type="hidden" name="path" value={`/travelers-review?userId=${selectedUserId}${query ? `&q=${encodeURIComponent(query)}` : ''}`} />
                  <button className="button secondary" type="submit">Run KYC analysis</button>
                </form>
              </div>
            ) : (
              <div className="muted">No hay traveler seleccionado.</div>
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
