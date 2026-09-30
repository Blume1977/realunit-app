// We deliberately use non-const constructors throughout this file so the
// generative constructor lines get counted as executed in the coverage
// report. Const-only construction is a compile-time optimisation and is
// not visible to the line-coverage instrumentation.
// ignore_for_file: prefer_const_constructors
import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/packages/service/dfx/models/user/dto/user_dto.dart';
import 'package:realunit_wallet/screens/settings_contact/cubit/settings_contact_cubit.dart';

void main() {
  group('SettingsContactInitial', () {
    test('two instances are equal and props are empty', () {
      final a = SettingsContactInitial();
      final b = SettingsContactInitial();
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a.props, isEmpty);
    });
  });

  group('SettingsContactLoading', () {
    test('two instances are equal and props are empty', () {
      final a = SettingsContactLoading();
      final b = SettingsContactLoading();
      expect(a, equals(b));
      expect(a.props, isEmpty);
    });
  });

  group('SettingsContactFailure', () {
    test('same message is equal, different message is not', () {
      final a = SettingsContactFailure(message: 'x');
      final b = SettingsContactFailure(message: 'x');
      final c = SettingsContactFailure(message: 'y');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('SettingsContactSuccess', () {
    test('null capability is equal across instances', () {
      // Pre-PR backend path: both Success states carry a null
      // capability. The decomposed props ([null, null, null]) must
      // compare equal.
      final a = SettingsContactSuccess();
      final b = SettingsContactSuccess();
      expect(a, equals(b));
      expect(a.props, [null, null, null]);
    });

    test('different residenceCountrySymbol is unequal', () {
      final a = SettingsContactSuccess(residenceCountrySymbol: 'CH');
      final b = SettingsContactSuccess(residenceCountrySymbol: 'DE');
      expect(a, isNot(equals(b)));
    });

    test('same capability (available true, no prerequisite) is equal', () {
      final a = SettingsContactSuccess(
        capability: CreateSupportTicketCapabilityDto(available: true),
      );
      final b = SettingsContactSuccess(
        capability: CreateSupportTicketCapabilityDto(available: true),
      );
      expect(a, equals(b));
    });

    test('different available flag is unequal', () {
      // The state's `props` decomposes `capability.available` —
      // toggling it must produce inequality.
      final a = SettingsContactSuccess(
        capability: CreateSupportTicketCapabilityDto(available: true),
      );
      final b = SettingsContactSuccess(
        capability: CreateSupportTicketCapabilityDto(available: false),
      );
      expect(a, isNot(equals(b)));
    });

    test('different missingPrerequisite is unequal', () {
      // Same available flag, different prerequisite — must still be
      // unequal so a future enum value with `available: false` flips
      // routing.
      final a = SettingsContactSuccess(
        capability: CreateSupportTicketCapabilityDto(available: false),
      );
      final b = SettingsContactSuccess(
        capability: CreateSupportTicketCapabilityDto(
          available: false,
          missingPrerequisite: MissingPrerequisite.email,
        ),
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('SettingsContactState (cross-subclass identity)', () {
    test('Initial vs Loading vs Failure vs Success are all distinct', () {
      // All inherit a props-empty default; Equatable's runtimeType
      // check keeps them apart.
      final i = SettingsContactInitial();
      final l = SettingsContactLoading();
      final f = SettingsContactFailure(message: 'x');
      final s = SettingsContactSuccess();
      expect(i, isNot(equals(l)));
      expect(l, isNot(equals(f)));
      expect(f, isNot(equals(s)));
      expect(i, isNot(equals(s)));
    });
  });
}
