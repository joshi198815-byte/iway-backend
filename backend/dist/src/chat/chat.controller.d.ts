import { ChatService } from './chat.service';
import { SendMessageDto } from './dto/send-message.dto';
export declare class ChatController {
    private readonly chatService;
    constructor(chatService: ChatService);
    findMessages(chatId: string, req: any): Promise<{
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
    getOrCreateByShipment(shipmentId: string, req: any): Promise<{
        id: string;
        createdAt: Date;
        shipmentId: string;
    }>;
    sendMessage(body: SendMessageDto, req: any): Promise<{
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
