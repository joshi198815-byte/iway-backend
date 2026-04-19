export const DEFAULT_API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL || 'https://api.iway.one/api';

export type AdminUser = {
  id: string;
  email: string;
  fullName?: string;
  role: 'admin' | 'support' | string;
};

export type LoginResponse = {
  accessToken: string;
  user: AdminUser;
};

type ApiOptions = RequestInit & {
  token?: string;
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

function buildHeaders(init?: RequestInit, token?: string) {
  return {
    'Content-Type': 'application/json',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...(init?.headers || {}),
  };
}

export async function apiRequest<T>(path: string, init?: ApiOptions): Promise<T> {
  const bases = [DEFAULT_API_BASE_URL, DEFAULT_API_BASE_URL.replace(/\/api$/, '')];
  let lastError: unknown;

  for (const base of [...new Set(bases)]) {
    const response = await fetch(`${base}${path}`, {
      ...init,
      headers: buildHeaders(init, init?.token),
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

export function getCollection<T>(payload: unknown): T[] {
  if (Array.isArray(payload)) return payload as T[];
  if (payload && typeof payload === 'object') {
    const objectPayload = payload as Record<string, unknown>;
    for (const key of ['items', 'data', 'results', 'rows', 'queue', 'points', 'buckets', 'timeline', 'collaborators']) {
      const value = objectPayload[key];
      if (Array.isArray(value)) return value as T[];
    }
  }
  return [];
}

export function getObject<T>(payload: unknown): T | null {
  if (payload && typeof payload === 'object' && !Array.isArray(payload)) {
    return payload as T;
  }
  return null;
}

export function formatMoney(value: unknown) {
  const amount = Number(value ?? 0);
  if (Number.isNaN(amount)) return '-';
  return new Intl.NumberFormat('es-GT', {
    style: 'currency',
    currency: 'USD',
    maximumFractionDigits: 2,
  }).format(amount);
}

export function formatDate(value: unknown) {
  if (!value) return '-';
  const date = new Date(String(value));
  if (Number.isNaN(date.getTime())) return String(value);
  return new Intl.DateTimeFormat('es-GT', {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: 'UTC',
  }).format(date);
}

export function parseProtectedFileParts(protectedUrl?: string | null) {
  if (!protectedUrl) return null;
  const parts = protectedUrl.split('/').filter(Boolean);
  const idx = parts.indexOf('file-preview') >= 0 ? parts.indexOf('file-preview') : parts.indexOf('file');
  if (idx === -1 || parts.length < idx + 4) return null;

  return {
    bucket: parts[idx + 1],
    ownerId: parts[idx + 2],
    fileName: parts.slice(idx + 3).join('/'),
  };
}

export async function login(email: string, password: string) {
  return apiRequest<LoginResponse>('/auth/login', {
    method: 'POST',
    body: JSON.stringify({ email, password }),
  });
}

export async function getTravelersReviewQueue(token: string) {
  return apiRequest<unknown>('/travelers/review-queue', { token });
}

export async function reviewTraveler(token: string, userId: string, action: string, reason?: string) {
  return apiRequest(`/travelers/${userId}/review`, {
    token,
    method: 'POST',
    body: JSON.stringify({ status: action, reason }),
  });
}

export async function updateTravelerPayoutHold(
  token: string,
  userId: string,
  enabled: boolean,
  reason?: string,
) {
  return apiRequest(`/travelers/${userId}/payout-hold`, {
    token,
    method: 'POST',
    body: JSON.stringify({ enabled, reason }),
  });
}

export async function runTravelerKyc(token: string, userId: string) {
  return apiRequest(`/travelers/${userId}/run-kyc-analysis`, {
    token,
    method: 'POST',
    body: JSON.stringify({}),
  });
}

export async function getTransfersReviewQueue(token: string) {
  return apiRequest<unknown>('/transfers/review-queue', { token });
}

export async function reviewTransfer(token: string, transferId: string, action: string, reason?: string) {
  return apiRequest(`/transfers/${transferId}/review`, {
    token,
    method: 'PUT',
    body: JSON.stringify({ status: action, reason }),
  });
}

export async function getShipments(token: string) {
  return apiRequest<unknown>('/shipments', { token });
}

export async function getShipmentDetail(token: string, shipmentId: string) {
  return apiRequest<unknown>(`/shipments/${shipmentId}`, { token });
}

export async function getShipmentOffers(token: string, shipmentId: string) {
  return apiRequest<unknown>(`/offers/shipment/${shipmentId}`, { token });
}

export async function getTrackingTimeline(token: string, shipmentId: string) {
  return apiRequest<unknown>(`/tracking/shipment/${shipmentId}/timeline`, { token });
}

export async function getDisputesQueue(token: string) {
  return apiRequest<unknown>('/disputes/queue', { token });
}

export async function resolveDispute(token: string, disputeId: string, status: string, resolution?: string) {
  return apiRequest(`/disputes/${disputeId}/resolve`, {
    token,
    method: 'PUT',
    body: JSON.stringify({ status, resolution }),
  });
}

export async function getAntiFraudReviewQueue(token: string) {
  return apiRequest<unknown>('/anti-fraud/review-queue', { token });
}

export async function recomputeAntiFraudSummary(token: string, userId: string) {
  return apiRequest<unknown>(`/anti-fraud/user/${userId}/recompute`, {
    token,
    method: 'POST',
    body: JSON.stringify({}),
  });
}

export async function createAntiFraudFlag(
  token: string,
  userId: string,
  payload: { flagType: string; severity: string; details?: Record<string, unknown> },
) {
  return apiRequest(`/anti-fraud/user/${userId}/flags`, {
    token,
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export async function updateShipmentStatus(token: string, shipmentId: string, status: string) {
  return apiRequest(`/shipments/${shipmentId}/status`, {
    token,
    method: 'PATCH',
    body: JSON.stringify({ status }),
  });
}

export async function getFinanceOverview(token: string, query = '') {
  return apiRequest<unknown>(`/finance/overview${query}`, { token });
}

export async function getFinanceDebtors(token: string, query = '') {
  return apiRequest<unknown>(`/finance/debtors${query}`, { token });
}

export async function getFinanceSettlements(token: string, query = '') {
  return apiRequest<unknown>(`/finance/settlements${query}`, { token });
}

export async function getFinanceCountries(token: string, query = '') {
  return apiRequest<unknown>(`/finance/countries${query}`, { token });
}

export async function getFinanceRevenueSeries(token: string, query = '') {
  return apiRequest<unknown>(`/finance/revenue-series${query}`, { token });
}

export async function getFinanceDebtAging(token: string, query = '') {
  return apiRequest<unknown>(`/finance/debt-aging${query}`, { token });
}

export async function getCollaborators(token: string) {
  return apiRequest<unknown>('/users/admin/collaborators', { token });
}

export async function createCollaborator(
  token: string,
  payload: {
    fullName: string;
    email: string;
    phone: string;
    role: string;
    password?: string;
  },
) {
  return apiRequest<unknown>('/users/admin/collaborators', {
    token,
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export async function updateCollaborator(
  token: string,
  userId: string,
  payload: { role?: string; status?: string; fullName?: string },
) {
  return apiRequest<unknown>(`/users/admin/collaborators/${userId}`, {
    token,
    method: 'PATCH',
    body: JSON.stringify(payload),
  });
}

export async function resetCollaboratorPassword(
  token: string,
  userId: string,
  password?: string,
) {
  return apiRequest<unknown>(`/users/admin/collaborators/${userId}/reset-password`, {
    token,
    method: 'POST',
    body: JSON.stringify({ password }),
  });
}

export async function getPricingSettings(token: string) {
  return apiRequest<unknown>('/commissions/settings', { token });
}

export async function updatePricingSettings(
  token: string,
  payload: { commissionPerLb: number; groundCommissionPercent: number },
) {
  return apiRequest<unknown>('/commissions/settings', {
    token,
    method: 'PUT',
    body: JSON.stringify(payload),
  });
}

export async function getBannerFeed(feedKey: 'home' | 'traveler') {
  return apiRequest<unknown>(feedKey === 'traveler' ? '/content/traveler-banners' : '/content/home-banners');
}

export async function updateBannerFeed(
  token: string,
  feedKey: 'home' | 'traveler',
  items: Array<Record<string, unknown>>,
) {
  return apiRequest<unknown>(`/content/${feedKey}`, {
    token,
    method: 'PUT',
    body: JSON.stringify({ items }),
  });
}

export async function getProtectedFilePreview(token: string, protectedUrl?: string | null) {
  const parts = parseProtectedFileParts(protectedUrl);
  if (!parts) return null;
  return apiRequest<{ dataUrl?: string; contentType?: string; sizeBytes?: number }>(
    `/storage/file-preview/${parts.bucket}/${parts.ownerId}/${parts.fileName}`,
    { token },
  );
}
