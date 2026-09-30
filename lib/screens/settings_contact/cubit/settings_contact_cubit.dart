import 'dart:developer' as developer;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:realunit_wallet/packages/service/dfx/dfx_kyc_service.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/api_exception.dart';
import 'package:realunit_wallet/packages/service/dfx/models/user/dto/user_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_registration_service.dart';

part 'settings_contact_state.dart';

class SettingsContactCubit extends Cubit<SettingsContactState> {
  final DfxKycService _kycService;
  final RealUnitRegistrationService _registrationService;

  SettingsContactCubit({
    required DfxKycService kycService,
    required RealUnitRegistrationService registrationService,
  }) : _kycService = kycService,
       _registrationService = registrationService,
       super(const SettingsContactInitial());

  Future<void> init() async {
    try {
      emit(const SettingsContactLoading());
      final user = await _kycService.getUser();
      String? residenceCountrySymbol;
      try {
        final info = await _registrationService.getRegistrationInfo();
        final trimmed = info.realUnitUserDataDto?.addressCountry.trim();
        if (trimmed != null && trimmed.isNotEmpty) {
          residenceCountrySymbol = trimmed;
        }
      } catch (e) {
        developer.log(e.toString());
      }
      emit(
        SettingsContactSuccess(
          capability: user.capabilities.createSupportTicket,
          residenceCountrySymbol: residenceCountrySymbol,
        ),
      );
    } on ApiException catch (e) {
      developer.log(e.toString());
      emit(SettingsContactFailure(message: e.message));
    } catch (e) {
      developer.log(e.toString());
      emit(SettingsContactFailure(message: e.toString()));
    }
  }
}
