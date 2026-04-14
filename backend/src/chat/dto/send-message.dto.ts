import { IsString } from 'class-validator';

export class SendMessageDto {
  @IsString()
  chatId!: string;

  @IsString()
  senderId!: string;

  @IsString()
  body!: string;
}
