import { Body, Controller, Get, Req, UseGuards, Post, Patch } from '@nestjs/common';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { RegisterCustomerDto } from './dto/register-customer.dto';
import { RegisterTravelerAuthDto } from './dto/register-traveler-auth.dto';
import { JwtAuthGuard } from './jwt-auth.guard';
import { RequestVerificationCodeDto } from './dto/request-verification-code.dto';
import { VerifyContactCodeDto } from './dto/verify-contact-code.dto';
import { UpdatePendingPhoneDto } from './dto/update-pending-phone.dto';
import { UpdateMeDto } from './dto/update-me.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';

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

  @Post('forgot-password')
  forgotPassword(@Body() body: ForgotPasswordDto) {
    return this.authService.requestPasswordReset(body.email);
  }

  @Post('reset-password')
  resetPassword(@Body() body: ResetPasswordDto) {
    return this.authService.resetPassword(body.email, body.code, body.newPassword);
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
  @Post('update-pending-phone')
  updatePendingPhone(@Body() body: UpdatePendingPhoneDto, @Req() req: any) {
    return this.authService.updatePendingPhone(req.user.sub, body.phone);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  me(@Req() req: any) {
    return this.authService.me(req.user.sub);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('me')
  updateMe(@Body() body: UpdateMeDto, @Req() req: any) {
    return this.authService.updateMe(req.user.sub, body);
  }
}
