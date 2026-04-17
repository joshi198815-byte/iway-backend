import { logoutAction } from '@/app/actions';

export function LogoutButton() {
  return (
    <form action={logoutAction}>
      <button className="button danger" type="submit">
        Salir
      </button>
    </form>
  );
}
