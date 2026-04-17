const API_BASE_URL = process.env.API_BASE_URL || 'https://api.iway.one/api';
const ADMIN_EMAIL = process.env.ADMIN_EMAIL || '';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || '';

if (!ADMIN_EMAIL || !ADMIN_PASSWORD) {
  console.error('Missing ADMIN_EMAIL or ADMIN_PASSWORD');
  process.exit(1);
}

async function request(path, init = {}) {
  const bases = [API_BASE_URL, API_BASE_URL.replace(/\/api$/, '')];
  let lastError;

  for (const base of [...new Set(bases)]) {
    const response = await fetch(`${base}${path}`, {
      ...init,
      headers: {
        'Content-Type': 'application/json',
        ...(init.headers || {}),
      },
    });

    if (response.status === 404 && base.endsWith('/api')) {
      continue;
    }

    const text = await response.text();
    let payload = null;
    try {
      payload = text ? JSON.parse(text) : null;
    } catch {
      payload = text;
    }

    if (!response.ok) {
      lastError = new Error(`${path} -> ${response.status} ${JSON.stringify(payload)}`);
      break;
    }

    return payload;
  }

  throw lastError || new Error(`Request failed for ${path}`);
}

async function main() {
  console.log(`Validating admin API against ${API_BASE_URL}`);

  const login = await request('/auth/login', {
    method: 'POST',
    body: JSON.stringify({ email: ADMIN_EMAIL, password: ADMIN_PASSWORD }),
  });

  const token = login?.accessToken;
  const me = login?.user;
  if (!token) throw new Error('Login did not return accessToken');

  console.log('Login OK');
  console.log(`User: ${me?.fullName || me?.email || 'unknown'} (${me?.role || 'unknown'})`);

  const auth = { Authorization: `Bearer ${token}` };
  const checks = [
    ['/travelers/review-queue', 'Travelers review queue'],
    ['/transfers/review-queue', 'Transfers review queue'],
    ['/shipments', 'Shipments'],
    ['/finance/overview?range=month', 'Finance overview'],
  ];

  if (me?.role === 'admin') {
    checks.push(['/users/admin/collaborators', 'Collaborators']);
  }

  for (const [path, label] of checks) {
    const payload = await request(path, { headers: auth });
    const size = Array.isArray(payload)
      ? payload.length
      : Array.isArray(payload?.items)
        ? payload.items.length
        : Array.isArray(payload?.collaborators)
          ? payload.collaborators.length
          : 'ok';
    console.log(`${label}: ${size}`);
  }

  console.log('Validation OK');
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
