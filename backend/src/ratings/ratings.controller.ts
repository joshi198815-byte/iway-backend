import { Body, Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import { RatingsService } from './ratings.service';
import { CreateRatingDto } from './dto/create-rating.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@UseGuards(JwtAuthGuard)

@Controller('ratings')
export class RatingsController {
  constructor(private readonly ratingsService: RatingsService) {}

  @Get('blueprint')
  getBlueprint() {
    return this.ratingsService.getBlueprint();
  }

  @Get('user/:userId')
  findByUser(@Param('userId') userId: string, @Req() req: any) {
    return this.ratingsService.findByUser(userId, req.user);
  }

  @Post()
  create(@Body() body: CreateRatingDto, @Req() req: any) {
    return this.ratingsService.create({
      ...body,
      fromUserId: req.user.sub,
    });
  }
}
