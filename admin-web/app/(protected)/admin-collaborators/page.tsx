import { DataTable } from '@/components/data-table';
import { KeyValueList } from '@/components/key-value-list';
import { createCollaboratorAction, resetCollaboratorPasswordAction, updateCollaboratorAction } from '@/app/(protected)/mutations';
import { getCollaborators, getCollection, formatDate } from '@/lib/api';
import { requireSession } from '@/lib/auth';

type SearchParams = Promise<Record<string, string | string[] | undefined>>;

function getParam(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] || '' : value || '';
}

export default async function AdminCollaboratorsPage({ searchParams }: { searchParams: SearchParams }) {
  const session = await requireSession();

  if (session.user?.role !== 'admin') {
    return (
      <section className="card panel">
        <h2>Admin Collaborators</h2>
        <p className="muted">Esta pantalla es solo para usuarios con rol admin.</p>
      </section>
    );
  }

  const token = session.token as string;
  const params = await searchParams;
  const selectedId = getParam(params.userId);
  const query = getParam(params.q).toLowerCase().trim();

  const payload = await getCollaborators(token);
  const collaboratorsRoot = (payload as Record<string, unknown>) || {};
  const collaborators = getCollection<Record<string, any>>(collaboratorsRoot.collaborators || payload).filter((item) => {
    if (!query) return true;
    return [item.fullName, item.email, item.phone, item.role, item.status]
      .filter(Boolean)
      .some((value) => String(value).toLowerCase().includes(query));
  });

  const selected = collaborators.find((item) => String(item.id) === selectedId) || collaborators[0] || null;
  const selectedUserId = selected ? String(selected.id) : '';

  return (
    <div className="stack">
      <div className="toolbar">
        <div>
          <h2 style={{ margin: 0 }}>Admin Collaborators</h2>
          <div className="muted">{collaborators.length} colaboradores</div>
        </div>
        <form className="filters" method="get">
          <input name="q" defaultValue={query} placeholder="Buscar por nombre, correo, teléfono o rol" />
          <button className="button secondary" type="submit">Buscar</button>
        </form>
      </div>

      <div className="grid cols-2">
        <section className="stack">
          <div className="card panel">
            <h3>Lista</h3>
            <DataTable
              rows={collaborators}
              empty="Sin colaboradores"
              rowLink={(row) => `/admin-collaborators?userId=${row.id}${query ? `&q=${encodeURIComponent(query)}` : ''}`}
              columns={[
                { key: 'name', header: 'Nombre', render: (row) => row.fullName || '-' },
                { key: 'email', header: 'Correo', render: (row) => row.email || '-' },
                { key: 'role', header: 'Rol', render: (row) => row.role || '-' },
                { key: 'status', header: 'Estado', render: (row) => row.status || '-' },
                { key: 'createdAt', header: 'Creado', render: (row) => formatDate(row.createdAt) },
              ]}
            />
          </div>

          <div className="card panel">
            <h3>Crear colaborador</h3>
            <form action={createCollaboratorAction} className="filters">
              <input name="fullName" placeholder="Nombre completo" />
              <input name="email" type="email" placeholder="correo@iway.one" />
              <input name="phone" placeholder="+50255551111" />
              <select name="role" defaultValue="support">
                <option value="support">Support</option>
                <option value="admin">Admin</option>
              </select>
              <input name="password" placeholder="Temporal opcional" />
              <button className="button primary" type="submit">Crear colaborador</button>
            </form>
          </div>
        </section>

        <section className="stack">
          <div className="card panel">
            <h3>Detalle</h3>
            {selected ? (
              <KeyValueList
                items={[
                  { label: 'Nombre', value: selected.fullName || '-' },
                  { label: 'Correo', value: selected.email || '-' },
                  { label: 'Teléfono', value: selected.phone || '-' },
                  { label: 'Rol', value: selected.role || '-' },
                  { label: 'Estado', value: selected.status || '-' },
                  { label: 'Actualizado', value: formatDate(selected.updatedAt) },
                ]}
              />
            ) : (
              <div className="muted">Selecciona un colaborador.</div>
            )}
          </div>

          <div className="card panel">
            <h3>Actualizar colaborador</h3>
            {selected ? (
              <form action={updateCollaboratorAction} className="filters">
                <input type="hidden" name="userId" value={selectedUserId} />
                <input type="hidden" name="path" value={`/admin-collaborators?userId=${selectedUserId}${query ? `&q=${encodeURIComponent(query)}` : ''}`} />
                <input name="fullName" defaultValue={selected.fullName || ''} placeholder="Nombre" />
                <select name="role" defaultValue={selected.role || 'support'}>
                  <option value="support">Support</option>
                  <option value="admin">Admin</option>
                </select>
                <select name="status" defaultValue={selected.status || 'active'}>
                  <option value="active">Active</option>
                  <option value="blocked">Blocked</option>
                  <option value="suspended">Suspended</option>
                </select>
                <button className="button primary" type="submit">Guardar cambios</button>
              </form>
            ) : (
              <div className="muted">No hay colaborador seleccionado.</div>
            )}
          </div>

          <div className="card panel">
            <h3>Reset password</h3>
            {selected ? (
              <form action={resetCollaboratorPasswordAction} className="filters">
                <input type="hidden" name="userId" value={selectedUserId} />
                <input type="hidden" name="path" value={`/admin-collaborators?userId=${selectedUserId}${query ? `&q=${encodeURIComponent(query)}` : ''}`} />
                <input name="password" placeholder="Nueva temporal opcional" />
                <button className="button secondary" type="submit">Resetear contraseña</button>
              </form>
            ) : (
              <div className="muted">No hay colaborador seleccionado.</div>
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
