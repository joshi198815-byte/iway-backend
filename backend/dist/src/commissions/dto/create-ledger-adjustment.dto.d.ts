export declare class CreateLedgerAdjustmentDto {
    direction: 'debit' | 'credit';
    amount: number;
    description: string;
    weeklySettlementId?: string;
}
