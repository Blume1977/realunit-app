import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/screens/startup_failure/cubit/startup_failure_cubit.dart';
import 'package:realunit_wallet/screens/startup_failure/startup_failure_page.dart';

import '../../../helper/helper.dart';

class _MockStartupFailureCubit extends MockCubit<StartupFailureState>
    implements StartupFailureCubit {}

void main() {
  late _MockStartupFailureCubit cubit;

  setUp(() {
    cubit = _MockStartupFailureCubit();

    when(() => cubit.state).thenReturn(
      const StartupFailureState(canResetWallet: false),
    );
    whenListen(
      cubit,
      const Stream<StartupFailureState>.empty(),
      initialState: const StartupFailureState(canResetWallet: false),
    );
    when(() => cubit.retry()).thenAnswer((_) async {});
    when(() => cubit.resetWallet()).thenAnswer((_) async {});
  });

  Widget buildSubject() => wrapForGolden(
        BlocProvider<StartupFailureCubit>.value(
          value: cubit,
          child: const StartupFailurePage(),
        ),
      );

  void stubState(StartupFailureState state) {
    when(() => cubit.state).thenReturn(state);
    whenListen(
      cubit,
      const Stream<StartupFailureState>.empty(),
      initialState: state,
    );
  }

  group('$StartupFailurePage', () {
    goldenTest(
      'retry only when the key is unreadable',
      fileName: 'startup_failure_page_retry',
      constraints: phoneConstraints,
      builder: () {
        stubState(const StartupFailureState(canResetWallet: false));
        return buildSubject();
      },
    );

    goldenTest(
      'reset offered when the key is missing',
      fileName: 'startup_failure_page_key_missing',
      constraints: phoneConstraints,
      builder: () {
        stubState(const StartupFailureState(canResetWallet: true));
        return buildSubject();
      },
    );

    goldenTest(
      'action failed hint on the retry screen',
      fileName: 'startup_failure_page_action_failed',
      constraints: phoneConstraints,
      builder: () {
        stubState(
          const StartupFailureState(
            canResetWallet: false,
            actionFailed: true,
          ),
        );
        return buildSubject();
      },
    );
  });
}
