'use client';

import { useActionState } from 'react';
import { loginAction, type LoginFormState } from '@/app/actions';

const initialState: LoginFormState = {};

export function LoginForm() {
  const [state, formAction, pending] = useActionState(loginAction, initialState);

  return (
    <form action={formAction} className="card auth-card">
      <div style={{ marginBottom: 20 }}>
        <div className="badge">Admin web</div>
        <h1 style={{ margin: '12px 0 8px' }}>iWay Admin</h1>
        <p className="muted" style={{ margin: 0 }}>
          Entra con tu usuario admin o support para operar revisiones, envíos y finanzas.
        </p>
      </div>

      <div className="field">
        <label htmlFor="email">Correo</label>
        <input id="email" name="email" type="email" placeholder="admin@iway.one" />
      </div>

      <div className="field">
        <label htmlFor="password">Contraseña</label>
        <input id="password" name="password" type="password" placeholder="••••••••" />
      </div>

      <button className="button primary" type="submit" disabled={pending} style={{ width: '100%' }}>
        {pending ? 'Entrando...' : 'Entrar'}
      </button>

      {state.error ? <div className="alert error">{state.error}</div> : null}
    </form>
  );
}
