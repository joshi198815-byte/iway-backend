import { Body, Controller, Get, Req, UseGuards, Post } from '@nestjs/common';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { RegisterCustomerDto } from './dto/register-customer.dto';
import { RegisterTravelerAuthDto } from './dto/register-traveler-auth.dto';
import { JwtAuthGuard } from './jwt-auth.guard';
import { RequestVerificationCodeDto } from './dto/request-verification-code.dto';
import { VerifyContactCodeDto } from './dto/verify-contact-code.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register/customer')
  registerCustomer(@Body() body: RegisterCustomerDto) {
    return this.authService.registerCustomer(body);
  }

  @Post('register/traveler')
  registerTraveler(@Body() body: RegisterTravelerAuthDto) {
    return this.authService.registerTraveler(body);
  }

  @Post('login')
  login(@Body() body: LoginDto) {
    return this.authService.login(body);
  }

  @UseGuards(JwtAuthGuard)
  @Post('verification-code')
  requestVerificationCode(@Body() body: RequestVerificationCodeDto, @Req() req: any) {
    return this.authService.requestVerificationCode(req.user.sub, body.channel);
  }

  @UseGuards(JwtAuthGuard)
  @Post('verify-contact')
  verifyContact(@Body() body: VerifyContactCodeDto, @Req() req: any) {
    return this.authService.verifyContactCode(req.user.sub, body.channel, body.code);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  me(@Req() req: any) {
    return this.authService.me(req.user.sub);
  }
}
