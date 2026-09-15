-- =====================================================
-- Super App Platform - Database Schema
-- PostgreSQL 14+
-- =====================================================

CREATE SCHEMA IF NOT EXISTS public;

-- =====================================================
-- USER MANAGEMENT
-- =====================================================

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_number VARCHAR(15) UNIQUE NOT NULL,
  email VARCHAR(255) UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  full_name VARCHAR(255),
  profile_picture_url TEXT,
  kyc_status VARCHAR(20) DEFAULT 'PENDING', -- PENDING, VERIFIED, REJECTED
  kyc_document_url TEXT,
  user_type VARCHAR(50) DEFAULT 'CUSTOMER', -- CUSTOMER, DRIVER, COURIER
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  deleted_at TIMESTAMP,
  
  CONSTRAINT chk_kyc_status CHECK (kyc_status IN ('PENDING', 'VERIFIED', 'REJECTED')),
  CONSTRAINT chk_user_type CHECK (user_type IN ('CUSTOMER', 'DRIVER', 'COURIER'))
);

CREATE INDEX idx_users_phone ON users(phone_number);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_kyc_status ON users(kyc_status);
CREATE INDEX idx_users_created_at ON users(created_at DESC);

-- =====================================================
-- WALLETS & PAYMENTS
-- =====================================================

CREATE TABLE wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  balance DECIMAL(12, 2) DEFAULT 0,
  currency VARCHAR(3) DEFAULT 'INR',
  frozen_balance DECIMAL(12, 2) DEFAULT 0, -- For in-flight transactions
  last_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT chk_balance CHECK (balance >= 0),
  CONSTRAINT chk_frozen_balance CHECK (frozen_balance >= 0)
);

CREATE INDEX idx_wallets_user_id ON wallets(user_id);

CREATE TABLE payment_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  order_id VARCHAR(255) UNIQUE NOT NULL,
  order_type VARCHAR(50) NOT NULL, -- PARCEL, RIDE, TICKET, WALLET_TOPUP
  order_reference_id UUID,
  
  amount DECIMAL(12, 2) NOT NULL,
  currency VARCHAR(3) DEFAULT 'INR',
  
  gateway VARCHAR(50), -- razorpay, stripe
  gateway_transaction_id VARCHAR(255) UNIQUE,
  gateway_order_id VARCHAR(255),
  
  status VARCHAR(50) DEFAULT 'INITIATED', -- INITIATED, PENDING, AUTHORIZED, CAPTURED, FAILED, REFUNDED
  failure_reason TEXT,
  
  attempt_count SMALLINT DEFAULT 1,
  last_retry_at TIMESTAMP,
  
  refund_status VARCHAR(50) DEFAULT 'NONE', -- NONE, PENDING, COMPLETED, FAILED
  refund_amount DECIMAL(12, 2),
  refund_reason TEXT,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT chk_amount CHECK (amount > 0),
  CONSTRAINT chk_status CHECK (status IN ('INITIATED', 'PENDING', 'AUTHORIZED', 'CAPTURED', 'FAILED', 'REFUNDED')),
  CONSTRAINT chk_order_type CHECK (order_type IN ('PARCEL', 'RIDE', 'TICKET', 'WALLET_TOPUP'))
);

CREATE INDEX idx_payments_user_id ON payment_transactions(user_id);
CREATE INDEX idx_payments_status ON payment_transactions(status);
CREATE INDEX idx_payments_gateway_txn ON payment_transactions(gateway_transaction_id);
CREATE INDEX idx_payments_created_at ON payment_transactions(created_at DESC);

-- =====================================================
-- PARCEL SERVICE
-- =====================================================

CREATE TABLE parcel_bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  shiprocket_shipment_id VARCHAR(255) UNIQUE,
  
  -- Pickup
  pickup_address JSONB NOT NULL, -- {street, city, state, zip, lat, lng}
  pickup_contact_name VARCHAR(255) NOT NULL,
  pickup_contact_phone VARCHAR(15) NOT NULL,
  
  -- Delivery
  delivery_address JSONB NOT NULL,
  delivery_contact_name VARCHAR(255) NOT NULL,
  delivery_contact_phone VARCHAR(15) NOT NULL,
  
  -- Parcel info
  parcel_weight_kg DECIMAL(8, 2) NOT NULL,
  parcel_dimensions_cm JSONB, -- {length, width, height}
  parcel_category VARCHAR(50), -- documents, electronics, fragile
  declared_value_inr DECIMAL(12, 2),
  
  -- Status
  status VARCHAR(50) DEFAULT 'CREATED', -- CREATED, SCHEDULED, PICKED_UP, IN_TRANSIT, DELIVERED, FAILED, CANCELLED
  current_location JSONB, -- {lat, lng, address, updated_at}
  estimated_delivery TIMESTAMP,
  actual_delivery TIMESTAMP,
  
  -- Pricing
  base_fare DECIMAL(10, 2) NOT NULL,
  distance_charge DECIMAL(10, 2) DEFAULT 0,
  weight_charge DECIMAL(10, 2) DEFAULT 0,
  surge_charge DECIMAL(10, 2) DEFAULT 0,
  total_amount DECIMAL(12, 2) NOT NULL,
  payment_status VARCHAR(50) DEFAULT 'PENDING', -- PENDING, COMPLETED, FAILED, REFUNDED
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT chk_parcel_status CHECK (status IN ('CREATED', 'SCHEDULED', 'PICKED_UP', 'IN_TRANSIT', 'DELIVERED', 'FAILED', 'CANCELLED')),
  CONSTRAINT chk_parcel_amount CHECK (total_amount > 0),
  CONSTRAINT chk_parcel_weight CHECK (parcel_weight_kg > 0)
);

