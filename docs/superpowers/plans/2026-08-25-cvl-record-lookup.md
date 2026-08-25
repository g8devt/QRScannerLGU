# CVL Record Lookup by QR Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scan a QR code and show the matching `app_cvl_list` record's details, or a "no record found" message when the code doesn't match anything.

**Architecture:** A new read-only Lambda endpoint (`find_cvl_by_qr_bataan`) does the `app_cvl_list` ⋈ `app_qr_code` lookup, mirroring the existing PHP `find_cvl_by_qr.php`. A new Flutter feature `cvl_lookup` fetches from it and mirrors `social_service_claim`'s `service_details_*` slice (fetch-on-init cubit → loading/error/loaded states → sectioned detail cards). `ScannerPage` gets a third `ScanPurpose`, `DashboardPage` gets a third tile.

**Tech Stack:** Python 3 (AWS Lambda, PyMySQL `DictCursor`), Flutter/Dart (flutter_bloc, equatable), existing `ApiClient` HTTP envelope.

**Spec:** `docs/superpowers/specs/2026-08-25-cvl-record-lookup-design.md`

## Global Constraints

- Read-only: no QR assignment/edit/removal from the app.
- No new auth mechanism — reuse existing `check_token()` app-token gate, same tier as `get_service_details_bataan` (not in `ADMIN_SESSION_REQUIRED_ENDPOINTS`).
- "Not found" message text: exactly `No CVL record was found for this QR code.` (backend) and shown verbatim in the error view.
- Android only (matches existing `qr_scanner` scope) — no iOS-specific work.
- Follow per-language existing test convention: backend endpoint gets `unittest`/`MagicMock` tests (matches `test_social_services_bataan_claim.py`); the Dart feature gets no new tests (matches `qr_scanner`/`social_service_claim`, neither of which has any).

---

## File Structure

**Backend (`backend/_external_lambdas/UniversalLGU-MainPost/`):**
- Create: `endpoints/cvl_records_bataan.py` — `find_cvl_by_qr_bataan(cur, data, files, ts)`.
- Modify: `lambda_function.py` — import + `ROUTES` entry.
- Create: `tests/test_cvl_records_bataan.py` — unit tests with a mocked cursor.

**Flutter (`lib/`):**
- Create: `features/cvl_lookup/domain/entities/cvl_record.dart`
- Create: `features/cvl_lookup/domain/repositories/cvl_repository.dart`
- Create: `features/cvl_lookup/domain/usecases/find_cvl_by_qr.dart`
- Create: `features/cvl_lookup/data/datasources/cvl_remote_datasource.dart`
- Create: `features/cvl_lookup/data/repositories/cvl_repository_impl.dart`
- Create: `features/cvl_lookup/presentation/bloc/cvl_lookup_state.dart`
- Create: `features/cvl_lookup/presentation/bloc/cvl_lookup_cubit.dart`
- Create: `features/cvl_lookup/presentation/pages/cvl_lookup_page.dart`
- Modify: `features/qr_scanner/presentation/pages/scanner_page.dart` — add `ScanPurpose.cvlLookup`.
- Modify: `features/dashboard/presentation/pages/dashboard_page.dart` — add third tile.
- Modify: `main.dart` — wire up `CvlRemoteDatasource` → `CvlRepositoryImpl` → `FindCvlByQr` → `CvlLookupCubit` in the existing manual DI block.

---

## Task 1: Backend endpoint — `find_cvl_by_qr_bataan`

**Files:**
- Create: `backend/_external_lambdas/UniversalLGU-MainPost/endpoints/cvl_records_bataan.py`
- Test: `backend/_external_lambdas/UniversalLGU-MainPost/tests/test_cvl_records_bataan.py`
- Modify: `backend/_external_lambdas/UniversalLGU-MainPost/lambda_function.py:9` (import), `lambda_function.py` in `ROUTES` dict (new entry, alongside the other `_bataan` entries around line 132-136)

**Interfaces:**
- Produces: `find_cvl_by_qr_bataan(cur, data, files, ts) -> dict` — a Lambda-style `{statusCode, body, headers}` response (via `ok()`/`fail()`). Success body: `{'status': True, 'data': {...serialized row...}}`. Not-found body (404): `{'status': False, 'message': 'No CVL record was found for this QR code.'}`.

- [ ] **Step 1: Write the failing tests**

