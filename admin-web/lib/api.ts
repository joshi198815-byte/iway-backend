export const DEFAULT_API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL || 'https://api.iway.one/api';

export type LoginResponse = {
  accessToken: string;
  user: {
    id: string;
    email: string;
    fullName?: string;
    role: 'admin' | 'support' | string;
  };
};

async function parseJsonSafe(response: Response) {
  const text = await response.text();
  if (!text) return null;

  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

export async function apiRequest<T>(path: string, init?: RequestInit): Promise<T> {
  const bases = [DEFAULT_API_BASE_URL, DEFAULT_API_BASE_URL.replace(/\/api$/, '')];
  let lastError: unknown;

  for (const base of [...new Set(bases)]) {
    const response = await fetch(`${base}${path}`, {
      ...init,
      headers: {
        'Content-Type': 'application/json',
        ...(init?.headers || {}),
      },
      cache: 'no-store',
    });

    if (response.status === 404 && base.endsWith('/api')) {
      continue;
    }

    if (!response.ok) {
      const payload = await parseJsonSafe(response);
      lastError = new Error(
        typeof payload === 'object' && payload && 'message' in payload
          ? String((payload as { message: string }).message)
          : `API error ${response.status}`,
      );
      break;
    }

    return (await response.json()) as T;
  }

  throw lastError || new Error('No se pudo conectar al backend');
}

export async function login(email: string, password: string) {
  return apiRequest<LoginResponse>('/auth/login', {
    method: 'POST',
    body: JSON.stringify({ email, password }),
  });
}

export async function getReviewQueue(token: string) {
  return apiRequest<Array<Record<string, unknown>>>('/travelers/review-queue', {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });
}

export async function getTransfersQueue(token: string) {
  return apiRequest<Array<Record<string, unknown>>>('/transfers/review-queue', {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });
}

export async function getShipments(token: string) {
  return apiRequest<Array<Record<string, unknown>>>('/shipments', {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });
}
