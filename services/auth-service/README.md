# Auth Service - OAuth2 & JWT Authentication

> Handles user registration, login, token generation, and refresh token management for the Super App platform.

## Features

- Phone-based OTP authentication
- OAuth2 + JWT token generation (RS256)
- Refresh token rotation with blacklist
- KYC verification status tracking
- Role-based access control (RBAC)
- JWT token introspection

## Environment Variables

```bash
NODE_ENV=development
PORT=3001
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/super_app
REDIS_URL=redis://localhost:6379
JWT_SECRET=your-secret-key
JWT_PRIVATE_KEY=your-private-key
JWT_PUBLIC_KEY=your-public-key
JWT_EXPIRY=900
REFRESH_TOKEN_EXPIRY=604800
TWILIO_ACCOUNT_SID=your-account-sid
TWILIO_AUTH_TOKEN=your-auth-token
TWILIO_PHONE_NUMBER=+1234567890
```

## API Endpoints

### Authentication
- `POST /auth/register` - Register new user with phone number
- `POST /auth/verify-otp` - Verify OTP and create account
- `POST /auth/login` - Login with phone + password
- `POST /auth/refresh` - Refresh access token
- `POST /auth/logout` - Logout and blacklist refresh token
- `GET /auth/me` - Get current user info
- `GET /auth/introspect` - Introspect JWT token

### User Management
- `PUT /users/:id` - Update user profile
- `GET /users/:id` - Get user details
- `POST /users/:id/kyc` - Submit KYC documents
- `GET /users/:id/kyc-status` - Check KYC verification status

## Installation

```bash
npm install
npm run db:migrate
npm run dev
```

## Testing

```bash
npm test
npm run test:coverage
```
