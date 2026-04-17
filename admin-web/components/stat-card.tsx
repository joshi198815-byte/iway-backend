export function StatCard({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <div className="card kpi">
      <div className="label">{label}</div>
      <div className="value" style={{ fontSize: 28 }}>{value}</div>
      {hint ? <div className="muted" style={{ marginTop: 6, fontSize: 13 }}>{hint}</div> : null}
    </div>
  );
}
