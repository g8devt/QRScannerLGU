import 'package:equatable/equatable.dart';

import '../../domain/entities/social_service_details.dart';

enum ServiceDetailsStatus { initial, loading, loaded, failed }

class ServiceDetailsState extends Equatable {
  const ServiceDetailsState({
    this.status = ServiceDetailsStatus.initial,
    this.details,
    this.errorMessage,
  });

  final ServiceDetailsStatus status;
  final SocialServiceDetails? details;
  final String? errorMessage;

  ServiceDetailsState copyWith({
    ServiceDetailsStatus? status,
    SocialServiceDetails? details,
    String? errorMessage,
  }) {
    return ServiceDetailsState(
      status: status ?? this.status,
      details: details ?? this.details,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, details, errorMessage];
}
