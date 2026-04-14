"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createRateLimitMiddleware = createRateLimitMiddleware;
const buckets = new Map();
function cleanupExpired(now) {
    for (const [key, value] of buckets.entries()) {
        if (value.resetAt <= now) {
            buckets.delete(key);
        }
    }
}
function createRateLimitMiddleware(options) {
    return (req, res, next) => {
        const now = Date.now();
        cleanupExpired(now);
        const requester = req;
        const identity = requester.user?.sub?.toString() ||
            req.ip ||
            req.headers['x-forwarded-for']?.toString() ||
            'unknown';
        const key = `${options.keyPrefix}:${identity}`;
        const existing = buckets.get(key);
        if (!existing || existing.resetAt <= now) {
            buckets.set(key, {
                count: 1,
                resetAt: now + options.windowMs,
            });
            return next();
        }
        existing.count += 1;
        if (existing.count > options.limit) {
            const retryAfterSeconds = Math.max(1, Math.ceil((existing.resetAt - now) / 1000));
            res.setHeader('Retry-After', retryAfterSeconds.toString());
            return res.status(429).json({
                statusCode: 429,
                message: 'Demasiadas solicitudes. Intenta de nuevo en un momento.',
            });
        }
        return next();
    };
}
//# sourceMappingURL=rate-limit.middleware.js.map