import { ReactNode } from 'react';
import { requireSession } from '@/lib/auth';
import { Sidebar } from '@/components/sidebar';
import { LogoutButton } from '@/components/logout-button';

export default async function ProtectedLayout({ children }: { children: ReactNode }) {
  const session = await requireSession();

  return (
    <div className="layout">
      <Sidebar />
      <main className="content">
        <div className="header">
          <div>
            <div className="badge">{session.user?.role || 'admin'}</div>
            <h1 style={{ margin: '10px 0 4px' }}>Hola{session.user?.fullName ? `, ${session.user.fullName}` : ''}</h1>
            <p className="muted" style={{ margin: 0 }}>
              Esta es la primera base de la admin web en código.
            </p>
          </div>
          <LogoutButton />
        </div>
        {children}
      </main>
    </div>
  );
}
