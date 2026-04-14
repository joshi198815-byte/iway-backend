export declare class CreateManualFlagDto {
    flagType: string;
    severity: 'low' | 'medium' | 'high';
    details?: Record<string, unknown>;
}
