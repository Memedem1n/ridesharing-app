import { Module } from '@nestjs/common';
import { UsersController } from './users.controller';
import { UsersService } from '@application/services/users/users.service';
import { PrismaService } from '@infrastructure/database/prisma.service';

@Module({
    controllers: [UsersController],
    providers: [UsersService, PrismaService],
    exports: [UsersService],
})
export class UsersModule { }
