import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

const jwtSecret = process.env.JWT_SECRET?.trim();

if (!jwtSecret) {
  throw new Error('JWT_SECRET is required');
}

@Injectable()
export class JwtAuthGuard implements CanActivate {
  private readonly jwtService = new JwtService({
    secret: jwtSecret,
  });

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const authHeader = request.headers.authorization as string | undefined;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedException('Token requerido.');
    }

    const token = authHeader.slice(7).trim();

    try {
      request.user = this.jwtService.verify(token);
      return true;
    } catch (_) {
      throw new UnauthorizedException('Token inválido o expirado.');
    }
  }
}