```python
# backend/_external_lambdas/UniversalLGU-MainPost/tests/test_cvl_records_bataan.py
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from endpoints.cvl_records_bataan import find_cvl_by_qr_bataan


class FindCvlByQrBataanTest(unittest.TestCase):
    def _cur(self, fetchone_return):
        cur = MagicMock()
        cur.fetchone.return_value = fetchone_return
        return cur

    def test_missing_qr_code_returns_400(self):
        cur = self._cur(None)
        result = find_cvl_by_qr_bataan(cur, {}, [], '2026-08-25 00:00:00')
        self.assertEqual(result['statusCode'], 400)

    def test_no_match_returns_404_with_exact_message(self):
        cur = self._cur(None)
        result = find_cvl_by_qr_bataan(cur, {'qr_code': 'QR-99999'}, [], '2026-08-25 00:00:00')
        self.assertEqual(result['statusCode'], 404)
        body = json.loads(result['body'])
        self.assertEqual(body['message'], 'No CVL record was found for this QR code.')

    def test_match_by_full_qr_code_returns_200_with_data(self):
        row = {
            'id': 1, 'cvl_id': 'CVL-0001', 'cvl_fullname': 'Juan Dela Cruz',
            'cvl_fname': 'Juan', 'cvl_mname': '', 'cvl_lname': 'Dela Cruz',
            'cvl_suffix': None, 'cvl_address': '123 Rizal St', 'cvl_mun': 'Balanga',
            'cvl_brgy': 'Poblacion', 'cvl_precinct_no': '0001A',
            'cvl_birthdate': '1990-01-01', 'cvl_contact_no': '09171234567',
            'cvl_email': 'juan@example.com', 'cvl_gender': 'Male',
            'cvl_sector': 'PWD', 'cvl_img_path': None, 'cvl_qr': 42,
            'cvl_qr_code': 'QR-00042',
        }
        cur = self._cur(row)
        result = find_cvl_by_qr_bataan(cur, {'qr_code': 'QR-00042'}, [], '2026-08-25 00:00:00')
        self.assertEqual(result['statusCode'], 200)
        body = json.loads(result['body'])
        self.assertEqual(body['data']['cvl_fullname'], 'Juan Dela Cruz')
        self.assertEqual(body['data']['cvl_qr_code'], 'QR-00042')

    def test_match_by_numeric_id_returns_200(self):
        row = {
            'id': 1, 'cvl_id': 'CVL-0001', 'cvl_fullname': 'Juan Dela Cruz',
            'cvl_fname': 'Juan', 'cvl_mname': '', 'cvl_lname': 'Dela Cruz',
            'cvl_suffix': None, 'cvl_address': '123 Rizal St', 'cvl_mun': 'Balanga',
            'cvl_brgy': 'Poblacion', 'cvl_precinct_no': '0001A',
            'cvl_birthdate': '1990-01-01', 'cvl_contact_no': '09171234567',
            'cvl_email': 'juan@example.com', 'cvl_gender': 'Male',
            'cvl_sector': 'PWD', 'cvl_img_path': None, 'cvl_qr': 42,
            'cvl_qr_code': 'QR-00042',
        }
        cur = self._cur(row)
        result = find_cvl_by_qr_bataan(cur, {'qr_code': '42'}, [], '2026-08-25 00:00:00')
        self.assertEqual(result['statusCode'], 200)

    def test_db_error_returns_500(self):
        cur = MagicMock()
        cur.execute.side_effect = RuntimeError('connection lost')
        result = find_cvl_by_qr_bataan(cur, {'qr_code': 'QR-00042'}, [], '2026-08-25 00:00:00')
        self.assertEqual(result['statusCode'], 500)


if __name__ == '__main__':
    unittest.main()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend/_external_lambdas/UniversalLGU-MainPost && python -m pytest tests/test_cvl_records_bataan.py -v`
Expected: FAIL/ERROR — `ModuleNotFoundError: No module named 'endpoints.cvl_records_bataan'`

- [ ] **Step 3: Write the endpoint implementation**

