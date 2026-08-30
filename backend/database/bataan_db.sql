-- phpMyAdmin SQL Dump
-- version 5.1.1deb5ubuntu1
-- https://www.phpmyadmin.net/
--
-- Host: dev-rds.c18y82cw62ll.ap-southeast-1.rds.amazonaws.com:3306
-- Generation Time: Aug 30, 2026 at 01:32 PM
-- Server version: 8.4.8
-- PHP Version: 8.1.2-1ubuntu2.25

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `bataan_db`
--

-- --------------------------------------------------------

--
-- Table structure for table `1srvr_gg_test`
--

CREATE TABLE `1srvr_gg_test` (
  `id` int NOT NULL,
  `h` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `admin_access_tbl`
--

CREATE TABLE `admin_access_tbl` (
  `id` int NOT NULL,
  `name` varchar(255) DEFAULT NULL,
  `mun` varchar(255) DEFAULT NULL,
  `imei` varchar(255) DEFAULT NULL,
  `status` varchar(255) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `app_account_deletion_log`
--

CREATE TABLE `app_account_deletion_log` (
  `id` int NOT NULL,
  `user_profile_id` int DEFAULT NULL,
  `mobile_number` varchar(20) DEFAULT NULL,
  `email_address` varchar(255) DEFAULT NULL,
  `reason` varchar(100) DEFAULT 'user_initiated',
  `app_version` varchar(50) DEFAULT NULL,
  `platform` varchar(50) DEFAULT NULL,
  `deleted_at_client` datetime DEFAULT NULL,
  `deleted_at_server` datetime DEFAULT CURRENT_TIMESTAMP,
  `ip_address` varchar(64) DEFAULT NULL,
  `fullname` varchar(255) DEFAULT NULL,
  `first_name` varchar(100) DEFAULT NULL,
  `middle_name` varchar(100) DEFAULT NULL,
  `last_name` varchar(100) DEFAULT NULL,
  `suffix_name` varchar(20) DEFAULT NULL,
  `gender` varchar(20) DEFAULT NULL,
  `birth_date` date DEFAULT NULL,
  `place_of_birth` varchar(255) DEFAULT NULL,
  `address` text,
  `region` varchar(100) DEFAULT NULL,
  `province` varchar(100) DEFAULT NULL,
  `district` varchar(100) DEFAULT NULL,
  `municipality` varchar(100) DEFAULT NULL,
  `barangay` varchar(100) DEFAULT NULL,
  `card_id` varchar(100) DEFAULT NULL,
  `card_id_type` varchar(100) DEFAULT NULL,
  `card_id_no` varchar(100) DEFAULT NULL,
  `card_id_date_issued` varchar(50) DEFAULT NULL,
  `card_id_first_name` varchar(100) DEFAULT NULL,
  `card_id_last_name` varchar(100) DEFAULT NULL,
  `card_id_middle_name` varchar(100) DEFAULT NULL,
  `profile_photo` varchar(500) DEFAULT NULL,
  `verification_profile_photo` varchar(500) DEFAULT NULL,
  `card_id_picture` varchar(500) DEFAULT NULL,
  `user_signature_photo` varchar(500) DEFAULT NULL,
  `user_status` varchar(50) DEFAULT NULL,
  `kyc_status` varchar(50) DEFAULT NULL,
  `registration_id` varchar(500) DEFAULT NULL,
  `date_account_created` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_admins`
--

CREATE TABLE `app_admins` (
  `id` bigint UNSIGNED NOT NULL,
  `name` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `username` varchar(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `password_hash` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `first_name` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `middle_name` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_name` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `suffix` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `role` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'ADMIN',
  `permissions` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `email` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mobile_number` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `gender` enum('MALE','FEMALE') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `birthdate` date DEFAULT NULL,
  `region` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'REGION III (CENTRAL LUZON)',
  `province` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'BATAAN',
  `city_municipality` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `barangay` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `approval_status` enum('PENDING','APPROVED','REJECTED') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PENDING',
  `approved_by` bigint UNSIGNED DEFAULT NULL,
  `approved_at` datetime DEFAULT NULL,
  `last_login` datetime DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `address` varchar(180) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `invite_id` bigint UNSIGNED DEFAULT NULL,
  `photo_url` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `signature_url` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `id_front_url` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `id_back_url` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `liveness_score` decimal(5,2) DEFAULT NULL,
  `liveness_reason` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `privacy_accepted_at` datetime DEFAULT NULL,
  `rejection_reason` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `date_created` datetime NOT NULL,
  `date_modified` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_admin_audit`
--

CREATE TABLE `app_admin_audit` (
  `id` bigint UNSIGNED NOT NULL,
  `admin_id` bigint UNSIGNED NOT NULL,
  `action` varchar(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `permission` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `target_table` varchar(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `target_id` bigint UNSIGNED NOT NULL,
  `from_status` varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `to_status` varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `remarks` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `ip_address` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `at` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_admin_finance_budget`
--

CREATE TABLE `app_admin_finance_budget` (
  `id` bigint NOT NULL,
  `name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `base_amount` decimal(12,2) NOT NULL,
  `current_amount` decimal(12,2) NOT NULL,
  `date_created` datetime(6) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_admin_finance_transaction`
--

CREATE TABLE `app_admin_finance_transaction` (
  `id` bigint NOT NULL,
  `transaction_type` varchar(3) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `amount` decimal(12,2) NOT NULL,
  `description` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `date_created` date NOT NULL,
  `budget_id` bigint NOT NULL,
  `balance_after` decimal(12,2) NOT NULL,
  `balance_before` decimal(12,2) NOT NULL,
  `source` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_admin_invites`
--

CREATE TABLE `app_admin_invites` (
  `id` bigint UNSIGNED NOT NULL,
  `token` char(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `role` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'ADMIN',
  `permissions` longtext COLLATE utf8mb4_unicode_ci,
  `invited_by` bigint UNSIGNED DEFAULT NULL,
  `invited_name` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `invited_mobile` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `invited_email` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` enum('PENDING','USED','REVOKED','EXPIRED') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PENDING',
  `multi_use` tinyint(1) NOT NULL DEFAULT '0',
  `use_count` int UNSIGNED NOT NULL DEFAULT '0',
  `expires_at` datetime NOT NULL,
  `created_at` datetime NOT NULL,
  `used_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_applicant_profiles`
--

CREATE TABLE `app_applicant_profiles` (
  `id` bigint UNSIGNED NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `profile_data` json NOT NULL,
  `date_created` datetime NOT NULL,
  `date_modified` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_audit_logs`
--

CREATE TABLE `app_audit_logs` (
  `id` bigint UNSIGNED NOT NULL,
  `actor_id` bigint UNSIGNED DEFAULT NULL,
  `actor_name` varchar(150) COLLATE utf8mb4_general_ci NOT NULL DEFAULT '',
  `actor_type` varchar(20) COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'admin',
  `action` varchar(60) COLLATE utf8mb4_general_ci NOT NULL,
  `entity_type` varchar(60) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `entity_id` varchar(64) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `summary` varchar(255) COLLATE utf8mb4_general_ci NOT NULL DEFAULT '',
  `details` longtext COLLATE utf8mb4_general_ci,
  `ip_address` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `user_agent` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `created_at` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_business_permits`
--

CREATE TABLE `app_business_permits` (
  `id` bigint UNSIGNED NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `application_number` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `application_type` enum('NEW','RENEWAL','CLOSURE') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'NEW',
  `previous_permit_number` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `renewal_reason` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `closure_date` date DEFAULT NULL,
  `closure_reason` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `final_remarks` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `business_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `trade_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `business_type` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `tin_number` varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `registration_number` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `capitalization` decimal(14,2) DEFAULT NULL,
  `owner_fname` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `owner_mname` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `owner_lname` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `owner_suffix` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `owner_mobile` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `owner_email` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address_line` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `barangay` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `municipality` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `province` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `zip_code` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `line_of_business` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `num_employees` int UNSIGNED DEFAULT NULL,
  `operating_hours` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `has_signage` tinyint(1) DEFAULT '0',
  `has_parking` tinyint(1) DEFAULT '0',
  `doc_dti_sec` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `doc_barangay` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `doc_lease` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `doc_fire_permit` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `doc_sanitary` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `doc_other` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `status` enum('PENDING','UNDER_REVIEW','APPROVED','REJECTED','CLOSED') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PENDING',
  `remarks` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `permit_number` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `date_submitted` datetime NOT NULL,
  `date_reviewed` datetime DEFAULT NULL,
  `date_approved` datetime DEFAULT NULL,
  `date_modified` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_card_registrations`
--

CREATE TABLE `app_card_registrations` (
  `id` bigint UNSIGNED NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `reference_number` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `first_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `middle_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `suffix` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mobile` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `residence_detail` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `barangay` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `city_municipality` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `province` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `region` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `zip_code` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `photo_url` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `signature_url` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `id_photo_url` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `status` enum('PENDING','UNDER_REVIEW','APPROVED','REJECTED') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PENDING',
  `card_number` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `remarks` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `date_submitted` datetime NOT NULL,
  `date_reviewed` datetime DEFAULT NULL,
  `date_approved` datetime DEFAULT NULL,
  `date_modified` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_card_request`
--

CREATE TABLE `app_card_request` (
  `id` bigint NOT NULL,
  `type` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `date_requested` datetime(6) DEFAULT NULL,
  `date_approved` datetime(6) DEFAULT NULL,
  `date_declined` datetime(6) DEFAULT NULL,
  `verify_photo` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `card_id` bigint DEFAULT NULL,
  `user_profile_id` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_card_transactions`
--

CREATE TABLE `app_card_transactions` (
  `id` bigint UNSIGNED NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `assign_card` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `transaction_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `scanned_by` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `scanner_id` bigint UNSIGNED DEFAULT NULL,
  `remarks` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `date_created` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_cho_sanitary_permit`
--

CREATE TABLE `app_cho_sanitary_permit` (
  `id` int NOT NULL,
  `application_number` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `application_type` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `datetime_created` datetime(6) DEFAULT NULL,
  `datetime_updated` datetime(6) DEFAULT NULL,
  `status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `remarks` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `first_name` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `middle_name` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_name` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `age` int DEFAULT NULL,
  `gender` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `barangay` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `name_of_establishment` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address_of_establishment` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `specify_establishment` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `schedule_inspection` date DEFAULT NULL,
  `contact_no` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `occupation_designation` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `date_construction_septic` date DEFAULT NULL,
  `name_informant` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `name_cadaver` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `name_of_funeral` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `nationality` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `name_cemetery` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cause_of_death` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `quantity` decimal(10,2) DEFAULT NULL,
  `unit` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `specify_food_products` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `place_transferred` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `date_transferred` date DEFAULT NULL,
  `name_client` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `water_source` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `sampling_point` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `date_water_collection` date DEFAULT NULL,
  `file_1` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `file_2` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `user_id` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_civil_registry`
--

CREATE TABLE `app_civil_registry` (
  `id` bigint NOT NULL,
  `application_number` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `child_first_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `child_middle_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `child_last_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `child_dob` date NOT NULL,
  `child_weight` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `child_place_of_birth` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `child_gender` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `child_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `multiple_birth` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `birth_order` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mother_first_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `mother_middle_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mother_last_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `mother_dob` date DEFAULT NULL,
  `mother_religion` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mother_children_alive` int DEFAULT NULL,
  `mother_children_living` int DEFAULT NULL,
  `mother_children_dead` int DEFAULT NULL,
  `mother_occupation` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mother_age` int DEFAULT NULL,
  `mother_region` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mother_province` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mother_city` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mother_barangay` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mother_file` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `father_first_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `father_middle_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `father_last_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `father_citizenship` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `father_religion` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `father_occupation` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `father_age` int DEFAULT NULL,
  `father_region` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `father_province` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `father_city` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `father_barangay` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `father_file` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `marriage_date` date DEFAULT NULL,
  `marriage_place` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attendant_first_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attendant_middle_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attendant_last_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attendant_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `marriage_file` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `informant_first_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `informant_middle_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `informant_last_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `informant_address` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `informant_phone` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `informant_email` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `informant_relationship` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `informant_file` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_civil_registry_marriage`
--

CREATE TABLE `app_civil_registry_marriage` (
  `id` bigint NOT NULL,
  `application_number` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `groom_first_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_middle_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_last_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_birth_date` date DEFAULT NULL,
  `groom_gender` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_citizenship` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_civil_status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_religion` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_birth_country` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_birth_province` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_birth_city` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_country` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_region` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_province` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_city` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_barangay` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_father_first_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_father_middle_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_father_last_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_father_citizenship` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_mother_first_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_mother_middle_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_mother_last_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_mother_citizenship` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_consent_first_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_consent_middle_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_consent_last_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_consent_relationship` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_consent_country` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_consent_region` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_consent_province` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_consent_city` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `groom_consent_barangay` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_first_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_middle_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_last_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_birth_date` date DEFAULT NULL,
  `bride_gender` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_citizenship` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_civil_status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_religion` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_birth_country` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_birth_province` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_birth_city` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_country` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_region` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_province` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_city` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_barangay` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_father_first_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_father_middle_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_father_last_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_father_citizenship` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_mother_first_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_mother_middle_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_mother_last_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_mother_citizenship` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_consent_first_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_consent_middle_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_consent_last_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_consent_relationship` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_consent_country` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_consent_region` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_consent_province` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_consent_city` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bride_consent_barangay` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_claim_logs`
--

CREATE TABLE `app_claim_logs` (
  `id` bigint NOT NULL,
  `application_number` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `social_service_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `user_fullname` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `scanner_id` int NOT NULL,
  `scanner_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `device_id` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `claimed_amount` decimal(12,2) DEFAULT NULL,
  `date_created` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_companies`
--

CREATE TABLE `app_companies` (
  `id` bigint UNSIGNED NOT NULL,
  `registered_company_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `trade_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `business_type` enum('SOLE_PROPRIETORSHIP','PARTNERSHIP','CORPORATION','COOPERATIVE') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `industry_sector` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `address_street` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `barangay` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `city_municipality` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `province` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `telephone_number` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mobile_number` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `official_email` varchar(190) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `website` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `dti_sec_cda_reg_no` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `date_registered` date NOT NULL,
  `permit_number` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `permit_valid_until` date NOT NULL,
  `tin` varchar(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `sss_employer_no` varchar(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `philhealth_employer_no` varchar(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `pagibig_employer_no` varchar(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `gov_id_url` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `dti_cda_sec_cert_url` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mayors_permit_url` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bir_2303_url` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `company_logo_url` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `rep_full_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `rep_position` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `rep_department` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `rep_mobile_number` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `login_email` varchar(190) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `username` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `password_hash` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` enum('ACTIVE','PENDING','APPROVED','REJECTED','SUSPENDED','ARCHIVED') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PENDING',
  `reviewed_by` int DEFAULT NULL,
  `reviewed_at` datetime DEFAULT NULL,
  `remarks` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `date_created` datetime NOT NULL,
  `date_modified` datetime DEFAULT NULL,
  `name` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `logo_url` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `about` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `address` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `contact_email` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `contact_phone` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_contact_us`
--

CREATE TABLE `app_contact_us` (
  `id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `subject` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `message` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `date_created` datetime DEFAULT NULL,
  `date_updated` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_cvl`
--

CREATE TABLE `app_cvl` (
  `id` bigint NOT NULL,
  `fullname` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `province` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `district` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `municipality` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `barangay` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `precinct` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `gender` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `birthdate` date DEFAULT NULL,
  `contact` varchar(11) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `profile_picture` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `image_count` int NOT NULL,
  `date_card_registered` datetime(6) DEFAULT NULL,
  `org` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `date_role_registered` datetime(6) DEFAULT NULL,
  `date_created` datetime(6) DEFAULT NULL,
  `added_from` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `import_status` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `remarks` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `role_upper_id` bigint DEFAULT NULL,
  `card_id` bigint DEFAULT NULL,
  `role_id` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_cvl_list`
--

CREATE TABLE `app_cvl_list` (
  `id` int NOT NULL,
  `cvl_id` varchar(25) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cvl_fullname` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_fname` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_mname` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_lname` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_suffix` enum('JR.','SR.','II','III') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cvl_address` longtext COLLATE utf8mb4_unicode_ci,
  `cvl_mun` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_brgy` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_precinct_no` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cvl_img_path` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cvl_qr` int DEFAULT NULL,
  `cvl_last_date_updated` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `cvl_updated_by` varchar(125) COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_birthdate` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_contact_no` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_email` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_gender` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_sector` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cvl_position_code` varchar(125) COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_leader` varchar(125) COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_secondary_position` enum('SUPPORTER','HARD SUPPORTER','OPPONENT','HARD OPPONENT','UNDECIDED','UNKNOWN','DOUBLE ENTRY') COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_vital_status` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cvl_working_status` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cvl_status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'ACTIVE',
  `cvl_household_leader` varchar(3) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'NO',
  `cvl_household_leader_cvl_id` varchar(60) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cvl_household_relationship` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cvl_last_leader` varchar(125) COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_is_voter` varchar(3) COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_cvl_locations`
--

CREATE TABLE `app_cvl_locations` (
  `id` bigint NOT NULL,
  `province` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `district` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `municipality` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `barangay` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `precinct` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_directory_hospital`
--

CREATE TABLE `app_directory_hospital` (
  `id` int NOT NULL,
  `region` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `province` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `municipality` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `hospital_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `hospital_address` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `hospital_contact` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `coordinates` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_fb_pages`
--

CREATE TABLE `app_fb_pages` (
  `id` bigint NOT NULL,
  `title` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `url` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `is_active` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'ACTIVE',
  `date_created` datetime DEFAULT NULL,
  `date_updated` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_feedback`
--

CREATE TABLE `app_feedback` (
  `id` bigint NOT NULL,
  `reaction` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `rate` int DEFAULT NULL,
  `remarks` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `datetime_created` datetime(6) DEFAULT NULL,
  `user_id` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_incident_report`
--

CREATE TABLE `app_incident_report` (
  `id` bigint NOT NULL,
  `type_issue` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `remarks` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `location` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `file` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `datetime_created` datetime(6) NOT NULL,
  `datetime_pending` datetime(6) DEFAULT NULL,
  `datetime_under_review` datetime(6) DEFAULT NULL,
  `datetime_in_progress` datetime(6) DEFAULT NULL,
  `datetime_completed` datetime(6) DEFAULT NULL,
  `user_id` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_incident_reports`
--

CREATE TABLE `app_incident_reports` (
  `id` bigint UNSIGNED NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `reference_number` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `reporter_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `report_type` enum('CALAMITY','FIRE','MEDICAL','CRIME','ACCIDENT','UTILITY','OTHER') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `latitude` decimal(10,7) NOT NULL,
  `longitude` decimal(10,7) NOT NULL,
  `address_text` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `photo_urls` json DEFAULT NULL,
  `video_url` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `status` enum('PENDING','ACKNOWLEDGED','IN_PROGRESS','RESOLVED','CANCELLED') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PENDING',
  `remarks` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `date_submitted` datetime NOT NULL,
  `expires_at` datetime NOT NULL,
  `date_modified` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_item_records`
--

CREATE TABLE `app_item_records` (
  `id` int NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `organization` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `record_date` date NOT NULL,
  `item` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `remarks` text COLLATE utf8mb4_general_ci,
  `batch_id` int DEFAULT NULL,
  `created_by` int DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_item_record_batches`
--

CREATE TABLE `app_item_record_batches` (
  `id` int NOT NULL,
  `filename` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `row_count` int NOT NULL DEFAULT '0',
  `uploaded_by` int DEFAULT NULL,
  `uploaded_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_job_applications`
--

CREATE TABLE `app_job_applications` (
  `id` bigint UNSIGNED NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `job_posting_id` bigint UNSIGNED NOT NULL,
  `reference_number` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `applicant_name_snapshot` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `mobile` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cover_letter` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `resume_url` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `status` enum('DRAFT','PENDING','REVIEWING','SHORTLISTED','ACCEPTED','REJECTED','WITHDRAWN') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'DRAFT',
  `remarks` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `date_submitted` datetime NOT NULL,
  `date_modified` datetime DEFAULT NULL,
  `user_profile_id` int DEFAULT NULL,
  `first_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `middle_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `suffix_name` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `birth_date` date DEFAULT NULL,
  `age` int DEFAULT NULL,
  `gender` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `civil_status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `nationality` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'FILIPINO',
  `contact_number` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email_address` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address` text COLLATE utf8mb4_unicode_ci,
  `position_applied` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `department` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `employment_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `educational_attainment` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `school_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `course` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `year_graduated` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `work_experience` json DEFAULT NULL,
  `skills` text COLLATE utf8mb4_unicode_ci,
  `supporting_documents` text COLLATE utf8mb4_unicode_ci,
  `date_created` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_job_posting`
--

CREATE TABLE `app_job_posting` (
  `id` bigint NOT NULL,
  `date_published` date DEFAULT NULL,
  `is_active` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `image_url` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `category` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `company_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `company_image` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `location` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `working_model` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `level` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `job_type` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `salary` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `company_id` bigint DEFAULT NULL,
  `skills` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_job_postings`
--

CREATE TABLE `app_job_postings` (
  `id` bigint UNSIGNED NOT NULL,
  `title` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `department` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `location` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `employment_type` enum('FULL_TIME','PART_TIME','CONTRACT','INTERNSHIP') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'FULL_TIME',
  `salary_min` decimal(12,2) DEFAULT NULL,
  `salary_max` decimal(12,2) DEFAULT NULL,
  `requirements` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `posted_at` datetime NOT NULL,
  `closes_at` datetime DEFAULT NULL,
  `status` enum('OPEN','CLOSED','FILLED') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'OPEN',
  `company_id` bigint UNSIGNED DEFAULT NULL,
  `date_created` datetime DEFAULT NULL,
  `date_modified` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_job_vacancies_applicant`
--

CREATE TABLE `app_job_vacancies_applicant` (
  `id` bigint NOT NULL,
  `application_number` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PENDING',
  `date_created` date DEFAULT NULL,
  `date_updated` date DEFAULT NULL,
  `is_active` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `job_posting_id` bigint DEFAULT NULL,
  `user_id` bigint DEFAULT NULL,
  `applicant_id` bigint UNSIGNED DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_kyc`
--

CREATE TABLE `app_kyc` (
  `id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `signature_image` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `face_picture` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `gov_id_front` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `gov_id_back` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `gov_id_type` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `birthdate` date DEFAULT NULL,
  `civil_status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `face_similarity_score` decimal(5,2) DEFAULT NULL,
  `status` enum('PENDING','VERIFIED','RECOMPLIANCE','REJECTED') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PENDING',
  `submitted_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `verified_at` datetime DEFAULT NULL,
  `remarks` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `recompliance_items` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cvl_list_id` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_legal_consultations`
--

CREATE TABLE `app_legal_consultations` (
  `id` int NOT NULL,
  `user_id` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `application_number` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL,
  `full_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `contact_method` enum('SMS','EMAIL','CALL') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'SMS',
  `contact_value` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `concern` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` enum('SUBMITTED','UNDER_REVIEW','SCHEDULED','RESOLVED') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'SUBMITTED',
  `scheduled_at` datetime DEFAULT NULL,
  `resolution_notes` text COLLATE utf8mb4_unicode_ci,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_legal_consultation_history`
--

CREATE TABLE `app_legal_consultation_history` (
  `id` int NOT NULL,
  `consultation_id` int NOT NULL,
  `status` enum('SUBMITTED','UNDER_REVIEW','SCHEDULED','RESOLVED') COLLATE utf8mb4_unicode_ci NOT NULL,
  `note` text COLLATE utf8mb4_unicode_ci,
  `actor` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_lgu_sites`
--

CREATE TABLE `app_lgu_sites` (
  `id` bigint NOT NULL,
  `title` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `url` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `is_active` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'ACTIVE',
  `date_created` datetime DEFAULT NULL,
  `date_updated` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_locations`
--

CREATE TABLE `app_locations` (
  `id` int NOT NULL,
  `region` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `province` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `city_municipality` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `barangay` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_LoginActivity`
--

CREATE TABLE `app_LoginActivity` (
  `id` bigint NOT NULL,
  `ip_address` char(39) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `device_type` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `browser` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `os` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `login_time` datetime(6) NOT NULL,
  `user_id` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_modules`
--

CREATE TABLE `app_modules` (
  `id` int NOT NULL,
  `social_services` tinyint(1) NOT NULL,
  `smart_brgy_services` tinyint(1) NOT NULL,
  `emergency_services` tinyint(1) NOT NULL,
  `citizen_corner` tinyint(1) NOT NULL,
  `job_seeker` tinyint(1) NOT NULL,
  `become_volunteer` tinyint(1) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_news_announcement_list`
--

CREATE TABLE `app_news_announcement_list` (
  `id` bigint NOT NULL,
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `url` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `image_url` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `description` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `date_published` datetime(6) DEFAULT NULL,
  `file` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `type` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_active` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_nonvoter_list`
--

CREATE TABLE `app_nonvoter_list` (
  `id` int NOT NULL,
  `cvl_id` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cvl_fullname` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_fname` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_mname` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cvl_lname` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_suffix` enum('JR.','SR.','II','III') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cvl_address` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `cvl_mun` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_brgy` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_precinct_no` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cvl_img_path` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cvl_qr` int DEFAULT NULL,
  `cvl_last_date_updated` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `cvl_updated_by` varchar(125) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_birthdate` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_contact_no` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_email` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_gender` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_sector` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cvl_position_code` varchar(125) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_leader` varchar(125) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_secondary_position` enum('SUPPORTER','HARD SUPPORTER','OPPONENT','HARD OPPONENT','UNDECIDED','UNKNOWN','DOUBLE ENTRY') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `cvl_vital_status` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cvl_working_status` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cvl_status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'ACTIVE',
  `cvl_household_leader` varchar(3) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'NO',
  `cvl_household_leader_cvl_id` varchar(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cvl_household_relationship` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cvl_last_leader` varchar(125) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `nv_social_service_id` int DEFAULT NULL,
  `nv_declared_voter` varchar(3) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `nv_source` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'SOCIAL_SERVICE',
  `nv_created_at` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_notifications`
--

CREATE TABLE `app_notifications` (
  `id` int NOT NULL,
  `user_profile_id` int DEFAULT NULL COMMENT 'NULL = broadcast to all',
  `title` varchar(255) NOT NULL,
  `message` text NOT NULL,
  `type` varchar(50) DEFAULT 'GENERAL' COMMENT 'GENERAL, ALERT, UPDATE, PROMO',
  `is_read` tinyint DEFAULT '0',
  `data` json DEFAULT NULL COMMENT 'Optional payload for deep linking',
  `date_created` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_notification_logs`
--

CREATE TABLE `app_notification_logs` (
  `id` bigint NOT NULL,
  `channel` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `recipient` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `subject` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `message` longtext COLLATE utf8mb4_unicode_ci,
  `status` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'QUEUED',
  `reference_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `reference_id` bigint DEFAULT NULL,
  `response_payload` longtext COLLATE utf8mb4_unicode_ci,
  `error_message` longtext COLLATE utf8mb4_unicode_ci,
  `created_at` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_obo_building_permit`
--

CREATE TABLE `app_obo_building_permit` (
  `id` bigint NOT NULL,
  `application_number` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `transaction_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `datetime_created` datetime(6) NOT NULL,
  `datetime_updated` datetime(6) NOT NULL,
  `updated_by` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `remarks` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `first_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `middle_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `tin` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `contact_no` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(254) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `residence` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `zip_code` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `house_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `lot_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `block_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `street` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `tct` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `tax_declaration` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `form_ownership` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `scope_of_work` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `use_character_occupancy` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `region` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `province` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `city` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `barangay` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `construction_location_region` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `construction_location_province` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `construction_location_city` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `construction_location_barangay` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `occupancy_classification` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `number_of_units` int DEFAULT NULL,
  `number_of_storeys` int DEFAULT NULL,
  `height_of_building` decimal(10,2) DEFAULT NULL,
  `total_floor_area` decimal(12,2) DEFAULT NULL,
  `lot_area` decimal(12,2) DEFAULT NULL,
  `proposed_date_of_construction` date DEFAULT NULL,
  `expected_date_of_completion` date DEFAULT NULL,
  `building_cost` decimal(15,2) DEFAULT NULL,
  `electrical_cost` decimal(15,2) DEFAULT NULL,
  `mechanical_cost` decimal(15,2) DEFAULT NULL,
  `electronics_cost` decimal(15,2) DEFAULT NULL,
  `plumbing_cost` decimal(15,2) DEFAULT NULL,
  `total_estimated_cost` decimal(15,2) DEFAULT NULL,
  `cost_of_equipment_installed` decimal(15,2) DEFAULT NULL,
  `engineer_full_name_planner` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `engineer_address_planner` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `engineer_validity_prc_planner` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `engineer_date_issued_ptr_planner` date DEFAULT NULL,
  `engineer_issued_at_ptr_planner` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `engineer_tin_planner` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `engineer_full_name_supervisor` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `engineer_address_supervisor` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `engineer_validity_prc_supervisor` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `engineer_date_issued_ptr_supervisor` date DEFAULT NULL,
  `engineer_issued_at_ptr_supervisor` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `engineer_tin_supervisor` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `owner_full_name` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `owner_address` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `owner_government_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `owner_date_issued_id` date DEFAULT NULL,
  `owner_place_issued_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `lot_owner_full_name` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `lot_owner_address` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `lot_owner_government_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `lot_owner_date_issued_id` date DEFAULT NULL,
  `lot_owner_place_issued_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `engineer_signature_planner` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `engineer_signature_supervisor` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `owner_signature` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `lot_owner_signature` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `user_id` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_osca_activities`
--

CREATE TABLE `app_osca_activities` (
  `id` bigint NOT NULL,
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `url` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `image_url` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `description` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `scheduled_date` datetime(6) DEFAULT NULL,
  `file` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `type` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_active` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_osca_news`
--

CREATE TABLE `app_osca_news` (
  `id` bigint NOT NULL,
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `url` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `image_url` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `description` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `date_published` datetime(6) DEFAULT NULL,
  `file` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `type` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_active` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_osca_registration`
--

CREATE TABLE `app_osca_registration` (
  `id` bigint UNSIGNED NOT NULL,
  `user_profile_id` bigint DEFAULT NULL,
  `service_type` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'OSCA REGISTRATION',
  `applying_for` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `relationship` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `remarks` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `first_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `middle_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `birth_date` date DEFAULT NULL,
  `age` int DEFAULT NULL,
  `gender` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `civil_status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `blood_type` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `religion` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `contact_number` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `emergency_contact_number` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `region` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `province` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `city` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `barangay` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `residence` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `zip_code` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `educational_attainment` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `employment_status` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `gsis_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `sss_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `tin_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `philhealth_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `classification` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `pension_bracket` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `uploaded_files` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `preferred_contact` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `consent_agreed` tinyint(1) DEFAULT '0',
  `submitted_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `status` enum('PENDING','APPROVED','DECLINED','SCHEDULED','RELEASED') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'PENDING',
  `date_requested` datetime DEFAULT CURRENT_TIMESTAMP,
  `date_approved` datetime DEFAULT NULL,
  `date_scheduled` datetime DEFAULT NULL,
  `date_released` datetime DEFAULT NULL,
  `date_declined` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_otp`
--

CREATE TABLE `app_otp` (
  `id` int NOT NULL,
  `otp_code` varchar(6) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `sender_number` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `date_created` varchar(90) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `expiration_date` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_otp_count`
--

CREATE TABLE `app_otp_count` (
  `id` int NOT NULL,
  `mobile_number` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `date_created` date DEFAULT NULL,
  `count` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_paymongo_sessions`
--

CREATE TABLE `app_paymongo_sessions` (
  `id` bigint UNSIGNED NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `reference_number` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `session_id` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `checkout_url` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `amount_centavos` bigint NOT NULL,
  `currency` varchar(8) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PHP',
  `status` enum('pending','paid','expired','cancelled','failed') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `raw_response` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `created_at` datetime NOT NULL,
  `updated_at` datetime DEFAULT NULL,
  `paid_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_permission_migrations`
--

CREATE TABLE `app_permission_migrations` (
  `migration_key` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `applied_at` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_peso_applications`
--

CREATE TABLE `app_peso_applications` (
  `id` bigint NOT NULL,
  `reference_no` varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `surname` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `firstname` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `middlename` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `suffix` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `birth_date` date NOT NULL,
  `age` smallint UNSIGNED DEFAULT NULL,
  `place_of_birth` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `sex` varchar(6) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `religion` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `civil_status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `present_house_street` varchar(160) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `present_village` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `present_barangay` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `present_municipality` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `present_province` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `present_region` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `height_cm` smallint UNSIGNED DEFAULT NULL,
  `tin_no` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `gsis_sss_no` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `pagibig_no` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `philhealth_no` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `landline_no` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cellphone_no` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `disability_visual` tinyint(1) NOT NULL,
  `disability_hearing` tinyint(1) NOT NULL,
  `disability_speech` tinyint(1) NOT NULL,
  `disability_physical` tinyint(1) NOT NULL,
  `disability_other` tinyint(1) NOT NULL,
  `disability_other_specify` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `emp_status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `emp_type` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `emp_abroad_country` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `emp_other_specify` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `actively_looking_for_work` varchar(3) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `looking_for_work_duration` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `willing_to_work_immediately` varchar(3) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `if_no_when` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ofw` varchar(3) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `former_ofw` varchar(3) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `four_ps_beneficiary` varchar(3) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `four_ps_household_id` varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `job_preferences` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `expected_salary_range` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `passport_no` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `passport_expiry` date DEFAULT NULL,
  `consent_agreed` varchar(3) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `requested_from` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `user_id` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_peso_applications_assessment`
--

CREATE TABLE `app_peso_applications_assessment` (
  `id` bigint NOT NULL,
  `assessed_by` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `eligible_spes` smallint NOT NULL,
  `eligible_gip` smallint NOT NULL,
  `eligible_tupad` smallint NOT NULL,
  `eligible_jobstart` smallint NOT NULL,
  `eligible_other` smallint NOT NULL,
  `eligible_other_specify` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `application_id` bigint NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_peso_applications_attachments`
--

CREATE TABLE `app_peso_applications_attachments` (
  `id` bigint NOT NULL,
  `attachment_type` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `file_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `file_url` varchar(1000) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bucket_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `object_key` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `date_created` datetime(6) NOT NULL,
  `date_updated` datetime(6) NOT NULL,
  `is_active` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `application_id` bigint NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_peso_applications_education`
--

CREATE TABLE `app_peso_applications_education` (
  `id` bigint NOT NULL,
  `currently_in_school` varchar(3) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `level` varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `school` varchar(160) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `course` varchar(160) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `year_graduated` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `if_undergraduate_what_level` varchar(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `year_last_attended` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `awards_received` varchar(160) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `application_id` bigint NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_peso_applications_eligibility`
--

CREATE TABLE `app_peso_applications_eligibility` (
  `id` bigint NOT NULL,
  `row_no` smallint UNSIGNED NOT NULL,
  `eligibility_name` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `rating` varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `exam_date` date DEFAULT NULL,
  `application_id` bigint NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_peso_applications_language_proficiency`
--

CREATE TABLE `app_peso_applications_language_proficiency` (
  `id` bigint NOT NULL,
  `language_name` varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `other_language_specify` varchar(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `can_read` tinyint(1) NOT NULL,
  `can_write` tinyint(1) NOT NULL,
  `can_speak` tinyint(1) NOT NULL,
  `can_understand` tinyint(1) NOT NULL,
  `application_id` bigint NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_peso_applications_prc_license`
--

CREATE TABLE `app_peso_applications_prc_license` (
  `id` bigint NOT NULL,
  `row_no` smallint UNSIGNED NOT NULL,
  `license_name` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `valid_until` date DEFAULT NULL,
  `application_id` bigint NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_peso_applications_preferred_locations`
--

CREATE TABLE `app_peso_applications_preferred_locations` (
  `id` bigint NOT NULL,
  `location_type` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `rank_no` smallint UNSIGNED NOT NULL,
  `location_value` varchar(160) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `application_id` bigint NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_peso_applications_preferred_occupations`
--

CREATE TABLE `app_peso_applications_preferred_occupations` (
  `id` bigint NOT NULL,
  `rank_no` smallint UNSIGNED NOT NULL,
  `occupation` varchar(160) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `application_id` bigint NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_peso_applications_skills`
--

CREATE TABLE `app_peso_applications_skills` (
  `id` bigint NOT NULL,
  `other_specify` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `application_id` bigint NOT NULL,
  `skill_id` bigint NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_peso_applications_skill_catalog`
--

CREATE TABLE `app_peso_applications_skill_catalog` (
  `id` bigint NOT NULL,
  `skill_code` varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `skill_name` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_peso_applications_training`
--

CREATE TABLE `app_peso_applications_training` (
  `id` bigint NOT NULL,
  `row_no` smallint UNSIGNED NOT NULL,
  `course` varchar(160) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `duration_from` date DEFAULT NULL,
  `duration_to` date DEFAULT NULL,
  `training_institution` varchar(160) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `certificates_received` varchar(160) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `application_id` bigint NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_peso_applications_work_experience`
--

CREATE TABLE `app_peso_applications_work_experience` (
  `id` bigint NOT NULL,
  `row_no` smallint UNSIGNED NOT NULL,
  `company_name` varchar(160) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `company_address_city_municipality` varchar(160) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `position` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `inclusive_from` date DEFAULT NULL,
  `inclusive_to` date DEFAULT NULL,
  `status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status_other` varchar(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `application_id` bigint NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_peso_company_profile`
--

CREATE TABLE `app_peso_company_profile` (
  `id` bigint NOT NULL,
  `status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `datetime_created` datetime(6) DEFAULT NULL,
  `datetime_verified` datetime(6) DEFAULT NULL,
  `datetime_declined` datetime(6) DEFAULT NULL,
  `decline_reason` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `company_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `trade_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `business_type` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `industry_sector_type` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `company_address` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `province` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `municipality` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `barangay` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `zipcode` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `tel_number` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mobile_number` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `company_email` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `website_url` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `dti_sec_cda_no` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `tin_no` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `sss_no` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `philhealth_no` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `pagibig_no` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `date_registered` date DEFAULT NULL,
  `docs_dti_sec_cda_url` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `docs_mayors_permit_url` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `docs_valid_id_representative_url` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `rep_fullname` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `rep_position` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `rep_department` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `rep_mobile_number` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `rep_email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `auth_user_id` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_peso_jobfair_registration`
--

CREATE TABLE `app_peso_jobfair_registration` (
  `id` bigint NOT NULL,
  `first_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `middle_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `suffix` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `gender` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `birthdate` date DEFAULT NULL,
  `birthplace` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `province` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `municipality` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `barangay` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `street` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `village` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `religion` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `civil_status` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mobile_number` varchar(11) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `landline` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `id_tin` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `id_gsis_sss` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `id_pagibig` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `id_philhealth` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `height` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `registration_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `datetime_created` datetime DEFAULT NULL,
  `status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `image_valid_id` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_profile_update_requests`
--

CREATE TABLE `app_profile_update_requests` (
  `id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `field_name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `current_value` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `requested_value` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` enum('PENDING','APPROVED','REJECTED') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'PENDING',
  `admin_remarks` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `requested_at` datetime NOT NULL,
  `reviewed_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_qr_code`
--

CREATE TABLE `app_qr_code` (
  `id` int NOT NULL,
  `qr_code` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `qr_code_display` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` enum('USED','AVAILABLE') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'AVAILABLE',
  `date_assigned` datetime NOT NULL,
  `date_updated` datetime NOT NULL,
  `qr_img` varchar(125) COLLATE utf8mb4_unicode_ci NOT NULL,
  `qr_path` varchar(125) COLLATE utf8mb4_unicode_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_results_2025`
--

CREATE TABLE `app_results_2025` (
  `id` int NOT NULL,
  `region` varchar(55) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `province` varchar(55) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `district` varchar(55) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `municipality` varchar(55) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `barangay` varchar(55) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `voter_count` int NOT NULL,
  `supporter_count` int DEFAULT NULL,
  `distributed_card` int DEFAULT NULL,
  `senior` int DEFAULT NULL,
  `singe_parents` int DEFAULT NULL,
  `youth` int DEFAULT NULL,
  `pwd` int DEFAULT NULL,
  `ofw` int DEFAULT NULL,
  `toda` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_reviews`
--

CREATE TABLE `app_reviews` (
  `id` int NOT NULL,
  `tourism_id` int NOT NULL,
  `reviewer_name` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `rating` decimal(2,1) DEFAULT NULL,
  `comment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `datetime_created` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_role`
--

CREATE TABLE `app_role` (
  `id` bigint NOT NULL,
  `role_title` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `group_title` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `upper_id` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_rpt_tax_declaration`
--

CREATE TABLE `app_rpt_tax_declaration` (
  `id` bigint NOT NULL,
  `td_no` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `property_id_no` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `owner_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `tin` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `tel` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `admin_beneficial_user` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `admin_address` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `admin_tin` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `location_of_property` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `barangay_district` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `city_province` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `oct_tct_no` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `survey_no` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cloa_csc_no` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cad_lot_no` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cct` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `dated` date DEFAULT NULL,
  `lot_no` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `block_no` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `north` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `east` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `south` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `west` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `land` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `land_description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `building` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `building_storey` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `building_decription` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `machinery` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `machinery_description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `others` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `others_specifiy` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `classification` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `area` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `market_value` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `actual_use` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `assessment_level` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `assessed_value` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `total_market_value` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `total_assessed_value` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `total_assessed_value_words` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `taxability` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `quarter` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `year` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `recommending_approval_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `recommending_asst_prov_mun_assessor` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `recommending_date` date DEFAULT NULL,
  `approved_by_name` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `approved_by_asst_prov_mun_assessor` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `approved_by_date` date DEFAULT NULL,
  `memoranda_this_dec_cancels` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `memoranda_owner` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `memoranda_previous_av_php` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `memoranda_details` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_id` bigint DEFAULT NULL,
  `address` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `latitude` decimal(9,6) DEFAULT NULL,
  `longitude` decimal(9,6) DEFAULT NULL,
  `upload_id` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `upload_tax_dec_copy` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `upload_tax_dec_receipt` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `upload_title_1` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `upload_title_2` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `upload_title_3` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_service_requests`
--

CREATE TABLE `app_service_requests` (
  `id` bigint NOT NULL,
  `user_id` bigint DEFAULT NULL,
  `application_number` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `service_type` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `requested_from` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `date_requested` datetime NOT NULL,
  `date_approved` datetime DEFAULT NULL,
  `date_scheduled` datetime DEFAULT NULL,
  `date_released` datetime DEFAULT NULL,
  `date_declined` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_service_toggles`
--

CREATE TABLE `app_service_toggles` (
  `id` tinyint UNSIGNED NOT NULL,
  `social_services_enabled` tinyint(1) NOT NULL DEFAULT '1',
  `job_application_enabled` tinyint(1) NOT NULL DEFAULT '1',
  `business_permit_enabled` tinyint(1) NOT NULL DEFAULT '1',
  `card_registration_enabled` tinyint(1) NOT NULL DEFAULT '1',
  `updated_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_settings`
--

CREATE TABLE `app_settings` (
  `id` int NOT NULL,
  `setting_key` varchar(100) NOT NULL,
  `setting_value` text,
  `description` varchar(255) DEFAULT NULL,
  `date_created` datetime DEFAULT CURRENT_TIMESTAMP,
  `date_modified` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_sms`
--

CREATE TABLE `app_sms` (
  `id` bigint NOT NULL,
  `mobile_number` varchar(20) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `sender_name` varchar(60) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `message` text COLLATE utf8mb4_general_ci,
  `status` varchar(16) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `endpoint` varchar(40) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `provider` varchar(30) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `provider_code` varchar(20) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `provider_status` varchar(60) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `transid` varchar(120) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `provider_response_json` json DEFAULT NULL,
  `date_created` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_sms_log`
--

CREATE TABLE `app_sms_log` (
  `id` bigint NOT NULL,
  `mobile_number` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `type` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `response` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `date_created` datetime(6) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_social_services`
--

CREATE TABLE `app_social_services` (
  `id` bigint NOT NULL,
  `service_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `service_sub_category` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `application_number` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `requested_from` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `submission_method` enum('IN_PERSON','ONLINE') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'IN_PERSON' COMMENT 'How the applicant will submit supporting documents',
  `appointment_date` date DEFAULT NULL COMMENT 'Auto-assigned for ONLINE submissions',
  `appointment_time` time DEFAULT NULL COMMENT 'Auto-assigned for ONLINE submissions (9am–3pm, 6-min granularity)',
  `appointment_location` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Office where applicant must appear for online-submission appointment',
  `status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `admin_notes` text COLLATE utf8mb4_unicode_ci,
  `date_requested` datetime(6) DEFAULT NULL,
  `date_reviewed` datetime(6) DEFAULT NULL,
  `date_approved` datetime(6) DEFAULT NULL,
  `date_scheduled` datetime(6) DEFAULT NULL,
  `schedule_slot_id` bigint DEFAULT NULL,
  `schedule_notes` text COLLATE utf8mb4_unicode_ci,
  `date_released` datetime(6) DEFAULT NULL,
  `date_declined` datetime(6) DEFAULT NULL,
  `decline_reason` text COLLATE utf8mb4_unicode_ci,
  `requested_for` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `requested_for_relation` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `beneficiary_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Full name of the beneficiary when applying for someone else',
  `brief_description` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `assistance_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `requested_for_fname` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `requested_for_mname` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `requested_for_lname` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `requested_for_birthdate` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `requested_for_gender` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `requested_for_civil_status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Applicant civil status: SINGLE/MARRIED/WIDOWED/SEPARATED/DIVORCED',
  `requested_for_contact` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `requested_for_email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `requested_for_country` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `requested_for_region` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `requested_for_province` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `requested_for_municipality` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `requested_for_barangay` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `requested_for_address` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `requested_for_zipcode` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `preferred_contact` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `upload_file_1` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `upload_file_1_type` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `upload_file_2` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `upload_file_2_type` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `upload_file_3` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `upload_file_3_type` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `upload_file_4` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `upload_file_4_type` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `upload_file_5` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `upload_file_5_type` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `upload_file_6` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `upload_file_6_type` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `upload_file_7` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `upload_file_7_type` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `upload_file_8` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `upload_file_8_type` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `educ_school_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `educ_grade_level` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `educ_year_level` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Grade 11/Grade 12 (Senior High) or First/Second/Third/Fourth Year (College)',
  `educ_is_scholar` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'YES/NO — whether the student is a scholar',
  `educ_course` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `educ_school_id_number` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `educ_school_address` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `educ_school_sector` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `tribal_membership` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `disability` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `other_financial_assistance` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `other_financial_assistance_type_1` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `other_financial_assistance_type_2` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `other_financial_assistance_agency_1` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `other_financial_assistance_agency_2` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `photo_2x2` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `photo_signature` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `image_verification` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `amount` int DEFAULT NULL,
  `family_composition` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `deceased_fullname` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `deceased_birthdate` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `deceased_deathdate` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `medicine_needed` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `document_sent_type` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_id` bigint DEFAULT NULL COMMENT 'Related to app_users',
  `admin_id` int DEFAULT NULL COMMENT 'Related to app_admins',
  `cvl_id` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `qr_code` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Unique QR token for the auto-scheduled appointment (SS-<id>-<hex>)',
  `date_claimed` datetime DEFAULT NULL,
  `claimed_amount` decimal(12,2) DEFAULT NULL,
  `claim_method` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `claimant_type` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `claimant_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `claimant_relation` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `claimant_id_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `claimant_id_number` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `claimant_id_front` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `claimant_id_back` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `claimant_signature` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `claimant_face_photo` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `users_scanner_id` bigint DEFAULT NULL COMMENT 'this id is from app_users_scanner'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_social_services_family`
--

CREATE TABLE `app_social_services_family` (
  `id` bigint NOT NULL,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `birthdate` date DEFAULT NULL,
  `relationship` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `skill_occupation` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `gender` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `birthplace` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `civl_status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `highest_educ` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `est_income` int DEFAULT NULL,
  `social_services_id` bigint DEFAULT NULL,
  `user_id` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_social_services_type`
--

CREATE TABLE `app_social_services_type` (
  `id` bigint NOT NULL,
  `ss_title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_social_service_schedule_slots`
--

CREATE TABLE `app_social_service_schedule_slots` (
  `id` bigint NOT NULL,
  `slot_date` date NOT NULL,
  `slot_time` time NOT NULL,
  `total_slots` int UNSIGNED NOT NULL,
  `status` enum('ACTIVE','INACTIVE') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'ACTIVE',
  `notes` text COLLATE utf8mb4_unicode_ci,
  `created_by` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_solicitations`
--

CREATE TABLE `app_solicitations` (
  `id` int NOT NULL,
  `fullname` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `organization` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `municipality` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `barangay` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `item` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `amount` decimal(12,2) DEFAULT NULL,
  `date_requested` date NOT NULL,
  `date_released` date DEFAULT NULL,
  `remarks` text COLLATE utf8mb4_general_ci,
  `batch_id` int DEFAULT NULL,
  `created_by` int DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_by` int DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_solicitation_batches`
--

CREATE TABLE `app_solicitation_batches` (
  `id` int NOT NULL,
  `filename` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `row_count` int NOT NULL DEFAULT '0',
  `uploaded_by` int DEFAULT NULL,
  `uploaded_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_support_attachments`
--

CREATE TABLE `app_support_attachments` (
  `id` int NOT NULL,
  `support_id` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `attachments` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `attachment_filename` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `attachment_filetype` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_support_reply`
--

CREATE TABLE `app_support_reply` (
  `reply_id` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `message_id_parent` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email_address_sender` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `support_message_reply` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `date_created` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `added_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `date_updated` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `updated_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_support_reply_attachments`
--

CREATE TABLE `app_support_reply_attachments` (
  `id` int NOT NULL,
  `reply_id` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `attachments` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `attachment_filename` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `attachment_filetype` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_support_tbl`
--

CREATE TABLE `app_support_tbl` (
  `id` int NOT NULL,
  `support_id` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `profile_id` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `email_address` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `support_subject` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `support_message` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `support_answer` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `date_created` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `is_read` enum('true','false') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'false',
  `is_bookmarked` enum('true','false') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'false',
  `is_starred` enum('true','false') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'false',
  `date_updated` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `updated_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '0',
  `type` enum('SUPPORT','COMPOSE','DRAFT') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'SUPPORT',
  `added_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `email_sent_to` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_support_tickets`
--

CREATE TABLE `app_support_tickets` (
  `id` int NOT NULL,
  `user_profile_id` int DEFAULT NULL,
  `ticket_number` varchar(50) DEFAULT NULL,
  `subject` varchar(255) DEFAULT NULL,
  `category` varchar(100) DEFAULT NULL COMMENT 'BUG_REPORT, FEEDBACK, INQUIRY, COMPLAINT',
  `message` text,
  `status` varchar(50) DEFAULT 'OPEN' COMMENT 'OPEN, IN_PROGRESS, RESOLVED, CLOSED',
  `priority` varchar(20) DEFAULT 'MEDIUM' COMMENT 'LOW, MEDIUM, HIGH, URGENT',
  `attachment_url` varchar(500) DEFAULT NULL,
  `admin_reply` text,
  `date_created` datetime DEFAULT CURRENT_TIMESTAMP,
  `date_modified` datetime DEFAULT NULL,
  `date_resolved` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_theme_dynamic`
--

CREATE TABLE `app_theme_dynamic` (
  `id` bigint NOT NULL,
  `theme_title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `theme_navbar_title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `theme_logo` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `theme_login_background_color` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `theme_login_signin_color` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `module_rpt` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `module_budget` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `module_incident` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `module_ss` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `module_cc` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `module_mobile` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_tourism`
--

CREATE TABLE `app_tourism` (
  `id` int NOT NULL,
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `location` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `details` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `what_todo` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `longitude` decimal(10,6) DEFAULT NULL,
  `latitude` decimal(10,6) DEFAULT NULL,
  `operating_hours` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `tips` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `rate` decimal(2,1) DEFAULT NULL,
  `services` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `reviews_count` int DEFAULT NULL,
  `category` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `datetime_created` datetime DEFAULT CURRENT_TIMESTAMP,
  `images` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `booking_link` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_transactions_history`
--

CREATE TABLE `app_transactions_history` (
  `id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `application_number` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `service_type` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `service` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PENDING',
  `datetime_created` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `datetime_updated` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_transaction_history`
--

CREATE TABLE `app_transaction_history` (
  `id` int NOT NULL,
  `user_profile_id` int DEFAULT NULL,
  `transaction_type` varchar(100) DEFAULT NULL,
  `reference_number` varchar(50) DEFAULT NULL,
  `description` text,
  `status` varchar(50) DEFAULT NULL,
  `date_created` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_users`
--

CREATE TABLE `app_users` (
  `id` bigint NOT NULL,
  `user_status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_type` enum('CLIENT','MENRO','ENGINEERING','ZONING','ASSESSOR','BFP','TREASURY','SANITARY') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'CLIENT',
  `status` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fullname` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `first_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `middle_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `suffix_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mobile_number` varchar(11) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email_address` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `pin_code_pass` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `region` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `province` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `district` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `municipality` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `barangay` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `gender` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `birth_date` datetime(6) DEFAULT NULL,
  `place_of_birth` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `civil_status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `age` int DEFAULT NULL,
  `user_profile_photo` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `agree_terms` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `card_id_no` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `verification_profile_photo` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `card_id_picture` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `card_id_first_name` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `card_id_middle_name` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `card_id_last_name` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `card_id_suffix_name` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `card_id_date_issued` datetime(6) DEFAULT NULL,
  `card_id_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `registration_id` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `date_created` datetime(6) DEFAULT NULL,
  `date_pending` datetime(6) DEFAULT NULL,
  `date_modified` datetime(6) DEFAULT NULL,
  `date_verified` datetime(6) DEFAULT NULL,
  `notify_status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `biometrics` int DEFAULT NULL,
  `is_active` int DEFAULT NULL,
  `date_deactivated` date DEFAULT NULL,
  `card_id` bigint DEFAULT NULL,
  `user_signature_photo` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `decline_reason` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `profile_photo` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `assign_card` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_users_scanner`
--

CREATE TABLE `app_users_scanner` (
  `id` bigint NOT NULL,
  `user_status` enum('VERIFIED','PENDING','NOT_VERIFIED','DEACTIVATED') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PENDING',
  `username` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `firstname` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `middlename` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `lastname` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `suffix` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `gender` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `birth_date` date DEFAULT NULL,
  `mobile_number` varchar(11) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email_address` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `date_created` datetime(6) DEFAULT NULL,
  `date_modified` datetime(6) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_user_operations_tbl`
--

CREATE TABLE `app_user_operations_tbl` (
  `id` int NOT NULL,
  `title` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `value` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `value_type` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `date_modified` datetime DEFAULT NULL,
  `date_created` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_user_preferences`
--

CREATE TABLE `app_user_preferences` (
  `user_profile_id` int NOT NULL,
  `prefs_json` json NOT NULL,
  `date_created` datetime DEFAULT CURRENT_TIMESTAMP,
  `date_modified` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_user_service_toggles`
--

CREATE TABLE `app_user_service_toggles` (
  `id` bigint UNSIGNED NOT NULL,
  `user_id` bigint UNSIGNED NOT NULL,
  `social_services_enabled` tinyint(1) NOT NULL DEFAULT '1',
  `job_application_enabled` tinyint(1) NOT NULL DEFAULT '1',
  `business_permit_enabled` tinyint(1) NOT NULL DEFAULT '1',
  `card_registration_enabled` tinyint(1) NOT NULL DEFAULT '1',
  `updated_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_version`
--

CREATE TABLE `app_version` (
  `id` int NOT NULL,
  `app_code` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `os_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `version` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `url` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `is_active` enum('ACTIVE','INACTIVE') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'ACTIVE',
  `date_created` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `date_modified` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `auth_group`
--

CREATE TABLE `auth_group` (
  `id` int NOT NULL,
  `name` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `auth_group_permissions`
--

CREATE TABLE `auth_group_permissions` (
  `id` bigint NOT NULL,
  `group_id` int NOT NULL,
  `permission_id` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `auth_permission`
--

CREATE TABLE `auth_permission` (
  `id` int NOT NULL,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `content_type_id` int NOT NULL,
  `codename` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `auth_user`
--

CREATE TABLE `auth_user` (
  `id` int NOT NULL,
  `password` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `last_login` datetime(6) DEFAULT NULL,
  `is_superuser` tinyint(1) NOT NULL,
  `username` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `first_name` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `last_name` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(254) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `is_staff` tinyint(1) NOT NULL,
  `is_active` tinyint(1) NOT NULL,
  `date_joined` datetime(6) NOT NULL,
  `account_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `auth_user_groups`
--

CREATE TABLE `auth_user_groups` (
  `id` bigint NOT NULL,
  `user_id` int NOT NULL,
  `group_id` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `auth_user_user_permissions`
--

CREATE TABLE `auth_user_user_permissions` (
  `id` bigint NOT NULL,
  `user_id` int NOT NULL,
  `permission_id` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `barangays`
--

CREATE TABLE `barangays` (
  `barangay_code` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `barangay_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `barangay_captain` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `municipality` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `barangay_logo` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `barangay_captain_signature` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `brgy_tbl`
--

CREATE TABLE `brgy_tbl` (
  `id` int NOT NULL,
  `municipality` varchar(255) DEFAULT NULL,
  `brgy` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `bulk_counter_checker_bulk_upload_admingmailcom`
--

CREATE TABLE `bulk_counter_checker_bulk_upload_admingmailcom` (
  `id` int NOT NULL,
  `temp_voters_id` varchar(255) NOT NULL DEFAULT '',
  `temp_name` varchar(255) DEFAULT NULL,
  `temp_imgpath` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `lastname` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `firstname` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `middlename` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `suffixname` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_code` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_address` varchar(255) DEFAULT NULL,
  `temp_gender` varchar(255) DEFAULT NULL,
  `temp_bday` varchar(255) DEFAULT NULL,
  `temp_region` varchar(255) DEFAULT NULL,
  `temp_province_city` varchar(255) DEFAULT NULL,
  `temp_district` varchar(255) DEFAULT NULL,
  `temp_mun` varchar(255) DEFAULT NULL,
  `temp_brgy` varchar(255) DEFAULT NULL,
  `temp_sitio` varchar(255) DEFAULT NULL,
  `temp_precinct_no` varchar(255) DEFAULT NULL,
  `temp_status` varchar(255) DEFAULT NULL,
  `temp_access_imei` varchar(255) DEFAULT NULL,
  `import` varchar(255) DEFAULT NULL,
  `temp_id_status` varchar(255) DEFAULT NULL,
  `isVoter` varchar(255) DEFAULT NULL,
  `temp_leader_id` varchar(20) DEFAULT NULL,
  `temp_structure_name` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_contact_number` varchar(255) DEFAULT NULL,
  `temp_household_title` varchar(255) DEFAULT NULL,
  `temp_household_leader` varchar(255) DEFAULT NULL,
  `temp_household_relationship` varchar(255) DEFAULT NULL,
  `temp_poll_watcher_workers` varchar(255) DEFAULT NULL,
  `temp_fb_email` varchar(255) DEFAULT NULL,
  `temp_household_update_status` varchar(255) DEFAULT NULL,
  `temp_tagged_numbering` varchar(255) DEFAULT NULL,
  `temp_sector` varchar(255) DEFAULT NULL,
  `temp_org` varchar(255) DEFAULT NULL,
  `temp_org_2` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_job_position` varchar(75) DEFAULT NULL,
  `temp_religion` varchar(150) DEFAULT NULL,
  `temp_tag_status` varchar(25) DEFAULT NULL,
  `temp_tag_update_status` varchar(255) DEFAULT NULL,
  `bulk_uploaded_by` varchar(50) DEFAULT NULL,
  `date_time` datetime DEFAULT CURRENT_TIMESTAMP,
  `temp_vital_status` varchar(20) DEFAULT NULL,
  `temp_working_status` varchar(20) DEFAULT NULL,
  `temp_quickcount_status` varchar(50) DEFAULT NULL,
  `temp_quick_count_info` varchar(50) DEFAULT NULL,
  `temp_clustered_precinct` varchar(150) DEFAULT NULL,
  `temp_cluster_number` varchar(10) DEFAULT NULL,
  `temp_clustered_polling_place` varchar(150) DEFAULT NULL,
  `temp_untagged_by` varchar(150) DEFAULT NULL,
  `temp_untagged_date` varchar(50) DEFAULT NULL,
  `temp_added_by` varchar(100) DEFAULT NULL,
  `temp_date_time_added` varchar(50) DEFAULT NULL,
  `temp_tagged_by` varchar(100) DEFAULT NULL,
  `temp_date_time_tagged` varchar(50) DEFAULT NULL,
  `temp_last_edited_by` varchar(100) DEFAULT NULL,
  `temp_last_edited_date_time` varchar(50) DEFAULT NULL,
  `temp_transferred_by` varchar(100) DEFAULT NULL,
  `temp_transferred_date_time` varchar(150) DEFAULT NULL,
  `temp_transferred_to` varchar(150) DEFAULT NULL,
  `temp_transferred_old_leader` varchar(25) DEFAULT NULL,
  `temp_remove_en_und_unk_by` varchar(100) DEFAULT NULL,
  `temp_remove_en_und_unk_date_time` varchar(80) DEFAULT NULL,
  `temp_changed_leader_by` varchar(100) DEFAULT NULL,
  `temp_changed_leader_date_time` varchar(50) DEFAULT NULL,
  `temp_changed_new_leader` varchar(25) DEFAULT NULL,
  `temp_changed_old_leader` varchar(25) DEFAULT NULL,
  `temp_sync_by` varchar(100) DEFAULT NULL,
  `temp_sync_date_time` varchar(50) DEFAULT NULL,
  `temp_final_voter_id` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `temp_inserted_to_temp` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT 'NOT INSERTED'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `bulk_counter_checker_final`
--

CREATE TABLE `bulk_counter_checker_final` (
  `id` int NOT NULL,
  `temp_name` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_voters_id` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_voters_id_from_countert` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `bulk_upload`
--

CREATE TABLE `bulk_upload` (
  `id` int NOT NULL,
  `first_name` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `last_name` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `email` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `temp_update_status` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'NOT UPDATED'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business`
--

CREATE TABLE `business` (
  `id` int(7) UNSIGNED ZEROFILL NOT NULL,
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `business_id_final` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `business_permit_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `business_plate_no` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `business_barangay_clearance_control_no` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `business_sanitary_permit_control_no` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `business_closure_no` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_requirement_status` enum('FOR UPLOADING','UPLOADED') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'FOR UPLOADING',
  `bus_status` enum('NEW','RENEW','FOR CLOSING','CLOSED') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'NEW',
  `last_bus_status` enum('NEW','RENEW','FOR CLOSING','CLOSED') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'NEW',
  `bus_status_for_retirement` enum('NEW','RENEW','FOR CLOSING','CLOSED') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `last_bus_status_for_retirement` enum('NEW','RENEW','FOR CLOSING','CLOSED','') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `last_bus_application_status_for_retirement` enum('FOR CHECKING','FOR INSPECTION','FOR APPROVAL','FOR ASSESSMENT','FOR PAYMENT','FOR RELEASING','DENIED','RELEASED','FOR RENEWAL','FOR UPLOADING','') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '',
  `last_renewed_for_year_for_retirement` int DEFAULT NULL,
  `bus_application_type` enum('WEB','KIOSK','MOBILE','TABLET','WALK IN') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'WALK IN',
  `bus_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_trade` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_franchise` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_type_of_registration` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_registration_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_registration_date` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_registration_date_exp` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_type` enum('CORPORATION','PARTNERSHIP','SOLE PROPRIETORSHIP','COOPERATIVE','ASSOCIATION') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ctc` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_tin` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_region` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_prov` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_district` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_city_mun` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_brgy` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_zip` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_bldg_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_ad_bldg_no` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_ad_lot_no` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_ad_block_no` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_ad_street` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_ad_subdivision` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_geo_tagging` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_telephone` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_mobile` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_email` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_pic_position` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_pic_other_position` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_pic_first_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_pic_middle_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_pic_last_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_pic_suffix` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_pic_gender` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_kind` enum('FILIPINO','FOREIGN') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'FILIPINO',
  `date_added` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `added_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `date_updated` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `updated_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '0',
  `bus_application_status` enum('FOR UPLOADING','FOR CHECKING','FOR INSPECTION','FOR APPROVAL','FOR ASSESSMENT','FOR PAYMENT','FOR RELEASING','DENIED','FOR COMPLIANCE','RELEASED','FOR RENEWAL','CANCELLED APPLICATION') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'FOR CHECKING',
  `bus_application_denied_reason` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_application_for_compliance_document` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `date_of_inspection` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_gross_essential` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '0',
  `bus_gross_non_essential` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '0',
  `bus_capital` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '0',
  `date_assessed` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `assessed_by` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `released_by` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `released_date` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_of_expiration` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `remarks` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `date_of_renewal` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `renewed_for_year` int DEFAULT NULL,
  `bus_is_delinquent` enum('true','false') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'false',
  `bus_is_delinquent_date_of_last_payment` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_is_delinquent_quarter_of_last_payment` enum('1st','2nd','3rd','4th') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_is_delinquent_paid_whole_year` enum('true','false') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_for_delivery` enum('true','false') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_type_of_payment` enum('COD','GCASH','MAYA') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_delivery_status` enum('DELIVERED','ONGOING','PENDING') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `retirement_status` enum('','pending','approved','cancelled','denied') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `retirement_reason` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `retirement_verification` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `retirement_date_applied` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `retirement_date_approved` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `retirement_date_cancelled` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `retirement_date_of_effectivity` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `retirement_date_issued` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `retirement_approved_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `retirement_deny_reason` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `retirement_denied_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `retirement_denied_date` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `deleted` enum('true','false') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'false'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_activity`
--

CREATE TABLE `business_activity` (
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `line_of_business` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `date_added` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `added_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `date_updated` datetime DEFAULT NULL,
  `updated_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_approvals`
--

CREATE TABLE `business_approvals` (
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `approval_year` int NOT NULL,
  `assessor_approval` enum('APPROVED','FOR COMPLIANCE','COMPLIED','DENIED','ON PROCESS') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'ON PROCESS',
  `zoning_approval` enum('APPROVED','FOR COMPLIANCE','COMPLIED','DENIED','ON PROCESS') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'ON PROCESS',
  `menro_approval` enum('APPROVED','FOR COMPLIANCE','COMPLIED','DENIED','ON PROCESS') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'ON PROCESS',
  `sanitary_approval` enum('APPROVED','FOR COMPLIANCE','COMPLIED','DENIED','ON PROCESS') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'ON PROCESS',
  `engineering_approval` enum('APPROVED','FOR COMPLIANCE','COMPLIED','DENIED','ON PROCESS') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'ON PROCESS',
  `bfp_approval` enum('APPROVED','FOR COMPLIANCE','COMPLIED','DENIED','ON PROCESS') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'ON PROCESS',
  `assessor_date_approved_denied` datetime DEFAULT NULL,
  `zoning_date_approved_denied` datetime DEFAULT NULL,
  `menro_date_approved_denied` datetime DEFAULT NULL,
  `sanitary_date_approved_denied` datetime DEFAULT NULL,
  `engineering_date_approved_denied` datetime DEFAULT NULL,
  `bfp_date_approved_denied` datetime DEFAULT NULL,
  `assessor_approved_denied_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `zoning_approved_denied_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `menro_approved_denied_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `sanitary_approved_denied_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `engineering_approved_denied_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bfp_approved_denied_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `assessor_deny_reason` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `zoning_deny_reason` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `menro_deny_reason` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `sanitary_deny_reason` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `engineering_deny_reason` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bfp_deny_reason` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `date_added` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `added_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_updated` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `updated_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0',
  `treasury_approval` enum('APPROVED','ON PROCESS','FOR COMPLIANCE','FOR VERIFICATION','FOR INTERVIEW','DENIED','COMPLIED') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'ON PROCESS',
  `treasury_date_approved_denied` datetime DEFAULT NULL,
  `treasury_approved_denied_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `treasury_deny_reason` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_capital`
--

CREATE TABLE `business_capital` (
  `business_id` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `bus_capital` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `added_by` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `date_added` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `updated_by` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `date_updated` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_category`
--

CREATE TABLE `business_category` (
  `id` int NOT NULL,
  `bus_category` varchar(225) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `bus_category_size_id` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `bus_category_fees` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `bus_category_size_name` varchar(225) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_category_sizes`
--

CREATE TABLE `business_category_sizes` (
  `id` int NOT NULL,
  `bus_category_size_id` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `bus_category_size_name` varchar(225) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `bus_category_size_range_1` int NOT NULL DEFAULT '0',
  `bus_category_size_range_2` bigint NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_category_sizes_bus_class`
--

CREATE TABLE `business_category_sizes_bus_class` (
  `id` int NOT NULL,
  `business_class_id` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `business_category_name` varchar(225) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_char`
--

CREATE TABLE `business_char` (
  `id` int NOT NULL,
  `char_code_1` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `char_code_2` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `char_code_3` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `char_code_4` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `char_code_5` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_char1`
--

CREATE TABLE `business_char1` (
  `bus_char_id` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `bus_char_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_char_parent` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_char_status` enum('ACTIVE','INACTIVE') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_char2`
--

CREATE TABLE `business_char2` (
  `bus_char_id` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `bus_char_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_char_parent_id` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_char_status` enum('ACTIVE','INACTIVE') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_char3`
--

CREATE TABLE `business_char3` (
  `bus_char_id` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `bus_char_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_char_parent_id` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_char_status` enum('ACTIVE','INACTIVE') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_char4`
--

CREATE TABLE `business_char4` (
  `bus_char_id` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `bus_char_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_char_parent_id` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_char_status` enum('ACTIVE','INACTIVE') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_char5`
--

CREATE TABLE `business_char5` (
  `bus_char_id` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `bus_char_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_char_parent_id` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_char_status` enum('ACTIVE','INACTIVE') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_charges`
--

CREATE TABLE `business_charges` (
  `bus_charges_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `bus_charges_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `bus_charges_status` enum('ACTIVE','INACTIVE') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_charges_final`
--

CREATE TABLE `business_charges_final` (
  `business_charges_final_id` int NOT NULL,
  `business_char1_id` varchar(75) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `business_charges_id` varchar(75) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `business_charges_sub_id` varchar(75) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `bus_charges_sub_amount` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_charges_sub`
--

CREATE TABLE `business_charges_sub` (
  `bus_charges_id` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `bus_charges_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `bus_charges_amount` int NOT NULL,
  `bus_charges_status` enum('ACTIVE','INACTIVE') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `bus_charges_parent_id` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `bus_charges_code` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `id` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_classification`
--

CREATE TABLE `business_classification` (
  `id` int NOT NULL,
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `business_class_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `business_class_fees` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `business_class_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `business_class_parent_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `business_capital` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `business_status` enum('NEW','RENEW','FOR CLOSING') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'NEW',
  `business_class_year` int DEFAULT NULL,
  `business_service` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `business_tax` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0',
  `business_tax_formula` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `business_is_essential` enum('true','false') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'false',
  `business_is_delinquent_year` enum('true','false') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'false',
  `bus_has_tax` enum('true','false') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `business_class_fees_essential` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0',
  `business_capital_essential` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0',
  `business_tax_essential` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0',
  `business_tax_formula_essential` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_has_tax_essential` enum('true','false') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_clearance_control_no_history`
--

CREATE TABLE `business_clearance_control_no_history` (
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `control_no` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `date_added` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `added_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_department_charges`
--

CREATE TABLE `business_department_charges` (
  `id` int NOT NULL,
  `charge_code` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `charge_code2` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `charge_name` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `charge_amount` varchar(11) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0',
  `charge_status` enum('ACTIVE','INACTIVE') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'ACTIVE',
  `charge_department` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_added` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `added_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `date_updated` datetime DEFAULT NULL,
  `updated_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_emailed_top`
--

CREATE TABLE `business_emailed_top` (
  `id` int NOT NULL,
  `business_email` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `top_year` int DEFAULT NULL,
  `top_no` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `top_is_used` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0',
  `date_added` datetime DEFAULT CURRENT_TIMESTAMP,
  `added_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_gross`
--

CREATE TABLE `business_gross` (
  `business_id` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `bus_gross` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `added_by` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `date_added` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `updated_by` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `date_updated` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_history`
--

CREATE TABLE `business_history` (
  `id` int NOT NULL,
  `profile_id` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `message_id` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `notification_message` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `date_added` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `added_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `notification_status` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0',
  `notification_action_type` enum('create','update','delete') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `notification_old_bus_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_images`
--

CREATE TABLE `business_images` (
  `id` int NOT NULL,
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `image_path` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `image_dep` enum('ASSESSOR','ZONING','MENRO','SANITARY','ENGINEERING','BFP','TREASURY','SKETCH | PICTURE') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `file_folder_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `file_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `file_size` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `date_added` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `added_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_updated` datetime DEFAULT NULL,
  `updated_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_inspections`
--

CREATE TABLE `business_inspections` (
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `inspection_year` int NOT NULL,
  `assessor_inspection_status` enum('FOR COMPLIANCE','SCHEDULED','IN PROGRESS','COMPLETED','PENDING REVIEW','INSPECTED','DENIED','ON HOLD','CANCELLED','RESCHEDULED','COMPLIED') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'SCHEDULED',
  `zoning_inspection_status` enum('FOR COMPLIANCE','SCHEDULED','IN PROGRESS','COMPLETED','PENDING REVIEW','INSPECTED','DENIED','ON HOLD','CANCELLED','RESCHEDULED','COMPLIED') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'SCHEDULED',
  `menro_inspection_status` enum('FOR COMPLIANCE','SCHEDULED','IN PROGRESS','COMPLETED','PENDING REVIEW','INSPECTED','DENIED','ON HOLD','CANCELLED','RESCHEDULED','COMPLIED') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'SCHEDULED',
  `sanitary_inspection_status` enum('FOR COMPLIANCE','SCHEDULED','IN PROGRESS','COMPLETED','PENDING REVIEW','INSPECTED','DENIED','ON HOLD','CANCELLED','RESCHEDULED','COMPLIED') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'SCHEDULED',
  `engineering_inspection_status` enum('FOR COMPLIANCE','SCHEDULED','IN PROGRESS','COMPLETED','PENDING REVIEW','INSPECTED','DENIED','ON HOLD','CANCELLED','RESCHEDULED','COMPLIED') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'SCHEDULED',
  `bfp_inspection_status` enum('FOR COMPLIANCE','SCHEDULED','IN PROGRESS','COMPLETED','PENDING REVIEW','INSPECTED','DENIED','ON HOLD','CANCELLED','RESCHEDULED','COMPLIED') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'SCHEDULED',
  `assessor_date_inspected` datetime DEFAULT NULL,
  `zoning_date_inspected` datetime DEFAULT NULL,
  `menro_date_inspected` datetime DEFAULT NULL,
  `sanitary_date_inspected` datetime DEFAULT NULL,
  `engineering_date_inspected` datetime DEFAULT NULL,
  `bfp_date_inspected` datetime DEFAULT NULL,
  `assessor_inspected_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `zoning_inspected_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `menro_inspected_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `sanitary_inspected_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `engineering_inspected_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bfp_inspected_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `assessor_deny_reason` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `zoning_deny_reason` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `menro_deny_reason` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `sanitary_deny_reason` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `engineering_deny_reason` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bfp_deny_reason` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `date_added` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `added_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_updated` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `updated_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0',
  `treasury_inspection_status` enum('SCHEDULED','IN PROGRESS','COMPLETED','PENDING REVIEW','INSPECTED','DENIED','ON HOLD','CANCELLED','RESCHEDULED','COMPLIED') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'SCHEDULED',
  `treasury_date_inspected` datetime DEFAULT NULL,
  `treasury_inspected_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `treasury_deny_reason` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Stand-in structure for view `business_inspections_vw`
-- (See below for the actual view)
--
CREATE TABLE `business_inspections_vw` (
`assessor_added_by` varchar(100)
,`assessor_date_added` varchar(20)
,`assessor_date_updated` varchar(20)
,`assessor_geo_tagging` varchar(250)
,`assessor_is_sync` enum('0','1')
,`assessor_lot_number` varchar(20)
,`assessor_lot_owner` varchar(100)
,`assessor_remark` varchar(250)
,`bfp_added_by` varchar(100)
,`bfp_date_added` varchar(20)
,`bfp_date_updated` varchar(20)
,`bfp_is_sync` enum('0','1')
,`bfp_remark` varchar(100)
,`bfp_updated_by` varchar(100)
,`business_id` varchar(100)
,`engineering_added_by` varchar(100)
,`engineering_compliance` varchar(200)
,`engineering_date_added` varchar(20)
,`engineering_date_updated` varchar(20)
,`engineering_is_sync` enum('0','1')
,`engineering_remark` varchar(250)
,`menro_added_by` varchar(100)
,`menro_date_added` varchar(20)
,`menro_date_updated` varchar(20)
,`menro_is_sync` enum('0','1')
,`menro_remark` varchar(250)
,`menro_selection` varchar(200)
,`sanitary_added_by` varchar(100)
,`sanitary_date_added` varchar(20)
,`sanitary_date_updated` varchar(20)
,`sanitary_is_sync` enum('0','1')
,`sanitary_remark` varchar(250)
,`treasury_added_by` varchar(100)
,`treasury_date_added` varchar(20)
,`treasury_date_updated` varchar(20)
,`treasury_is_sync` enum('0','1')
,`treasury_remark` varchar(250)
,`treasury_updated_by` varchar(100)
,`zoning_added_by` varchar(50)
,`zoning_building_structure` varchar(250)
,`zoning_date_added` varchar(20)
,`zoning_date_updated` varchar(20)
,`zoning_geo_tagging` varchar(250)
,`zoning_is_sync` enum('0','1')
,`zoning_location_clearance` varchar(50)
,`zoning_remark` varchar(100)
);

-- --------------------------------------------------------

--
-- Table structure for table `business_inspection_assessor`
--

CREATE TABLE `business_inspection_assessor` (
  `id` int NOT NULL,
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `lot_number` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `lot_owner` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `geo_tagging` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `remark_recommendation` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `added_by` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_added` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_updated` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_inspection_bfp`
--

CREATE TABLE `business_inspection_bfp` (
  `id` int NOT NULL,
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `remark_recommendation` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `added_by` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_added` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_updated` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `updated_by` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_inspection_engineering`
--

CREATE TABLE `business_inspection_engineering` (
  `id` int NOT NULL,
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `compliance` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `remark_recommendation` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `added_by` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_added` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_updated` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_inspection_menro`
--

CREATE TABLE `business_inspection_menro` (
  `id` int NOT NULL,
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `menro_select` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `remark_recommendation` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `added_by` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_added` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_updated` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_inspection_sanitary`
--

CREATE TABLE `business_inspection_sanitary` (
  `id` int NOT NULL,
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `remark_recommendation` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `added_by` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_added` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_updated` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_inspection_treasury`
--

CREATE TABLE `business_inspection_treasury` (
  `id` int NOT NULL,
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `remark_recommendation` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_added` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `added_by` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_updated` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `updated_by` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_inspection_zoning`
--

CREATE TABLE `business_inspection_zoning` (
  `id` int NOT NULL,
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `location_clearance` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `building_structure` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `remark_recommendation` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `geo_tagging` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `added_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_added` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_updated` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_old`
--

CREATE TABLE `business_old` (
  `id` int(7) UNSIGNED ZEROFILL NOT NULL,
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `business_id_final` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `business_permit_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `business_plate_no` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `business_barangay_clearance_control_no` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_status` enum('NEW','RENEW','FOR CLOSING','CLOSED') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'NEW',
  `last_bus_status` enum('NEW','RENEW','FOR CLOSING','CLOSED') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'NEW',
  `bus_application_type` enum('WEB','KIOSK','MOBILE','TABLET','WALK IN') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'WALK IN',
  `bus_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_trade` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_franchise` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_type_of_registration` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_registration_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_registration_date` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_registration_date_exp` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_type` enum('CORPORATION','PARTNERSHIP','SOLE PROPRIETORSHIP','COOPERATIVE','ASSOCIATION') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ctc` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_tin` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_region` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_prov` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_district` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_city_mun` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_brgy` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_zip` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_bldg_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_ad_bldg_no` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_ad_lot_no` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_ad_block_no` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_ad_street` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_ad_subdivision` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_geo_tagging` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_telephone` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_mobile` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_email` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_pic_position` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_pic_other_position` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_pic_first_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_pic_middle_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_pic_last_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_pic_suffix` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_pic_gender` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_kind` enum('FILIPINO','FOREIGN') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'FILIPINO',
  `business_sanitary_control_no` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_added` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `added_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `date_updated` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `updated_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '0',
  `bus_application_status` enum('FOR CHECKING','FOR INSPECTION','FOR APPROVAL','FOR ASSESSMENT','FOR PAYMENT','FOR RELEASING','DENIED','RELEASED','FOR RENEWAL') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'FOR CHECKING',
  `bus_application_denied_reason` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `date_of_inspection` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_gross_essential` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '0',
  `bus_gross_non_essential` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '0',
  `bus_capital` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '0',
  `business_closure_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_assessed` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `assessed_by` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `released_by` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `released_date` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_of_expiration` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `remarks` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `date_of_renewal` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `renewed_for_year` int NOT NULL,
  `bus_is_delinquent` enum('true','false') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'false',
  `bus_is_delinquent_date_of_last_payment` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_is_delinquent_quarter_of_last_payment` enum('1st','2nd','3rd','4th') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_is_delinquent_paid_whole_year` enum('true','false') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_for_delivery` enum('true','false') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_type_of_payment` enum('COD','GCASH','MAYA') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_delivery_status` enum('DELIVERED','ONGOING','PENDING') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `retirement_status` enum('pending','approved') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `retirement_reason` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `retirement_date_applied` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `retirement_date_approved` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `retirement_approved_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `deleted` enum('true','false') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'false'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_operation`
--

CREATE TABLE `business_operation` (
  `business_op_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `business_op_activity` varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_op_ad_region` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_op_ad_prov` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_op_ad_district` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_op_ad_city_mun` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_op_ad_brgy` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_op_ad_zip` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_op_ad_bldg_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_op_ad_bldg_no` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_op_ad_lot_no` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_op_ad_block_no` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_op_ad_street` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_op_ad_subdivision` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_op_area` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_op_floor_area` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_op_internet_provider` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_op_thru_representative` enum('YES','NO') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_op_est_male` varchar(6) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_op_est_female` varchar(6) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_op_res_male` varchar(6) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_op_res_female` varchar(6) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_op_sputum` varchar(6) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_op_no_of_truck_van` varchar(6) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_op_no_of_motorcycles` varchar(6) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_op_is_owned` enum('true','false') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_op_tdn` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_op_pin` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_op_has_incentives` enum('true','false') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_op_is_rented` enum('true','false') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_op_is_rented_hm` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0',
  `bus_op_lessor_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_op_lessor_address` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_op_lessor_contact` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_op_lessor_email` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_op_emergency_fullname` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_op_emergency_contact` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_op_line_of_business` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `date_added` datetime DEFAULT CURRENT_TIMESTAMP,
  `added_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `date_updated` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `updated_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0',
  `bus_op_same_as_main_office` enum('true','false') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'false',
  `bus_op_same_as_no_in_establishment` enum('true','false') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'false',
  `business_op_if_subd` enum('YES','NO') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_paid_transactions`
--

CREATE TABLE `business_paid_transactions` (
  `id` int NOT NULL,
  `business_id` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `transaction_id` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_mode` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `cash_amount` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `total_payables` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bank` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `cheque_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `cheque_amount` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `official_receipt` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `reference_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_added` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `date_of_last_payment` date DEFAULT NULL,
  `added_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `date_updated` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `updated_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0',
  `payment_business_status` enum('NEW','RENEW','FOR CLOSING','') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '',
  `business_permit_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_paid_transactions_cancelled`
--

CREATE TABLE `business_paid_transactions_cancelled` (
  `id` int NOT NULL,
  `business_id` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `transaction_id` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `official_receipt` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `amount_deducted` float NOT NULL DEFAULT '0',
  `year` int NOT NULL,
  `quarters` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `date_added` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `added_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0',
  `payment_business_status` enum('NEW','RENEW','FOR CLOSING','') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_payment_delivery`
--

CREATE TABLE `business_payment_delivery` (
  `id` int NOT NULL,
  `business_id` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `bus_type_of_payment` enum('COD','GCASH','MAYA') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `account_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `account_number` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `reference_number` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `date_created` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_queuing`
--

CREATE TABLE `business_queuing` (
  `id` int NOT NULL,
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `queue_no` int DEFAULT NULL,
  `date_queued` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `status` enum('PENDING','DONE','','') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_renewal`
--

CREATE TABLE `business_renewal` (
  `id` int(7) UNSIGNED ZEROFILL NOT NULL,
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `business_id_final` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `business_permit_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `business_plate_no` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_status` enum('NEW','RENEW','FOR CLOSING','CLOSED') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'NEW',
  `last_bus_status` enum('NEW','RENEW','FOR CLOSING','CLOSED') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'NEW',
  `bus_application_type` enum('WEB','KIOSK','MOBILE','TABLET','WALK IN') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'WALK IN',
  `bus_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_trade` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_franchise` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_type_of_registration` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_registration_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_registration_date` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_registration_date_exp` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_type` enum('CORPORATION','PARTNERSHIP','SOLE PROPRIETORSHIP','COOPERATIVE') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ctc` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_tin` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_region` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_prov` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_district` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_city_mun` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_brgy` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_zip` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_bldg_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_ad_bldg_no` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_ad_lot_no` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_ad_block_no` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_ad_street` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_ad_subdivision` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_geo_tagging` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_telephone` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_mobile` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_email` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_pic_position` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_pic_other_position` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_pic_first_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_pic_middle_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_pic_last_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_pic_suffix` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_pic_gender` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_kind` enum('FILIPINO','FOREIGN') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'FILIPINO',
  `date_added` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `added_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `date_updated` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `updated_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '0',
  `bus_application_status` enum('FOR CHECKING','FOR INSPECTION','FOR APPROVAL','FOR ASSESSMENT','FOR PAYMENT','FOR RELEASING','DENIED','RELEASED','FOR RENEWAL') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'FOR CHECKING',
  `bus_application_denied_reason` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `date_of_inspection` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_gross_essential` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '0',
  `bus_gross_non_essential` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '0',
  `bus_capital` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '0',
  `date_assessed` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `assessed_by` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `released_by` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `released_date` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_of_expiration` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `remarks` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `date_of_renewal` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `renewed_for_year` int DEFAULT NULL,
  `bus_is_delinquent` enum('true','false') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'false',
  `bus_is_delinquent_date_of_last_payment` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_is_delinquent_quarter_of_last_payment` enum('1st','2nd','3rd','4th') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_is_delinquent_paid_whole_year` enum('true','false') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `deleted` enum('true','false') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'false'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_renewal_old`
--

CREATE TABLE `business_renewal_old` (
  `id` int(7) UNSIGNED ZEROFILL NOT NULL,
  `renewal_date_start` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'December 1',
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `business_id_final` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_status` enum('NEW','RENEW') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'NEW',
  `bus_application_type` enum('WEB','KIOSK','MOBILE','TABLET','WALK IN') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'WALK IN',
  `bus_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_trade` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_franchise` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_type_of_registration` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_registration_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_registration_date` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_registration_date_exp` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_type` enum('CORPORATION','PARTNERSHIP','SOLE PROPRIETORSHIP','COOPERATIVE') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ctc` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_tin` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_region` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_prov` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_district` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_city_mun` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_brgy` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_zip` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_ad_bldg_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_ad_bldg_no` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_ad_lot_no` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_ad_block_no` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_ad_street` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_ad_subdivision` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_geo_tagging` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_telephone` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_mobile` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_email` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_pic_position` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_pic_other_position` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_pic_first_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_pic_middle_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_pic_last_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_pic_suffix` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `bus_kind` enum('FILIPINO','FOREIGN') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'FILIPINO',
  `date_added` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `added_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `date_updated` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `updated_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '0',
  `bus_application_status` enum('FOR CHECKING','FOR INSPECTION','FOR APPROVAL','FOR ASSESSMENT','FOR PAYMENT','FOR RELEASING','DENIED','RELEASED','FOR RENEWAL') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'FOR CHECKING',
  `bus_application_denied_reason` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `date_of_inspection` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_sanitary_control_no_history`
--

CREATE TABLE `business_sanitary_control_no_history` (
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `control_no` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `date_added` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `added_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '0',
  `sanitary_status` enum('FOR COMPLIANCE','COMPLIANT') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_sms_notification`
--

CREATE TABLE `business_sms_notification` (
  `id` int NOT NULL,
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `business_contact` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `notification_message` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `date_added` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `added_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `notification_status` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_taxpayers_payment`
--

CREATE TABLE `business_taxpayers_payment` (
  `id` int NOT NULL,
  `payment_official_receipt_no` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_year` int DEFAULT NULL,
  `business_class_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_method` enum('quarterly','semi_annually','annually','') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_mode` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_quarter` enum('1st','2nd','3rd','4th') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_amount` float DEFAULT '0',
  `payment_amount_status` enum('PAID','UNPAID','LAPSED') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'UNPAID',
  `payment_due_date` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_date_paid` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_paid_by_taxpayer_id` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_accepted_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_added` datetime DEFAULT CURRENT_TIMESTAMP,
  `added_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_updated` datetime DEFAULT NULL,
  `updated_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '0',
  `payment_remarks` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `payment_top_no` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_business_status` enum('NEW','RENEW','FOR CLOSING','') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_taxpayers_payment_fees`
--

CREATE TABLE `business_taxpayers_payment_fees` (
  `id` int NOT NULL,
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_charge_type` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_charge_name` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_charge_code` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_charge_code2` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `payment_interest` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '0',
  `payment_surcharge` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '0',
  `payment_formula` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_amount` float NOT NULL DEFAULT '0',
  `payment_no_of_months_late` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_is_late` enum('true','false') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'false',
  `payment_year` int DEFAULT NULL,
  `payment_quarter` enum('1st','2nd','3rd','4th') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '1st',
  `payment_unit` int DEFAULT NULL,
  `date_added` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `added_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `date_updated` datetime DEFAULT NULL,
  `updated_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_business_status` enum('NEW','RENEW','FOR CLOSING','') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '',
  `payment_checked_unchecked` enum('CHECKED','UNCHECKED') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'CHECKED'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_taxpayers_payment_fees_department`
--

CREATE TABLE `business_taxpayers_payment_fees_department` (
  `id` int NOT NULL,
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_charge_name` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_department` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_charge_code` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_charge_code2` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `payment_interest` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_surcharge` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_formula` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_no_of_months_late` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_amount` float NOT NULL DEFAULT '0',
  `payment_year` int DEFAULT NULL,
  `date_added` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `added_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `date_updated` datetime DEFAULT NULL,
  `updated_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '0',
  `is_removed` enum('true','false') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'false'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_tax_history_of_interest_and_surcharge`
--

CREATE TABLE `business_tax_history_of_interest_and_surcharge` (
  `id` int NOT NULL,
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_charge_name` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_interest` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '0',
  `payment_surcharge` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '0',
  `payment_formula` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_amount` float NOT NULL DEFAULT '0',
  `payment_no_of_months_late` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `payment_year` int DEFAULT NULL,
  `payment_quarter` enum('1st','2nd','3rd','4th') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_added` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `added_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `date_updated` datetime DEFAULT NULL,
  `updated_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_tax_range`
--

CREATE TABLE `business_tax_range` (
  `id` int NOT NULL,
  `business_tax_range_id` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `business_tax_range_1` int NOT NULL,
  `business_tax_range_2` bigint DEFAULT NULL,
  `business_tax_range_fees` float NOT NULL,
  `business_tax_range_name` varchar(225) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `business_tax_range_type` enum('FORMULA','NON-FORMULA') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `business_tax_range_formula` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `business_formula_year` varchar(4) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_tax_range_bus_class`
--

CREATE TABLE `business_tax_range_bus_class` (
  `id` int NOT NULL,
  `bus_tax_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `bus_tax_range_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `bus_tax_range_bus_class_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_tax_range_old`
--

CREATE TABLE `business_tax_range_old` (
  `id` int NOT NULL,
  `business_tax_range_id` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `business_tax_range_1` int NOT NULL,
  `business_tax_range_2` int NOT NULL,
  `business_tax_range_fees` float NOT NULL,
  `business_tax_range_name` varchar(225) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `business_tax_range_type` enum('FORMULA','NON-FORMULA') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `business_tax_range_formula` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_utility_charges`
--

CREATE TABLE `business_utility_charges` (
  `charge_code` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `charge_name` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `charge_amount` varchar(11) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0',
  `charge_status` enum('ACTIVE','INACTIVE') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'ACTIVE',
  `charge_type` enum('Heavy Equipment Tax','Public Utility Vehicles Tax','Delivery Trucks or Vans Tax','Business Tax','Laboratory Fee - Stool','Laboratory Fee - Sputum','Business Area Tax','Health Certificate','Occupational Fee','Certificate Fee') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_added` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `added_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `date_updated` datetime DEFAULT NULL,
  `updated_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `clustered_precinct`
--

CREATE TABLE `clustered_precinct` (
  `id` int NOT NULL,
  `clustered_province` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `clustered_municipality` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `clustered_brgy` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `clustered_polling_place` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `clustered_precinct` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `clustered_polling_center` varchar(150) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `cluster_number` varchar(5) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `cvl_event_attendance_tbl`
--

CREATE TABLE `cvl_event_attendance_tbl` (
  `id` int NOT NULL,
  `cvl_row_id` int NOT NULL,
  `event_date` date DEFAULT NULL,
  `event_title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `event_location` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `assistance_provided` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `amount` decimal(12,2) NOT NULL DEFAULT '0.00',
  `event_municipality` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `event_barangay` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `event_precinct_no` varchar(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `cvl_household_members_tbl`
--

CREATE TABLE `cvl_household_members_tbl` (
  `id` int NOT NULL,
  `leader_row_id` int NOT NULL,
  `member_row_id` int NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `cvl_leader_assignment_tbl`
--

CREATE TABLE `cvl_leader_assignment_tbl` (
  `id` int NOT NULL,
  `cvl_row_id` int NOT NULL,
  `leader_cvl_row_id` int NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `cvl_tagging_tbl`
--

CREATE TABLE `cvl_tagging_tbl` (
  `id` int NOT NULL,
  `cvl_row_id` int NOT NULL,
  `structure_name` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `tag_as` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `job_position` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `organization_name` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `sector_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `tagged_by` varchar(125) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `database_backup`
--

CREATE TABLE `database_backup` (
  `id` int NOT NULL,
  `database_comment` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `database_filename` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `database_filesize` varchar(255) COLLATE utf8mb4_general_ci NOT NULL DEFAULT '0',
  `database_date_added` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `database_created_by` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `database_status` varchar(255) COLLATE utf8mb4_general_ci DEFAULT 'UNDELETED',
  `database_deleted_by` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `debug_toolbar_historyentry`
--

CREATE TABLE `debug_toolbar_historyentry` (
  `request_id` char(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `data` json NOT NULL,
  `created_at` datetime(6) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `default_business_id`
--

CREATE TABLE `default_business_id` (
  `business_prefix` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'BP',
  `business_infix_1` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `business_infix_2` int(7) UNSIGNED ZEROFILL NOT NULL,
  `business_suffix` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `default_due_dates`
--

CREATE TABLE `default_due_dates` (
  `id` int NOT NULL,
  `application_type` enum('NEW','RENEW') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `due_date` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `duration_type` enum('annually','semi_annually','quarterly','') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `duration_quarter` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `default_location`
--

CREATE TABLE `default_location` (
  `id` int NOT NULL,
  `default_region` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `default_province` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `default_district` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `default_city_municipality` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `default_barangay` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `region_code` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `province_code` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `district_code` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `city_municipality_code` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `barangay_code` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `default_renewal_year`
--

CREATE TABLE `default_renewal_year` (
  `year` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `deleted_ss_data`
--

CREATE TABLE `deleted_ss_data` (
  `trans_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `table_name` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `sync_status` enum('NOT UPDATED','UPDATED') COLLATE utf8mb4_unicode_ci DEFAULT 'NOT UPDATED',
  `deleted_by` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `deleted_date` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `directory`
--

CREATE TABLE `directory` (
  `id` int NOT NULL,
  `office` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `name_official` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `position` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `contact_number` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email_address` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `date_created` datetime DEFAULT CURRENT_TIMESTAMP,
  `date_modified` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `district`
--

CREATE TABLE `district` (
  `id` int NOT NULL,
  `district` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `district_icon` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `django_admin_log`
--

CREATE TABLE `django_admin_log` (
  `id` int NOT NULL,
  `action_time` datetime(6) NOT NULL,
  `object_id` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `object_repr` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `action_flag` smallint UNSIGNED NOT NULL,
  `change_message` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `content_type_id` int DEFAULT NULL,
  `user_id` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `django_content_type`
--

CREATE TABLE `django_content_type` (
  `id` int NOT NULL,
  `app_label` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `model` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `django_migrations`
--

CREATE TABLE `django_migrations` (
  `id` bigint NOT NULL,
  `app` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `applied` datetime(6) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `django_session`
--

CREATE TABLE `django_session` (
  `session_key` varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `session_data` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `expire_date` datetime(6) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `educ_course`
--

CREATE TABLE `educ_course` (
  `id` int NOT NULL,
  `courses_name` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

-- --------------------------------------------------------

--
-- Table structure for table `history_business_permit_no`
--

CREATE TABLE `history_business_permit_no` (
  `id` int NOT NULL,
  `business_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `permit_no` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bus_status` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_added` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `added_by` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `is_sync` enum('0','1') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `leader_structure_tbl`
--

CREATE TABLE `leader_structure_tbl` (
  `id` int NOT NULL,
  `leader_level` varchar(2) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `leader_unique_id` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `leader_title` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `leader_structure_name` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `leader_person_involved` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `leader_has_downline` enum('YES','NO') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `leader_location` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `leader_ratio` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `location_data_tbl`
--

CREATE TABLE `location_data_tbl` (
  `id` int NOT NULL,
  `mun` varchar(255) NOT NULL,
  `brgy` varchar(255) NOT NULL,
  `sitio` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `login_history`
--

CREATE TABLE `login_history` (
  `id` int NOT NULL,
  `user` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `date_time` text COLLATE utf8mb4_unicode_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `login_record`
--

CREATE TABLE `login_record` (
  `id` int NOT NULL,
  `username` text COLLATE utf8mb4_general_ci NOT NULL,
  `fullname` text COLLATE utf8mb4_general_ci NOT NULL,
  `date_login` text COLLATE utf8mb4_general_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `mac_tbl`
--

CREATE TABLE `mac_tbl` (
  `id` int NOT NULL,
  `mac_id` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `medicines`
--

CREATE TABLE `medicines` (
  `id` int NOT NULL,
  `medicine_name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
  `medicine_for` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `merchant_tbl`
--

CREATE TABLE `merchant_tbl` (
  `id` int NOT NULL,
  `merc_name` varchar(255) DEFAULT NULL,
  `merc_email` varchar(255) NOT NULL,
  `merc_password` varchar(255) DEFAULT NULL,
  `merc_salt` varchar(255) DEFAULT NULL,
  `merc_image` varchar(255) DEFAULT NULL,
  `merc_address` varchar(255) DEFAULT NULL,
  `merc_date_added` varchar(255) DEFAULT NULL,
  `merc_date_expire` varchar(255) DEFAULT NULL,
  `merc_description` varchar(255) DEFAULT NULL,
  `merc_type` varchar(255) DEFAULT NULL,
  `merc_position` varchar(30) NOT NULL DEFAULT '',
  `merc_district` varchar(50) DEFAULT NULL,
  `merc_municipality` varchar(255) DEFAULT NULL,
  `merc_brgy` varchar(255) DEFAULT NULL,
  `merc_product_limit` varchar(255) DEFAULT NULL,
  `merc_status` varchar(255) DEFAULT NULL,
  `date_time_added` datetime DEFAULT CURRENT_TIMESTAMP,
  `added_by` varchar(50) DEFAULT NULL,
  `permissions` longtext
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `municipal_tbl`
--

CREATE TABLE `municipal_tbl` (
  `id` int NOT NULL,
  `municipality` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `district` varchar(25) COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `org_tbl`
--

CREATE TABLE `org_tbl` (
  `id` int NOT NULL,
  `org_name` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `otp_tbl`
--

CREATE TABLE `otp_tbl` (
  `id` int NOT NULL,
  `otp_code` varchar(6) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `sender_number` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `date_created` varchar(90) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `expiration_date` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `peso_applications`
--

CREATE TABLE `peso_applications` (
  `id` bigint UNSIGNED NOT NULL,
  `reference_no` varchar(40) NOT NULL,
  `surname` varchar(80) NOT NULL,
  `firstname` varchar(80) NOT NULL,
  `middlename` varchar(80) DEFAULT NULL,
  `suffix` varchar(20) DEFAULT NULL,
  `birth_date` date NOT NULL,
  `age` tinyint UNSIGNED DEFAULT NULL,
  `place_of_birth` varchar(120) DEFAULT NULL,
  `sex` enum('Male','Female') DEFAULT NULL,
  `religion` varchar(80) DEFAULT NULL,
  `civil_status` enum('Single','Married','Separated','Live-in','Widowed') DEFAULT NULL,
  `present_house_street` varchar(160) DEFAULT NULL,
  `present_village` varchar(120) DEFAULT NULL,
  `present_barangay` varchar(120) DEFAULT NULL,
  `present_municipality` varchar(120) DEFAULT NULL,
  `present_province` varchar(120) DEFAULT NULL,
  `present_region` varchar(120) DEFAULT NULL,
  `height_cm` smallint UNSIGNED DEFAULT NULL,
  `tin_no` varchar(30) DEFAULT NULL,
  `gsis_sss_no` varchar(30) DEFAULT NULL,
  `pagibig_no` varchar(30) DEFAULT NULL,
  `philhealth_no` varchar(30) DEFAULT NULL,
  `email` varchar(120) DEFAULT NULL,
  `landline_no` varchar(30) DEFAULT NULL,
  `cellphone_no` varchar(20) DEFAULT NULL,
  `disability_visual` tinyint(1) NOT NULL DEFAULT '0',
  `disability_hearing` tinyint(1) NOT NULL DEFAULT '0',
  `disability_speech` tinyint(1) NOT NULL DEFAULT '0',
  `disability_physical` tinyint(1) NOT NULL DEFAULT '0',
  `disability_other` tinyint(1) NOT NULL DEFAULT '0',
  `disability_other_specify` varchar(120) DEFAULT NULL,
  `emp_status` enum('Part-time','Unemployed','Full-time','Sefl-employed','Temporary','Contractual','Freelance','Other','Internship','Commission-based') CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  `emp_type` enum('Wage Employed','Self Employed','New/Fresh Grad','Finished Contract','Resigned','Retired','Terminated/Laid-off (Local)','Terminated/Laid-off (Abroad)','Other') DEFAULT NULL,
  `emp_abroad_country` varchar(80) DEFAULT NULL,
  `emp_other_specify` varchar(120) DEFAULT NULL,
  `actively_looking_for_work` enum('Yes','No') DEFAULT NULL,
  `looking_for_work_duration` varchar(80) DEFAULT NULL,
  `willing_to_work_immediately` enum('Yes','No') DEFAULT NULL,
  `if_no_when` varchar(80) DEFAULT NULL,
  `ofw` enum('Yes','No') NOT NULL DEFAULT 'No',
  `former_ofw` enum('Yes','No') NOT NULL DEFAULT 'No',
  `four_ps_beneficiary` enum('Yes','No') DEFAULT NULL,
  `four_ps_household_id` varchar(40) DEFAULT NULL,
  `job_preferences` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  `expected_salary_range` varchar(80) DEFAULT NULL,
  `passport_no` varchar(30) DEFAULT NULL,
  `passport_expiry` date DEFAULT NULL,
  `consent_agreed` enum('Yes','No') NOT NULL DEFAULT 'No',
  `requested_from` varchar(20) NOT NULL DEFAULT 'WEB',
  `status` varchar(30) NOT NULL DEFAULT 'PENDING',
  `user_id` bigint DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `peso_applications_assessment`
--

CREATE TABLE `peso_applications_assessment` (
  `id` bigint UNSIGNED NOT NULL,
  `application_id` bigint UNSIGNED NOT NULL,
  `assessed_by` varchar(120) DEFAULT NULL,
  `eligible_spes` tinyint(1) NOT NULL DEFAULT '0',
  `eligible_gip` tinyint(1) NOT NULL DEFAULT '0',
  `eligible_tupad` tinyint(1) NOT NULL DEFAULT '0',
  `eligible_jobstart` tinyint(1) NOT NULL DEFAULT '0',
  `eligible_other` tinyint(1) NOT NULL DEFAULT '0',
  `eligible_other_specify` varchar(120) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `peso_applications_education`
--

CREATE TABLE `peso_applications_education` (
  `id` bigint UNSIGNED NOT NULL,
  `application_id` bigint UNSIGNED NOT NULL,
  `currently_in_school` enum('Yes','No') NOT NULL DEFAULT 'No',
  `level` enum('Elementary','Elementary UnderGrad','High School','High School UnderGrad','K-12 Senior High','Vocational Course','College UnderGrad','Some College No Degree','Associates Degree','Bachelors Degree') CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `school` varchar(160) DEFAULT NULL,
  `course` varchar(160) DEFAULT NULL,
  `year_graduated` varchar(20) DEFAULT NULL,
  `if_undergraduate_what_level` varchar(60) DEFAULT NULL,
  `year_last_attended` varchar(20) DEFAULT NULL,
  `awards_received` varchar(160) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `peso_applications_eligibility`
--

CREATE TABLE `peso_applications_eligibility` (
  `id` bigint UNSIGNED NOT NULL,
  `application_id` bigint UNSIGNED NOT NULL,
  `row_no` tinyint UNSIGNED NOT NULL,
  `eligibility_name` varchar(120) DEFAULT NULL,
  `rating` varchar(40) DEFAULT NULL,
  `exam_date` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `peso_applications_language_proficiency`
--

CREATE TABLE `peso_applications_language_proficiency` (
  `id` bigint UNSIGNED NOT NULL,
  `application_id` bigint UNSIGNED NOT NULL,
  `language_name` varchar(40) NOT NULL,
  `other_language_specify` varchar(60) DEFAULT NULL,
  `can_read` tinyint(1) NOT NULL DEFAULT '0',
  `can_write` tinyint(1) NOT NULL DEFAULT '0',
  `can_speak` tinyint(1) NOT NULL DEFAULT '0',
  `can_understand` tinyint(1) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `peso_applications_prc_license`
--

CREATE TABLE `peso_applications_prc_license` (
  `id` bigint UNSIGNED NOT NULL,
  `application_id` bigint UNSIGNED NOT NULL,
  `row_no` tinyint UNSIGNED NOT NULL,
  `license_name` varchar(120) DEFAULT NULL,
  `valid_until` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `peso_applications_preferred_locations`
--

CREATE TABLE `peso_applications_preferred_locations` (
  `id` bigint UNSIGNED NOT NULL,
  `application_id` bigint UNSIGNED NOT NULL,
  `location_type` enum('Local','Overseas') NOT NULL,
  `rank_no` tinyint UNSIGNED NOT NULL,
  `location_value` varchar(160) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `peso_applications_preferred_occupations`
--

CREATE TABLE `peso_applications_preferred_occupations` (
  `id` bigint UNSIGNED NOT NULL,
  `application_id` bigint UNSIGNED NOT NULL,
  `rank_no` tinyint UNSIGNED NOT NULL,
  `occupation` varchar(160) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `peso_applications_skills`
--

CREATE TABLE `peso_applications_skills` (
  `application_id` bigint UNSIGNED NOT NULL,
  `skill_id` int UNSIGNED NOT NULL,
  `other_specify` varchar(120) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `peso_applications_skill_catalog`
--

CREATE TABLE `peso_applications_skill_catalog` (
  `id` int UNSIGNED NOT NULL,
  `skill_code` varchar(40) NOT NULL,
  `skill_name` varchar(120) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `peso_applications_training`
--

CREATE TABLE `peso_applications_training` (
  `id` bigint UNSIGNED NOT NULL,
  `application_id` bigint UNSIGNED NOT NULL,
  `row_no` tinyint UNSIGNED NOT NULL,
  `course` varchar(160) DEFAULT NULL,
  `duration_from` date DEFAULT NULL,
  `duration_to` date DEFAULT NULL,
  `training_institution` varchar(160) DEFAULT NULL,
  `certificates_received` varchar(160) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `peso_applications_work_experience`
--

CREATE TABLE `peso_applications_work_experience` (
  `id` bigint UNSIGNED NOT NULL,
  `application_id` bigint UNSIGNED NOT NULL,
  `row_no` tinyint UNSIGNED NOT NULL DEFAULT '1',
  `company_name` varchar(160) DEFAULT NULL,
  `company_address_city_municipality` varchar(160) DEFAULT NULL,
  `position` varchar(120) DEFAULT NULL,
  `inclusive_from` date DEFAULT NULL,
  `inclusive_to` date DEFAULT NULL,
  `status` enum('Permanent','Contractual','Part-time','Probationary','Other') DEFAULT NULL,
  `status_other` varchar(60) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `philippine_locations`
--

CREATE TABLE `philippine_locations` (
  `id` int NOT NULL,
  `region` varchar(80) DEFAULT NULL,
  `province` varchar(80) DEFAULT NULL,
  `city_municipality` varchar(80) DEFAULT NULL,
  `barangay` varchar(80) DEFAULT NULL,
  `region_code` varchar(80) DEFAULT NULL,
  `provincial_code` varchar(80) DEFAULT NULL,
  `city_municipality_code` varchar(80) DEFAULT NULL,
  `barangay_code` varchar(80) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

-- --------------------------------------------------------

--
-- Table structure for table `program_tbl`
--

CREATE TABLE `program_tbl` (
  `id` int NOT NULL,
  `program_name` varchar(255) DEFAULT NULL,
  `category` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `ptms_associations`
--

CREATE TABLE `ptms_associations` (
  `code` int UNSIGNED NOT NULL,
  `description` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `ptms_banks`
--

CREATE TABLE `ptms_banks` (
  `code` int UNSIGNED NOT NULL,
  `description` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `ptms_barangays`
--

CREATE TABLE `ptms_barangays` (
  `code` int UNSIGNED NOT NULL,
  `description` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `ptms_billing`
--

CREATE TABLE `ptms_billing` (
  `id` int UNSIGNED NOT NULL,
  `tricycle_no` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `billing_date` date NOT NULL,
  `or_number` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `payment_mode` enum('cash','check','money_order') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'cash',
  `bank_code` int UNSIGNED DEFAULT NULL,
  `check_no` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `check_date` date DEFAULT NULL,
  `noted_by` int UNSIGNED DEFAULT NULL,
  `approved_by` int UNSIGNED DEFAULT NULL,
  `posted_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `ptms_billing_items`
--

CREATE TABLE `ptms_billing_items` (
  `id` int UNSIGNED NOT NULL,
  `billing_id` int UNSIGNED NOT NULL,
  `fee_type_code` int UNSIGNED NOT NULL DEFAULT '0',
  `tax_paid` decimal(10,2) NOT NULL DEFAULT '0.00',
  `penalty_paid` decimal(10,2) NOT NULL DEFAULT '0.00',
  `total_amount` decimal(10,2) NOT NULL DEFAULT '0.00'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `ptms_business_types`
--

CREATE TABLE `ptms_business_types` (
  `code` int UNSIGNED NOT NULL,
  `description` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `ptms_drivers`
--

CREATE TABLE `ptms_drivers` (
  `driver_code` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `tricycle_no` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `first_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `mid_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `last_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `license_no` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `license_expiry` date DEFAULT NULL,
  `birthday` date DEFAULT NULL,
  `address` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `ptms_due_dates`
--

CREATE TABLE `ptms_due_dates` (
  `id` int UNSIGNED NOT NULL,
  `business_type` enum('business','franchise','nothing') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'business',
  `year_interval` int NOT NULL DEFAULT '1',
  `bill_date_type` enum('system_date','franchise_date','not_applicable') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'system_date'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `ptms_fee_types`
--

CREATE TABLE `ptms_fee_types` (
  `code` int UNSIGNED NOT NULL,
  `abbr` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `description` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `type` enum('business','franchise','nothing') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'business',
  `bill` enum('once','regular') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'regular'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `ptms_operators`
--

CREATE TABLE `ptms_operators` (
  `account_no` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `first_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `middle_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `last_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `suffix` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `name_of_operator` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `address` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `birthday` date DEFAULT NULL,
  `photo` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gcash_no` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `ptms_or_config`
--

CREATE TABLE `ptms_or_config` (
  `field` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `col_pos` int NOT NULL DEFAULT '0',
  `row_pos` int NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `ptms_revision_fees`
--

CREATE TABLE `ptms_revision_fees` (
  `id` int UNSIGNED NOT NULL,
  `year` year NOT NULL,
  `business_code` int UNSIGNED NOT NULL DEFAULT '0',
  `fee_type_code` int UNSIGNED NOT NULL DEFAULT '0',
  `fee_amount` decimal(10,2) NOT NULL DEFAULT '0.00'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `ptms_revision_years`
--

CREATE TABLE `ptms_revision_years` (
  `year` year NOT NULL,
  `surcharge_pct` decimal(5,2) NOT NULL DEFAULT '0.00',
  `penalty_pct` decimal(5,2) NOT NULL DEFAULT '0.00',
  `extension_months` tinyint NOT NULL DEFAULT '0',
  `extension_days` tinyint NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `ptms_route_areas`
--

CREATE TABLE `ptms_route_areas` (
  `code` int UNSIGNED NOT NULL,
  `description` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `ptms_signatories`
--

CREATE TABLE `ptms_signatories` (
  `id` int UNSIGNED NOT NULL,
  `type` enum('position','name') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'position',
  `code` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `value` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `ptms_title_setup`
--

CREATE TABLE `ptms_title_setup` (
  `id` int UNSIGNED NOT NULL,
  `header1` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `header2` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `header3` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `header4` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `ptms_tricycles`
--

CREATE TABLE `ptms_tricycles` (
  `tricycle_no` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `account_no` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `type_of_service` varchar(60) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `bus_code` int UNSIGNED NOT NULL DEFAULT '0',
  `brgy_code` int UNSIGNED NOT NULL DEFAULT '0',
  `route_code` int UNSIGNED NOT NULL DEFAULT '0',
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `application_date` date DEFAULT NULL,
  `registration_date` date DEFAULT NULL,
  `plate_no` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `model` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `make` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `motor_no` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `chassis_no` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `color` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `assn_code` int UNSIGNED NOT NULL DEFAULT '0',
  `year_start` year DEFAULT NULL,
  `motor_photo` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `is_dropped` tinyint(1) NOT NULL DEFAULT '0',
  `date_dropped` date DEFAULT NULL,
  `remarks` text COLLATE utf8mb4_unicode_ci,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `queuing_table`
--

CREATE TABLE `queuing_table` (
  `id` int NOT NULL,
  `application_no` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `service` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `queue_no` int DEFAULT NULL,
  `date_of_application` date DEFAULT NULL,
  `queue_status` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `counter` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `religion_tbl`
--

CREATE TABLE `religion_tbl` (
  `id` int NOT NULL,
  `religion_name` varchar(150) COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `scanner_users`
--

CREATE TABLE `scanner_users` (
  `id` int NOT NULL,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `code` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `is_active` tinyint(1) DEFAULT '1',
  `failed_attempts` int DEFAULT '0',
  `locked_until` datetime DEFAULT NULL,
  `date_created` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `sector_tbl`
--

CREATE TABLE `sector_tbl` (
  `id` int NOT NULL,
  `sector_name` varchar(255) DEFAULT NULL,
  `sector_title` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `sms_outbox`
--

CREATE TABLE `sms_outbox` (
  `id` int NOT NULL,
  `mobilenum` varchar(20) DEFAULT NULL,
  `originator` varchar(100) DEFAULT NULL,
  `message` text,
  `provider_code` int DEFAULT NULL,
  `provider_status` varchar(20) DEFAULT NULL,
  `transid` varchar(100) DEFAULT NULL,
  `client_outboxnum` varchar(100) DEFAULT NULL,
  `txtparts` int DEFAULT NULL,
  `dlr_flag` varchar(10) DEFAULT NULL,
  `cost_ctr` tinyint DEFAULT NULL,
  `ctr_mobilenum` varchar(20) DEFAULT NULL,
  `valid_mobilenum` varchar(20) DEFAULT NULL,
  `provider_timestamp` varchar(50) DEFAULT NULL,
  `provider_response_json` json DEFAULT NULL,
  `date_created` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `social_services_tbl`
--

CREATE TABLE `social_services_tbl` (
  `id` varchar(20) COLLATE utf8mb3_unicode_ci NOT NULL,
  `requester_fullname` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `requester_isVoter` varchar(20) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `requester_cvl_id` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `requester_gender` varchar(20) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `requester_birthdate` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `requester_age` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `requester_contact` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `requester_email` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `requester_address` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `requester_mun` varchar(80) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `requester_brgy` varchar(80) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `requester_sitio` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `requester_sector` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `requester_rel` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `fullname` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `isVoter` varchar(20) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `cvl_id` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `email` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `contact` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `gender` varchar(20) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `birthplace` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `birthdate` varchar(50) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `age` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `address` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `municipality` varchar(80) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `brgy` varchar(80) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `sitio` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `sector` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `spouse` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `father_name` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `mother_name` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `referrer_1` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `referrer_2` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `agriculture` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `amount` int DEFAULT NULL,
  `agency` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `program` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `date_request` varchar(50) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `date_time` varchar(25) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `reEncode` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `status` varchar(20) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `import` varchar(50) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `remarks` varchar(255) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `bulk_uploaded_by` varchar(50) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `sync_status` varchar(20) COLLATE utf8mb3_unicode_ci DEFAULT 'NOT UPDATED',
  `inserted_by` varchar(50) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `last_updated_by` varchar(50) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `family_id` varchar(20) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `family_role` varchar(25) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `beneficiary` enum('YES','NO') COLLATE utf8mb3_unicode_ci NOT NULL,
  `type` varchar(100) COLLATE utf8mb3_unicode_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `social_service_relationship_tbl`
--

CREATE TABLE `social_service_relationship_tbl` (
  `id` int NOT NULL,
  `relationship_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `temp_comelec_tbl`
--

CREATE TABLE `temp_comelec_tbl` (
  `id` int NOT NULL,
  `role_name` varchar(255) DEFAULT NULL,
  `temp_voters_id` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `temp_name` varchar(150) DEFAULT NULL,
  `temp_imgpath` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `lastname` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `firstname` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `middlename` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `suffixname` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_code` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_leader_id` varchar(20) DEFAULT NULL,
  `temp_structure_name` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_address` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_gender` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_bday` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_region` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_province_city` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_district` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_mun` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_brgy` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_sitio` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_precinct_no` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_access_imei` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `import` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_id_status` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `isVoter` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_contact_number` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_household_title` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_household_leader` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_household_relationship` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_poll_watcher_workers` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_fb_email` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_household_update_status` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_tagged_numbering` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_sector` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_org` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_org_2` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_religion` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_tag_status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_tag_update_status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bulk_uploaded_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date_time` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'current_timestamp()',
  `temp_vital_status` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_working_status` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_quickcount_status` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_quick_count_info` varchar(255) DEFAULT NULL,
  `temp_clustered_precinct` varchar(150) DEFAULT NULL,
  `temp_cluster_number` varchar(10) DEFAULT NULL,
  `temp_clustered_polling_place` varchar(150) DEFAULT NULL,
  `temp_untagged_by` varchar(150) DEFAULT NULL,
  `temp_untagged_date` varchar(50) DEFAULT NULL,
  `temp_added_by` varchar(100) DEFAULT NULL,
  `temp_date_time_added` varchar(50) DEFAULT NULL,
  `temp_job_position` varchar(255) DEFAULT NULL,
  `temp_tagged_by` varchar(255) DEFAULT NULL,
  `temp_date_time_tagged` varchar(50) DEFAULT NULL,
  `temp_last_edited_by` varchar(100) DEFAULT NULL,
  `temp_last_edited_date_time` varchar(50) DEFAULT NULL,
  `temp_transferred_by` varchar(100) DEFAULT NULL,
  `temp_transferred_date_time` varchar(150) DEFAULT NULL,
  `temp_transferred_to` varchar(150) DEFAULT NULL,
  `temp_transferred_old_leader` varchar(25) DEFAULT NULL,
  `temp_remove_en_und_unk_by` varchar(100) DEFAULT NULL,
  `temp_remove_en_und_unk_date_time` varchar(80) DEFAULT NULL,
  `temp_changed_leader_by` varchar(100) DEFAULT NULL,
  `temp_changed_leader_date_time` varchar(50) DEFAULT NULL,
  `temp_changed_new_leader` varchar(25) DEFAULT NULL,
  `temp_changed_old_leader` varchar(25) DEFAULT NULL,
  `temp_old_mun` varchar(100) DEFAULT NULL,
  `temp_old_brgy` varchar(100) DEFAULT NULL,
  `temp_old_cluster` varchar(20) DEFAULT NULL,
  `temp_old_precinct` varchar(20) DEFAULT NULL,
  `temp_is_assigned` tinytext,
  `temp_sync_by` varchar(100) DEFAULT NULL,
  `temp_sync_date_time` varchar(50) DEFAULT NULL,
  `temp_id_remove_info` varchar(80) DEFAULT NULL,
  `voter_status` enum('ACTIVE','INACTIVE') NOT NULL DEFAULT 'ACTIVE',
  `card_count` int NOT NULL DEFAULT '0',
  `voter_history` enum('NEW','OLD') DEFAULT 'NEW'
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `temp_comelec_tbl_nv`
--

CREATE TABLE `temp_comelec_tbl_nv` (
  `id` int NOT NULL,
  `nonvoters_id` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `fullname` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `gender` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `bday` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `address` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_mun` varchar(100) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_brgy` varchar(100) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `head_cvl_id` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `relationship` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `contact` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `fb_email` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_tag_status` varchar(255) COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'NOT UPDATED',
  `temp_tag_update_status` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `temp_household_update_status` varchar(15) COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `user_session_tbl`
--

CREATE TABLE `user_session_tbl` (
  `id` int NOT NULL,
  `user_session_contact` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_session_code` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_session_start_date` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_session_end_date` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_session_start_time` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_session_end_time` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `user_tbl`
--

CREATE TABLE `user_tbl` (
  `id` int NOT NULL,
  `user_type` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_id` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_email` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_pin_number` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_fname` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_mname` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_lname` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_suffix` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_contact` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_current_address` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_valid_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_valid_id_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_valid_id_number` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_selfie_photo` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_pin_status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_status` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `registration_id` varchar(250) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `date_created` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `date_modified` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `website_table_updates`
--

CREATE TABLE `website_table_updates` (
  `id` int NOT NULL,
  `unique_id` varchar(25) COLLATE utf8mb4_unicode_ci NOT NULL,
  `table_to_do` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `table_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `column_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `column_type` varchar(25) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `default_column_val` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `key_type` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `version` varchar(25) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` varchar(25) COLLATE utf8mb4_unicode_ci DEFAULT 'NOT UPDATED'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `website_version_tbl`
--

CREATE TABLE `website_version_tbl` (
  `id` int NOT NULL,
  `version_id` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `web_login`
--

CREATE TABLE `web_login` (
  `id` int NOT NULL,
  `mobile_number` varchar(11) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `otp` varchar(11) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Structure for view `business_inspections_vw`
--
DROP TABLE IF EXISTS `business_inspections_vw`;

CREATE ALGORITHM=UNDEFINED DEFINER=`admin`@`%` SQL SECURITY DEFINER VIEW `business_inspections_vw`  AS SELECT `bi`.`business_id` AS `business_id`, `bia`.`lot_number` AS `assessor_lot_number`, `bia`.`lot_owner` AS `assessor_lot_owner`, `bia`.`geo_tagging` AS `assessor_geo_tagging`, `bia`.`remark_recommendation` AS `assessor_remark`, `bia`.`added_by` AS `assessor_added_by`, `bia`.`date_added` AS `assessor_date_added`, `bia`.`date_updated` AS `assessor_date_updated`, `bia`.`is_sync` AS `assessor_is_sync`, `bib`.`remark_recommendation` AS `bfp_remark`, `bib`.`added_by` AS `bfp_added_by`, `bib`.`updated_by` AS `bfp_updated_by`, `bib`.`date_added` AS `bfp_date_added`, `bib`.`date_updated` AS `bfp_date_updated`, `bib`.`is_sync` AS `bfp_is_sync`, `bie`.`compliance` AS `engineering_compliance`, `bie`.`remark_recommendation` AS `engineering_remark`, `bie`.`added_by` AS `engineering_added_by`, `bie`.`date_added` AS `engineering_date_added`, `bie`.`date_updated` AS `engineering_date_updated`, `bie`.`is_sync` AS `engineering_is_sync`, `bim`.`menro_select` AS `menro_selection`, `bim`.`remark_recommendation` AS `menro_remark`, `bim`.`added_by` AS `menro_added_by`, `bim`.`date_added` AS `menro_date_added`, `bim`.`date_updated` AS `menro_date_updated`, `bim`.`is_sync` AS `menro_is_sync`, `bis`.`remark_recommendation` AS `sanitary_remark`, `bis`.`added_by` AS `sanitary_added_by`, `bis`.`date_added` AS `sanitary_date_added`, `bis`.`date_updated` AS `sanitary_date_updated`, `bis`.`is_sync` AS `sanitary_is_sync`, `bitr`.`remark_recommendation` AS `treasury_remark`, `bitr`.`added_by` AS `treasury_added_by`, `bitr`.`updated_by` AS `treasury_updated_by`, `bitr`.`date_added` AS `treasury_date_added`, `bitr`.`date_updated` AS `treasury_date_updated`, `bitr`.`is_sync` AS `treasury_is_sync`, `biz`.`location_clearance` AS `zoning_location_clearance`, `biz`.`building_structure` AS `zoning_building_structure`, `biz`.`geo_tagging` AS `zoning_geo_tagging`, `biz`.`remark_recommendation` AS `zoning_remark`, `biz`.`added_by` AS `zoning_added_by`, `biz`.`date_added` AS `zoning_date_added`, `biz`.`date_updated` AS `zoning_date_updated`, `biz`.`is_sync` AS `zoning_is_sync` FROM (((((((`business_inspections` `bi` left join `business_inspection_assessor` `bia` on((`bia`.`business_id` = `bi`.`business_id`))) left join `business_inspection_bfp` `bib` on((`bib`.`business_id` = `bi`.`business_id`))) left join `business_inspection_engineering` `bie` on((`bie`.`business_id` = `bi`.`business_id`))) left join `business_inspection_menro` `bim` on((`bim`.`business_id` = `bi`.`business_id`))) left join `business_inspection_sanitary` `bis` on((`bis`.`business_id` = `bi`.`business_id`))) left join `business_inspection_treasury` `bitr` on((`bitr`.`business_id` = `bi`.`business_id`))) left join `business_inspection_zoning` `biz` on((`biz`.`business_id` = `bi`.`business_id`))) ;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `1srvr_gg_test`
--
ALTER TABLE `1srvr_gg_test`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `admin_access_tbl`
--
ALTER TABLE `admin_access_tbl`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_account_deletion_log`
--
ALTER TABLE `app_account_deletion_log`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_mobile_number` (`mobile_number`),
  ADD KEY `idx_user_profile_id` (`user_profile_id`),
  ADD KEY `idx_deleted_at_server` (`deleted_at_server`),
  ADD KEY `idx_email_address` (`email_address`),
  ADD KEY `idx_card_id_no` (`card_id_no`),
  ADD KEY `idx_name_dob` (`first_name`,`last_name`,`birth_date`);

--
-- Indexes for table `app_admins`
--
ALTER TABLE `app_admins`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uniq_admin_email` (`email`),
  ADD UNIQUE KEY `uniq_admin_username` (`username`),
  ADD KEY `idx_admin_approval_status` (`approval_status`);

--
-- Indexes for table `app_admin_audit`
--
ALTER TABLE `app_admin_audit`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_audit_admin` (`admin_id`),
  ADD KEY `idx_audit_target` (`target_table`,`target_id`),
  ADD KEY `idx_audit_perm` (`permission`);

--
-- Indexes for table `app_admin_finance_budget`
--
ALTER TABLE `app_admin_finance_budget`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_admin_finance_transaction`
--
ALTER TABLE `app_admin_finance_transaction`
  ADD PRIMARY KEY (`id`),
  ADD KEY `app_admin_finance_tr_budget_id_e72f4e27_fk_app_admin` (`budget_id`);

--
-- Indexes for table `app_admin_invites`
--
ALTER TABLE `app_admin_invites`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uniq_admin_invite_token` (`token`),
  ADD KEY `idx_admin_invite_status` (`status`),
  ADD KEY `idx_admin_invite_expires` (`expires_at`);

--
-- Indexes for table `app_applicant_profiles`
--
ALTER TABLE `app_applicant_profiles`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `user_id` (`user_id`),
  ADD KEY `idx_applicant_profile_user` (`user_id`);

--
-- Indexes for table `app_audit_logs`
--
ALTER TABLE `app_audit_logs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_created` (`created_at`),
  ADD KEY `idx_actor` (`actor_id`),
  ADD KEY `idx_action` (`action`),
  ADD KEY `idx_entity` (`entity_type`,`entity_id`);

--
-- Indexes for table `app_business_permits`
--
ALTER TABLE `app_business_permits`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `application_number` (`application_number`),
  ADD KEY `idx_bp_user` (`user_id`),
  ADD KEY `idx_bp_status` (`status`),
  ADD KEY `idx_bp_appnum` (`application_number`),
  ADD KEY `idx_bp_apptype` (`application_type`);

--
-- Indexes for table `app_card_registrations`
--
ALTER TABLE `app_card_registrations`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `reference_number` (`reference_number`),
  ADD KEY `idx_card_user` (`user_id`),
  ADD KEY `idx_card_status` (`status`),
  ADD KEY `idx_card_ref` (`reference_number`);

--
-- Indexes for table `app_card_request`
--
ALTER TABLE `app_card_request`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_card_transactions`
--
ALTER TABLE `app_card_transactions`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_cardtx_user` (`user_id`),
  ADD KEY `idx_cardtx_card` (`assign_card`),
  ADD KEY `idx_cardtx_date` (`date_created`),
  ADD KEY `idx_cardtx_scanner` (`scanner_id`);

--
-- Indexes for table `app_cho_sanitary_permit`
--
ALTER TABLE `app_cho_sanitary_permit`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `application_number` (`application_number`),
  ADD KEY `app_cho_sanitary_permit_user_id_c6945f2a_fk_app_users_id` (`user_id`);

--
-- Indexes for table `app_civil_registry`
--
ALTER TABLE `app_civil_registry`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_civil_registry_marriage`
--
ALTER TABLE `app_civil_registry_marriage`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_claim_logs`
--
ALTER TABLE `app_claim_logs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_scanner` (`scanner_id`),
  ADD KEY `idx_app_no` (`application_number`),
  ADD KEY `idx_device` (`device_id`);

--
-- Indexes for table `app_companies`
--
ALTER TABLE `app_companies`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_companies_login_email` (`login_email`),
  ADD UNIQUE KEY `uq_companies_username` (`username`),
  ADD UNIQUE KEY `uq_company_name` (`name`),
  ADD KEY `idx_companies_status` (`status`);

--
-- Indexes for table `app_contact_us`
--
ALTER TABLE `app_contact_us`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_cvl`
--
ALTER TABLE `app_cvl`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `card_id` (`card_id`),
  ADD KEY `app_cvl_role_id_558b0b1c_fk_app_role_id` (`role_id`),
  ADD KEY `app_cvl_role_upper_id_a06f1454_fk_app_cvl_id` (`role_upper_id`),
  ADD KEY `app_cvl_fullname_8c205682` (`fullname`),
  ADD KEY `app_cvl_province_b24c1045` (`province`),
  ADD KEY `app_cvl_district_f4e48369` (`district`),
  ADD KEY `app_cvl_municipality_2208fcd3` (`municipality`),
  ADD KEY `app_cvl_barangay_32be63cf` (`barangay`),
  ADD KEY `app_cvl_precinct_c38f5ba2` (`precinct`),
  ADD KEY `app_cvl_contact_6117d149` (`contact`),
  ADD KEY `app_cvl_org_d5da1042` (`org`);

--
-- Indexes for table `app_cvl_list`
--
ALTER TABLE `app_cvl_list`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `idx_cvl_id` (`cvl_id`),
  ADD KEY `fk_qrcode` (`cvl_qr`),
  ADD KEY `idx_cvl_mun_id` (`cvl_mun`,`id`),
  ADD KEY `idx_cvl_brgy_id` (`cvl_brgy`,`id`),
  ADD KEY `idx_cvl_precinct_id` (`cvl_precinct_no`,`id`),
  ADD KEY `idx_cvl_secondary_position_id` (`cvl_secondary_position`,`id`),
  ADD KEY `idx_cvl_position_code` (`cvl_position_code`),
  ADD KEY `idx_cvl_fullname_id` (`cvl_fullname`,`id`),
  ADD KEY `idx_cvl_mun_fullname_id` (`cvl_mun`,`cvl_fullname`,`id`),
  ADD KEY `idx_cvl_mun_brgy_fullname_id` (`cvl_mun`,`cvl_brgy`,`cvl_fullname`,`id`),
  ADD KEY `idx_cvl_precinct_fullname_id` (`cvl_precinct_no`,`cvl_fullname`,`id`),
  ADD KEY `idx_cvl_secondary_position_fullname_id` (`cvl_secondary_position`,`cvl_fullname`,`id`),
  ADD KEY `idx_cvl_status_fullname` (`cvl_status`,`cvl_fullname`(191)),
  ADD KEY `idx_cvl_status_mun_brgy_precinct` (`cvl_status`,`cvl_mun`,`cvl_brgy`,`cvl_precinct_no`),
  ADD KEY `idx_cvl_status_position_sector` (`cvl_status`,`cvl_position_code`,`cvl_sector`),
  ADD KEY `idx_cvl_household_leader` (`cvl_household_leader`),
  ADD KEY `idx_cvl_household_leader_cvl_id` (`cvl_household_leader_cvl_id`);
ALTER TABLE `app_cvl_list` ADD FULLTEXT KEY `ft_cvl_fullname` (`cvl_fullname`);

--
-- Indexes for table `app_cvl_locations`
--
ALTER TABLE `app_cvl_locations`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_directory_hospital`
--
ALTER TABLE `app_directory_hospital`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_fb_pages`
--
ALTER TABLE `app_fb_pages`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_feedback`
--
ALTER TABLE `app_feedback`
  ADD PRIMARY KEY (`id`),
  ADD KEY `app_feedback_user_id_57be9fb8_fk_app_users_id` (`user_id`);

--
-- Indexes for table `app_incident_report`
--
ALTER TABLE `app_incident_report`
  ADD PRIMARY KEY (`id`),
  ADD KEY `app_incident_report_user_id_52fc8ebb_fk_app_users_id` (`user_id`);

--
-- Indexes for table `app_incident_reports`
--
ALTER TABLE `app_incident_reports`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `reference_number` (`reference_number`),
  ADD KEY `idx_ir_user` (`user_id`),
  ADD KEY `idx_ir_status` (`status`),
  ADD KEY `idx_ir_type` (`report_type`),
  ADD KEY `idx_ir_expires` (`expires_at`);

--
-- Indexes for table `app_item_records`
--
ALTER TABLE `app_item_records`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_item_records_date` (`record_date`),
  ADD KEY `idx_item_records_organization` (`organization`),
  ADD KEY `fk_item_records_batch` (`batch_id`);

--
-- Indexes for table `app_item_record_batches`
--
ALTER TABLE `app_item_record_batches`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_job_applications`
--
ALTER TABLE `app_job_applications`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `reference_number` (`reference_number`),
  ADD KEY `idx_ja_user` (`user_id`),
  ADD KEY `idx_ja_job` (`job_posting_id`),
  ADD KEY `idx_ja_status` (`status`);

--
-- Indexes for table `app_job_posting`
--
ALTER TABLE `app_job_posting`
  ADD PRIMARY KEY (`id`),
  ADD KEY `app_job_posting_company_id_82f570ed_fk_app_peso_` (`company_id`);

--
-- Indexes for table `app_job_postings`
--
ALTER TABLE `app_job_postings`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_jp_status` (`status`),
  ADD KEY `idx_jp_posted` (`posted_at`),
  ADD KEY `idx_company_id` (`company_id`);

--
-- Indexes for table `app_job_vacancies_applicant`
--
ALTER TABLE `app_job_vacancies_applicant`
  ADD PRIMARY KEY (`id`),
  ADD KEY `app_job_vacancies_ap_job_posting_id_596dd501_fk_app_job_p` (`job_posting_id`),
  ADD KEY `app_job_vacancies_applicant_user_id_941d8198_fk_app_users_id` (`user_id`),
  ADD KEY `fk_applicant_peso` (`applicant_id`);

--
-- Indexes for table `app_kyc`
--
ALTER TABLE `app_kyc`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_app_kyc_user_id` (`user_id`);

--
-- Indexes for table `app_legal_consultations`
--
ALTER TABLE `app_legal_consultations`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `application_number` (`application_number`),
  ADD KEY `idx_legal_user` (`user_id`),
  ADD KEY `idx_legal_status` (`status`);

--
-- Indexes for table `app_legal_consultation_history`
--
ALTER TABLE `app_legal_consultation_history`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_legal_hist_consult` (`consultation_id`);

--
-- Indexes for table `app_lgu_sites`
--
ALTER TABLE `app_lgu_sites`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_locations`
--
ALTER TABLE `app_locations`
  ADD PRIMARY KEY (`id`),
  ADD KEY `app_locatio_region_262f9b_idx` (`region`),
  ADD KEY `app_locatio_provinc_fe0190_idx` (`province`),
  ADD KEY `app_locatio_city_mu_7d2a71_idx` (`city_municipality`);

--
-- Indexes for table `app_LoginActivity`
--
ALTER TABLE `app_LoginActivity`
  ADD PRIMARY KEY (`id`),
  ADD KEY `app_audit_LoginActivity_user_id_5f1bf4cb_fk_auth_user_id` (`user_id`);

--
-- Indexes for table `app_modules`
--
ALTER TABLE `app_modules`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_news_announcement_list`
--
ALTER TABLE `app_news_announcement_list`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_nonvoter_list`
--
ALTER TABLE `app_nonvoter_list`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_nonvoter_cvl_id` (`cvl_id`),
  ADD KEY `idx_nonvoter_fullname` (`cvl_fullname`),
  ADD KEY `idx_nonvoter_social_service` (`nv_social_service_id`);

--
-- Indexes for table `app_notifications`
--
ALTER TABLE `app_notifications`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_user_id` (`user_profile_id`),
  ADD KEY `idx_is_read` (`is_read`);

--
-- Indexes for table `app_notification_logs`
--
ALTER TABLE `app_notification_logs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_notification_reference` (`reference_type`,`reference_id`),
  ADD KEY `idx_notification_channel_status` (`channel`,`status`);

--
-- Indexes for table `app_obo_building_permit`
--
ALTER TABLE `app_obo_building_permit`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `application_number` (`application_number`),
  ADD KEY `user_id` (`user_id`);

--
-- Indexes for table `app_osca_activities`
--
ALTER TABLE `app_osca_activities`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_osca_news`
--
ALTER TABLE `app_osca_news`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_osca_registration`
--
ALTER TABLE `app_osca_registration`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_otp`
--
ALTER TABLE `app_otp`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_otp_count`
--
ALTER TABLE `app_otp_count`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_paymongo_sessions`
--
ALTER TABLE `app_paymongo_sessions`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `session_id` (`session_id`),
  ADD KEY `idx_paymongo_user` (`user_id`),
  ADD KEY `idx_paymongo_ref` (`reference_number`),
  ADD KEY `idx_paymongo_stat` (`status`);

--
-- Indexes for table `app_permission_migrations`
--
ALTER TABLE `app_permission_migrations`
  ADD PRIMARY KEY (`migration_key`);

--
-- Indexes for table `app_peso_applications`
--
ALTER TABLE `app_peso_applications`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `reference_no` (`reference_no`),
  ADD KEY `app_peso_applications_user_id_f55d0fb6_fk_app_users_id` (`user_id`);

--
-- Indexes for table `app_peso_applications_assessment`
--
ALTER TABLE `app_peso_applications_assessment`
  ADD PRIMARY KEY (`id`),
  ADD KEY `app_peso_application_application_id_5fd19810_fk_app_peso_` (`application_id`);

--
-- Indexes for table `app_peso_applications_attachments`
--
ALTER TABLE `app_peso_applications_attachments`
  ADD PRIMARY KEY (`id`),
  ADD KEY `app_peso_application_application_id_63550fdd_fk_app_peso_` (`application_id`);

--
-- Indexes for table `app_peso_applications_education`
--
ALTER TABLE `app_peso_applications_education`
  ADD PRIMARY KEY (`id`),
  ADD KEY `app_peso_application_application_id_4bc9568e_fk_app_peso_` (`application_id`);

--
-- Indexes for table `app_peso_applications_eligibility`
--
ALTER TABLE `app_peso_applications_eligibility`
  ADD PRIMARY KEY (`id`),
  ADD KEY `app_peso_application_application_id_c9e73fdb_fk_app_peso_` (`application_id`);

--
-- Indexes for table `app_peso_applications_language_proficiency`
--
ALTER TABLE `app_peso_applications_language_proficiency`
  ADD PRIMARY KEY (`id`),
  ADD KEY `app_peso_application_application_id_c75ee6f6_fk_app_peso_` (`application_id`);

--
-- Indexes for table `app_peso_applications_prc_license`
--
ALTER TABLE `app_peso_applications_prc_license`
  ADD PRIMARY KEY (`id`),
  ADD KEY `app_peso_application_application_id_70a51421_fk_app_peso_` (`application_id`);

--
-- Indexes for table `app_peso_applications_preferred_locations`
--
ALTER TABLE `app_peso_applications_preferred_locations`
  ADD PRIMARY KEY (`id`),
  ADD KEY `app_peso_application_application_id_546e8229_fk_app_peso_` (`application_id`);

--
-- Indexes for table `app_peso_applications_preferred_occupations`
--
ALTER TABLE `app_peso_applications_preferred_occupations`
  ADD PRIMARY KEY (`id`),
  ADD KEY `app_peso_application_application_id_44a6445c_fk_app_peso_` (`application_id`);

--
-- Indexes for table `app_peso_applications_skills`
--
ALTER TABLE `app_peso_applications_skills`
  ADD PRIMARY KEY (`id`),
  ADD KEY `app_peso_application_application_id_fb44c8a6_fk_app_peso_` (`application_id`),
  ADD KEY `app_peso_application_skill_id_7ca90089_fk_app_peso_` (`skill_id`);

--
-- Indexes for table `app_peso_applications_skill_catalog`
--
ALTER TABLE `app_peso_applications_skill_catalog`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `skill_code` (`skill_code`);

--
-- Indexes for table `app_peso_applications_training`
--
ALTER TABLE `app_peso_applications_training`
  ADD PRIMARY KEY (`id`),
  ADD KEY `app_peso_application_application_id_442c1af9_fk_app_peso_` (`application_id`);

--
-- Indexes for table `app_peso_applications_work_experience`
--
ALTER TABLE `app_peso_applications_work_experience`
  ADD PRIMARY KEY (`id`),
  ADD KEY `app_peso_application_application_id_21a77246_fk_app_peso_` (`application_id`);

--
-- Indexes for table `app_peso_company_profile`
--
ALTER TABLE `app_peso_company_profile`
  ADD PRIMARY KEY (`id`),
  ADD KEY `app_peso_company_profile_auth_user_id_dc7e66b8_fk_auth_user_id` (`auth_user_id`);

--
-- Indexes for table `app_peso_jobfair_registration`
--
ALTER TABLE `app_peso_jobfair_registration`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_profile_update_requests`
--
ALTER TABLE `app_profile_update_requests`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_user_id` (`user_id`),
  ADD KEY `idx_status` (`status`);

--
-- Indexes for table `app_qr_code`
--
ALTER TABLE `app_qr_code`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_results_2025`
--
ALTER TABLE `app_results_2025`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_reviews`
--
ALTER TABLE `app_reviews`
  ADD PRIMARY KEY (`id`),
  ADD KEY `tourism_id` (`tourism_id`);

--
-- Indexes for table `app_role`
--
ALTER TABLE `app_role`
  ADD PRIMARY KEY (`id`),
  ADD KEY `app_role_upper_id_4b103556_fk_app_role_id` (`upper_id`);

--
-- Indexes for table `app_rpt_tax_declaration`
--
ALTER TABLE `app_rpt_tax_declaration`
  ADD PRIMARY KEY (`id`),
  ADD KEY `app_rpt_tax_declaration_user_id_07b08271_fk_app_users_id` (`user_id`);

--
-- Indexes for table `app_service_requests`
--
ALTER TABLE `app_service_requests`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `application_number` (`application_number`);

--
-- Indexes for table `app_service_toggles`
--
ALTER TABLE `app_service_toggles`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_settings`
--
ALTER TABLE `app_settings`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uk_setting_key` (`setting_key`);

--
-- Indexes for table `app_sms`
--
ALTER TABLE `app_sms`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_app_sms_mobile` (`mobile_number`),
  ADD KEY `idx_app_sms_status` (`status`),
  ADD KEY `idx_app_sms_date` (`date_created`);

--
-- Indexes for table `app_sms_log`
--
ALTER TABLE `app_sms_log`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_social_services`
--
ALTER TABLE `app_social_services`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_app_social_services_qr_code` (`qr_code`),
  ADD KEY `app_social_services_user_id_cff9b5fb_fk_app_users_id` (`user_id`),
  ADD KEY `idx_appointment_date_method` (`appointment_date`,`submission_method`),
  ADD KEY `idx_social_services_cvl_id` (`cvl_id`),
  ADD KEY `idx_social_services_qr_code` (`qr_code`),
  ADD KEY `idx_social_services_schedule_slot_id` (`schedule_slot_id`),
  ADD KEY `idx_social_services_admin_id` (`admin_id`);

--
-- Indexes for table `app_social_services_family`
--
ALTER TABLE `app_social_services_family`
  ADD PRIMARY KEY (`id`),
  ADD KEY `app_social_services__social_services_id_30d6cf26_fk_app_socia` (`social_services_id`),
  ADD KEY `app_social_services_family_user_id_3acb0468_fk_app_users_id` (`user_id`);

--
-- Indexes for table `app_social_services_type`
--
ALTER TABLE `app_social_services_type`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_social_service_schedule_slots`
--
ALTER TABLE `app_social_service_schedule_slots`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uniq_schedule_slots_date_time` (`slot_date`,`slot_time`),
  ADD KEY `idx_schedule_slots_status` (`status`);

--
-- Indexes for table `app_solicitations`
--
ALTER TABLE `app_solicitations`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_solicitations_date_requested` (`date_requested`),
  ADD KEY `idx_solicitations_organization` (`organization`),
  ADD KEY `fk_solicitations_batch` (`batch_id`);

--
-- Indexes for table `app_solicitation_batches`
--
ALTER TABLE `app_solicitation_batches`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_support_tickets`
--
ALTER TABLE `app_support_tickets`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_user_id` (`user_profile_id`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_ticket` (`ticket_number`);

--
-- Indexes for table `app_theme_dynamic`
--
ALTER TABLE `app_theme_dynamic`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_tourism`
--
ALTER TABLE `app_tourism`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_transactions_history`
--
ALTER TABLE `app_transactions_history`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `application_number` (`application_number`),
  ADD KEY `user_id` (`user_id`);

--
-- Indexes for table `app_transaction_history`
--
ALTER TABLE `app_transaction_history`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_user_id` (`user_profile_id`),
  ADD KEY `idx_type` (`transaction_type`);

--
-- Indexes for table `app_users`
--
ALTER TABLE `app_users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `card_id` (`card_id`),
  ADD KEY `app_user_card` (`assign_card`);

--
-- Indexes for table `app_users_scanner`
--
ALTER TABLE `app_users_scanner`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_app_users_scanner_username` (`username`);

--
-- Indexes for table `app_user_operations_tbl`
--
ALTER TABLE `app_user_operations_tbl`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_user_preferences`
--
ALTER TABLE `app_user_preferences`
  ADD PRIMARY KEY (`user_profile_id`);

--
-- Indexes for table `app_user_service_toggles`
--
ALTER TABLE `app_user_service_toggles`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `user_id` (`user_id`),
  ADD KEY `idx_uts_user` (`user_id`);

--
-- Indexes for table `app_version`
--
ALTER TABLE `app_version`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `auth_group`
--
ALTER TABLE `auth_group`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `name` (`name`);

--
-- Indexes for table `auth_group_permissions`
--
ALTER TABLE `auth_group_permissions`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `auth_group_permissions_group_id_permission_id_0cd325b0_uniq` (`group_id`,`permission_id`),
  ADD KEY `auth_group_permissio_permission_id_84c5c92e_fk_auth_perm` (`permission_id`);

--
-- Indexes for table `auth_permission`
--
ALTER TABLE `auth_permission`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `auth_permission_content_type_id_codename_01ab375a_uniq` (`content_type_id`,`codename`);

--
-- Indexes for table `auth_user`
--
ALTER TABLE `auth_user`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `username` (`username`);

--
-- Indexes for table `auth_user_groups`
--
ALTER TABLE `auth_user_groups`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `auth_user_groups_user_id_group_id_94350c0c_uniq` (`user_id`,`group_id`),
  ADD KEY `auth_user_groups_group_id_97559544_fk_auth_group_id` (`group_id`);

--
-- Indexes for table `auth_user_user_permissions`
--
ALTER TABLE `auth_user_user_permissions`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `auth_user_user_permissions_user_id_permission_id_14a6b632_uniq` (`user_id`,`permission_id`),
  ADD KEY `auth_user_user_permi_permission_id_1fbb5f2c_fk_auth_perm` (`permission_id`);

--
-- Indexes for table `barangays`
--
ALTER TABLE `barangays`
  ADD PRIMARY KEY (`barangay_code`),
  ADD KEY `municipality` (`municipality`);

--
-- Indexes for table `brgy_tbl`
--
ALTER TABLE `brgy_tbl`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `municipality` (`municipality`,`brgy`),
  ADD UNIQUE KEY `municipality_2` (`municipality`,`brgy`),
  ADD UNIQUE KEY `municipality_3` (`municipality`,`brgy`),
  ADD UNIQUE KEY `municipality_4` (`municipality`,`brgy`),
  ADD UNIQUE KEY `municipality_5` (`municipality`,`brgy`);

--
-- Indexes for table `business`
--
ALTER TABLE `business`
  ADD PRIMARY KEY (`business_id`),
  ADD UNIQUE KEY `id` (`id`),
  ADD UNIQUE KEY `business_plate_no` (`business_plate_no`),
  ADD UNIQUE KEY `business_closure_no` (`business_closure_no`),
  ADD KEY `bus_ad_brgy` (`bus_ad_brgy`),
  ADD KEY `bus_ad_prov` (`bus_ad_prov`),
  ADD KEY `bus_ad_city_mun` (`bus_ad_city_mun`),
  ADD KEY `is_sync` (`is_sync`),
  ADD KEY `bus_ad_region` (`bus_ad_region`),
  ADD KEY `bus_kind` (`bus_kind`),
  ADD KEY `bus_ad_district` (`bus_ad_district`),
  ADD KEY `bus_status` (`bus_status`),
  ADD KEY `bus_application_status` (`bus_application_status`),
  ADD KEY `bus_type` (`bus_type`),
  ADD KEY `bus_ad_zip` (`bus_ad_zip`),
  ADD KEY `business_id_final` (`business_id_final`),
  ADD KEY `date_updated` (`date_updated`),
  ADD KEY `date_of_inspection` (`date_of_inspection`),
  ADD KEY `bus_application_type` (`bus_application_type`),
  ADD KEY `business_permit_no` (`business_permit_no`),
  ADD KEY `deleted` (`deleted`),
  ADD KEY `bus_for_delivery` (`bus_for_delivery`),
  ADD KEY `bus_type_of_payment` (`bus_type_of_payment`),
  ADD KEY `bus_delivery_status` (`bus_delivery_status`),
  ADD KEY `business_barangay_clearance_control_no` (`business_barangay_clearance_control_no`),
  ADD KEY `idx_released` (`released_date`);
ALTER TABLE `business` ADD FULLTEXT KEY `bus_name` (`bus_name`);
ALTER TABLE `business` ADD FULLTEXT KEY `bus_pic_first_name` (`bus_pic_first_name`,`bus_pic_middle_name`,`bus_pic_last_name`,`bus_pic_suffix`);

--
-- Indexes for table `business_approvals`
--
ALTER TABLE `business_approvals`
  ADD PRIMARY KEY (`business_id`,`approval_year`),
  ADD KEY `date_updated` (`date_updated`),
  ADD KEY `is_sync` (`is_sync`);

--
-- Indexes for table `business_capital`
--
ALTER TABLE `business_capital`
  ADD PRIMARY KEY (`business_id`);

--
-- Indexes for table `business_category`
--
ALTER TABLE `business_category`
  ADD PRIMARY KEY (`id`),
  ADD KEY `bus_category` (`bus_category`,`bus_category_size_name`);

--
-- Indexes for table `business_category_sizes`
--
ALTER TABLE `business_category_sizes`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `business_category_sizes_bus_class`
--
ALTER TABLE `business_category_sizes_bus_class`
  ADD PRIMARY KEY (`id`),
  ADD KEY `business_class_id` (`business_class_id`,`business_category_name`);

--
-- Indexes for table `business_char`
--
ALTER TABLE `business_char`
  ADD PRIMARY KEY (`id`),
  ADD KEY `char_code_1` (`char_code_1`),
  ADD KEY `char_code_2` (`char_code_2`),
  ADD KEY `char_code_3` (`char_code_3`),
  ADD KEY `char_code_4` (`char_code_4`);

--
-- Indexes for table `business_char1`
--
ALTER TABLE `business_char1`
  ADD PRIMARY KEY (`bus_char_id`),
  ADD KEY `bus_char_status` (`bus_char_status`);

--
-- Indexes for table `business_char2`
--
ALTER TABLE `business_char2`
  ADD PRIMARY KEY (`bus_char_id`),
  ADD KEY `bus_char_status` (`bus_char_status`);

--
-- Indexes for table `business_char3`
--
ALTER TABLE `business_char3`
  ADD PRIMARY KEY (`bus_char_id`),
  ADD KEY `bus_char_status` (`bus_char_status`);

--
-- Indexes for table `business_char4`
--
ALTER TABLE `business_char4`
  ADD PRIMARY KEY (`bus_char_id`),
  ADD KEY `bus_char_status` (`bus_char_status`);

--
-- Indexes for table `business_char5`
--
ALTER TABLE `business_char5`
  ADD PRIMARY KEY (`bus_char_id`),
  ADD KEY `bus_char_status` (`bus_char_status`);

--
-- Indexes for table `business_charges`
--
ALTER TABLE `business_charges`
  ADD PRIMARY KEY (`bus_charges_id`),
  ADD KEY `bus_charges_status` (`bus_charges_status`);

--
-- Indexes for table `business_charges_final`
--
ALTER TABLE `business_charges_final`
  ADD PRIMARY KEY (`business_char1_id`,`business_charges_id`,`business_charges_sub_id`),
  ADD UNIQUE KEY `business_charges_final_id` (`business_charges_final_id`);

--
-- Indexes for table `business_charges_sub`
--
ALTER TABLE `business_charges_sub`
  ADD PRIMARY KEY (`bus_charges_id`);

--
-- Indexes for table `business_classification`
--
ALTER TABLE `business_classification`
  ADD PRIMARY KEY (`id`),
  ADD KEY `business_id` (`business_id`);

--
-- Indexes for table `business_clearance_control_no_history`
--
ALTER TABLE `business_clearance_control_no_history`
  ADD PRIMARY KEY (`business_id`,`control_no`);

--
-- Indexes for table `business_department_charges`
--
ALTER TABLE `business_department_charges`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `business_gross`
--
ALTER TABLE `business_gross`
  ADD PRIMARY KEY (`business_id`);

--
-- Indexes for table `business_history`
--
ALTER TABLE `business_history`
  ADD PRIMARY KEY (`id`),
  ADD KEY `business_id` (`business_id`),
  ADD KEY `notification_status` (`notification_status`),
  ADD KEY `id` (`id`);

--
-- Indexes for table `business_images`
--
ALTER TABLE `business_images`
  ADD PRIMARY KEY (`id`),
  ADD KEY `business_id` (`business_id`),
  ADD KEY `is_sync` (`is_sync`);

--
-- Indexes for table `business_inspections`
--
ALTER TABLE `business_inspections`
  ADD PRIMARY KEY (`business_id`,`inspection_year`),
  ADD KEY `date_updated` (`date_updated`),
  ADD KEY `date_added` (`date_added`);

--
-- Indexes for table `business_inspection_assessor`
--
ALTER TABLE `business_inspection_assessor`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `business_inspection_bfp`
--
ALTER TABLE `business_inspection_bfp`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `business_inspection_engineering`
--
ALTER TABLE `business_inspection_engineering`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `business_inspection_menro`
--
ALTER TABLE `business_inspection_menro`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `business_inspection_sanitary`
--
ALTER TABLE `business_inspection_sanitary`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `business_inspection_treasury`
--
ALTER TABLE `business_inspection_treasury`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `business_inspection_zoning`
--
ALTER TABLE `business_inspection_zoning`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `business_old`
--
ALTER TABLE `business_old`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `business_operation`
--
ALTER TABLE `business_operation`
  ADD PRIMARY KEY (`business_op_id`),
  ADD KEY `bus_op_ad_region` (`bus_op_ad_region`),
  ADD KEY `bus_op_ad_prov` (`bus_op_ad_prov`),
  ADD KEY `bus_op_ad_city_mun` (`bus_op_ad_city_mun`),
  ADD KEY `bus_op_ad_brgy` (`bus_op_ad_brgy`),
  ADD KEY `bus_op_ad_zip` (`bus_op_ad_zip`),
  ADD KEY `bus_op_is_rented` (`bus_op_is_rented`),
  ADD KEY `bus_op_has_incentives` (`bus_op_has_incentives`),
  ADD KEY `bus_op_internet_provider` (`bus_op_internet_provider`),
  ADD KEY `bus_op_is_owned` (`bus_op_is_owned`),
  ADD KEY `date_updated` (`date_updated`);

--
-- Indexes for table `business_paid_transactions`
--
ALTER TABLE `business_paid_transactions`
  ADD PRIMARY KEY (`id`),
  ADD KEY `business_id` (`business_id`),
  ADD KEY `official_receipt` (`official_receipt`);

--
-- Indexes for table `business_paid_transactions_cancelled`
--
ALTER TABLE `business_paid_transactions_cancelled`
  ADD PRIMARY KEY (`id`),
  ADD KEY `business_id` (`business_id`),
  ADD KEY `official_receipt` (`official_receipt`);

--
-- Indexes for table `business_payment_delivery`
--
ALTER TABLE `business_payment_delivery`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `business_queuing`
--
ALTER TABLE `business_queuing`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `queue_no` (`queue_no`,`date_queued`);

--
-- Indexes for table `business_renewal`
--
ALTER TABLE `business_renewal`
  ADD PRIMARY KEY (`business_id`),
  ADD UNIQUE KEY `id` (`id`),
  ADD UNIQUE KEY `business_plate_no` (`business_plate_no`),
  ADD KEY `bus_ad_brgy` (`bus_ad_brgy`),
  ADD KEY `bus_ad_prov` (`bus_ad_prov`),
  ADD KEY `bus_ad_city_mun` (`bus_ad_city_mun`),
  ADD KEY `is_sync` (`is_sync`),
  ADD KEY `bus_ad_region` (`bus_ad_region`),
  ADD KEY `bus_kind` (`bus_kind`),
  ADD KEY `bus_ad_district` (`bus_ad_district`),
  ADD KEY `bus_status` (`bus_status`),
  ADD KEY `bus_application_status` (`bus_application_status`),
  ADD KEY `bus_type` (`bus_type`),
  ADD KEY `bus_ad_zip` (`bus_ad_zip`),
  ADD KEY `business_id_final` (`business_id_final`),
  ADD KEY `date_updated` (`date_updated`),
  ADD KEY `date_of_inspection` (`date_of_inspection`),
  ADD KEY `bus_application_type` (`bus_application_type`),
  ADD KEY `business_permit_no` (`business_permit_no`),
  ADD KEY `deleted` (`deleted`);
ALTER TABLE `business_renewal` ADD FULLTEXT KEY `bus_name` (`bus_name`);
ALTER TABLE `business_renewal` ADD FULLTEXT KEY `bus_pic_first_name` (`bus_pic_first_name`,`bus_pic_middle_name`,`bus_pic_last_name`,`bus_pic_suffix`);

--
-- Indexes for table `business_sanitary_control_no_history`
--
ALTER TABLE `business_sanitary_control_no_history`
  ADD PRIMARY KEY (`business_id`,`control_no`);

--
-- Indexes for table `business_sms_notification`
--
ALTER TABLE `business_sms_notification`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `business_taxpayers_payment`
--
ALTER TABLE `business_taxpayers_payment`
  ADD PRIMARY KEY (`id`),
  ADD KEY `business_id` (`business_id`),
  ADD KEY `is_sync` (`is_sync`);

--
-- Indexes for table `business_taxpayers_payment_fees`
--
ALTER TABLE `business_taxpayers_payment_fees`
  ADD PRIMARY KEY (`id`),
  ADD KEY `business_id` (`business_id`),
  ADD KEY `is_sync` (`is_sync`),
  ADD KEY `payment_year` (`payment_year`),
  ADD KEY `payment_charge_type` (`payment_charge_type`),
  ADD KEY `payment_quarter` (`payment_quarter`);

--
-- Indexes for table `business_taxpayers_payment_fees_department`
--
ALTER TABLE `business_taxpayers_payment_fees_department`
  ADD PRIMARY KEY (`id`),
  ADD KEY `business_id` (`business_id`),
  ADD KEY `payment_year` (`payment_year`);

--
-- Indexes for table `business_tax_history_of_interest_and_surcharge`
--
ALTER TABLE `business_tax_history_of_interest_and_surcharge`
  ADD PRIMARY KEY (`id`),
  ADD KEY `business_id` (`business_id`),
  ADD KEY `payment_year` (`payment_year`),
  ADD KEY `is_sync` (`is_sync`);

--
-- Indexes for table `business_tax_range`
--
ALTER TABLE `business_tax_range`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `business_tax_range_bus_class`
--
ALTER TABLE `business_tax_range_bus_class`
  ADD PRIMARY KEY (`id`),
  ADD KEY `bus_tax_range_bus_class_id` (`bus_tax_range_bus_class_id`);

--
-- Indexes for table `business_tax_range_old`
--
ALTER TABLE `business_tax_range_old`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `business_utility_charges`
--
ALTER TABLE `business_utility_charges`
  ADD PRIMARY KEY (`charge_code`),
  ADD KEY `charge_status` (`charge_status`),
  ADD KEY `charge_type` (`charge_type`);

--
-- Indexes for table `clustered_precinct`
--
ALTER TABLE `clustered_precinct`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_clustered_brgy_precinct` (`clustered_brgy`,`clustered_precinct`);

--
-- Indexes for table `cvl_event_attendance_tbl`
--
ALTER TABLE `cvl_event_attendance_tbl`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_cvl_row_id` (`cvl_row_id`),
  ADD KEY `idx_event_date` (`event_date`);

--
-- Indexes for table `cvl_household_members_tbl`
--
ALTER TABLE `cvl_household_members_tbl`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_member_row_id` (`member_row_id`),
  ADD UNIQUE KEY `unique_leader_member` (`leader_row_id`,`member_row_id`),
  ADD KEY `idx_leader_row_id` (`leader_row_id`);

--
-- Indexes for table `cvl_leader_assignment_tbl`
--
ALTER TABLE `cvl_leader_assignment_tbl`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_cvl_row_id` (`cvl_row_id`),
  ADD KEY `idx_leader_cvl_row_id` (`leader_cvl_row_id`);

--
-- Indexes for table `database_backup`
--
ALTER TABLE `database_backup`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `debug_toolbar_historyentry`
--
ALTER TABLE `debug_toolbar_historyentry`
  ADD PRIMARY KEY (`request_id`);

--
-- Indexes for table `default_location`
--
ALTER TABLE `default_location`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `default_renewal_year`
--
ALTER TABLE `default_renewal_year`
  ADD PRIMARY KEY (`year`);

--
-- Indexes for table `deleted_ss_data`
--
ALTER TABLE `deleted_ss_data`
  ADD PRIMARY KEY (`trans_id`,`table_name`);

--
-- Indexes for table `django_admin_log`
--
ALTER TABLE `django_admin_log`
  ADD PRIMARY KEY (`id`),
  ADD KEY `django_admin_log_content_type_id_c4bce8eb_fk_django_co` (`content_type_id`),
  ADD KEY `django_admin_log_user_id_c564eba6_fk_auth_user_id` (`user_id`);

--
-- Indexes for table `django_content_type`
--
ALTER TABLE `django_content_type`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `django_content_type_app_label_model_76bd3d3b_uniq` (`app_label`,`model`);

--
-- Indexes for table `django_migrations`
--
ALTER TABLE `django_migrations`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `django_session`
--
ALTER TABLE `django_session`
  ADD PRIMARY KEY (`session_key`),
  ADD KEY `django_session_expire_date_a5c62663` (`expire_date`);

--
-- Indexes for table `educ_course`
--
ALTER TABLE `educ_course`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `courses_name` (`courses_name`),
  ADD UNIQUE KEY `courses_name_2` (`courses_name`),
  ADD UNIQUE KEY `courses_name_3` (`courses_name`),
  ADD UNIQUE KEY `courses_name_4` (`courses_name`),
  ADD UNIQUE KEY `courses_name_5` (`courses_name`),
  ADD UNIQUE KEY `courses_name_6` (`courses_name`),
  ADD UNIQUE KEY `courses_name_7` (`courses_name`),
  ADD UNIQUE KEY `courses_name_8` (`courses_name`),
  ADD UNIQUE KEY `courses_name_9` (`courses_name`);

--
-- Indexes for table `history_business_permit_no`
--
ALTER TABLE `history_business_permit_no`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `leader_structure_tbl`
--
ALTER TABLE `leader_structure_tbl`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `leader_unique_id` (`leader_unique_id`),
  ADD UNIQUE KEY `leader_unique_id_2` (`leader_unique_id`),
  ADD UNIQUE KEY `leader_unique_id_3` (`leader_unique_id`),
  ADD UNIQUE KEY `leader_unique_id_4` (`leader_unique_id`),
  ADD UNIQUE KEY `leader_unique_id_5` (`leader_unique_id`),
  ADD UNIQUE KEY `leader_unique_id_6` (`leader_unique_id`);

--
-- Indexes for table `location_data_tbl`
--
ALTER TABLE `location_data_tbl`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `login_history`
--
ALTER TABLE `login_history`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `login_record`
--
ALTER TABLE `login_record`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `medicines`
--
ALTER TABLE `medicines`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `merchant_tbl`
--
ALTER TABLE `merchant_tbl`
  ADD PRIMARY KEY (`merc_email`),
  ADD UNIQUE KEY `id` (`id`);

--
-- Indexes for table `municipal_tbl`
--
ALTER TABLE `municipal_tbl`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `municipality` (`municipality`);

--
-- Indexes for table `org_tbl`
--
ALTER TABLE `org_tbl`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `peso_applications`
--
ALTER TABLE `peso_applications`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uk_reference_no` (`reference_no`);

--
-- Indexes for table `peso_applications_assessment`
--
ALTER TABLE `peso_applications_assessment`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uk_app` (`application_id`);

--
-- Indexes for table `peso_applications_education`
--
ALTER TABLE `peso_applications_education`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uk_app_level` (`application_id`,`level`),
  ADD KEY `idx_app` (`application_id`);

--
-- Indexes for table `peso_applications_eligibility`
--
ALTER TABLE `peso_applications_eligibility`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uk_app_row` (`application_id`,`row_no`),
  ADD KEY `idx_app` (`application_id`);

--
-- Indexes for table `peso_applications_language_proficiency`
--
ALTER TABLE `peso_applications_language_proficiency`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uk_app_lang` (`application_id`,`language_name`),
  ADD KEY `idx_app` (`application_id`);

--
-- Indexes for table `peso_applications_prc_license`
--
ALTER TABLE `peso_applications_prc_license`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uk_app_row` (`application_id`,`row_no`),
  ADD KEY `idx_app` (`application_id`);

--
-- Indexes for table `peso_applications_preferred_locations`
--
ALTER TABLE `peso_applications_preferred_locations`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uk_app_loc` (`application_id`,`location_type`,`rank_no`),
  ADD KEY `idx_app` (`application_id`);

--
-- Indexes for table `peso_applications_preferred_occupations`
--
ALTER TABLE `peso_applications_preferred_occupations`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uk_app_rank` (`application_id`,`rank_no`),
  ADD KEY `idx_app` (`application_id`);

--
-- Indexes for table `peso_applications_skills`
--
ALTER TABLE `peso_applications_skills`
  ADD PRIMARY KEY (`application_id`,`skill_id`),
  ADD KEY `fk_as_skill` (`skill_id`);

--
-- Indexes for table `peso_applications_skill_catalog`
--
ALTER TABLE `peso_applications_skill_catalog`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uk_code` (`skill_code`);

--
-- Indexes for table `peso_applications_training`
--
ALTER TABLE `peso_applications_training`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uk_app_row` (`application_id`,`row_no`),
  ADD KEY `idx_app` (`application_id`);

--
-- Indexes for table `peso_applications_work_experience`
--
ALTER TABLE `peso_applications_work_experience`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_app` (`application_id`);

--
-- Indexes for table `philippine_locations`
--
ALTER TABLE `philippine_locations`
  ADD PRIMARY KEY (`id`),
  ADD KEY `region` (`region`),
  ADD KEY `province` (`province`),
  ADD KEY `city_municipality` (`city_municipality`),
  ADD KEY `barangay` (`barangay`),
  ADD KEY `region_code` (`region_code`),
  ADD KEY `provincial_code` (`provincial_code`),
  ADD KEY `city_municipality_code` (`city_municipality_code`),
  ADD KEY `barangay_code` (`barangay_code`);

--
-- Indexes for table `program_tbl`
--
ALTER TABLE `program_tbl`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `ptms_associations`
--
ALTER TABLE `ptms_associations`
  ADD PRIMARY KEY (`code`);

--
-- Indexes for table `ptms_banks`
--
ALTER TABLE `ptms_banks`
  ADD PRIMARY KEY (`code`);

--
-- Indexes for table `ptms_barangays`
--
ALTER TABLE `ptms_barangays`
  ADD PRIMARY KEY (`code`);

--
-- Indexes for table `ptms_billing`
--
ALTER TABLE `ptms_billing`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `ptms_billing_items`
--
ALTER TABLE `ptms_billing_items`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `ptms_business_types`
--
ALTER TABLE `ptms_business_types`
  ADD PRIMARY KEY (`code`);

--
-- Indexes for table `ptms_drivers`
--
ALTER TABLE `ptms_drivers`
  ADD PRIMARY KEY (`driver_code`);

--
-- Indexes for table `ptms_due_dates`
--
ALTER TABLE `ptms_due_dates`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `ptms_fee_types`
--
ALTER TABLE `ptms_fee_types`
  ADD PRIMARY KEY (`code`);

--
-- Indexes for table `ptms_operators`
--
ALTER TABLE `ptms_operators`
  ADD PRIMARY KEY (`account_no`);

--
-- Indexes for table `ptms_or_config`
--
ALTER TABLE `ptms_or_config`
  ADD PRIMARY KEY (`field`);

--
-- Indexes for table `ptms_revision_fees`
--
ALTER TABLE `ptms_revision_fees`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uniq_rev_fee` (`year`,`business_code`,`fee_type_code`);

--
-- Indexes for table `ptms_revision_years`
--
ALTER TABLE `ptms_revision_years`
  ADD PRIMARY KEY (`year`);

--
-- Indexes for table `ptms_route_areas`
--
ALTER TABLE `ptms_route_areas`
  ADD PRIMARY KEY (`code`);

--
-- Indexes for table `ptms_signatories`
--
ALTER TABLE `ptms_signatories`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uniq_sig` (`type`,`code`);

--
-- Indexes for table `ptms_title_setup`
--
ALTER TABLE `ptms_title_setup`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `ptms_tricycles`
--
ALTER TABLE `ptms_tricycles`
  ADD PRIMARY KEY (`tricycle_no`);

--
-- Indexes for table `queuing_table`
--
ALTER TABLE `queuing_table`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `religion_tbl`
--
ALTER TABLE `religion_tbl`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `scanner_users`
--
ALTER TABLE `scanner_users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `code` (`code`);

--
-- Indexes for table `sector_tbl`
--
ALTER TABLE `sector_tbl`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `sms_outbox`
--
ALTER TABLE `sms_outbox`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_mobilenum` (`mobilenum`),
  ADD KEY `idx_transid` (`transid`);

--
-- Indexes for table `social_services_tbl`
--
ALTER TABLE `social_services_tbl`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fullname` (`fullname`),
  ADD KEY `requester_mun` (`requester_mun`,`requester_brgy`),
  ADD KEY `municipality` (`municipality`,`brgy`);

--
-- Indexes for table `social_service_relationship_tbl`
--
ALTER TABLE `social_service_relationship_tbl`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `temp_comelec_tbl`
--
ALTER TABLE `temp_comelec_tbl`
  ADD PRIMARY KEY (`id`),
  ADD KEY `id` (`id`),
  ADD KEY `temp_name` (`temp_name`,`temp_brgy`,`temp_precinct_no`) USING BTREE,
  ADD KEY `temp_household_leader` (`temp_household_leader`),
  ADD KEY `temp_structure_name` (`temp_structure_name`,`temp_code`),
  ADD KEY `temp_id_status` (`temp_id_status`),
  ADD KEY `temp_bday` (`temp_bday`),
  ADD KEY `temp_mun` (`temp_mun`),
  ADD KEY `temp_district` (`temp_district`),
  ADD KEY `temp_mun_2` (`temp_mun`,`temp_brgy`),
  ADD KEY `temp_mun_3` (`temp_mun`,`temp_brgy`,`temp_precinct_no`),
  ADD KEY `temp_code` (`temp_code`,`temp_structure_name`),
  ADD KEY `idx_temp_voters_id` (`temp_voters_id`),
  ADD KEY `idx_temp_leader_id` (`temp_leader_id`);

--
-- Indexes for table `temp_comelec_tbl_nv`
--
ALTER TABLE `temp_comelec_tbl_nv`
  ADD PRIMARY KEY (`id`),
  ADD KEY `head_cvl_id` (`head_cvl_id`);

--
-- Indexes for table `user_session_tbl`
--
ALTER TABLE `user_session_tbl`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_session_contact` (`user_session_contact`);

--
-- Indexes for table `user_tbl`
--
ALTER TABLE `user_tbl`
  ADD PRIMARY KEY (`user_id`),
  ADD KEY `id` (`id`);

--
-- Indexes for table `website_table_updates`
--
ALTER TABLE `website_table_updates`
  ADD PRIMARY KEY (`unique_id`),
  ADD UNIQUE KEY `id` (`id`);

--
-- Indexes for table `website_version_tbl`
--
ALTER TABLE `website_version_tbl`
  ADD PRIMARY KEY (`version_id`),
  ADD UNIQUE KEY `id` (`id`);

--
-- Indexes for table `web_login`
--
ALTER TABLE `web_login`
  ADD PRIMARY KEY (`id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `app_account_deletion_log`
--
ALTER TABLE `app_account_deletion_log`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_admins`
--
ALTER TABLE `app_admins`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_admin_audit`
--
ALTER TABLE `app_admin_audit`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_admin_finance_budget`
--
ALTER TABLE `app_admin_finance_budget`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_admin_finance_transaction`
--
ALTER TABLE `app_admin_finance_transaction`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_admin_invites`
--
ALTER TABLE `app_admin_invites`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_applicant_profiles`
--
ALTER TABLE `app_applicant_profiles`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_audit_logs`
--
ALTER TABLE `app_audit_logs`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_business_permits`
--
ALTER TABLE `app_business_permits`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_card_registrations`
--
ALTER TABLE `app_card_registrations`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_card_request`
--
ALTER TABLE `app_card_request`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_card_transactions`
--
ALTER TABLE `app_card_transactions`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_cho_sanitary_permit`
--
ALTER TABLE `app_cho_sanitary_permit`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_civil_registry`
--
ALTER TABLE `app_civil_registry`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_civil_registry_marriage`
--
ALTER TABLE `app_civil_registry_marriage`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_claim_logs`
--
ALTER TABLE `app_claim_logs`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_companies`
--
ALTER TABLE `app_companies`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_contact_us`
--
ALTER TABLE `app_contact_us`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_cvl`
--
ALTER TABLE `app_cvl`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_cvl_list`
--
ALTER TABLE `app_cvl_list`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_cvl_locations`
--
ALTER TABLE `app_cvl_locations`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_directory_hospital`
--
ALTER TABLE `app_directory_hospital`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_fb_pages`
--
ALTER TABLE `app_fb_pages`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_feedback`
--
ALTER TABLE `app_feedback`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_incident_report`
--
ALTER TABLE `app_incident_report`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_incident_reports`
--
ALTER TABLE `app_incident_reports`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_item_records`
--
ALTER TABLE `app_item_records`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_item_record_batches`
--
ALTER TABLE `app_item_record_batches`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_job_applications`
--
ALTER TABLE `app_job_applications`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_job_posting`
--
ALTER TABLE `app_job_posting`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_job_postings`
--
ALTER TABLE `app_job_postings`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_job_vacancies_applicant`
--
ALTER TABLE `app_job_vacancies_applicant`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_kyc`
--
ALTER TABLE `app_kyc`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_legal_consultations`
--
ALTER TABLE `app_legal_consultations`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_legal_consultation_history`
--
ALTER TABLE `app_legal_consultation_history`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_lgu_sites`
--
ALTER TABLE `app_lgu_sites`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_locations`
--
ALTER TABLE `app_locations`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_LoginActivity`
--
ALTER TABLE `app_LoginActivity`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_modules`
--
ALTER TABLE `app_modules`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_news_announcement_list`
--
ALTER TABLE `app_news_announcement_list`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_nonvoter_list`
--
ALTER TABLE `app_nonvoter_list`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_notifications`
--
ALTER TABLE `app_notifications`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_notification_logs`
--
ALTER TABLE `app_notification_logs`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_obo_building_permit`
--
ALTER TABLE `app_obo_building_permit`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_osca_activities`
--
ALTER TABLE `app_osca_activities`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_osca_news`
--
ALTER TABLE `app_osca_news`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_osca_registration`
--
ALTER TABLE `app_osca_registration`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_otp`
--
ALTER TABLE `app_otp`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_otp_count`
--
ALTER TABLE `app_otp_count`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_paymongo_sessions`
--
ALTER TABLE `app_paymongo_sessions`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_peso_applications`
--
ALTER TABLE `app_peso_applications`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_peso_applications_assessment`
--
ALTER TABLE `app_peso_applications_assessment`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_peso_applications_attachments`
--
ALTER TABLE `app_peso_applications_attachments`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_peso_applications_education`
--
ALTER TABLE `app_peso_applications_education`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_peso_applications_eligibility`
--
ALTER TABLE `app_peso_applications_eligibility`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_peso_applications_language_proficiency`
--
ALTER TABLE `app_peso_applications_language_proficiency`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_peso_applications_prc_license`
--
ALTER TABLE `app_peso_applications_prc_license`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_peso_applications_preferred_locations`
--
ALTER TABLE `app_peso_applications_preferred_locations`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_peso_applications_preferred_occupations`
--
ALTER TABLE `app_peso_applications_preferred_occupations`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_peso_applications_skills`
--
ALTER TABLE `app_peso_applications_skills`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_peso_applications_skill_catalog`
--
ALTER TABLE `app_peso_applications_skill_catalog`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_peso_applications_training`
--
ALTER TABLE `app_peso_applications_training`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_peso_applications_work_experience`
--
ALTER TABLE `app_peso_applications_work_experience`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_peso_company_profile`
--
ALTER TABLE `app_peso_company_profile`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_peso_jobfair_registration`
--
ALTER TABLE `app_peso_jobfair_registration`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_profile_update_requests`
--
ALTER TABLE `app_profile_update_requests`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_qr_code`
--
ALTER TABLE `app_qr_code`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_results_2025`
--
ALTER TABLE `app_results_2025`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_reviews`
--
ALTER TABLE `app_reviews`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_role`
--
ALTER TABLE `app_role`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_rpt_tax_declaration`
--
ALTER TABLE `app_rpt_tax_declaration`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_service_requests`
--
ALTER TABLE `app_service_requests`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_settings`
--
ALTER TABLE `app_settings`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_sms`
--
ALTER TABLE `app_sms`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_sms_log`
--
ALTER TABLE `app_sms_log`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_social_services`
--
ALTER TABLE `app_social_services`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_social_services_family`
--
ALTER TABLE `app_social_services_family`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_social_services_type`
--
ALTER TABLE `app_social_services_type`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_social_service_schedule_slots`
--
ALTER TABLE `app_social_service_schedule_slots`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_solicitations`
--
ALTER TABLE `app_solicitations`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_solicitation_batches`
--
ALTER TABLE `app_solicitation_batches`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_support_tickets`
--
ALTER TABLE `app_support_tickets`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_theme_dynamic`
--
ALTER TABLE `app_theme_dynamic`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_tourism`
--
ALTER TABLE `app_tourism`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_transactions_history`
--
ALTER TABLE `app_transactions_history`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_transaction_history`
--
ALTER TABLE `app_transaction_history`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_users`
--
ALTER TABLE `app_users`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_users_scanner`
--
ALTER TABLE `app_users_scanner`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_user_operations_tbl`
--
ALTER TABLE `app_user_operations_tbl`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_user_service_toggles`
--
ALTER TABLE `app_user_service_toggles`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_version`
--
ALTER TABLE `app_version`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `auth_group`
--
ALTER TABLE `auth_group`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `auth_group_permissions`
--
ALTER TABLE `auth_group_permissions`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `auth_permission`
--
ALTER TABLE `auth_permission`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `auth_user`
--
ALTER TABLE `auth_user`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `auth_user_groups`
--
ALTER TABLE `auth_user_groups`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `auth_user_user_permissions`
--
ALTER TABLE `auth_user_user_permissions`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `brgy_tbl`
--
ALTER TABLE `brgy_tbl`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business`
--
ALTER TABLE `business`
  MODIFY `id` int(7) UNSIGNED ZEROFILL NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_category`
--
ALTER TABLE `business_category`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_category_sizes`
--
ALTER TABLE `business_category_sizes`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_category_sizes_bus_class`
--
ALTER TABLE `business_category_sizes_bus_class`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_classification`
--
ALTER TABLE `business_classification`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_department_charges`
--
ALTER TABLE `business_department_charges`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_history`
--
ALTER TABLE `business_history`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_images`
--
ALTER TABLE `business_images`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_inspection_assessor`
--
ALTER TABLE `business_inspection_assessor`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_inspection_bfp`
--
ALTER TABLE `business_inspection_bfp`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_inspection_engineering`
--
ALTER TABLE `business_inspection_engineering`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_inspection_menro`
--
ALTER TABLE `business_inspection_menro`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_inspection_sanitary`
--
ALTER TABLE `business_inspection_sanitary`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_inspection_treasury`
--
ALTER TABLE `business_inspection_treasury`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_inspection_zoning`
--
ALTER TABLE `business_inspection_zoning`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_paid_transactions`
--
ALTER TABLE `business_paid_transactions`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_paid_transactions_cancelled`
--
ALTER TABLE `business_paid_transactions_cancelled`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_payment_delivery`
--
ALTER TABLE `business_payment_delivery`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_queuing`
--
ALTER TABLE `business_queuing`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_renewal`
--
ALTER TABLE `business_renewal`
  MODIFY `id` int(7) UNSIGNED ZEROFILL NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_sms_notification`
--
ALTER TABLE `business_sms_notification`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_taxpayers_payment`
--
ALTER TABLE `business_taxpayers_payment`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_taxpayers_payment_fees`
--
ALTER TABLE `business_taxpayers_payment_fees`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_taxpayers_payment_fees_department`
--
ALTER TABLE `business_taxpayers_payment_fees_department`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_tax_history_of_interest_and_surcharge`
--
ALTER TABLE `business_tax_history_of_interest_and_surcharge`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_tax_range`
--
ALTER TABLE `business_tax_range`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_tax_range_bus_class`
--
ALTER TABLE `business_tax_range_bus_class`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_tax_range_old`
--
ALTER TABLE `business_tax_range_old`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `clustered_precinct`
--
ALTER TABLE `clustered_precinct`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `cvl_event_attendance_tbl`
--
ALTER TABLE `cvl_event_attendance_tbl`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `database_backup`
--
ALTER TABLE `database_backup`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `default_location`
--
ALTER TABLE `default_location`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `django_admin_log`
--
ALTER TABLE `django_admin_log`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `django_content_type`
--
ALTER TABLE `django_content_type`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `django_migrations`
--
ALTER TABLE `django_migrations`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `educ_course`
--
ALTER TABLE `educ_course`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `history_business_permit_no`
--
ALTER TABLE `history_business_permit_no`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `leader_structure_tbl`
--
ALTER TABLE `leader_structure_tbl`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `location_data_tbl`
--
ALTER TABLE `location_data_tbl`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `login_history`
--
ALTER TABLE `login_history`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `login_record`
--
ALTER TABLE `login_record`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `medicines`
--
ALTER TABLE `medicines`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `merchant_tbl`
--
ALTER TABLE `merchant_tbl`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `municipal_tbl`
--
ALTER TABLE `municipal_tbl`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `org_tbl`
--
ALTER TABLE `org_tbl`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `peso_applications`
--
ALTER TABLE `peso_applications`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `peso_applications_assessment`
--
ALTER TABLE `peso_applications_assessment`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `peso_applications_education`
--
ALTER TABLE `peso_applications_education`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `peso_applications_eligibility`
--
ALTER TABLE `peso_applications_eligibility`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `peso_applications_language_proficiency`
--
ALTER TABLE `peso_applications_language_proficiency`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `peso_applications_prc_license`
--
ALTER TABLE `peso_applications_prc_license`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `peso_applications_preferred_locations`
--
ALTER TABLE `peso_applications_preferred_locations`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `peso_applications_preferred_occupations`
--
ALTER TABLE `peso_applications_preferred_occupations`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `peso_applications_skill_catalog`
--
ALTER TABLE `peso_applications_skill_catalog`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `peso_applications_training`
--
ALTER TABLE `peso_applications_training`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `peso_applications_work_experience`
--
ALTER TABLE `peso_applications_work_experience`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `philippine_locations`
--
ALTER TABLE `philippine_locations`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `program_tbl`
--
ALTER TABLE `program_tbl`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `ptms_associations`
--
ALTER TABLE `ptms_associations`
  MODIFY `code` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `ptms_banks`
--
ALTER TABLE `ptms_banks`
  MODIFY `code` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `ptms_barangays`
--
ALTER TABLE `ptms_barangays`
  MODIFY `code` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `ptms_billing`
--
ALTER TABLE `ptms_billing`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `ptms_billing_items`
--
ALTER TABLE `ptms_billing_items`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `ptms_business_types`
--
ALTER TABLE `ptms_business_types`
  MODIFY `code` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `ptms_due_dates`
--
ALTER TABLE `ptms_due_dates`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `ptms_fee_types`
--
ALTER TABLE `ptms_fee_types`
  MODIFY `code` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `ptms_revision_fees`
--
ALTER TABLE `ptms_revision_fees`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `ptms_route_areas`
--
ALTER TABLE `ptms_route_areas`
  MODIFY `code` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `ptms_signatories`
--
ALTER TABLE `ptms_signatories`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `ptms_title_setup`
--
ALTER TABLE `ptms_title_setup`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `queuing_table`
--
ALTER TABLE `queuing_table`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `religion_tbl`
--
ALTER TABLE `religion_tbl`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `scanner_users`
--
ALTER TABLE `scanner_users`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `sector_tbl`
--
ALTER TABLE `sector_tbl`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `sms_outbox`
--
ALTER TABLE `sms_outbox`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `social_service_relationship_tbl`
--
ALTER TABLE `social_service_relationship_tbl`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `temp_comelec_tbl`
--
ALTER TABLE `temp_comelec_tbl`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `temp_comelec_tbl_nv`
--
ALTER TABLE `temp_comelec_tbl_nv`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `user_session_tbl`
--
ALTER TABLE `user_session_tbl`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `user_tbl`
--
ALTER TABLE `user_tbl`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `website_table_updates`
--
ALTER TABLE `website_table_updates`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `website_version_tbl`
--
ALTER TABLE `website_version_tbl`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `web_login`
--
ALTER TABLE `web_login`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `app_admin_finance_transaction`
--
ALTER TABLE `app_admin_finance_transaction`
  ADD CONSTRAINT `app_admin_finance_tr_budget_id_e72f4e27_fk_app_admin` FOREIGN KEY (`budget_id`) REFERENCES `app_admin_finance_budget` (`id`);

--
-- Constraints for table `app_cho_sanitary_permit`
--
ALTER TABLE `app_cho_sanitary_permit`
  ADD CONSTRAINT `app_cho_sanitary_permit_user_id_c6945f2a_fk_app_users_id` FOREIGN KEY (`user_id`) REFERENCES `app_users` (`id`);

--
-- Constraints for table `app_cvl`
--
ALTER TABLE `app_cvl`
  ADD CONSTRAINT `app_cvl_card_id_51f87aa8_fk_app_id_qr_container_id` FOREIGN KEY (`card_id`) REFERENCES `app_id_qr_container` (`id`),
  ADD CONSTRAINT `app_cvl_role_id_558b0b1c_fk_app_role_id` FOREIGN KEY (`role_id`) REFERENCES `app_role` (`id`),
  ADD CONSTRAINT `app_cvl_role_upper_id_a06f1454_fk_app_cvl_id` FOREIGN KEY (`role_upper_id`) REFERENCES `app_cvl` (`id`);

--
-- Constraints for table `app_cvl_list`
--
ALTER TABLE `app_cvl_list`
  ADD CONSTRAINT `fk_qrcode` FOREIGN KEY (`cvl_qr`) REFERENCES `app_qr_code` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `app_feedback`
--
ALTER TABLE `app_feedback`
  ADD CONSTRAINT `app_feedback_user_id_57be9fb8_fk_app_users_id` FOREIGN KEY (`user_id`) REFERENCES `app_users` (`id`);

--
-- Constraints for table `app_incident_report`
--
ALTER TABLE `app_incident_report`
  ADD CONSTRAINT `app_incident_report_user_id_52fc8ebb_fk_app_users_id` FOREIGN KEY (`user_id`) REFERENCES `app_users` (`id`);

--
-- Constraints for table `app_item_records`
--
ALTER TABLE `app_item_records`
  ADD CONSTRAINT `fk_item_records_batch` FOREIGN KEY (`batch_id`) REFERENCES `app_item_record_batches` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `app_job_posting`
--
ALTER TABLE `app_job_posting`
  ADD CONSTRAINT `app_job_posting_company_id_82f570ed_fk_app_peso_` FOREIGN KEY (`company_id`) REFERENCES `app_peso_company_profile` (`id`);

--
-- Constraints for table `app_legal_consultation_history`
--
ALTER TABLE `app_legal_consultation_history`
  ADD CONSTRAINT `fk_legal_hist_consult` FOREIGN KEY (`consultation_id`) REFERENCES `app_legal_consultations` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `app_obo_building_permit`
--
ALTER TABLE `app_obo_building_permit`
  ADD CONSTRAINT `app_obo_building_permit_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `app_users` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;

--
-- Constraints for table `app_peso_applications_attachments`
--
ALTER TABLE `app_peso_applications_attachments`
  ADD CONSTRAINT `app_peso_application_application_id_63550fdd_fk_app_peso_` FOREIGN KEY (`application_id`) REFERENCES `app_peso_applications` (`id`);

--
-- Constraints for table `app_solicitations`
--
ALTER TABLE `app_solicitations`
  ADD CONSTRAINT `fk_solicitations_batch` FOREIGN KEY (`batch_id`) REFERENCES `app_solicitation_batches` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `app_users`
--
ALTER TABLE `app_users`
  ADD CONSTRAINT `app_user_card` FOREIGN KEY (`assign_card`) REFERENCES `app_qr_code` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

--
-- Constraints for table `auth_group_permissions`
--
ALTER TABLE `auth_group_permissions`
  ADD CONSTRAINT `auth_group_permissio_permission_id_84c5c92e_fk_auth_perm` FOREIGN KEY (`permission_id`) REFERENCES `auth_permission` (`id`),
  ADD CONSTRAINT `auth_group_permissions_group_id_b120cbf9_fk_auth_group_id` FOREIGN KEY (`group_id`) REFERENCES `auth_group` (`id`);

--
-- Constraints for table `auth_permission`
--
ALTER TABLE `auth_permission`
  ADD CONSTRAINT `auth_permission_content_type_id_2f476e4b_fk_django_co` FOREIGN KEY (`content_type_id`) REFERENCES `django_content_type` (`id`);

--
-- Constraints for table `auth_user_groups`
--
ALTER TABLE `auth_user_groups`
  ADD CONSTRAINT `auth_user_groups_group_id_97559544_fk_auth_group_id` FOREIGN KEY (`group_id`) REFERENCES `auth_group` (`id`),
  ADD CONSTRAINT `auth_user_groups_user_id_6a12ed8b_fk_auth_user_id` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`);

--
-- Constraints for table `auth_user_user_permissions`
--
ALTER TABLE `auth_user_user_permissions`
  ADD CONSTRAINT `auth_user_user_permi_permission_id_1fbb5f2c_fk_auth_perm` FOREIGN KEY (`permission_id`) REFERENCES `auth_permission` (`id`),
  ADD CONSTRAINT `auth_user_user_permissions_user_id_a95ead1b_fk_auth_user_id` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`);

--
-- Constraints for table `django_admin_log`
--
ALTER TABLE `django_admin_log`
  ADD CONSTRAINT `django_admin_log_content_type_id_c4bce8eb_fk_django_co` FOREIGN KEY (`content_type_id`) REFERENCES `django_content_type` (`id`),
  ADD CONSTRAINT `django_admin_log_user_id_c564eba6_fk_auth_user_id` FOREIGN KEY (`user_id`) REFERENCES `auth_user` (`id`);

--
-- Constraints for table `peso_applications_assessment`
--
ALTER TABLE `peso_applications_assessment`
  ADD CONSTRAINT `fk_assess_app` FOREIGN KEY (`application_id`) REFERENCES `peso_applications` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `peso_applications_education`
--
ALTER TABLE `peso_applications_education`
  ADD CONSTRAINT `fk_edu_app` FOREIGN KEY (`application_id`) REFERENCES `peso_applications` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `peso_applications_eligibility`
--
ALTER TABLE `peso_applications_eligibility`
  ADD CONSTRAINT `fk_el_app` FOREIGN KEY (`application_id`) REFERENCES `peso_applications` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `peso_applications_language_proficiency`
--
ALTER TABLE `peso_applications_language_proficiency`
  ADD CONSTRAINT `fk_lang_app` FOREIGN KEY (`application_id`) REFERENCES `peso_applications` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `peso_applications_prc_license`
--
ALTER TABLE `peso_applications_prc_license`
  ADD CONSTRAINT `fk_prc_app` FOREIGN KEY (`application_id`) REFERENCES `peso_applications` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `peso_applications_preferred_locations`
--
ALTER TABLE `peso_applications_preferred_locations`
  ADD CONSTRAINT `fk_loc_app` FOREIGN KEY (`application_id`) REFERENCES `peso_applications` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `peso_applications_preferred_occupations`
--
ALTER TABLE `peso_applications_preferred_occupations`
  ADD CONSTRAINT `fk_occ_app` FOREIGN KEY (`application_id`) REFERENCES `peso_applications` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `peso_applications_skills`
--
ALTER TABLE `peso_applications_skills`
  ADD CONSTRAINT `fk_as_app` FOREIGN KEY (`application_id`) REFERENCES `peso_applications` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_as_skill` FOREIGN KEY (`skill_id`) REFERENCES `peso_applications_skill_catalog` (`id`);

--
-- Constraints for table `peso_applications_training`
--
ALTER TABLE `peso_applications_training`
  ADD CONSTRAINT `fk_tr_app` FOREIGN KEY (`application_id`) REFERENCES `peso_applications` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `peso_applications_work_experience`
--
ALTER TABLE `peso_applications_work_experience`
  ADD CONSTRAINT `fk_we_app` FOREIGN KEY (`application_id`) REFERENCES `peso_applications` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
