part of 'startup_failure_cubit.dart';

final class StartupFailureState extends Equatable {
  const StartupFailureState({
    required this.canResetWallet,
    this.isBusy = false,
    this.actionFailed = false,
  });

  final bool canResetWallet;
  final bool isBusy;
  final bool actionFailed;

  StartupFailureState copyWith({
    bool? canResetWallet,
    bool? isBusy,
    bool? actionFailed,
  }) => StartupFailureState(
    canResetWallet: canResetWallet ?? this.canResetWallet,
    isBusy: isBusy ?? this.isBusy,
    actionFailed: actionFailed ?? this.actionFailed,
  );

  @override
  List<Object?> get props => [canResetWallet, isBusy, actionFailed];
}
