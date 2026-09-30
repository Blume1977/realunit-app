import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:realunit_wallet/setup/error_handling/crash_reporting.dart';
import 'package:realunit_wallet/setup/startup/startup_exceptions.dart';

part 'startup_failure_state.dart';

class StartupFailureCubit extends Cubit<StartupFailureState> {
  StartupFailureCubit({
    required Object error,
    required Future<void> Function() restart,
    required Future<void> Function() resetWallet,
    TracedNonFatalReporter report = reportNonFatal,
  }) : _restart = restart,
       _resetWallet = resetWallet,
       _report = report,
       _currentError = error,
       super(
         StartupFailureState(
           canResetWallet: error is DatabaseKeyMissingException,
         ),
       );

  final Future<void> Function() _restart;
  final Future<void> Function() _resetWallet;
  final TracedNonFatalReporter _report;
  Object _currentError;

  Future<void> retry() async {
    if (state.isBusy) return;
    emit(state.copyWith(isBusy: true, actionFailed: false));
    try {
      await _restart();
    } catch (error, stackTrace) {
      _handleFailure(error, stackTrace);
    }
  }

  Future<void> resetWallet() async {
    if (state.isBusy || !state.canResetWallet) return;
    emit(state.copyWith(isBusy: true, actionFailed: false));
    try {
      await _resetWallet();
    } catch (error, stackTrace) {
      _report(error, stackTrace: stackTrace);
      if (!isClosed) emit(state.copyWith(isBusy: false, actionFailed: true));
      return;
    }
    try {
      await _restart();
    } catch (error, stackTrace) {
      _handleFailure(error, stackTrace);
    }
  }

  void _handleFailure(Object error, StackTrace stackTrace) {
    final previousType = _currentError.runtimeType;
    _currentError = error;
    if (error.runtimeType != previousType) {
      _report(error, stackTrace: stackTrace);
    }
    if (!isClosed) {
      emit(
        StartupFailureState(
          canResetWallet: error is DatabaseKeyMissingException,
          actionFailed: true,
        ),
      );
    }
  }
}