```python
# backend/_external_lambdas/UniversalLGU-MainPost/endpoints/cvl_records_bataan.py
"""CVL (civil registry / voter list) record lookup by QR code.

Read-only lookup for the scanner app's staff-facing "Check CVL Record"
flow. Mirrors the join and match logic already used by
`bataan_lgu_admin`'s `EMS/api/find_cvl_by_qr.php` (a separate PHP-session
codebase, not called by this app) — `app_cvl_list.cvl_qr` is a foreign key
into `app_qr_code.id`; `app_qr_code.qr_code` holds the human-readable
`QR-xxxxx` string printed/encoded on the physical code.
"""

import logging
import re

from helpers.auth import ok, fail, require
from helpers.db import serialize_row

logger = logging.getLogger()


def _numeric_suffix(value):
    """Strips everything but digits, e.g. 'QR-00042' -> '00042'."""
    return re.sub(r'\D+', '', value)


def find_cvl_by_qr_bataan(cur, data, files, ts):
    """Looks up `app_cvl_list` by a scanned QR value.

    Requires `qr_code` — the raw value decoded off the scanned QR (may be
    the full `QR-xxxxx` string, its bare numeric suffix, or the
    `app_qr_code.id` itself if the scanned value is purely numeric).
    Responds with `{status, data}` on a match, or a 404 `fail(...)` with
    a fixed human-readable message when nothing matches.
    """
    try:
        require(data, 'qr_code')
        raw_value = (data.get('qr_code') or '').strip()
        if not raw_value:
            return fail('Missing qr_code')

        numeric_value = _numeric_suffix(raw_value)
        is_numeric = raw_value.isdigit()
        numeric_id = int(raw_value) if is_numeric else 0

        cur.execute(
            """
            SELECT c.id, c.cvl_id, c.cvl_fullname, c.cvl_fname, c.cvl_mname,
                   c.cvl_lname, c.cvl_suffix, c.cvl_address, c.cvl_mun,
                   c.cvl_brgy, c.cvl_precinct_no, c.cvl_birthdate,
                   c.cvl_contact_no, c.cvl_email, c.cvl_gender, c.cvl_sector,
                   c.cvl_img_path, c.cvl_qr, q.qr_code AS cvl_qr_code
            FROM app_cvl_list c
            INNER JOIN app_qr_code q ON q.id = c.cvl_qr
            WHERE q.qr_code = %s
               OR (%s != '' AND REPLACE(q.qr_code, 'QR-', '') = %s)
               OR (%s = 1 AND q.id = %s)
            LIMIT 1
            """,
            (raw_value, numeric_value, numeric_value, 1 if is_numeric else 0, numeric_id),
        )
        row = cur.fetchone()
        if not row:
            return fail('No CVL record was found for this QR code.', 404)

        return ok({'status': True, 'data': serialize_row(row)})
    except ValueError as e:
        return fail(str(e))
    except Exception as e:
        logger.error(f'find_cvl_by_qr_bataan error: {e}', exc_info=True)
        return fail(f'Server error: {e}', 500)
```

- [ ] **Step 4: Register the route**

In `backend/_external_lambdas/UniversalLGU-MainPost/lambda_function.py`, add the import next to the other `_bataan` imports:

```python
from endpoints import cvl_records_bataan
```

And add to `ROUTES`, next to the other `_bataan` entries:

```python
    'find_cvl_by_qr_bataan': cvl_records_bataan.find_cvl_by_qr_bataan,
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd backend/_external_lambdas/UniversalLGU-MainPost && python -m pytest tests/test_cvl_records_bataan.py -v`
Expected: PASS (5 tests)

- [ ] **Step 6: Commit**

```bash
git add backend/_external_lambdas/UniversalLGU-MainPost/endpoints/cvl_records_bataan.py backend/_external_lambdas/UniversalLGU-MainPost/tests/test_cvl_records_bataan.py backend/_external_lambdas/UniversalLGU-MainPost/lambda_function.py
git commit -m "feat(backend): add find_cvl_by_qr_bataan endpoint"
```

---

## Task 2: Flutter domain layer — entity, repository interface, usecase

**Files:**
- Create: `lib/features/cvl_lookup/domain/entities/cvl_record.dart`
- Create: `lib/features/cvl_lookup/domain/repositories/cvl_repository.dart`
- Create: `lib/features/cvl_lookup/domain/usecases/find_cvl_by_qr.dart`

