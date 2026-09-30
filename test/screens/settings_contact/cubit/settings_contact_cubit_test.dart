import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/packages/service/dfx/dfx_kyc_service.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/api_exception.dart';
import 'package:realunit_wallet/packages/service/dfx/models/kyc/kyc_level.dart';
import 'package:realunit_wallet/packages/service/dfx/models/registration/kyc/kyc_personal_data.dart';
import 'package:realunit_wallet/packages/service/dfx/models/user/dto/real_unit_user_data_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/user/dto/user_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/wallet/real_unit_registration_info_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/wallet/real_unit_registration_state.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_registration_service.dart';
import 'package:realunit_wallet/screens/settings_contact/cubit/settings_contact_cubit.dart';

class _MockKycService extends Mock implements DfxKycService {}

class _MockRegistrationService extends Mock
    implements RealUnitRegistrationService {}

UserDto _user({
  String? mail,
  CreateSupportTicketCapabilityDto? createSupportTicket,
  bool includeCapabilities = true,
}) {
  return UserDto(
    mail: mail,
    kyc: const UserKycDto(
      hash: 'h',
      level: KycLevel.level10,
      dataComplete: true,
    ),
    capabilities: includeCapabilities
        ? UserCapabilitiesDto(createSupportTicket: createSupportTicket)
        : const UserCapabilitiesDto(),
  );
}

RealUnitUserDataDto buildUserData({
  String addressCountry = 'CH',
  bool swissTaxResidence = true,
}) => RealUnitUserDataDto(
  email: 'a@b.com',
  name: 'Ada Lovelace',
  type: 'HUMAN',
  phoneNumber: '+41 79 000 00 00',
  birthday: '1815-12-10',
  nationality: 'CH',
  addressStreet: 'Bahnhofstrasse 1',
  addressPostalCode: '8000',
  addressCity: 'Zurich',
  addressCountry: addressCountry,
  swissTaxResidence: swissTaxResidence,
  lang: 'de',
  kycData: const KycPersonalData(
    accountType: KycAccountType.personal,
    firstName: 'Ada',
    lastName: 'Lovelace',
    phone: '+41 79 000 00 00',
    address: KycAddress(
      street: 'Bahnhofstrasse',
      zip: '8000',
      city: 'Zurich',
      country: 41,
    ),
  ),
);

