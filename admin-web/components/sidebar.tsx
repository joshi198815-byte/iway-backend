import Link from 'next/link';

type SidebarProps = {
  role?: string;
};

export function Sidebar({ role }: SidebarProps) {
  const links = [
    { href: '/dashboard', label: 'Dashboard' },
    { href: '/finance-dashboard', label: 'Tarifas y Wallet' },
    { href: '/transfers-review', label: 'Pagos viajeros' },
    { href: '/travelers-review', label: 'KYC viajeros' },
    { href: '/banner-feeds', label: 'Banners' },
    { href: '/shipments', label: 'Shipments' },
    { href: '/disputes', label: 'Disputes' },
    { href: '/antifraud', label: 'Anti-Fraud' },
    ...(role === 'admin' ? [{ href: '/admin-collaborators', label: 'Admin Collaborators' }] : []),
  ];

  return (
    <aside className="sidebar">
      <div>
        <div className="badge">iWay</div>
        <h2 style={{ margin: '12px 0 0' }}>Admin web</h2>
        <p className="muted" style={{ marginTop: 8 }}>
          Base inicial en Next.js conectada al backend actual.
        </p>
      </div>

      <nav>
        {links.map((link) => (
          <Link key={link.label} href={link.href}>
            {link.label}
          </Link>
        ))}
      </nav>
    </aside>
  );
}
