# Ticket Service - Train & Bus Booking

> Handles train ticket booking, seat selection, and integration with IRCTC/RailRest APIs.

## Features

- Train availability search
- Real-time seat availability
- IRCTC API integration with retry logic
- Synchronous booking with timeout handling
- E-ticket PDF generation
- Booking status polling
- Cancellation and refund processing

## Environment Variables

```bash
NODE_ENV=development
PORT=3004
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/super_app
REDIS_URL=redis://localhost:6379
KAFKA_BROKERS=localhost:9092
IRCTC_API_KEY=your-api-key
IRCTC_API_URL=https://railrestapi.herokuapp.com
AUTH_SERVICE_URL=http://localhost:3001
PAYMENT_SERVICE_URL=http://localhost:3005
```

## API Endpoints

### Train Search
- `GET /trains/search` - Search available trains
- `GET /trains/:id/seats` - Get seat availability

### Ticket Booking
- `POST /tickets` - Book tickets
- `GET /tickets/:id` - Get ticket details
- `POST /tickets/:id/cancel` - Cancel booking
- `GET /tickets/history` - Get booking history

### Status Management
- `GET /tickets/:id/status` - Get ticket status
- `POST /tickets/:id/resend-eticket` - Resend e-ticket

## Installation

```bash
npm install
npm run db:migrate
npm run dev
```

## Testing

```bash
npm test
npm run test:irctc-integration
```
