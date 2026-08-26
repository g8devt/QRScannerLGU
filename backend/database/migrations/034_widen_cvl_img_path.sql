-- Migration 034: Widen app_cvl_list.cvl_img_path from varchar(100) to
-- varchar(512). A full S3 photo URL (bucket domain + cvl/<record_id>/
-- <name>_<unique>.<ext>, where <name> is the client-supplied filename —
-- often itself a UUID-based name like "scaled_<uuid>.jpg") routinely
-- exceeds 100 characters. With no STRICT_TRANS_TABLES, MySQL silently
-- truncated the value to fit instead of erroring, storing a broken URL
-- with no file extension (e.g. cut off mid-UUID). Run manually against
-- bataan_db (no migration-runner exists in this repo yet).
--
-- 512, not 255: today's public S3 URLs need well under 255, but a
-- future switch to presigned URLs (X-Amz-Signature/X-Amz-Credential
-- query strings routinely run 300-500+ characters) would blow past
-- that. 512 gives real headroom for that without jumping to
-- LONGTEXT, which loses easy indexing and is unnecessary for a single
-- URL string.
--
-- Paired with two fixes in cvl_records_bataan.py:
-- 1. update_cvl_photo_bataan no longer duplicates record_id into the S3
--    key itself (cvl/<id>/<id>/... -> cvl/<id>/...).
-- 2. A length guard rejects the save with a clear error if a URL would
--    ever still exceed this column's width (_MAX_IMG_PATH_LENGTH),
--    instead of ever again relying on silent DB-level truncation.
--
-- NOTE: this does not repair rows already truncated by the bug — their
-- cvl_img_path is unrecoverable (the missing suffix was never stored)
-- and those records need their photo re-uploaded.

ALTER TABLE app_cvl_list
  MODIFY COLUMN cvl_img_path VARCHAR(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
