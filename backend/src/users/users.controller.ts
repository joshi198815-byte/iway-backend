import { Controller, Get, Param } from '@nestjs/common';
import { UsersService } from './users.service';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('blueprint')
  getBlueprint() {
    return this.usersService.getBlueprint();
  }

  @Get(':id')
  getById(@Param('id') id: string) {
    return this.usersService.findPublicById(id);
  }
}
