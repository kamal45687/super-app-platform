import { Injectable, BadRequestException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { User } from './entities/user.entity';
import { RefreshToken } from './entities/refresh-token.entity';
import { RegisterDto, LoginDto, RefreshTokenDto } from './dtos';

@Injectable()
export class AuthService {
  constructor(
    private jwtService: JwtService,
    @InjectRepository(User) private userRepo: Repository<User>,
    @InjectRepository(RefreshToken) private refreshTokenRepo: Repository<RefreshToken>,
  ) {}

  /**
   * Register new user with phone number
   */
  async register(dto: RegisterDto) {
    const existingUser = await this.userRepo.findOne({
      where: { phoneNumber: dto.phoneNumber },
    });

    if (existingUser) {
      throw new BadRequestException('User already registered with this phone number');
    }

    const user = this.userRepo.create({
      phoneNumber: dto.phoneNumber,
      fullName: dto.fullName,
      email: dto.email,
      passwordHash: await bcrypt.hash(dto.password, 10),
    });

    await this.userRepo.save(user);
    return { userId: user.id, message: 'OTP sent to your phone' };
  }

  /**
   * Verify OTP and activate account
   */
  async verifyOtp(phoneNumber: string, otp: string) {
    const user = await this.userRepo.findOne({
      where: { phoneNumber },
    });

    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    // TODO: Verify OTP with Twilio
    user.kycStatus = 'PENDING';
    await this.userRepo.save(user);

    return { message: 'OTP verified successfully' };
  }

  /**
   * Login with phone and password
   */
  async login(dto: LoginDto) {
    const user = await this.userRepo.findOne({
      where: { phoneNumber: dto.phoneNumber },
    });

    if (!user || !(await bcrypt.compare(dto.password, user.passwordHash))) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const payload = {
      sub: user.id,
      phoneNumber: user.phoneNumber,
      scopes: ['ride', 'parcel', 'ticket'],
      kycVerified: user.kycStatus === 'VERIFIED',
    };

    const accessToken = this.jwtService.sign(payload);
    const refreshToken = await this.generateRefreshToken(user.id);

    return {
      accessToken,
      refreshToken: refreshToken.token,
      expiresIn: 900,
      tokenType: 'Bearer',
    };
  }

  /**
   * Refresh access token
   */
  async refreshAccessToken(dto: RefreshTokenDto) {
    const refreshToken = await this.refreshTokenRepo.findOne({
      where: { token: dto.refreshToken, isBlacklisted: false },
      relations: ['user'],
    });

    if (!refreshToken || refreshToken.expiresAt < new Date()) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    // Invalidate old refresh token (rotation)
    refreshToken.isBlacklisted = true;
    await this.refreshTokenRepo.save(refreshToken);

    // Generate new tokens
    const payload = {
      sub: refreshToken.user.id,
      phoneNumber: refreshToken.user.phoneNumber,
      scopes: ['ride', 'parcel', 'ticket'],
      kycVerified: refreshToken.user.kycStatus === 'VERIFIED',
    };

    const newAccessToken = this.jwtService.sign(payload);
    const newRefreshToken = await this.generateRefreshToken(refreshToken.user.id);

    return {
      accessToken: newAccessToken,
      refreshToken: newRefreshToken.token,
      expiresIn: 900,
    };
  }

  /**
   * Logout user
   */
  async logout(userId: string) {
    await this.refreshTokenRepo.update(
      { userId, isBlacklisted: false },
      { isBlacklisted: true },
    );
    return { message: 'Logged out successfully' };
  }

  /**
   * Get current user
   */
  async getCurrentUser(userId: string) {
    const user = await this.userRepo.findOne({
      where: { id: userId },
      select: ['id', 'phoneNumber', 'fullName', 'email', 'kycStatus', 'createdAt'],
    });

    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    return user;
  }

  /**
   * Generate refresh token
   */
  private async generateRefreshToken(userId: string) {
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7); // 7 days

    const refreshToken = this.refreshTokenRepo.create({
      userId,
      token: this.jwtService.sign({ sub: userId }, { expiresIn: '7d' }),
      expiresAt,
    });

    return await this.refreshTokenRepo.save(refreshToken);
  }
}
