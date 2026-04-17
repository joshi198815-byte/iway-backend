export function EmptyState({ title, description }: { title: string; description: string }) {
  return (
    <div className="empty-state card panel">
      <div className="badge">Vacío</div>
      <h3 style={{ margin: '12px 0 8px' }}>{title}</h3>
      <p className="muted" style={{ margin: 0 }}>{description}</p>
    </div>
  );
}