CREATE INDEX idx_parcels_user_id ON parcel_bookings(user_id);
CREATE INDEX idx_parcels_status ON parcel_bookings(status);
CREATE INDEX idx_parcels_created_at ON parcel_bookings(created_at DESC);
CREATE INDEX idx_parcels_delivery_address ON parcel_bookings USING GIN (delivery_address);

-- =====================================================
-- RIDE SERVICE
-- =====================================================

CREATE TABLE ride_bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  passenger_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  driver_id UUID REFERENCES users(id) ON DELETE SET NULL,
  
  -- Route
  pickup_location JSONB NOT NULL, -- {lat, lng, address}
  dropoff_location JSONB NOT NULL,
  
  -- Status
  status VARCHAR(50) DEFAULT 'REQUESTED', -- REQUESTED, ACCEPTED, ARRIVED, IN_PROGRESS, COMPLETED, CANCELLED
  
  -- Pricing
  base_fare DECIMAL(10, 2) NOT NULL,
  distance_km DECIMAL(8, 2),
  surge_multiplier DECIMAL(4, 2) DEFAULT 1.0,
  wait_time_minutes INT DEFAULT 0,
  wait_charges DECIMAL(10, 2) DEFAULT 0,
  total_fare DECIMAL(12, 2) NOT NULL,
  payment_method VARCHAR(50) DEFAULT 'WALLET', -- WALLET, CARD, UPI
  
  -- Ride details
  ride_start_time TIMESTAMP,
  ride_end_time TIMESTAMP,
  vehicle_type VARCHAR(50), -- AUTO, BIKE, CAR
  vehicle_registration VARCHAR(20),
  
  -- Safety
  otp_code CHAR(6) UNIQUE,
  rating_by_passenger SMALLINT,
  feedback_by_passenger TEXT,
  rating_by_driver SMALLINT,
  feedback_by_driver TEXT,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT chk_ride_status CHECK (status IN ('REQUESTED', 'ACCEPTED', 'ARRIVED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
  CONSTRAINT chk_ride_rating CHECK (rating_by_passenger IS NULL OR (rating_by_passenger >= 1 AND rating_by_passenger <= 5)),
  CONSTRAINT chk_ride_amount CHECK (total_fare > 0)
);

CREATE INDEX idx_rides_passenger_id ON ride_bookings(passenger_id);
CREATE INDEX idx_rides_driver_id ON ride_bookings(driver_id);
CREATE INDEX idx_rides_status ON ride_bookings(status);
CREATE INDEX idx_rides_created_at ON ride_bookings(created_at DESC);

-- =====================================================
-- TICKET SERVICE
-- =====================================================

CREATE TABLE ticket_bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Train details
  train_number VARCHAR(10) NOT NULL,
  train_name VARCHAR(255) NOT NULL,
  journey_date DATE NOT NULL,
  source_station_code VARCHAR(10) NOT NULL,
  destination_station_code VARCHAR(10) NOT NULL,
  
  -- Seat & Coach
  coach_number VARCHAR(5),
  seat_numbers TEXT[],
  class_type VARCHAR(20), -- 1AC, 2AC, 3AC, SL, GEN
  
  -- Passengers
  passengers JSONB NOT NULL, -- [{name, age, gender, berth_choice}, ...]
  
  -- Booking status
  pnr_number VARCHAR(20) UNIQUE,
  booking_status VARCHAR(50) DEFAULT 'PENDING', -- PENDING, CONFIRMED, RAC, WAITLIST, CANCELLED
  irctc_booking_id VARCHAR(255) UNIQUE,
  
  -- Pricing
  base_fare DECIMAL(12, 2),
  reservation_charge DECIMAL(10, 2),
  gst DECIMAL(10, 2),
  total_amount DECIMAL(12, 2) NOT NULL,
  payment_status VARCHAR(50) DEFAULT 'PENDING', -- PENDING, COMPLETED, FAILED
  
  -- E-ticket
  e_ticket_url TEXT,
  seat_layout_json JSONB,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT chk_ticket_status CHECK (booking_status IN ('PENDING', 'CONFIRMED', 'RAC', 'WAITLIST', 'CANCELLED')),
  CONSTRAINT chk_ticket_amount CHECK (total_amount > 0)
);

CREATE INDEX idx_tickets_user_id ON ticket_bookings(user_id);
CREATE INDEX idx_tickets_pnr ON ticket_bookings(pnr_number);
CREATE INDEX idx_tickets_booking_status ON ticket_bookings(booking_status);
CREATE INDEX idx_tickets_journey_date ON ticket_bookings(journey_date);
CREATE INDEX idx_tickets_created_at ON ticket_bookings(created_at DESC);

