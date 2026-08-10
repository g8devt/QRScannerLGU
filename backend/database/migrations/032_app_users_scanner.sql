-- Migration 032: Scanner-staff accounts for the bataan_lgu_scanner app's
-- login_scanner_bataan endpoint. Separate from app_users (citizen accounts) --
-- staff log in with username/password, not mobile+PIN. Run manually against
-- bataan_db (no migration-runner exists in this repo yet).

CREATE TABLE app_users_scanner (
  id            BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_status   ENUM('VERIFIED','PENDING','NOT_VERIFIED','DEACTIVATED')
                  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
                  NOT NULL DEFAULT 'PENDING',
  username      VARCHAR(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  password      VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  firstname     VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  middlename    VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  lastname      VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  suffix        VARCHAR(20)  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  gender        VARCHAR(20)  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  birth_date    DATE         DEFAULT NULL,
  mobile_number VARCHAR(11)  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  email_address VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  is_active     TINYINT(1)   NOT NULL DEFAULT 1,
  date_created  DATETIME(6)  DEFAULT NULL,
  date_modified DATETIME(6)  DEFAULT NULL,
  UNIQUE KEY uq_app_users_scanner_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
