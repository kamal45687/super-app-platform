-- Migration: Create TimescaleDB hypertable for GPS tracking
CREATE EXTENSION IF NOT EXISTS timescaledb;

SELECT create_hypertable('vehicle_location_events', 'time', if_not_exists => TRUE);

-- Create continuous aggregates for dashboards
CREATE MATERIALIZED VIEW vehicle_location_hourly WITH (timescaledb.continuous) AS
SELECT 
  time_bucket('1 hour', time) as bucket,
  vehicle_id,
  booking_id,
  AVG(latitude) as avg_latitude,
  AVG(longitude) as avg_longitude,
  AVG(speed_kmh) as avg_speed,
  MAX(speed_kmh) as max_speed,
  COUNT(*) as location_updates
FROM vehicle_location_events
GROUP BY bucket, vehicle_id, booking_id
WITH DATA;

-- Create daily aggregate view
CREATE MATERIALIZED VIEW vehicle_location_daily WITH (timescaledb.continuous) AS
SELECT 
  time_bucket('1 day', time) as bucket,
  vehicle_id,
  COUNT(DISTINCT booking_id) as daily_trips,
  SUM(CASE WHEN speed_kmh > 60 THEN 1 ELSE 0 END) as overspeeding_events,
  MAX(speed_kmh) as max_speed_observed
FROM vehicle_location_events
GROUP BY bucket, vehicle_id
WITH DATA;

-- Set up automatic refresh for continuous aggregates (every hour)
SELECT add_continuous_aggregate_policy('vehicle_location_hourly',
  start_offset => INTERVAL '2 hours',
  end_offset => INTERVAL '10 minutes',
  schedule_interval => INTERVAL '1 hour');
