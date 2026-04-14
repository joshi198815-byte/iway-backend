import { Injectable } from '@nestjs/common';

@Injectable()
export class AuditService {
  log(action: string, entityType: string, entityId?: string) {
    return { action, entityType, entityId };
  }
}
