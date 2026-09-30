part of 'settings_contact_cubit.dart';

abstract class SettingsContactState extends Equatable {
  const SettingsContactState();

  @override
  List<Object?> get props => [];
}

class SettingsContactInitial extends SettingsContactState {
  const SettingsContactInitial();
}

class SettingsContactLoading extends SettingsContactState {
  const SettingsContactLoading();
}

class SettingsContactSuccess extends SettingsContactState {
  // Nullable because pre-PR backends do not ship the field. A null
  // capability is a load-bearing signal: callers must treat it as
  // "no information, fall back to a direct push".
  final CreateSupportTicketCapabilityDto? capability;
  final String? residenceCountrySymbol;

  const SettingsContactSuccess({
    this.capability,
    this.residenceCountrySymbol,
  });

  // The DTO is non-Equatable per repo convention, so we decompose its
  // fields manually here. If the API extends
  // `CreateSupportTicketCapabilityDto` with new fields, they MUST be
  // added to this list — otherwise two state instances that differ
  // only by the new field will compare equal and the cubit will skip
  // a UI rebuild.
  @override
  List<Object?> get props => [
    capability?.available,
    capability?.missingPrerequisite,
    residenceCountrySymbol,
  ];
}

class SettingsContactFailure extends SettingsContactState {
  final String message;

  const SettingsContactFailure({required this.message});

  @override
  List<Object?> get props => [message];
}
