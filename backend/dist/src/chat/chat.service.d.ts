import { PrismaService } from '../database/prisma/prisma.service';
import { AntiFraudService } from '../anti-fraud/anti-fraud.service';
import { SendMessageDto } from './dto/send-message.dto';
import { RealtimeGateway } from '../realtime/realtime.gateway';
export declare class ChatService {
    private readonly prisma;
    private readonly antiFraudService;
    private readonly realtimeGateway;
    constructor(prisma: PrismaService, antiFraudService: AntiFraudService, realtimeGateway: RealtimeGateway);
    findMessages(chatId: string, userId: string): Promise<{
        id: string;
        createdAt: Date;
        body: string;
        senderId: string;
        chatId: string;
        riskStatus: import(".prisma/client").$Enums.MessageRiskStatus;
        riskFlags: import("@prisma/client/runtime/library").JsonValue | null;
        containsPhone: boolean;
        containsEmail: boolean;
        containsExternalLink: boolean;
    }[]>;
    getOrCreateByShipment(shipmentId: string, userId: string): Promise<{
        id: string;
        createdAt: Date;
        shipmentId: string;
    }>;
    sendMessage(payload: SendMessageDto): Promise<{
        message: {
            id: string;
            createdAt: Date;
            body: string;
            senderId: string;
            chatId: string;
            riskStatus: import(".prisma/client").$Enums.MessageRiskStatus;
            riskFlags: import("@prisma/client/runtime/library").JsonValue | null;
            containsPhone: boolean;
            containsEmail: boolean;
            containsExternalLink: boolean;
        };
        moderation: {
            riskStatus: "flagged" | "clean";
            flags: string[];
            directContactBlocked: boolean;
        };
    }>;
}
