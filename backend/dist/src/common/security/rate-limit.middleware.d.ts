import { NextFunction, Request, Response } from 'express';
export declare function createRateLimitMiddleware(options: {
    keyPrefix: string;
    limit: number;
    windowMs: number;
}): (req: Request, res: Response, next: NextFunction) => void | Response<any, Record<string, any>>;
