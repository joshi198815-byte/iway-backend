'use server';

import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { AUTH_COOKIE, USER_COOKIE } from '@/lib/auth';
import { login } from '@/lib/api';

const isSecureCookie = process.env.NODE_ENV === 'production';

export type LoginFormState = {
  error?: string;
};

export async function loginAction(
  _prevState: LoginFormState,
  formData: FormData,
): Promise<LoginFormState> {
  const email = String(formData.get('email') || '').trim();
  const password = String(formData.get('password') || '').trim();

  if (!email || !password) {
    return { error: 'Ingresa correo y contraseña.' };
  }

  try {
    const result = await login(email, password);

    if (!['admin', 'support'].includes(result.user.role)) {
      return { error: 'Tu usuario no tiene permisos de admin.' };
    }

    const store = await cookies();
    store.set(AUTH_COOKIE, result.accessToken, {
      httpOnly: true,
      sameSite: 'lax',
      secure: isSecureCookie,
      path: '/',
      maxAge: 60 * 60 * 12,
    });
    store.set(USER_COOKIE, JSON.stringify(result.user), {
      httpOnly: true,
      sameSite: 'lax',
      secure: isSecureCookie,
      path: '/',
      maxAge: 60 * 60 * 12,
    });
  } catch (error) {
    return {
      error: error instanceof Error ? error.message : 'No se pudo iniciar sesión.',
    };
  }

  redirect('/dashboard');
}

export async function logoutAction() {
  const store = await cookies();
  store.delete(AUTH_COOKIE);
  store.delete(USER_COOKIE);
  redirect('/login');
}
