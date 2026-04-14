export declare function dispatchOperationalAlert(input: {
    requestId?: string;
    method?: string;
    path?: string;
    statusCode: number;
    message: string;
}): Promise<void>;
