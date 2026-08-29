import 'package:equatable/equatable.dart';

/// Fixed list of `app_cvl_list.cvl_secondary_position` enum values — a
/// DB-level enum, so hardcoded here rather than fetched via
/// [CvlFilterOptions].
const List<String> cvlSecondaryPositionOptions = [
  'SUPPORTER',
  'HARD SUPPORTER',
  'OPPONENT',
  'HARD OPPONENT',
  'UNDECIDED',
  'UNKNOWN',
  'DOUBLE ENTRY',
];

/// Fixed list of `cvl_position_code` values, matching `bataan_lgu_admin`'s
/// EMS dropdown — hardcoded rather than fetched via [CvlFilterOptions], the
/// same as [cvlSecondaryPositionOptions]: this is a fixed admin-defined
/// option set, not a free-text column with organically varying values.
const List<String> cvlMajorPositionOptions = [
  'ATR',
  'BECS',
  'D-DAY',
  'KABAKA',
  'R1-POLITICAL',
];

/// Fixed list of `cvl_leader` values, matching `bataan_lgu_admin`'s EMS
/// dropdown — hardcoded for the same reason as [cvlMajorPositionOptions].
const List<String> cvlLeaderTitleOptions = [
  'AREA COORDINATOR',
  'COORDINATOR',
  'DISTRICT COORDINATOR',
  'MAIN COORDINATOR',
  'PRINCIPAL',
  'BARANGAY COORDINATOR',
  'BARANGAY COORDINATOR [CHAIRMAN]',
  'BARANGAY COORDINATOR [KAGAWAD]',
  'CAMPAIGN MANAGER',
  'MEMBERS',
  'MUNICIPAL COORDINATOR',
  'PUROK COORDINATOR',
  'CHIEF OF STAFF',
  'PUROK LEADER',
  'HOUSEHOLD LEADER',
  'POLITICAL CONSULTANT',
  'PRESIDENT',
  'MEMBER',
  'HEAD WATCHER',
  'WATCHER',
];

/// Fixed list of `cvl_sector` values, matching `bataan_lgu_admin`'s EMS
/// dropdown — hardcoded for the same reason as [cvlMajorPositionOptions].
const List<String> cvlSectorOptions = [
  '4Ps',
  'FARMER',
  'FISHERFOLKS',
  'LGBTQIA+',
  'OFW',
  'PWD',
  'SENIOR',
  'SOLO PARENTS',
  'WOMAN',
];

/// A yes/no filter that can also be left unset ("any").
enum TriState { any, yes, no }

/// Filter selection for the "Search CVL Record" flow, passed alongside the
/// name term to `search_cvl_by_name_bataan`. Every field is optional —
/// [isEmpty] is true when none are set, meaning the search relies on the
/// name term alone.
class CvlSearchFilters extends Equatable {
  const CvlSearchFilters({
    this.municipality = '',
    this.barangay = '',
    this.precinct = '',
    this.positionCode = '',
    this.leaderTitle = '',
    this.secondaryPosition = '',
    this.sector = '',
    this.hasPhoto = TriState.any,
    this.hasCard = TriState.any,
  });

  final String municipality;
  final String barangay;
  final String precinct;
  final String positionCode;
  final String leaderTitle;
  final String secondaryPosition;
  final String sector;
  final TriState hasPhoto;
  final TriState hasCard;

  bool get isEmpty =>
      municipality.isEmpty &&
      barangay.isEmpty &&
      precinct.isEmpty &&
      positionCode.isEmpty &&
      leaderTitle.isEmpty &&
      secondaryPosition.isEmpty &&
      sector.isEmpty &&
      hasPhoto == TriState.any &&
      hasCard == TriState.any;

  /// Number of individual filters currently set — shown as a badge on the
  /// filter icon.
  int get activeCount => [
    municipality.isNotEmpty,
    barangay.isNotEmpty,
    precinct.isNotEmpty,
    positionCode.isNotEmpty,
    leaderTitle.isNotEmpty,
    secondaryPosition.isNotEmpty,
    sector.isNotEmpty,
    hasPhoto != TriState.any,
    hasCard != TriState.any,
  ].where((set) => set).length;

  /// Request body fragment for `search_cvl_by_name_bataan` — only
  /// non-default values are included, matching the backend's "empty
  /// means unset" convention.
  Map<String, String> toRequestParams() {
    return {
      if (municipality.isNotEmpty) 'mun': municipality,
      if (barangay.isNotEmpty) 'brgy': barangay,
      if (precinct.isNotEmpty) 'precinct': precinct,
      if (positionCode.isNotEmpty) 'position_code': positionCode,
      if (leaderTitle.isNotEmpty) 'leader': leaderTitle,
      if (secondaryPosition.isNotEmpty) 'secondary_position': secondaryPosition,
      if (sector.isNotEmpty) 'sector': sector,
      if (hasPhoto != TriState.any) 'has_photo': hasPhoto == TriState.yes ? '1' : '0',
      if (hasCard != TriState.any) 'has_card': hasCard == TriState.yes ? '1' : '0',
    };
  }

  CvlSearchFilters copyWith({
    String? municipality,
    String? barangay,
    String? precinct,
    String? positionCode,
    String? leaderTitle,
    String? secondaryPosition,
    String? sector,
    TriState? hasPhoto,
    TriState? hasCard,
  }) {
    return CvlSearchFilters(
      municipality: municipality ?? this.municipality,
      barangay: barangay ?? this.barangay,
      precinct: precinct ?? this.precinct,
      positionCode: positionCode ?? this.positionCode,
      leaderTitle: leaderTitle ?? this.leaderTitle,
      secondaryPosition: secondaryPosition ?? this.secondaryPosition,
      sector: sector ?? this.sector,
      hasPhoto: hasPhoto ?? this.hasPhoto,
      hasCard: hasCard ?? this.hasCard,
    );
  }

  @override
  List<Object?> get props => [
    municipality,
    barangay,
    precinct,
    positionCode,
    leaderTitle,
    secondaryPosition,
    sector,
    hasPhoto,
    hasCard,
  ];
}

/// The dropdown choices for [CvlSearchFilters]'s location filters, as
/// returned by `get_cvl_filter_options_bataan` — each list is that
/// column's distinct, non-empty live values, sorted. Major position,
/// leader title, secondary position, and sector are fixed admin-defined
/// option sets instead (see [cvlMajorPositionOptions] etc.), not fetched
/// here — municipality/barangay/precinct are the only genuinely
/// free-text, organically-varying columns among the filterable fields.
class CvlFilterOptions extends Equatable {
  const CvlFilterOptions({
    this.municipalities = const [],
    this.barangays = const [],
    this.precincts = const [],
  });

  final List<String> municipalities;
  final List<String> barangays;
  final List<String> precincts;

  static List<String> _list(dynamic v) =>
      (v as List<dynamic>? ?? []).map((e) => e.toString()).toList();

  factory CvlFilterOptions.fromJson(Map<String, dynamic> json) {
    return CvlFilterOptions(
      municipalities: _list(json['mun']),
      barangays: _list(json['brgy']),
      precincts: _list(json['precinct']),
    );
  }

  @override
  List<Object?> get props => [municipalities, barangays, precincts];
}
