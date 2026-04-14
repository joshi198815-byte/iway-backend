const alertState = {
  lastSentAtMs: 0,
};

function shouldAlert(statusCode: number) {
  return statusCode >= 500;
}

export async function dispatchOperationalAlert(input: {
  requestId?: string;
  method?: string;
  path?: string;
  statusCode: number;
  message: string;
}) {
  const webhookUrl = process.env.OBSERVABILITY_ALERT_WEBHOOK_URL;
  if (!webhookUrl || !shouldAlert(input.statusCode)) {
    return;
  }

  const cooldownMs = Number(process.env.OBSERVABILITY_ALERT_COOLDOWN_MS ?? 120000);
  const now = Date.now();
  if (now - alertState.lastSentAtMs < cooldownMs) {
    return;
  }

  alertState.lastSentAtMs = now;

  try {
    await fetch(webhookUrl, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        service: 'iway-backend',
        env: process.env.NODE_ENV ?? 'development',
        at: new Date().toISOString(),
        severity: 'error',
        requestId: input.requestId,
        method: input.method,
        path: input.path,
        statusCode: input.statusCode,
        message: input.message,
      }),
    });
  } catch {
    // best effort, never break the request pipeline because alert delivery failed
  }
}
