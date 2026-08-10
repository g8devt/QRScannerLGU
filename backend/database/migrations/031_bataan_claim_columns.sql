-- Migration 031: Bataan social-service claim-capture columns.
-- Adds claimant/claim-method tracking to app_social_services for the
-- verify_qr_bataan / submit_claim_bataan endpoints. Run manually against
-- bataan_db (no migration-runner exists in this repo yet).

ALTER TABLE app_social_services
  ADD COLUMN claim_method        VARCHAR(20)  NULL,  -- 'QR' | 'MANUAL'
  ADD COLUMN claimant_type       VARCHAR(20)  NULL,  -- 'SELF' | 'REPRESENTATIVE'
  ADD COLUMN claimant_name       VARCHAR(255) NULL,
  ADD COLUMN claimant_relation   VARCHAR(100) NULL,
  ADD COLUMN claimant_id_type    VARCHAR(50)  NULL,
  ADD COLUMN claimant_id_number  VARCHAR(100) NULL,
  ADD COLUMN claimant_id_front   VARCHAR(500) NULL,
  ADD COLUMN claimant_id_back    VARCHAR(500) NULL,
  ADD COLUMN claimant_signature  VARCHAR(500) NULL,
  ADD COLUMN claimant_face_photo VARCHAR(500) NULL;
