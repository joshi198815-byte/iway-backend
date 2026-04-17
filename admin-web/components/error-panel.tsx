export function ErrorPanel({ title = 'Algo salió mal', message }: { title?: string; message: string }) {
  return (
    <section className="alert error">
      <strong>{title}:</strong> {message}
    </section>
  );
}
