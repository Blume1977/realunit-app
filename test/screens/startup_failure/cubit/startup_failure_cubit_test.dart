import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/screens/startup_failure/cubit/startup_failure_cubit.dart';
import 'package:realunit_wallet/setup/startup/startup_exceptions.dart';

void main() {
  const missingKey = DatabaseKeyMissingException(walletConfigured: true);
  const unreadableKey = DatabaseKeyUnreadableException(
    protectedDataAvailable: null,
  );

  group('StartupFailureCubit initial state', () {
    test('DatabaseKeyMissingException enables reset', () async {
      final cubit = StartupFailureCubit(
        error: missingKey,
        restart: () async {},
        resetWallet: () async {},
      );
      expect(
        cubit.state,
        const StartupFailureState(canResetWallet: true),
      );
      await cubit.close();
    });

    test('DatabaseKeyUnreadableException does not enable reset', () async {
      final cubit = StartupFailureCubit(
        error: unreadableKey,
        restart: () async {},
        resetWallet: () async {},
      );
      expect(
        cubit.state,
        const StartupFailureState(canResetWallet: false),
      );
      await cubit.close();
    });

    test('generic Exception does not enable reset', () async {
      final cubit = StartupFailureCubit(
        error: Exception('boom'),
        restart: () async {},
        resetWallet: () async {},
      );
      expect(
        cubit.state,
        const StartupFailureState(canResetWallet: false),
      );
      await cubit.close();
    });
  });

  group('StartupFailureCubit.retry', () {
    late int restartCalls;
    late List<({Object error, StackTrace? stackTrace})> reports;

    setUp(() {
      restartCalls = 0;
      reports = [];
    });

    blocTest<StartupFailureCubit, StartupFailureState>(
      'success emits busy only and calls restart once',
      build: () => StartupFailureCubit(
        error: Exception('initial'),
        restart: () async {
          restartCalls++;
        },
        resetWallet: () async {},
        report: (_, {stackTrace}) => fail('should not report'),
      ),
      act: (cubit) => cubit.retry(),
      expect: () => [
        const StartupFailureState(canResetWallet: false, isBusy: true),
      ],
      verify: (_) {
        expect(restartCalls, 1);
      },
    );

    blocTest<StartupFailureCubit, StartupFailureState>(
      'same error type failure emits actionFailed and does not report',
      build: () => StartupFailureCubit(
        error: Exception('initial'),
        restart: () async {
          throw Exception('again');
        },
        resetWallet: () async {},
        report: (_, {stackTrace}) => fail('should not report'),
      ),
      act: (cubit) => cubit.retry(),
      expect: () => [
        const StartupFailureState(canResetWallet: false, isBusy: true),
        const StartupFailureState(
          canResetWallet: false,
          actionFailed: true,
        ),
      ],
    );

    blocTest<StartupFailureCubit, StartupFailureState>(
      'different error type is reported and canResetWallet follows new error',
      build: () => StartupFailureCubit(
        error: Exception('initial'),
        restart: () async {
          throw missingKey;
        },
        resetWallet: () async {},
        report: (error, {stackTrace}) {
          reports.add((error: error, stackTrace: stackTrace));
        },
      ),
      act: (cubit) => cubit.retry(),
      expect: () => [
        const StartupFailureState(canResetWallet: false, isBusy: true),
        const StartupFailureState(
          canResetWallet: true,
          actionFailed: true,
        ),
      ],
      verify: (_) {
        expect(reports, hasLength(1));
        expect(reports.single.error, missingKey);
        expect(reports.single.stackTrace, isNotNull);
      },
    );

    blocTest<StartupFailureCubit, StartupFailureState>(
      'different error type turns canResetWallet false',
      build: () => StartupFailureCubit(
        error: missingKey,
        restart: () async {
          throw Exception('other');
        },
        resetWallet: () async {},
        report: (error, {stackTrace}) {
          reports.add((error: error, stackTrace: stackTrace));
        },
      ),
      act: (cubit) => cubit.retry(),
      expect: () => [
        const StartupFailureState(canResetWallet: true, isBusy: true),
        const StartupFailureState(
          canResetWallet: false,
          actionFailed: true,
        ),
      ],
      verify: (_) {
        expect(reports, hasLength(1));
        expect(reports.single.error, isA<Exception>());
        expect(reports.single.stackTrace, isNotNull);
      },
    );

    test('retry while busy is ignored', () async {
      final gate = Completer<void>();
      final cubit = StartupFailureCubit(
        error: Exception('initial'),
        restart: () async {
          restartCalls++;
          await gate.future;
        },
        resetWallet: () async {},
        report: (_, {stackTrace}) => fail('should not report'),
      );

      final first = cubit.retry();
      await cubit.retry();
      gate.complete();
      await first;

      expect(restartCalls, 1);
      await cubit.close();
    });
  });

  group('StartupFailureCubit.resetWallet', () {
    late List<String> callOrder;
    late int restartCalls;
    late List<({Object error, StackTrace? stackTrace})> reports;

    setUp(() {
      callOrder = [];
      restartCalls = 0;
      reports = [];
    });

    blocTest<StartupFailureCubit, StartupFailureState>(
      'success calls reset before restart and emits busy only',
      build: () => StartupFailureCubit(
        error: missingKey,
        restart: () async {
          callOrder.add('restart');
        },
        resetWallet: () async {
          callOrder.add('reset');
        },
        report: (_, {stackTrace}) => fail('should not report'),
      ),
      act: (cubit) => cubit.resetWallet(),
      expect: () => [
        const StartupFailureState(canResetWallet: true, isBusy: true),
      ],
      verify: (_) {
        expect(callOrder, ['reset', 'restart']);
      },
    );

    blocTest<StartupFailureCubit, StartupFailureState>(
      'when canResetWallet is false does nothing',
      build: () => StartupFailureCubit(
        error: Exception('initial'),
        restart: () async => fail('restart should not be called'),
        resetWallet: () async => fail('reset should not be called'),
        report: (_, {stackTrace}) => fail('should not report'),
      ),
      act: (cubit) => cubit.resetWallet(),
      expect: () => <StartupFailureState>[],
    );

    blocTest<StartupFailureCubit, StartupFailureState>(
      'reset step throw keeps canResetWallet, does not restart, and reports',
      build: () => StartupFailureCubit(
        error: missingKey,
        restart: () async {
          restartCalls++;
        },
        resetWallet: () async {
          throw Exception('reset failed');
        },
        report: (error, {stackTrace}) {
          reports.add((error: error, stackTrace: stackTrace));
        },
      ),
      act: (cubit) => cubit.resetWallet(),
      expect: () => [
        const StartupFailureState(canResetWallet: true, isBusy: true),
        const StartupFailureState(
          canResetWallet: true,
          isBusy: false,
          actionFailed: true,
        ),
      ],
      verify: (_) {
        expect(restartCalls, 0);
        expect(reports, hasLength(1));
        expect(reports.single.error, isA<Exception>());
        expect(reports.single.stackTrace, isNotNull);
      },
    );

    test('after a failed reset step a second resetWallet runs reset again', () async {
      var resetCalls = 0;
      final cubit = StartupFailureCubit(
        error: missingKey,
        restart: () async {
          restartCalls++;
        },
        resetWallet: () async {
          resetCalls++;
          throw Exception('reset failed');
        },
        report: (error, {stackTrace}) {
          reports.add((error: error, stackTrace: stackTrace));
        },
      );

      await cubit.resetWallet();
      await cubit.resetWallet();

      expect(resetCalls, 2);
      expect(restartCalls, 0);
      expect(cubit.state.canResetWallet, isTrue);
      await cubit.close();
    });

    test('reset step failures are always reported, even for the same type', () async {
      final cubit = StartupFailureCubit(
        error: missingKey,
        restart: () async {},
        resetWallet: () async {
          throw Exception('reset failed');
        },
        report: (error, {stackTrace}) {
          reports.add((error: error, stackTrace: stackTrace));
        },
      );

      await cubit.resetWallet();
      await cubit.resetWallet();

      expect(reports, hasLength(2));
      expect(reports[0].error, isA<Exception>());
      expect(reports[1].error, isA<Exception>());
      expect(reports[0].stackTrace, isNotNull);
      expect(reports[1].stackTrace, isNotNull);
      await cubit.close();
    });

    test('resetWallet while a retry is busy is ignored', () async {
      final gate = Completer<void>();
      var resetCalls = 0;
      final cubit = StartupFailureCubit(
        error: missingKey,
        restart: () async {
          restartCalls++;
          await gate.future;
        },
        resetWallet: () async {
          resetCalls++;
        },
        report: (_, {stackTrace}) => fail('should not report'),
      );

      final pending = cubit.retry();
      await cubit.resetWallet();
      gate.complete();
      await pending;

      expect(restartCalls, 1);
      expect(resetCalls, 0);
      await cubit.close();
    });

    blocTest<StartupFailureCubit, StartupFailureState>(
      'restart throw after reset emits actionFailed',
      build: () => StartupFailureCubit(
        error: missingKey,
        restart: () async {
          throw Exception('restart failed');
        },
        resetWallet: () async {},
        report: (error, {stackTrace}) {},
      ),
      act: (cubit) => cubit.resetWallet(),
      expect: () => [
        const StartupFailureState(canResetWallet: true, isBusy: true),
        const StartupFailureState(
          canResetWallet: false,
          actionFailed: true,
        ),
      ],
    );

    test('closing while restart is pending then failing does not throw', () async {
      final gate = Completer<void>();
      final cubit = StartupFailureCubit(
        error: Exception('initial'),
        restart: () async {
          await gate.future;
          throw Exception('late failure');
        },
        resetWallet: () async {},
        report: (_, {stackTrace}) {},
      );

      final pending = cubit.retry();
      await cubit.close();
      gate.complete();
      await expectLater(pending, completes);
    });

    test('closing while reset is pending then failing does not throw', () async {
      final gate = Completer<void>();
      final cubit = StartupFailureCubit(
        error: missingKey,
        restart: () async => fail('restart should not be called'),
        resetWallet: () async {
          await gate.future;
          throw Exception('late reset failure');
        },
        report: (_, {stackTrace}) {},
      );

      final pending = cubit.resetWallet();
      await cubit.close();
      gate.complete();
      await expectLater(pending, completes);
    });
  });

  group('StartupFailureState', () {
    test('equality, copyWith and props', () {
      const a = StartupFailureState(canResetWallet: true);
      const b = StartupFailureState(canResetWallet: true);
      const c = StartupFailureState(
        canResetWallet: true,
        isBusy: true,
        actionFailed: true,
      );

      expect(a, b);
      expect(a, isNot(c));
      expect(a.props, [true, false, false]);

      expect(
        a.copyWith(),
        const StartupFailureState(canResetWallet: true),
      );
      expect(
        a.copyWith(isBusy: true),
        const StartupFailureState(canResetWallet: true, isBusy: true),
      );
      expect(
        a.copyWith(actionFailed: true),
        const StartupFailureState(
          canResetWallet: true,
          actionFailed: true,
        ),
      );
      expect(
        a.copyWith(canResetWallet: false),
        const StartupFailureState(canResetWallet: false),
      );
      expect(
        c.copyWith(isBusy: false, actionFailed: false),
        const StartupFailureState(canResetWallet: true),
      );
    });
  });
}
