import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';

export const AUTH_COOKIE = 'iway_admin_token';
export const USER_COOKIE = 'iway_admin_user';
const ALLOWED_ADMIN_ROLES = ['admin', 'support'] as const;

type AdminRole = (typeof ALLOWED_ADMIN_ROLES)[number];
export type AdminSessionUser = {
  id: string;
  email: string;
  fullName?: string;
  role?: string;
};

function isAllowedRole(role?: string): role is AdminRole {
  return !!role && ALLOWED_ADMIN_ROLES.includes(role as AdminRole);
}

export async function getSession() {
  const store = await cookies();
  const token = store.get(AUTH_COOKIE)?.value;
  const userRaw = store.get(USER_COOKIE)?.value;
  const user = userRaw ? (JSON.parse(userRaw) as AdminSessionUser) : null;

  return { token, user } as {
    token?: string;
    user?: AdminSessionUser | null;
  };
}

export async function requireSession() {
  const session = await getSession();
  if (!session.token || !isAllowedRole(session.user?.role)) {
    redirect('/login');
  }
  return session as { token: string; user: AdminSessionUser & { role: AdminRole } };
}

export async function requireAdminSession() {
  const session = await requireSession();
  if (session.user.role !== 'admin') {
    redirect('/dashboard');
  }
  return session;
}
