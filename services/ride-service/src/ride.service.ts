import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Inject } from '@nestjs/common';
import { ClientKafka } from '@nestjs/microservices';
import { InjectRedis } from '@nestjs-modules/ioredis';
import Redis from 'ioredis';
import { RideBooking } from './entities/ride-booking.entity';
import { CreateRideDto } from './dtos';

@Injectable()
export class RideService {
  private readonly logger = new Logger(RideService.name);

  constructor(
    @InjectRepository(RideBooking) private rideRepo: Repository<RideBooking>,
    @Inject('KAFKA_SERVICE') private kafkaClient: ClientKafka,
    @InjectRedis() private redisClient: Redis,
  ) {}

  /**
   * Request a ride (matching algorithm)
   */
  async requestRide(userId: string, dto: CreateRideDto) {
    // Create ride request
    const ride = this.rideRepo.create({
      passengerId: userId,
      pickupLocation: dto.pickupLocation,
      dropoffLocation: dto.dropoffLocation,
      vehicleType: dto.vehicleType || 'CAR',
      status: 'REQUESTED',
      baseFare: this.getBaseFare(dto.vehicleType),
    });

    const savedRide = await this.rideRepo.save(ride);

    // Find nearby available drivers (Redis Geo)
    const nearbyDrivers = await this.findNearbyDrivers(
      dto.pickupLocation.lat,
      dto.pickupLocation.lng,
      5, // 5km radius
    );

    this.logger.debug(`Found ${nearbyDrivers.length} nearby drivers for ride ${savedRide.id}`);

    // Send matching requests to nearby drivers
    for (const driver of nearbyDrivers) {
      this.kafkaClient.emit('ride.matching.request', {
        rideId: savedRide.id,
        driverId: driver.id,
        pickupLocation: dto.pickupLocation,
        estimatedFare: this.estimateFare(dto),
      });
    }

    return savedRide;
  }

  /**
   * Find nearby drivers using Redis Geo
   */
  private async findNearbyDrivers(
    lat: number,
    lng: number,
    radiusKm: number,
  ): Promise<any[]> {
    const drivers = await this.redisClient.georadius(
      'active_drivers:geo',
      lng,
      lat,
      radiusKm,
      'km',
      'WITHCOORD',
      'WITHDIST',
      'COUNT',
      50,
      'ASC',
    );

    return drivers.map((d: any) => ({
      id: d[0],
      distance: parseFloat(d[1]),
      location: { lng: parseFloat(d[2][0]), lat: parseFloat(d[2][1]) },
    }));
  }

  /**
   * Get base fare by vehicle type
   */
  private getBaseFare(vehicleType: string): number {
    const fares: Record<string, number> = {
      'BIKE': 30,
      'AUTO': 40,
      'CAR': 50,
    };
    return fares[vehicleType] || 50;
  }

  /**
   * Estimate ride fare
   */
  private estimateFare(dto: CreateRideDto): number {
    // TODO: Integrate with Google Maps Distance Matrix API
    const baseFare = this.getBaseFare(dto.vehicleType);
    const distanceFare = 10 * 8; // Mock: 10km * 8 per km
    const surgeFactor = 1.0; // Dynamic surge pricing

    return (baseFare + distanceFare) * surgeFactor;
  }
}
