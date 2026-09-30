import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:realunit_wallet/packages/service/debug_auth_service.dart';

part 'debug_auth_state.dart';

class DebugAuthCubit extends Cubit<DebugAuthState> {
  final DebugAuthService _service;

  DebugAuthCubit(DebugAuthService service)
    : _service = service,
      super(
        DebugAuthState(
          address: service.savedAddress ?? '',
          savedSignature: service.savedSignature,
        ),
      );

  Future<void> fetchSignMessage(String address) async {
    emit(state.copyWith(address: address, isLoading: true));
    try {
      final message = await _service.fetchSignMessage(address);
      emit(state.copyWith(signMessage: message, isLoading: false));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString(), isLoading: false));
    }
  }

  Future<void> authenticate(String signature) async {
    if (state.signMessage == null) {
      emit(state.copyWith(missingSignMessage: true, isLoading: false));
      return;
    }
    emit(state.copyWith(isLoading: true));
    try {
      await _service.authenticate(
        state.address,
        signature,
        message: state.signMessage!,
      );
      emit(state.copyWith(isAuthenticated: true, isLoading: false));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString(), isLoading: false));
    }
  }
}
