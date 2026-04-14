import { NextFunction, Request, Response } from 'express';

type BucketEntry = {
  count: number;
  resetAt: number;
};

const buckets = new Map<string, BucketEntry>();

function cleanupExpired(now: number) {
  for (const [key, value] of buckets.entries()) {
    if (value.resetAt <= now) {
      buckets.delete(key);
    }
  }
}

export function createRateLimitMiddleware(options: {
  keyPrefix: string;
  limit: number;
  windowMs: number;
}) {
  return (req: Request, res: Response, next: NextFunction) => {
    const now = Date.now();
    cleanupExpired(now);

    const requester = req as Request & { user?: { sub?: string } };
    const identity =
      requester.user?.sub?.toString() ||
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
