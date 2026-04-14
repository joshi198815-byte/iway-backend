"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.dispatchOperationalAlert = dispatchOperationalAlert;
const alertState = {
    lastSentAtMs: 0,
};
function shouldAlert(statusCode) {
    return statusCode >= 500;
}
async function dispatchOperationalAlert(input) {
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
    }
    catch {
    }
}
//# sourceMappingURL=alert-dispatcher.js.map