**Interfaces:**
- Produces: `CvlRecord` (immutable entity, `CvlRecord.fromJson(Map<String, dynamic>)` factory, `fullName` getter — actually `cvlFullname` field is already the full name, see below). `CvlRepository.findByQr(String qrCode) -> Future<CvlRecord>`, throwing `CvlLookupException` on any rejection/network failure. `FindCvlByQr` usecase: `call(String qrCode) -> Future<CvlRecord>`.
- Consumes: nothing (pure domain layer, no dependency on Task 1 beyond the JSON shape it returns — see field list below, matching `serialize_row(row)`'s output for the columns selected in Task 1).

- [ ] **Step 1: Write the entity**

```dart
// lib/features/cvl_lookup/domain/entities/cvl_record.dart
import 'package:equatable/equatable.dart';

/// A single `app_cvl_list` record, resolved via its assigned
/// `app_qr_code` and returned by `find_cvl_by_qr_bataan`.
class CvlRecord extends Equatable {
  const CvlRecord({
    required this.id,
    required this.cvlId,
    required this.fullName,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.suffix,
    required this.address,
    required this.municipality,
    required this.barangay,
    required this.precinctNo,
    required this.birthdate,
    required this.contactNo,
    required this.email,
    required this.gender,
    required this.sector,
    required this.qrCode,
  });

  final int id;
  final String cvlId;
  final String fullName;
  final String firstName;
  final String middleName;
  final String lastName;
  final String suffix;
  final String address;
  final String municipality;
  final String barangay;
  final String precinctNo;
  final String birthdate;
  final String contactNo;
  final String email;
  final String gender;
  final String sector;
  final String qrCode;

  static String _str(dynamic v) => v == null ? '' : v.toString();

  factory CvlRecord.fromJson(Map<String, dynamic> json) {
    return CvlRecord(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      cvlId: _str(json['cvl_id']),
      fullName: _str(json['cvl_fullname']),
      firstName: _str(json['cvl_fname']),
      middleName: _str(json['cvl_mname']),
      lastName: _str(json['cvl_lname']),
      suffix: _str(json['cvl_suffix']),
      address: _str(json['cvl_address']),
      municipality: _str(json['cvl_mun']),
      barangay: _str(json['cvl_brgy']),
      precinctNo: _str(json['cvl_precinct_no']),
      birthdate: _str(json['cvl_birthdate']),
      contactNo: _str(json['cvl_contact_no']),
      email: _str(json['cvl_email']),
      gender: _str(json['cvl_gender']),
      sector: _str(json['cvl_sector']),
      qrCode: _str(json['cvl_qr_code']),
    );
  }

  @override
  List<Object?> get props => [
        id,
        cvlId,
        fullName,
        firstName,
        middleName,
        lastName,
        suffix,
        address,
        municipality,
        barangay,
        precinctNo,
        birthdate,
        contactNo,
        email,
        gender,
        sector,
        qrCode,
      ];
}
```

- [ ] **Step 2: Write the repository interface**

```dart
// lib/features/cvl_lookup/domain/repositories/cvl_repository.dart
import '../entities/cvl_record.dart';

abstract class CvlRepository {
  /// Looks up [qrCode] against the backend. Returns the matching CVL
  /// record. Throws [CvlLookupException] with a human-readable reason
  /// on any rejection (not found) or network failure.
  Future<CvlRecord> findByQr(String qrCode);
}

class CvlLookupException implements Exception {
  CvlLookupException(this.message);
  final String message;
  @override
  String toString() => message;
}
```

- [ ] **Step 3: Write the usecase**

```dart
// lib/features/cvl_lookup/domain/usecases/find_cvl_by_qr.dart
import '../entities/cvl_record.dart';
import '../repositories/cvl_repository.dart';

class FindCvlByQr {
  FindCvlByQr(this._repository);

  final CvlRepository _repository;

  Future<CvlRecord> call(String qrCode) => _repository.findByQr(qrCode);
}
```

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze lib/features/cvl_lookup`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/cvl_lookup/domain
git commit -m "feat(cvl_lookup): add domain layer (entity, repository, usecase)"
```

---

## Task 3: Flutter data layer — remote datasource, repository impl

**Files:**
- Create: `lib/features/cvl_lookup/data/datasources/cvl_remote_datasource.dart`
- Create: `lib/features/cvl_lookup/data/repositories/cvl_repository_impl.dart`

**Interfaces:**
- Consumes: `ApiClient.post(String, Map<String, dynamic>) -> Future<Map<String, dynamic>>` and `ApiException` (both from `lib/core/network/api_client.dart`, existing). `CvlRecord.fromJson` and `CvlRepository`/`CvlLookupException` from Task 2.
- Produces: `CvlRemoteDatasource.findByQr(String qrCode) -> Future<Map<String, dynamic>>` (raw decoded JSON). `CvlRepositoryImpl implements CvlRepository`.

- [ ] **Step 1: Write the remote datasource**

```dart
// lib/features/cvl_lookup/data/datasources/cvl_remote_datasource.dart
import '../../../../core/network/api_client.dart';

/// Talks to `find_cvl_by_qr_bataan`. Returns raw decoded JSON — mapping
/// to the domain entity happens in [CvlRepositoryImpl].
class CvlRemoteDatasource {
  CvlRemoteDatasource(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> findByQr(String qrCode) {
    return _apiClient.post('find_cvl_by_qr_bataan', {'qr_code': qrCode});
  }
}
```

- [ ] **Step 2: Write the repository implementation**

```dart
// lib/features/cvl_lookup/data/repositories/cvl_repository_impl.dart
import '../../../../core/network/api_client.dart';
import '../../domain/entities/cvl_record.dart';
import '../../domain/repositories/cvl_repository.dart';
import '../datasources/cvl_remote_datasource.dart';

class CvlRepositoryImpl implements CvlRepository {
  CvlRepositoryImpl(this._datasource);

  final CvlRemoteDatasource _datasource;

  @override
  Future<CvlRecord> findByQr(String qrCode) async {
    try {
      final json = await _datasource.findByQr(qrCode);
      final data = json['data'] as Map<String, dynamic>? ?? {};
      return CvlRecord.fromJson(data);
    } on ApiException catch (e) {
      throw CvlLookupException(e.message);
    } catch (e) {
      throw CvlLookupException('Network error — could not reach the server: $e');
    }
  }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/features/cvl_lookup`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/cvl_lookup/data
git commit -m "feat(cvl_lookup): add data layer (remote datasource, repository impl)"
```

---

## Task 4: Flutter presentation layer — cubit, state, page

**Files:**
- Create: `lib/features/cvl_lookup/presentation/bloc/cvl_lookup_state.dart`
- Create: `lib/features/cvl_lookup/presentation/bloc/cvl_lookup_cubit.dart`
- Create: `lib/features/cvl_lookup/presentation/pages/cvl_lookup_page.dart`

**Interfaces:**
- Consumes: `FindCvlByQr` (Task 2), `CvlRecord` (Task 2).
- Produces: `CvlLookupStatus` enum (`initial`, `loading`, `loaded`, `failed`), `CvlLookupState`, `CvlLookupCubit` with `fetch(String qrCode)` and `reset()` (mirrors `ServiceDetailsCubit`/`ServiceDetailsState` exactly). `CvlLookupPage({required String rawValue})`.

- [ ] **Step 1: Write the state**

```dart
// lib/features/cvl_lookup/presentation/bloc/cvl_lookup_state.dart
import 'package:equatable/equatable.dart';

import '../../domain/entities/cvl_record.dart';

enum CvlLookupStatus { initial, loading, loaded, failed }

class CvlLookupState extends Equatable {
  const CvlLookupState({
    this.status = CvlLookupStatus.initial,
    this.record,
    this.errorMessage,
  });

  final CvlLookupStatus status;
  final CvlRecord? record;
  final String? errorMessage;

  CvlLookupState copyWith({
    CvlLookupStatus? status,
    CvlRecord? record,
    String? errorMessage,
  }) {
    return CvlLookupState(
      status: status ?? this.status,
      record: record ?? this.record,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, record, errorMessage];
}
```

- [ ] **Step 2: Write the cubit**

```dart
// lib/features/cvl_lookup/presentation/bloc/cvl_lookup_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/find_cvl_by_qr.dart';
import 'cvl_lookup_state.dart';

class CvlLookupCubit extends Cubit<CvlLookupState> {
  CvlLookupCubit(this._findCvlByQr) : super(const CvlLookupState());

  final FindCvlByQr _findCvlByQr;

  Future<void> fetch(String qrCode) async {
    emit(state.copyWith(status: CvlLookupStatus.loading));
    try {
      final record = await _findCvlByQr(qrCode);
      emit(state.copyWith(status: CvlLookupStatus.loaded, record: record));
    } catch (e) {
      emit(state.copyWith(status: CvlLookupStatus.failed, errorMessage: e.toString()));
    }
  }

  void reset() => emit(const CvlLookupState());
}
```

- [ ] **Step 3: Write the page**

```dart
// lib/features/cvl_lookup/presentation/pages/cvl_lookup_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/cvl_record.dart';
import '../bloc/cvl_lookup_cubit.dart';
import '../bloc/cvl_lookup_state.dart';

/// Read-only view of a scanned CVL record, or a "no record found" message
/// when the scanned QR doesn't match anything in `app_cvl_list`.
class CvlLookupPage extends StatefulWidget {
  const CvlLookupPage({super.key, required this.rawValue});

  final String rawValue;

  @override
  State<CvlLookupPage> createState() => _CvlLookupPageState();
}

class _CvlLookupPageState extends State<CvlLookupPage> {
  late final CvlLookupCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<CvlLookupCubit>();
    _cubit.fetch(widget.rawValue);
  }

  @override
  void dispose() {
    _cubit.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(title: const Text('CVL Record')),
        body: BlocBuilder<CvlLookupCubit, CvlLookupState>(
          builder: (context, state) {
            switch (state.status) {
              case CvlLookupStatus.initial:
              case CvlLookupStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case CvlLookupStatus.failed:
                return _ErrorView(message: state.errorMessage ?? 'No record found for this QR code.');
              case CvlLookupStatus.loaded:
                return _DetailsView(record: state.record!);
            }
          },
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 64),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsView extends StatelessWidget {
  const _DetailsView({required this.record});

  final CvlRecord record;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'Identity',
            rows: {
              'Full Name': record.fullName,
              if (record.gender.isNotEmpty) 'Gender': record.gender,
              if (record.birthdate.isNotEmpty) 'Birthdate': record.birthdate,
            },
          ),
          _SectionCard(
            title: 'Location',
            rows: {
              if (record.address.isNotEmpty) 'Address': record.address,
              if (record.barangay.isNotEmpty) 'Barangay': record.barangay,
              if (record.municipality.isNotEmpty) 'Municipality': record.municipality,
              if (record.precinctNo.isNotEmpty) 'Precinct No.': record.precinctNo,
            },
          ),
          _SectionCard(
            title: 'Contact',
            rows: {
              if (record.contactNo.isNotEmpty) 'Contact No.': record.contactNo,
              if (record.email.isNotEmpty) 'Email': record.email,
            },
          ),
          if (record.sector.isNotEmpty)
            _SectionCard(title: 'Sector', rows: {'Sector': record.sector}),
          _SectionCard(
            title: 'QR Code',
            rows: {'Code': record.qrCode},
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Another'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.rows});

  final String title;
  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final entry in rows.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Expanded(child: Text(entry.value)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze lib/features/cvl_lookup`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/cvl_lookup/presentation
git commit -m "feat(cvl_lookup): add presentation layer (cubit, state, page)"
```

---

## Task 5: Wire into ScannerPage, DashboardPage, and main.dart DI

**Files:**
- Modify: `lib/features/qr_scanner/presentation/pages/scanner_page.dart`
- Modify: `lib/features/dashboard/presentation/pages/dashboard_page.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `CvlLookupPage` (Task 4), `CvlLookupCubit` (Task 4), `FindCvlByQr` (Task 2), `CvlRepositoryImpl` (Task 3), `CvlRemoteDatasource` (Task 3).

- [ ] **Step 1: Add the third `ScanPurpose` value and routing**

In `lib/features/qr_scanner/presentation/pages/scanner_page.dart`, add the import and enum value:

```dart
import '../../../cvl_lookup/presentation/pages/cvl_lookup_page.dart';
```

```dart
enum ScanPurpose {
  /// Route into the claim-verification flow (VerifyPage).
  claim,

  /// Route into the read-only application-details view.
  viewDetails,

  /// Route into the read-only CVL record lookup view.
  cvlLookup,
}
```

Update the `listener` in `build()` — replace the ternary with a switch so all three purposes are explicit:

```dart
          listener: (context, state) {
            if (state is ScannerDetected) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => switch (widget.purpose) {
                    ScanPurpose.viewDetails => ServiceDetailsPage(rawValue: state.rawValue),
                    ScanPurpose.cvlLookup => CvlLookupPage(rawValue: state.rawValue),
                    ScanPurpose.claim => VerifyPage(rawValue: state.rawValue),
                  },
                ),
              );
            }
          },
```

Update the top `InfoBanner` text to a switch as well:

```dart
                        child: Text(
                          switch (widget.purpose) {
                            ScanPurpose.viewDetails => 'Scan QR to View Details',
                            ScanPurpose.cvlLookup => 'Scan QR to View CVL Record',
                            ScanPurpose.claim => 'Scan QR to Fetch ID',
                          },
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
```

And the bottom `InfoBanner` text:

```dart
                        child: Text(
                          switch (widget.purpose) {
                            ScanPurpose.viewDetails =>
                              'Align the QR within the frame to view application details.',
                            ScanPurpose.cvlLookup =>
                              'Align the QR within the frame to view the CVL record.',
                            ScanPurpose.claim =>
                              'Align the QR within the frame. After scan, you can capture a verification photo.',
                          },
                        ),
```

- [ ] **Step 2: Add the third dashboard tile**

In `lib/features/dashboard/presentation/pages/dashboard_page.dart`, add after the "View Social Service Details" `Card` (still inside the same `Column`'s `children`):

```dart
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.badge_outlined, size: 32),
                        title: const Text('Check CVL Record'),
                        subtitle: const Text('Scan a QR to view voter record'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ScannerPage(purpose: ScanPurpose.cvlLookup),
                          ),
                        ),
                      ),
                    ),
