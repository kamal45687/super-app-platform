# Database Migrations

## Initialization

To initialize the database with the complete schema:

```bash
# If using Docker Compose
docker-compose exec postgres psql -U postgres -d super_app -f /schemas/init.sql

# Or directly with psql
psql -h localhost -U postgres -d super_app -f schemas/init.sql
```

## TimescaleDB Setup

For real-time GPS tracking with time-series optimization:

```bash
# Run TimescaleDB migrations
psql -h localhost -U postgres -d super_app -f schemas/timescale-migrations.sql

# Verify hypertable creation
psql -h localhost -U postgres -d super_app -c "SELECT * FROM timescaledb_information.hypertables;"
```

## Database Structure Overview

### Core Tables
- **users** - User accounts (customer, driver, courier)
- **wallets** - Account balance tracking
- **payment_transactions** - Payment history and reconciliation

### Domain Tables
- **parcel_bookings** - Delivery orders
- **ride_bookings** - Ride requests and completions
- **ticket_bookings** - Train/bus ticket bookings

### Operational Tables
- **driver_profiles** - Driver metadata and ratings
- **vehicle_location_events** - Real-time GPS tracking (TimescaleDB)
- **refresh_tokens** - JWT refresh token management
- **notifications** - User notifications (SMS, Email, Push)

### Analytics Views
- **parcel_summary** - Daily parcel analytics
- **ride_summary** - Daily ride analytics
- **ticket_summary** - Daily ticket analytics

## Indexing Strategy

All tables are optimized with strategic indexes:
- Full-text search on addresses (JSONB GIN indexes)
- Time-based queries (composite indexes with timestamps)
- User lookups (unique constraints and indexes)
- Status filtering (enum-based indexes)

## Backup & Recovery

```bash
# Backup
pg_dump -h localhost -U postgres -d super_app > backup.sql

# Restore
psql -h localhost -U postgres -d super_app < backup.sql
```

## Performance Tuning

```sql
-- Check slow queries
SELECT query, mean_time, calls FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;

-- Analyze query plans
EXPLAIN ANALYZE SELECT * FROM parcel_bookings WHERE status = 'IN_TRANSIT';

-- Vacuum and analyze
VACUUM ANALYZE;
```
