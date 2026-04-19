import { Body, Controller, Delete, Get, Param, Patch, Post, Req, UseGuards } from '@nestjs/common';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateCollaboratorDto } from './dto/create-collaborator.dto';
import { UpdateCollaboratorRoleDto } from './dto/update-collaborator-role.dto';
import { ResetCollaboratorPasswordDto } from './dto/reset-collaborator-password.dto';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('blueprint')
  getBlueprint() {
    return this.usersService.getBlueprint();
  }

  @UseGuards(JwtAuthGuard)
  @Delete('me')
  deleteMe(@Req() req: any) {
    return this.usersService.deleteMyAccount(req.user.sub);
  }

  @UseGuards(JwtAuthGuard)
  @Get('admin/collaborators')
  listCollaborators(@Req() req: any) {
    return this.usersService.listCollaborators(req.user);
  }

  @UseGuards(JwtAuthGuard)
  @Post('admin/collaborators')
  createCollaborator(@Body() body: CreateCollaboratorDto, @Req() req: any) {
    return this.usersService.createCollaborator(body, req.user);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('admin/collaborators/:userId')
  updateCollaborator(@Param('userId') userId: string, @Body() body: UpdateCollaboratorRoleDto, @Req() req: any) {
    return this.usersService.updateCollaborator(userId, body, req.user);
  }

  @UseGuards(JwtAuthGuard)
  @Post('admin/collaborators/:userId/reset-password')
  resetCollaboratorPassword(
    @Param('userId') userId: string,
    @Body() body: ResetCollaboratorPasswordDto,
    @Req() req: any,
  ) {
    return this.usersService.resetCollaboratorPassword(userId, body.password, req.user);
  }

  @Get(':id')
  getById(@Param('id') id: string) {
    return this.usersService.findPublicById(id);
  }
}
