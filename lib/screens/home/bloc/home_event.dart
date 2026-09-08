part of 'home_bloc.dart';

sealed class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object> get props => [];
}

final class CheckWalletExistsEvent extends HomeEvent {
  const CheckWalletExistsEvent();
}

final class LoadCurrentWalletEvent extends HomeEvent {
  const LoadCurrentWalletEvent();
}

final class DeleteCurrentWalletEvent extends HomeEvent {
  const DeleteCurrentWalletEvent();
}

final class LoadWalletEvent extends HomeEvent {
  const LoadWalletEvent(this.wallet);

  final AWallet wallet;

  @override
  List<Object> get props => [wallet];
}

final class SyncWalletServicesEvent extends HomeEvent {
  const SyncWalletServicesEvent(this.wallet);

  final AWallet wallet;

  @override
  List<Object> get props => [wallet];
}

final class CompleteOnboardingEvent extends HomeEvent {
  const CompleteOnboardingEvent();
}

final class AcceptSoftwareTermsEvent extends HomeEvent {
  const AcceptSoftwareTermsEvent();
}

final class DebugAuthCompleteEvent extends HomeEvent {
  const DebugAuthCompleteEvent({required this.address});

  final String address;

  @override
  List<Object> get props => [address];
}

final class HistorySyncStartedEvent extends HomeEvent {
  const HistorySyncStartedEvent();
}

final class HistorySyncFailedEvent extends HomeEvent {
  const HistorySyncFailedEvent();
}
