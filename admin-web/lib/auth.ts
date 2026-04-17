import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';

export const AUTH_COOKIE = 'iway_admin_token';
export const USER_COOKIE = 'iway_admin_user';

export async function getSession() {
  const store = await cookies();
  const token = store.get(AUTH_COOKIE)?.value;
  const userRaw = store.get(USER_COOKIE)?.value;
  const user = userRaw ? JSON.parse(userRaw) : null;

  return { token, user } as {
    token?: string;
    user?: { id: string; email: string; fullName?: string; role?: string } | null;
  };
}

export async function requireSession() {
  const session = await getSession();
  if (!session.token) {
    redirect('/login');
  }
  return session;
}
