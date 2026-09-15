import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Inject } from '@nestjs/common';
import { ClientKafka } from '@nestjs/microservices';
import { ParcelBooking } from './entities/parcel-booking.entity';
import { ShiprocketAdapter } from './adapters/shiprocket.adapter';
import { CreateParcelDto, UpdateParcelDto } from './dtos';
import * as crypto from 'crypto';

@Injectable()
export class ParcelService {
  constructor(
    @InjectRepository(ParcelBooking) private parcelRepo: Repository<ParcelBooking>,
    @Inject('KAFKA_SERVICE') private kafkaClient: ClientKafka,
    private shiprocketAdapter: ShiprocketAdapter,
  ) {}

  /**
   * Create parcel booking
   */
  async createBooking(userId: string, dto: CreateParcelDto) {
    // Validate pickup and delivery addresses
    if (!dto.pickupAddress || !dto.deliveryAddress) {
      throw new BadRequestException('Pickup and delivery addresses are required');
    }

    // Calculate distance using Google Maps API
    const distance = await this.calculateDistance(
      dto.pickupAddress,
      dto.deliveryAddress,
    );

    // Calculate pricing
    const pricing = this.calculatePricing(dto.parcelWeightKg, distance);

    // Create booking
    const parcel = this.parcelRepo.create({
      userId,
      ...dto,
      distanceKm: distance,
      ...pricing,
      status: 'CREATED',
    });

    const savedParcel = await this.parcelRepo.save(parcel);

    // Publish event to Kafka
    this.kafkaClient.emit('parcel.created', {
      parcelId: savedParcel.id,
      userId,
      pickupAddress: savedParcel.pickupAddress,
      deliveryAddress: savedParcel.deliveryAddress,
      totalAmount: savedParcel.totalAmount,
    });

    return savedParcel;
  }

  /**
   * Get parcel details
   */
  async getParcel(parcelId: string, userId: string) {
    const parcel = await this.parcelRepo.findOne({
      where: { id: parcelId, userId },
    });

    if (!parcel) {
      throw new NotFoundException('Parcel not found');
    }

    return parcel;
  }

  /**
   * Update parcel (only before scheduled)
   */
  async updateParcel(parcelId: string, userId: string, dto: UpdateParcelDto) {
    const parcel = await this.parcelRepo.findOne({
      where: { id: parcelId, userId },
    });

    if (!parcel) {
      throw new NotFoundException('Parcel not found');
    }

    if (parcel.status !== 'CREATED') {
      throw new BadRequestException('Cannot update parcel after scheduling');
    }

    Object.assign(parcel, dto);
    await this.parcelRepo.save(parcel);

    return parcel;
  }

  /**
   * Cancel parcel booking
   */
  async cancelParcel(parcelId: string, userId: string) {
    const parcel = await this.parcelRepo.findOne({
      where: { id: parcelId, userId },
    });

    if (!parcel) {
      throw new NotFoundException('Parcel not found');
    }

    if (['DELIVERED', 'FAILED', 'CANCELLED'].includes(parcel.status)) {
      throw new BadRequestException('Cannot cancel completed bookings');
    }

    parcel.status = 'CANCELLED';
    await this.parcelRepo.save(parcel);

    // Publish cancellation event
    this.kafkaClient.emit('parcel.cancelled', {
      parcelId,
      userId,
    });

    return parcel;
  }

  /**
   * Handle Shiprocket webhook
   */
  async handleShiprocketWebhook(
    payload: any,
    signature: string,
  ) {
    // Verify HMAC signature
    const hash = crypto
      .createHmac('sha256', process.env.SHIPROCKET_WEBHOOK_SECRET)
      .update(JSON.stringify(payload))
      .digest('hex');

    if (hash !== signature) {
      throw new BadRequestException('Invalid webhook signature');
    }

    const parcel = await this.parcelRepo.findOne({
      where: { shiprocketShipmentId: payload.shipment_id },
    });

    if (!parcel) {
      return; // Ignore unknown shipments
    }

    // Update parcel status
    parcel.status = this.mapShiprocketStatus(payload.status);
    parcel.currentLocation = payload.current_location;
    parcel.updatedAt = new Date();

    await this.parcelRepo.save(parcel);

    // Publish tracking update event
    this.kafkaClient.emit('parcel.tracking.updated', {
      parcelId: parcel.id,
      status: parcel.status,
      location: parcel.currentLocation,
      timestamp: new Date(),
    });
  }

  /**
   * Calculate distance between two addresses
   */
  private async calculateDistance(from: any, to: any): Promise<number> {
    // TODO: Integrate with Google Maps API
    // For now, return mock value
    return 15.5;
  }

  /**
   * Calculate pricing
   */
  private calculatePricing(weightKg: number, distanceKm: number) {
    const baseFare = 50; // Base fare in INR
    const perKmRate = 8;
    const perKgRate = 5;

    const distanceCharge = distanceKm * perKmRate;
    const weightCharge = weightKg * perKgRate;
    const totalAmount = baseFare + distanceCharge + weightCharge;

    return {
      baseFare,
      distanceCharge,
      weightCharge,
      totalAmount,
      paymentStatus: 'PENDING',
    };
  }

  /**
   * Map Shiprocket status to internal status
   */
  private mapShiprocketStatus(shiprocketStatus: string): string {
    const statusMap: Record<string, string> = {
      'pickup_scheduled': 'SCHEDULED',
      'picked_up': 'PICKED_UP',
      'in_transit': 'IN_TRANSIT',
      'out_for_delivery': 'OUT_FOR_DELIVERY',
      'delivered': 'DELIVERED',
      'failed': 'FAILED',
      'return_initiated': 'RETURN_INITIATED',
      'return_in_transit': 'RETURN_IN_TRANSIT',
      'returned': 'RETURNED',
    };

    return statusMap[shiprocketStatus] || 'UNKNOWN';
  }
}