```

- [ ] **Step 3: Wire DI in `main.dart`**

Add imports:

```dart
import 'features/cvl_lookup/data/datasources/cvl_remote_datasource.dart';
import 'features/cvl_lookup/data/repositories/cvl_repository_impl.dart';
import 'features/cvl_lookup/domain/usecases/find_cvl_by_qr.dart';
import 'features/cvl_lookup/presentation/bloc/cvl_lookup_cubit.dart';
```

In the `Builder` body, after the `getServiceDetails` line:

```dart
          final cvlRemoteDatasource = CvlRemoteDatasource(apiClient);
          final cvlRepository = CvlRepositoryImpl(cvlRemoteDatasource);
          final findCvlByQr = FindCvlByQr(cvlRepository);
```

In `MultiBlocProvider`'s `providers` list, after the `ServiceDetailsCubit` provider:

```dart
                BlocProvider(create: (_) => CvlLookupCubit(findCvlByQr)),
```

- [ ] **Step 4: Verify it compiles and static-analyzes clean**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Verify existing tests still pass**

Run: `flutter test`
Expected: PASS (all existing tests, unaffected by this change)

- [ ] **Step 6: Commit**

```bash
git add lib/features/qr_scanner/presentation/pages/scanner_page.dart lib/features/dashboard/presentation/pages/dashboard_page.dart lib/main.dart
git commit -m "feat(cvl_lookup): wire CVL lookup into scanner, dashboard, and DI"
```

---

## Self-Review Notes

- **Spec coverage:** endpoint (Task 1), Flutter domain/data/presentation layers (Tasks 2-4), scanner/dashboard/DI wiring (Task 5) — all spec sections have a task.
- **Not-found message:** verified identical string (`No CVL record was found for this QR code.`) used in Task 1's backend `fail()` call and asserted in Task 1's test; `CvlLookupPage`'s error view (Task 4) renders whatever `errorMessage` the cubit received from the thrown `CvlLookupException`, which carries that exact backend message through unchanged.
- **Type consistency checked:** `CvlRecord` fields (Task 2) match `CvlRecord.fromJson` keys, which match the `serialize_row()` output of the exact column list selected in Task 1's SQL (`id, cvl_id, cvl_fullname, cvl_fname, cvl_mname, cvl_lname, cvl_suffix, cvl_address, cvl_mun, cvl_brgy, cvl_precinct_no, cvl_birthdate, cvl_contact_no, cvl_email, cvl_gender, cvl_sector, cvl_img_path, cvl_qr, cvl_qr_code`) — `cvl_img_path`/`cvl_qr` are selected but intentionally unused by the entity (not part of the display spec); harmless extra JSON keys. `FindCvlByQr.call` signature matches `CvlLookupCubit.fetch`'s usage. `CvlRepository.findByQr`/`CvlLookupException` names match between the interface (Task 2) and implementation (Task 3).
