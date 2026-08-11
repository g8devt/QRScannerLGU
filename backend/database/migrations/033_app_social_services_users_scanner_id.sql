-- Migration 033: Track which scanner-staff account processed a claim.
-- Adds users_scanner_id to app_social_services, referencing app_users_scanner.id
-- (migration 032). Written by submit_claim_bataan going forward; NULL for any
-- claim recorded before this column existed. Run manually against bataan_db
-- (no migration-runner exists in this repo yet).

ALTER TABLE app_social_services
  ADD COLUMN users_scanner_id BIGINT NULL COMMENT 'this id is from app_users_scanner';
