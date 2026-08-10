import 'package:equatable/equatable.dart';

enum ClaimantType { self, representative }

class ClaimantInfo extends Equatable {
  const ClaimantInfo({
    required this.type,
    this.name = '',
    this.relation = '',
    required this.idType,
    required this.idNumber,
  });

  final ClaimantType type;
  final String name;
  final String relation;
  final String idType;
  final String idNumber;

  ClaimantInfo copyWith({
    ClaimantType? type,
    String? name,
    String? relation,
    String? idType,
    String? idNumber,
  }) {
    return ClaimantInfo(
      type: type ?? this.type,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      idType: idType ?? this.idType,
      idNumber: idNumber ?? this.idNumber,
    );
  }

  @override
  List<Object?> get props => [type, name, relation, idType, idNumber];
}
