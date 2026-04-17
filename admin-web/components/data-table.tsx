import Link from 'next/link';
import { ReactNode } from 'react';

type Column<T> = {
  key: string;
  header: string;
  render: (row: T) => ReactNode;
};

export function DataTable<T extends { id?: string | number }>({
  rows,
  columns,
  empty,
  rowLink,
}: {
  rows: T[];
  columns: Array<Column<T>>;
  empty?: string;
  rowLink?: (row: T) => string;
}) {
  return (
    <table className="table">
      <thead>
        <tr>
          {columns.map((column) => (
            <th key={column.key}>{column.header}</th>
          ))}
        </tr>
      </thead>
      <tbody>
        {rows.length ? (
          rows.map((row, index) => (
            <tr key={String(row.id ?? index)}>
              {columns.map((column, columnIndex) => {
                const content = column.render(row);
                if (columnIndex === 0 && rowLink) {
                  return (
                    <td key={column.key}>
                      <Link href={rowLink(row)}>{content}</Link>
                    </td>
                  );
                }
                return <td key={column.key}>{content}</td>;
              })}
            </tr>
          ))
        ) : (
          <tr>
            <td colSpan={columns.length} className="muted">
              {empty || 'Sin datos'}
            </td>
          </tr>
        )}
      </tbody>
    </table>
  );
}
