import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/packages/service/debug_auth_service.dart';
import 'package:realunit_wallet/screens/debug_auth/cubit/debug_auth_cubit.dart';

class _MockDebugAuthService extends Mock implements DebugAuthService {}

void main() {
  late _MockDebugAuthService service;

  setUp(() {
    service = _MockDebugAuthService();
    when(() => service.savedAddress).thenReturn(null);
    when(() => service.savedSignature).thenReturn(null);
  });

  group('$DebugAuthCubit', () {
    test('initial state seeds address+savedSignature from the service', () {
      when(() => service.savedAddress).thenReturn('0xabc');
      when(() => service.savedSignature).thenReturn('0xsig');

      final cubit = DebugAuthCubit(service);

      expect(cubit.state.address, '0xabc');
      expect(cubit.state.savedSignature, '0xsig');
      expect(cubit.state.isAuthenticated, isFalse);
      expect(cubit.state.isLoading, isFalse);
    });

    test('initial address falls back to empty string when service has none', () {
      final cubit = DebugAuthCubit(service);

      expect(cubit.state.address, '');
      expect(cubit.state.savedSignature, isNull);
    });

    test('fetchSignMessage stores the message on success', () async {
      when(() => service.fetchSignMessage(any())).thenAnswer((_) async => 'sign this');
      final cubit = DebugAuthCubit(service);

      await cubit.fetchSignMessage('0xnew');

      expect(cubit.state.address, '0xnew');
      expect(cubit.state.signMessage, 'sign this');
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.errorMessage, isNull);
    });

    test('fetchSignMessage captures the error message on failure', () async {
      when(() => service.fetchSignMessage(any())).thenAnswer((_) async => throw Exception('no net'));
      final cubit = DebugAuthCubit(service);

      await cubit.fetchSignMessage('0xnew');

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.errorMessage, contains('no net'));
      expect(cubit.state.signMessage, isNull);
    });

    test('authenticate flips isAuthenticated=true on success and clears any prior error', () async {
      when(() => service.fetchSignMessage(any())).thenAnswer((_) async => 'sign this');
      when(
        () => service.authenticate(any(), any(), message: any(named: 'message')),
      ).thenAnswer((_) async {});
      final cubit = DebugAuthCubit(service);

      await cubit.fetchSignMessage('0xnew');
      await cubit.authenticate('0xsig');

      expect(cubit.state.isAuthenticated, isTrue);
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.errorMessage, isNull);
      verify(() => service.authenticate('0xnew', '0xsig', message: 'sign this')).called(1);
    });

    test('authenticate uses the address currently in state', () async {
      when(() => service.savedAddress).thenReturn('0xfromservice');
      when(() => service.fetchSignMessage(any())).thenAnswer((_) async => 'sign this');
      when(
        () => service.authenticate(any(), any(), message: any(named: 'message')),
      ).thenAnswer((_) async {});
      final cubit = DebugAuthCubit(service);

      await cubit.fetchSignMessage('0xfromservice');
      await cubit.authenticate('0xsig');

      verify(
        () => service.authenticate('0xfromservice', '0xsig', message: 'sign this'),
      ).called(1);
    });

    test('authenticate captures errors and keeps isAuthenticated=false', () async {
      when(() => service.fetchSignMessage(any())).thenAnswer((_) async => 'sign this');
      when(
        () => service.authenticate(any(), any(), message: any(named: 'message')),
      ).thenAnswer((_) async => throw Exception('401'));
      final cubit = DebugAuthCubit(service);

      await cubit.fetchSignMessage('0xnew');
      await cubit.authenticate('0xsig');

      expect(cubit.state.isAuthenticated, isFalse);
      expect(cubit.state.errorMessage, contains('401'));
      verify(() => service.authenticate('0xnew', '0xsig', message: 'sign this')).called(1);
    });

    test('authenticate emits an error when signMessage is null and does not call the service', () async {
      when(
        () => service.authenticate(any(), any(), message: any(named: 'message')),
      ).thenAnswer((_) async {});
      final cubit = DebugAuthCubit(service);

      await cubit.authenticate('0xsig');

      expect(cubit.state.isAuthenticated, isFalse);
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.missingSignMessage, isTrue);
      expect(cubit.state.errorMessage, isNull);
      verifyNever(
        () => service.authenticate(any(), any(), message: any(named: 'message')),
      );
    });
  });
}