-- =====================================================
-- AUTHENTICATION & SESSIONS
-- =====================================================

CREATE TABLE refresh_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  is_blacklisted BOOLEAN DEFAULT FALSE,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT chk_expires_at CHECK (expires_at > CURRENT_TIMESTAMP)
);

CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_token ON refresh_tokens(token);
CREATE INDEX idx_refresh_tokens_blacklist ON refresh_tokens(is_blacklisted);

-- =====================================================
-- TIME-SERIES DATA (for TimescaleDB)
-- =====================================================

CREATE TABLE IF NOT EXISTS vehicle_location_events (
  time TIMESTAMP NOT NULL,
  vehicle_id UUID NOT NULL, -- driver_id or courier_id
  booking_id UUID NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  speed_kmh DECIMAL(6, 2),
  bearing SMALLINT, -- 0-360 degrees
  accuracy_meters INT,
  event_type VARCHAR(50) -- location_update, geofence_exit, harsh_acceleration
);

CREATE INDEX idx_vehicle_location_vehicle_time ON vehicle_location_events(vehicle_id, time DESC);
CREATE INDEX idx_vehicle_location_booking_time ON vehicle_location_events(booking_id, time DESC);

-- =====================================================
-- DRIVER & COURIER MANAGEMENT
-- =====================================================

CREATE TABLE driver_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  
  license_number VARCHAR(50) UNIQUE NOT NULL,
  license_expiry DATE NOT NULL,
  vehicle_registration VARCHAR(20) UNIQUE NOT NULL,
  vehicle_type VARCHAR(50), -- AUTO, BIKE, CAR
  vehicle_model VARCHAR(100),
  vehicle_capacity INT,
  
  total_rides INT DEFAULT 0,
  total_earnings DECIMAL(12, 2) DEFAULT 0,
  average_rating DECIMAL(3, 2) DEFAULT 0,
  is_online BOOLEAN DEFAULT FALSE,
  current_location JSONB, -- {lat, lng, updated_at}
  
  bank_account_number VARCHAR(50),
  bank_ifsc_code VARCHAR(20),
  pan_number VARCHAR(20),
  
  status VARCHAR(50) DEFAULT 'PENDING', -- PENDING, APPROVED, SUSPENDED, REJECTED
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT chk_driver_status CHECK (status IN ('PENDING', 'APPROVED', 'SUSPENDED', 'REJECTED'))
);

CREATE INDEX idx_driver_profiles_user_id ON driver_profiles(user_id);
CREATE INDEX idx_driver_profiles_status ON driver_profiles(status);
CREATE INDEX idx_driver_profiles_is_online ON driver_profiles(is_online);

-- =====================================================
-- NOTIFICATIONS
-- =====================================================

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  notification_type VARCHAR(50), -- BOOKING, PAYMENT, TRACKING, PROMOTIONAL
  related_entity_id UUID,
  related_entity_type VARCHAR(50), -- PARCEL, RIDE, TICKET
  
  is_read BOOLEAN DEFAULT FALSE,
  delivery_channel VARCHAR(50), -- SMS, EMAIL, PUSH
  delivery_status VARCHAR(50) DEFAULT 'PENDING', -- PENDING, SENT, FAILED
  delivery_timestamp TIMESTAMP,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);

-- =====================================================
-- VIEWS FOR ANALYTICS
-- =====================================================

CREATE OR REPLACE VIEW parcel_summary AS
SELECT 
  DATE(created_at) as booking_date,
  COUNT(*) as total_bookings,
  SUM(total_amount) as total_revenue,
  AVG(total_amount) as avg_booking_value,
  COUNT(CASE WHEN status = 'DELIVERED' THEN 1 END) as successful_deliveries,
  COUNT(CASE WHEN status = 'FAILED' THEN 1 END) as failed_deliveries
FROM parcel_bookings
GROUP BY DATE(created_at)
ORDER BY booking_date DESC;

CREATE OR REPLACE VIEW ride_summary AS
SELECT 
  DATE(created_at) as booking_date,
  COUNT(*) as total_rides,
  SUM(total_fare) as total_revenue,
  AVG(total_fare) as avg_ride_fare,
  COUNT(DISTINCT driver_id) as active_drivers,
  COUNT(DISTINCT passenger_id) as active_passengers,
  AVG(COALESCE(rating_by_passenger, 0)) as avg_rating
FROM ride_bookings
GROUP BY DATE(created_at)
ORDER BY booking_date DESC;

CREATE OR REPLACE VIEW ticket_summary AS
SELECT 
  DATE(created_at) as booking_date,
  COUNT(*) as total_bookings,
  SUM(total_amount) as total_revenue,
  AVG(total_amount) as avg_ticket_price,
  COUNT(CASE WHEN booking_status = 'CONFIRMED' THEN 1 END) as confirmed_bookings
FROM ticket_bookings
GROUP BY DATE(created_at)
ORDER BY booking_date DESC;
