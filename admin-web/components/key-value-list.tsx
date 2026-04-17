export function KeyValueList({ items }: { items: Array<{ label: string; value: string }> }) {
  return (
    <div className="kv-list">
      {items.map((item) => (
        <div key={item.label} className="kv-item">
          <div className="muted" style={{ fontSize: 13 }}>{item.label}</div>
          <div>{item.value}</div>
        </div>
      ))}
    </div>
  );
}
