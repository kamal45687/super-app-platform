import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ClientsModule, Transport } from '@nestjs/microservices';
import { ParcelController } from './parcel.controller';
import { ParcelService } from './parcel.service';
import { ParcelBooking } from './entities/parcel-booking.entity';
import { TrackingEvent } from './entities/tracking-event.entity';
import { LogisticsAdapter } from './adapters/logistics.adapter';
import { ShiprocketAdapter } from './adapters/shiprocket.adapter';

@Module({
  imports: [
    ConfigModule.forRoot(),
    TypeOrmModule.forFeature([ParcelBooking, TrackingEvent]),
    ClientsModule.register([
      {
        name: 'KAFKA_SERVICE',
        transport: Transport.KAFKA,
        options: {
          client: {
            brokers: process.env.KAFKA_BROKERS?.split(',') || ['localhost:9092'],
          },
          consumer: {
            groupId: 'parcel-service',
          },
        },
      },
    ]),
  ],
  controllers: [ParcelController],
  providers: [ParcelService, LogisticsAdapter, ShiprocketAdapter],
})
export class ParcelModule {}
