# Parcel Service - Logistics & Delivery Tracking

> Handles parcel booking, tracking, and integration with third-party logistics providers like Shiprocket and Delhivery.

## Features

- Parcel booking with pickup/delivery address management
- Real-time GPS tracking via WebSocket
- Integration with Shiprocket/Delhivery APIs
- Dynamic pricing based on weight and distance
- Webhook handling for carrier updates
- Parcel status lifecycle management
- Real-time notifications

## Environment Variables

```bash
NODE_ENV=development
PORT=3002
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/super_app
REDIS_URL=redis://localhost:6379
KAFKA_BROKERS=localhost:9092
SHIPROCKET_API_KEY=your-api-key
SHIPROCKET_WEBHOOK_SECRET=your-webhook-secret
GOOGLE_MAPS_API_KEY=your-api-key
AUTH_SERVICE_URL=http://localhost:3001
PAYMENT_SERVICE_URL=http://localhost:3005
```

## API Endpoints

### Parcel Management
- `POST /parcels` - Create parcel booking
- `GET /parcels/:id` - Get parcel details
- `GET /parcels` - List user's parcels
- `PUT /parcels/:id` - Update parcel
- `DELETE /parcels/:id` - Cancel parcel booking

### Tracking
- `GET /parcels/:id/tracking` - Get tracking history
- `WS /ws/tracking/:bookingId` - Real-time tracking via WebSocket

### Webhooks
- `POST /webhooks/shiprocket` - Handle Shiprocket webhooks
- `POST /webhooks/delhivery` - Handle Delhivery webhooks

## Installation

```bash
npm install
npm run db:migrate
npm run dev
```

## Testing

```bash
npm test
npm run test:e2e
```
