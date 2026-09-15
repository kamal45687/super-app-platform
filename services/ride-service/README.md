# Ride Service - Ride-Hailing & Matching Algorithm

> Handles ride requests, driver-passenger matching, real-time tracking, and dynamic pricing for taxi/bike services.

## Features

- Real-time driver-passenger matching algorithm
- Dynamic surge pricing based on demand
- Live location tracking via gRPC/WebSocket
- Integration with Google Maps API for routing
- OTP-based ride confirmation
- Driver rating and review system
- Surge pricing optimization

## Environment Variables

```bash
NODE_ENV=development
PORT=3003
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/super_app
REDIS_URL=redis://localhost:6379
KAFKA_BROKERS=localhost:9092
GOOGLE_MAPS_API_KEY=your-api-key
AUTH_SERVICE_URL=http://localhost:3001
PAYMENT_SERVICE_URL=http://localhost:3005
```

## API Endpoints

### Ride Management
- `POST /rides/request` - Request a ride
- `GET /rides/:id` - Get ride details
- `POST /rides/:id/cancel` - Cancel ride
- `POST /rides/:id/rate` - Rate ride and driver
- `GET /rides/history` - Get ride history

### Driver Management
- `POST /drivers/register` - Register as driver
- `PUT /drivers/:id/status` - Update driver online/offline status
- `GET /drivers/:id/earnings` - Get driver earnings
- `POST /drivers/:id/kyc` - Submit KYC documents

### Real-time Tracking
- `WS /ws/tracking/:rideId` - Real-time ride tracking

## Installation

```bash
npm install
npm run db:migrate
npm run dev
```

## Testing

```bash
npm test
npm run test:matching
```