void main() {
  late _MockKycService kycService;
  late _MockRegistrationService registrationService;

  setUp(() {
    kycService = _MockKycService();
    registrationService = _MockRegistrationService();
    when(() => registrationService.getRegistrationInfo()).thenAnswer(
      (_) async => RealUnitRegistrationInfoDto(
        state: RealUnitRegistrationState.alreadyRegistered,
      ),
    );
  });

  SettingsContactCubit build() => SettingsContactCubit(
    kycService: kycService,
    registrationService: registrationService,
  );

  group('initial state', () {
    test('emits $SettingsContactInitial', () {
      expect(build().state, isA<SettingsContactInitial>());
    });
  });

  group('init', () {
    blocTest<SettingsContactCubit, SettingsContactState>(
      'user with mail set + capability.available=true → Loading → Success(capability available)',
      setUp: () => when(() => kycService.getUser()).thenAnswer(
        (_) async => _user(
          mail: 'a@b.com',
          createSupportTicket: const CreateSupportTicketCapabilityDto(available: true),
        ),
      ),
      build: build,
      act: (c) => c.init(),
      expect: () => [
        const SettingsContactLoading(),
        isA<SettingsContactSuccess>()
            .having((s) => s.capability, 'capability', isNotNull)
            .having((s) => s.capability!.available, 'available', isTrue)
            .having(
              (s) => s.capability!.missingPrerequisite,
              'missingPrerequisite',
              isNull,
            )
            .having(
              (s) => s.residenceCountrySymbol,
              'residenceCountrySymbol',
              isNull,
            ),
      ],
    );

    blocTest<SettingsContactCubit, SettingsContactState>(
      'user without mail + capability.available=false + Email prerequisite → Success(prerequisite)',
      setUp: () => when(() => kycService.getUser()).thenAnswer(
        (_) async => _user(
          createSupportTicket: const CreateSupportTicketCapabilityDto(
            available: false,
            missingPrerequisite: MissingPrerequisite.email,
          ),
        ),
      ),
      build: build,
      act: (c) => c.init(),
      expect: () => [
        const SettingsContactLoading(),
        isA<SettingsContactSuccess>()
            .having((s) => s.capability!.available, 'available', isFalse)
            .having(
              (s) => s.capability!.missingPrerequisite,
              'missingPrerequisite',
              MissingPrerequisite.email,
            )
            .having(
              (s) => s.residenceCountrySymbol,
              'residenceCountrySymbol',
              isNull,
            ),
      ],
    );

    blocTest<SettingsContactCubit, SettingsContactState>(
      'legacy backend (capability null) → Success(capability: null), graceful fallback',
      setUp: () => when(() => kycService.getUser()).thenAnswer(
        (_) async => _user(mail: 'a@b.com'),
      ),
      build: build,
      act: (c) => c.init(),
      expect: () => [
        const SettingsContactLoading(),
        isA<SettingsContactSuccess>()
            .having((s) => s.capability, 'capability', isNull)
            .having(
              (s) => s.residenceCountrySymbol,
              'residenceCountrySymbol',
              isNull,
            ),
      ],
    );

    blocTest<SettingsContactCubit, SettingsContactState>(
      '$ApiException → Loading → Failure(message)',
      setUp: () => when(() => kycService.getUser()).thenAnswer(
        (_) async => throw const ApiException(
          code: 'WHATEVER',
          message: 'boom',
        ),
      ),
      build: build,
      act: (c) => c.init(),
      expect: () => [
        const SettingsContactLoading(),
        const SettingsContactFailure(message: 'boom'),
      ],
      verify: (_) {
        verifyNever(() => registrationService.getRegistrationInfo());
      },
    );

    blocTest<SettingsContactCubit, SettingsContactState>(
      'generic exception → Failure(toString)',
      setUp: () => when(() => kycService.getUser()).thenAnswer(
        (_) async => throw Exception('socket'),
      ),
      build: build,
      act: (c) => c.init(),
      expect: () => [
        const SettingsContactLoading(),
        isA<SettingsContactFailure>().having(
          (s) => s.message,
          'message',
          contains('socket'),
        ),
      ],
      verify: (_) {
        verifyNever(() => registrationService.getRegistrationInfo());
      },
    );

    blocTest<SettingsContactCubit, SettingsContactState>(
      'address country DE with swissTaxResidence true stores DE',
      setUp: () {
        when(() => kycService.getUser()).thenAnswer(
          (_) async => _user(mail: 'a@b.com'),
        );
        when(() => registrationService.getRegistrationInfo()).thenAnswer(
          (_) async => RealUnitRegistrationInfoDto(
            state: RealUnitRegistrationState.alreadyRegistered,
            realUnitUserDataDto: buildUserData(
              addressCountry: 'DE',
              swissTaxResidence: true,
            ),
          ),
        );
      },
      build: build,
      act: (c) => c.init(),
      expect: () => [
        const SettingsContactLoading(),
        isA<SettingsContactSuccess>().having(
          (s) => s.residenceCountrySymbol,
          'residenceCountrySymbol',
          'DE',
        ),
      ],
    );

    blocTest<SettingsContactCubit, SettingsContactState>(
      'address country CH stores CH',
      setUp: () {
        when(() => kycService.getUser()).thenAnswer(
          (_) async => _user(mail: 'a@b.com'),
        );
        when(() => registrationService.getRegistrationInfo()).thenAnswer(
          (_) async => RealUnitRegistrationInfoDto(
            state: RealUnitRegistrationState.alreadyRegistered,
            realUnitUserDataDto: buildUserData(addressCountry: 'CH'),
          ),
        );
      },
      build: build,
      act: (c) => c.init(),
      expect: () => [
        const SettingsContactLoading(),
        isA<SettingsContactSuccess>().having(
          (s) => s.residenceCountrySymbol,
          'residenceCountrySymbol',
          'CH',
        ),
      ],
    );

    blocTest<SettingsContactCubit, SettingsContactState>(
      'registration $ApiException → Success with null symbol',
      setUp: () {
        when(() => kycService.getUser()).thenAnswer(
          (_) async => _user(
            mail: 'a@b.com',
            createSupportTicket: const CreateSupportTicketCapabilityDto(
              available: true,
            ),
          ),
        );
        when(() => registrationService.getRegistrationInfo()).thenAnswer(
          (_) async => throw const ApiException(
            code: 'WHATEVER',
            message: 'boom',
          ),
        );
      },
      build: build,
      act: (c) => c.init(),
      expect: () => [
        const SettingsContactLoading(),
        isA<SettingsContactSuccess>()
            .having((s) => s.capability, 'capability', isNotNull)
            .having((s) => s.capability!.available, 'available', isTrue)
            .having(
              (s) => s.residenceCountrySymbol,
              'residenceCountrySymbol',
              isNull,
            ),
      ],
    );
  });
}
