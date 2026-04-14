import { CanActivate, ExecutionContext } from '@nestjs/common';
export declare class JwtAuthGuard implements CanActivate {
    private readonly jwtService;
    canActivate(context: ExecutionContext): boolean;
}
