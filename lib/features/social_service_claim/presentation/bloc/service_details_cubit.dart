import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_service_details.dart';
import 'service_details_state.dart';

class ServiceDetailsCubit extends Cubit<ServiceDetailsState> {
  ServiceDetailsCubit(this._getServiceDetails) : super(const ServiceDetailsState());

  final GetServiceDetails _getServiceDetails;

  Future<void> fetch(String qrCode) async {
    emit(state.copyWith(status: ServiceDetailsStatus.loading));
    try {
      final details = await _getServiceDetails(qrCode);
      emit(state.copyWith(status: ServiceDetailsStatus.loaded, details: details));
    } catch (e) {
      emit(state.copyWith(status: ServiceDetailsStatus.failed, errorMessage: e.toString()));
    }
  }

  void reset() => emit(const ServiceDetailsState());
}
