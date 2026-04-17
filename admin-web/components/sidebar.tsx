import Link from 'next/link';

const links = [
  { href: '/dashboard', label: 'Dashboard' },
  { href: '/travelers-review', label: 'Travelers Review' },
  { href: '/transfers-review', label: 'Transfers Review' },
  { href: '/shipments', label: 'Shipments' },
  { href: '/finance-dashboard', label: 'Finance Dashboard' },
  { href: '/admin-collaborators', label: 'Admin Collaborators' },
];

export function Sidebar() {
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
