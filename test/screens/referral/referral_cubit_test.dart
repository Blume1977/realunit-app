import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/api_exception.dart';
import 'package:realunit_wallet/packages/service/dfx/models/referral/dto/referral_created_invite_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/referral/dto/referral_invite_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/referral/dto/referral_summary_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/referral/dto/referral_terms_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_referral_service.dart';
import 'package:realunit_wallet/screens/referral/cubit/referral_cubit.dart';
import 'package:realunit_wallet/screens/referral/referral_error_message.dart';
import 'package:realunit_wallet/screens/referral/referral_limits.dart';

class _MockService extends Mock implements RealUnitReferralService {}

const _eligible = ReferralSummaryDto(
  eligible: true,
  termsAccepted: true,
  openCount: 1,
  creditedCount: 0,
  realuSum: 0,
  chfSum: 0,
);

const _needsTerms = ReferralSummaryDto(
  eligible: true,
  termsAccepted: false,
  openCount: 0,
  creditedCount: 0,
  realuSum: 0,
  chfSum: 0,
);

void main() {
  late _MockService service;
  late Completer<ReferralSummaryDto> loadRelease;
  late Completer<ReferralSummaryDto> refreshRelease;
  late Completer<List<ReferralInviteDto>> staleInvites;
  late Completer<void> acceptRelease;

  setUp(() {
    service = _MockService();
  });

  blocTest<ReferralCubit, ReferralState>(
    'load emits not-eligible when the API gate is closed',
    build: () {
      when(() => service.getSummary()).thenAnswer(
        (_) async => const ReferralSummaryDto(
          eligible: false,
          termsAccepted: false,
          openCount: 0,
          creditedCount: 0,
          realuSum: 0,
          chfSum: 0,
        ),
      );
      return ReferralCubit(service);
    },
    act: (cubit) => cubit.load(),
    expect: () => const [
      ReferralLoading(),
      ReferralNotEligible(),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'load emits needs-terms when eligible but terms are not accepted',
    build: () {
      when(() => service.getSummary()).thenAnswer((_) async => _needsTerms);
      return ReferralCubit(service);
    },
    act: (cubit) => cubit.load(),
    expect: () => [
      const ReferralLoading(),
      const ReferralNeedsTerms(summary: _needsTerms),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'load emits overview when eligible and terms accepted',
    build: () {
      when(() => service.getSummary()).thenAnswer((_) async => _eligible);
      when(() => service.getInvites()).thenAnswer((_) async => []);
      return ReferralCubit(service);
    },
    act: (cubit) => cubit.load(),
    expect: () => [
      const ReferralLoading(),
      const ReferralOverviewLoaded(summary: _eligible, invites: []),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'load does not emit after the cubit is closed mid-flight',
    build: () {
      loadRelease = Completer<ReferralSummaryDto>();
      when(() => service.getSummary()).thenAnswer((_) => loadRelease.future);
      return ReferralCubit(service);
    },
    act: (cubit) async {
      final pending = cubit.load();
      await cubit.close();
      loadRelease.complete(_eligible);
      await pending;
    },
    // Only the synchronous Loading survives: the post-await emit is guarded by
    // `isClosed`, so no ReferralOverviewLoaded is emitted after close (and
    // no emit-after-close StateError is thrown).
    expect: () => const [
      ReferralLoading(),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'acceptTerms posts acceptance then loads overview',
    build: () {
      when(() => service.acceptTerms(version: any(named: 'version'))).thenAnswer((_) async {});
      when(() => service.getSummary()).thenAnswer((_) async => _eligible);
      when(() => service.getInvites()).thenAnswer((_) async => []);
      return ReferralCubit(service);
    },
    seed: () => const ReferralNeedsTerms(summary: _needsTerms),
    act: (cubit) => cubit.acceptTerms(version: '2026-09-01'),
    expect: () => [
      const ReferralTermsAccepting(summary: _needsTerms),
      const ReferralOverviewLoaded(summary: _eligible, invites: []),
    ],
    verify: (_) {
      verify(() => service.acceptTerms(version: '2026-09-01')).called(1);
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'acceptTerms returns to the checkbox with the API error',
    build: () {
      when(() => service.acceptTerms(version: any(named: 'version'))).thenThrow(
        const ApiException(code: 'FAILED', message: 'nope'),
      );
      return ReferralCubit(service);
    },
    seed: () => const ReferralNeedsTerms(summary: _needsTerms),
    act: (cubit) => cubit.acceptTerms(),
    expect: () => [
      const ReferralTermsAccepting(summary: _needsTerms),
      const ReferralNeedsTerms(
        summary: _needsTerms,
        errorMessage: referralUnavailableMessage,
      ),
    ],
    verify: (_) {
      verify(
        () => service.acceptTerms(version: ReferralTermsDto.bundledVersion),
      ).called(1);
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'acceptTerms keeps the previous error while the retry PUT is in flight',
    build: () {
      when(() => service.acceptTerms(version: any(named: 'version'))).thenAnswer((_) async {});
      when(() => service.getSummary()).thenAnswer((_) async => _eligible);
      when(() => service.getInvites()).thenAnswer((_) async => []);
      return ReferralCubit(service);
    },
    seed: () => const ReferralNeedsTerms(summary: _needsTerms, errorMessage: 'nope'),
    act: (cubit) => cubit.acceptTerms(),
    expect: () => [
      const ReferralTermsAccepting(summary: _needsTerms, errorMessage: 'nope'),
      const ReferralOverviewLoaded(summary: _eligible, invites: []),
    ],
    verify: (_) {
      verify(
        () => service.acceptTerms(version: ReferralTermsDto.bundledVersion),
      ).called(1);
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'acceptTerms ignores a second call while the PUT is in flight',
    build: () {
      acceptRelease = Completer<void>();
      when(
        () => service.acceptTerms(version: any(named: 'version')),
      ).thenAnswer((_) => acceptRelease.future);
      when(() => service.getSummary()).thenAnswer((_) async => _eligible);
      when(() => service.getInvites()).thenAnswer((_) async => []);
      return ReferralCubit(service);
    },
    seed: () => const ReferralNeedsTerms(summary: _needsTerms),
    act: (cubit) async {
      final first = cubit.acceptTerms();
      final second = cubit.acceptTerms();
      acceptRelease.complete();
      await first;
      await second;
    },
    verify: (_) {
      verify(
        () => service.acceptTerms(version: ReferralTermsDto.bundledVersion),
      ).called(1);
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'refreshOverview reloads counts after a new invite',
    build: () {
      when(() => service.getSummary()).thenAnswer((_) async => _eligible);
      when(() => service.getInvites()).thenAnswer((_) async => []);
      return ReferralCubit(service);
    },
    seed: () => const ReferralInviteCreated(
      summary: _eligible,
      invite: ReferralCreatedInviteDto(
        code: 'AB12',
        url: 'https://realunit.app/invite/AB12',
        guestName: 'Alice',
      ),
    ),
    act: (cubit) => cubit.refreshOverview(),
    expect: () => [
      const ReferralOverviewLoaded(summary: _eligible, invites: []),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'refreshOverview ignores a second call while summary is in flight',
    build: () {
      refreshRelease = Completer<ReferralSummaryDto>();
      when(() => service.getSummary()).thenAnswer((_) => refreshRelease.future);
      when(() => service.getInvites()).thenAnswer((_) async => []);
      return ReferralCubit(service);
    },
    seed: () => const ReferralInviteCreated(
      summary: _eligible,
      invite: ReferralCreatedInviteDto(
        code: 'AB12',
        url: 'https://realunit.app/invite/AB12',
        guestName: 'Alice',
      ),
    ),
    act: (cubit) async {
      final first = cubit.refreshOverview();
      final second = cubit.refreshOverview();
      refreshRelease.complete(_eligible);
      await first;
      await second;
    },
    expect: () => [
      const ReferralOverviewLoaded(summary: _eligible, invites: []),
    ],
    verify: (_) {
      verify(() => service.getSummary()).called(1);
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'refreshOverview keeps overview tiles when the summary call fails',
    build: () {
      when(() => service.getSummary()).thenThrow(
        const ApiException(code: 'SERVER_ERROR', message: 'down'),
      );
      return ReferralCubit(service);
    },
    seed: () => const ReferralOverviewLoaded(summary: _eligible, invites: []),
    act: (cubit) => cubit.refreshOverview(),
    expect: () => <ReferralState>[],
  );

  blocTest<ReferralCubit, ReferralState>(
    'createInvite emits the created invite from the API',
    build: () {
      when(() => service.createInvite(guestName: 'Alice', idempotencyKey: any(named: 'idempotencyKey'))).thenAnswer(
        (_) async => const ReferralCreatedInviteDto(
          code: 'AB12',
          url: 'https://realunit.app/invite/AB12',
          guestName: 'Alice',
        ),
      );
      return ReferralCubit(service);
    },
    seed: () => const ReferralCreateReady(summary: _eligible),
    act: (cubit) => cubit.createInvite(guestName: 'Alice'),
    expect: () => [
      const ReferralCreating(summary: _eligible, guestName: 'Alice'),
      const ReferralInviteCreated(
        summary: _eligible,
        invite: ReferralCreatedInviteDto(
          code: 'AB12',
          url: 'https://realunit.app/invite/AB12',
          guestName: 'Alice',
        ),
      ),
    ],
  );

  test('createInvite mints a fresh idempotency key when the name changes', () async {
    when(
      () => service.createInvite(
        guestName: any(named: 'guestName'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenThrow(const ApiException(code: 'FAILED', message: 'boom'));
    final cubit = ReferralCubit(service);
    cubit.emit(const ReferralCreateReady(summary: _eligible));

    await cubit.createInvite(guestName: 'Alice');
    await cubit.createInvite(guestName: 'Alice');
    await cubit.createInvite(guestName: 'Bob');

    final keys = verify(
      () => service.createInvite(
        guestName: any(named: 'guestName'),
        idempotencyKey: captureAny(named: 'idempotencyKey'),
      ),
    ).captured.cast<String?>();

    // A retry for the same name must reuse the key so the server can dedupe,
    // but a different name must never travel under the previous name's key.
    expect(keys, hasLength(3));
    expect(keys[0], keys[1]);
    expect(keys[2], isNot(keys[0]));
    await cubit.close();
  });

  blocTest<ReferralCubit, ReferralState>(
    'createInvite maps NOT_ELIGIBLE to the gate screen',
    build: () {
      when(() => service.createInvite(guestName: 'Alice', idempotencyKey: any(named: 'idempotencyKey'))).thenThrow(
        const ApiException(
          statusCode: 403,
          code: 'NOT_ELIGIBLE',
          message: 'holding below min',
        ),
      );
      return ReferralCubit(service);
    },
    seed: () => const ReferralCreateReady(summary: _eligible),
    act: (cubit) => cubit.createInvite(guestName: 'Alice'),
    expect: () => [
      const ReferralCreating(summary: _eligible, guestName: 'Alice'),
      const ReferralNotEligible(),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'createInvite maps NEEDS_TERMS to the terms screen',
    build: () {
      when(() => service.createInvite(guestName: 'Alice', idempotencyKey: any(named: 'idempotencyKey'))).thenThrow(
        const ApiException(
          statusCode: 409,
          code: 'NEEDS_TERMS',
          message: 'terms not accepted',
        ),
      );
      return ReferralCubit(service);
    },
    seed: () => const ReferralCreateReady(summary: _eligible),
    act: (cubit) => cubit.createInvite(guestName: 'Alice'),
    expect: () => [
      const ReferralCreating(summary: _eligible, guestName: 'Alice'),
      const ReferralNeedsTerms(summary: _eligible),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'createInvite surfaces the API error on the name-entry form',
    build: () {
      when(() => service.createInvite(guestName: 'Alice', idempotencyKey: any(named: 'idempotencyKey'))).thenThrow(
        const ApiException(code: 'QUOTA', message: 'limit'),
      );
      return ReferralCubit(service);
    },
    seed: () => const ReferralCreateReady(summary: _eligible),
    act: (cubit) => cubit.createInvite(guestName: 'Alice'),
    expect: () => [
      const ReferralCreating(summary: _eligible, guestName: 'Alice'),
      const ReferralCreateReady(
        summary: _eligible,
        errorMessage: referralQuotaMessage,
      ),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'createInvite maps 503 holding lookup failed to the unavailable token',
    build: () {
      when(() => service.createInvite(guestName: 'Alice', idempotencyKey: any(named: 'idempotencyKey'))).thenThrow(
        const ApiException(
          statusCode: 503,
          code: 'UNAVAILABLE',
          message: 'holding lookup failed',
        ),
      );
      return ReferralCubit(service);
    },
    seed: () => const ReferralCreateReady(summary: _eligible),
    act: (cubit) => cubit.createInvite(guestName: 'Alice'),
    expect: () => [
      const ReferralCreating(summary: _eligible, guestName: 'Alice'),
      const ReferralCreateReady(
        summary: _eligible,
        errorMessage: referralUnavailableMessage,
      ),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'createInvite keeps the previous error while the retry POST is in flight',
    build: () {
      when(() => service.createInvite(guestName: 'Alice', idempotencyKey: any(named: 'idempotencyKey'))).thenAnswer(
        (_) async => const ReferralCreatedInviteDto(
          code: 'AB12',
          url: 'https://realunit.app/invite/AB12',
          guestName: 'Alice',
        ),
      );
      return ReferralCubit(service);
    },
    seed: () => const ReferralCreateReady(summary: _eligible, errorMessage: 'limit'),
    act: (cubit) => cubit.createInvite(guestName: 'Alice'),
    expect: () => [
      const ReferralCreating(
        summary: _eligible,
        guestName: 'Alice',
        errorMessage: 'limit',
      ),
      const ReferralInviteCreated(
        summary: _eligible,
        invite: ReferralCreatedInviteDto(
          code: 'AB12',
          url: 'https://realunit.app/invite/AB12',
          guestName: 'Alice',
        ),
      ),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'openCreate moves from overview to the name-entry form',
    build: () => ReferralCubit(service),
    seed: () => const ReferralOverviewLoaded(summary: _eligible, invites: []),
    act: (cubit) => cubit.openCreate(),
    expect: () => [
      const ReferralCreateReady(summary: _eligible),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'openCreate moves from a created invite back to the name-entry form',
    build: () => ReferralCubit(service),
    seed: () => const ReferralInviteCreated(
      summary: _eligible,
      invite: ReferralCreatedInviteDto(
        code: 'AB12',
        url: 'https://realunit.app/invite/AB12',
        guestName: 'Alice',
      ),
    ),
    act: (cubit) => cubit.openCreate(),
    expect: () => [
      const ReferralCreateReady(summary: _eligible),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'acceptTerms still shows overview when the invite list is down',
    build: () {
      when(() => service.acceptTerms(version: any(named: 'version'))).thenAnswer((_) async {});
      when(() => service.getSummary()).thenAnswer((_) async => _eligible);
      when(() => service.getInvites()).thenThrow(
        const ApiException(code: 'SERVER_ERROR', message: 'invites down'),
      );
      return ReferralCubit(service);
    },
    seed: () => const ReferralNeedsTerms(summary: _needsTerms),
    act: (cubit) => cubit.acceptTerms(),
    expect: () => [
      const ReferralTermsAccepting(summary: _needsTerms),
      const ReferralOverviewLoaded(
        summary: _eligible,
        invites: [],
        invitesError: referralUnavailableMessage,
      ),
    ],
    verify: (_) {
      verify(
        () => service.acceptTerms(version: ReferralTermsDto.bundledVersion),
      ).called(1);
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'load shows overview counts when the invite list is down',
    build: () {
      when(() => service.getSummary()).thenAnswer((_) async => _eligible);
      when(() => service.getInvites()).thenThrow(
        const ApiException(code: 'SERVER_ERROR', message: 'invites down'),
      );
      return ReferralCubit(service);
    },
    act: (cubit) => cubit.load(),
    expect: () => [
      const ReferralLoading(),
      const ReferralOverviewLoaded(
        summary: _eligible,
        invites: [],
        invitesError: referralUnavailableMessage,
      ),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'reloadInvites replaces open-invite rows without hiding the summary',
    build: () {
      when(() => service.getInvites()).thenAnswer(
        (_) async => [
          ReferralInviteDto(
            id: 1,
            code: 'AAAA',
            url: 'https://realunit.app/invite/AAAA',
            guestName: 'Alice',
            status: 'Open',
            created: DateTime.utc(2026, 8, 1),
          ),
        ],
      );
      return ReferralCubit(service);
    },
    seed: () => const ReferralOverviewLoaded(summary: _eligible, invites: []),
    act: (cubit) => cubit.reloadInvites(),
    expect: () => [
      const ReferralOverviewLoaded(
        summary: _eligible,
        invites: [],
        invitesLoading: true,
      ),
      ReferralOverviewLoaded(
        summary: _eligible,
        invites: [
          ReferralInviteDto(
            id: 1,
            code: 'AAAA',
            url: 'https://realunit.app/invite/AAAA',
            guestName: 'Alice',
            status: 'Open',
            created: DateTime.utc(2026, 8, 1),
          ),
        ],
      ),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'reloadInvites keeps the current overview when the list is still down',
    build: () {
      when(() => service.getInvites()).thenThrow(
        const ApiException(code: 'SERVER_ERROR', message: 'invites down'),
      );
      return ReferralCubit(service);
    },
    seed: () => const ReferralOverviewLoaded(summary: _eligible, invites: []),
    act: (cubit) => cubit.reloadInvites(),
    expect: () => [
      const ReferralOverviewLoaded(
        summary: _eligible,
        invites: [],
        invitesLoading: true,
      ),
      const ReferralOverviewLoaded(
        summary: _eligible,
        invites: [],
        invitesError: referralUnavailableMessage,
      ),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'reloadInvites keeps a previous list error while the retry is in flight',
    build: () {
      when(() => service.getInvites()).thenAnswer((_) async => const []);
      return ReferralCubit(service);
    },
    seed: () => const ReferralOverviewLoaded(
      summary: _eligible,
      invites: [],
      invitesError: 'invites down',
    ),
    act: (cubit) => cubit.reloadInvites(),
    expect: () => [
      const ReferralOverviewLoaded(
        summary: _eligible,
        invites: [],
        invitesError: 'invites down',
        invitesLoading: true,
      ),
      const ReferralOverviewLoaded(summary: _eligible, invites: []),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'reloadInvites ignores a call while overview refresh is in flight',
    build: () {
      refreshRelease = Completer<ReferralSummaryDto>();
      when(() => service.getSummary()).thenAnswer((_) => refreshRelease.future);
      when(() => service.getInvites()).thenAnswer((_) async => []);
      return ReferralCubit(service);
    },
    seed: () => const ReferralOverviewLoaded(summary: _eligible, invites: []),
    act: (cubit) async {
      final refresh = cubit.refreshOverview();
      final reload = cubit.reloadInvites();
      refreshRelease.complete(_eligible);
      await refresh;
      await reload;
    },
    verify: (_) {
      verify(() => service.getInvites()).called(1);
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'reloadInvites discards a stale list after a later overview refresh',
    build: () {
      staleInvites = Completer<List<ReferralInviteDto>>();
      var inviteCalls = 0;
      when(() => service.getInvites()).thenAnswer((_) {
        inviteCalls += 1;
        if (inviteCalls == 1) return staleInvites.future;
        return Future<List<ReferralInviteDto>>.value(const []);
      });
      when(() => service.getSummary()).thenAnswer((_) async => _eligible);
      return ReferralCubit(service);
    },
    seed: () => const ReferralOverviewLoaded(summary: _eligible, invites: []),
    act: (cubit) async {
      final reload = cubit.reloadInvites();
      final refresh = cubit.refreshOverview();
      await refresh;
      staleInvites.complete([
        ReferralInviteDto(
          id: 9,
          code: 'STALE',
          url: 'https://realunit.app/invite/STALE',
          guestName: 'Old',
          status: 'Open',
          created: DateTime.utc(2026, 8, 1),
        ),
      ]);
      await reload;
    },
    expect: () => [
      const ReferralOverviewLoaded(
        summary: _eligible,
        invites: [],
        invitesLoading: true,
      ),
      const ReferralOverviewLoaded(summary: _eligible, invites: []),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'refreshOverview returns to terms when the API withdraws acceptance',
    build: () {
      when(() => service.getSummary()).thenAnswer((_) async => _needsTerms);
      return ReferralCubit(service);
    },
    seed: () => const ReferralOverviewLoaded(summary: _eligible, invites: []),
    act: (cubit) => cubit.refreshOverview(),
    expect: () => [
      const ReferralNeedsTerms(summary: _needsTerms),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'acceptTerms hides the programme when the refreshed gate is closed',
    build: () {
      when(() => service.acceptTerms(version: any(named: 'version'))).thenAnswer((_) async {});
      when(() => service.getSummary()).thenAnswer(
        (_) async => const ReferralSummaryDto(
          eligible: false,
          termsAccepted: true,
          openCount: 0,
          creditedCount: 0,
          realuSum: 0,
          chfSum: 0,
        ),
      );
      return ReferralCubit(service);
    },
    seed: () => const ReferralNeedsTerms(summary: _needsTerms),
    act: (cubit) => cubit.acceptTerms(),
    expect: () => [
      const ReferralTermsAccepting(summary: _needsTerms),
      const ReferralNotEligible(),
    ],
    verify: (_) {
      verify(
        () => service.acceptTerms(version: ReferralTermsDto.bundledVersion),
      ).called(1);
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'refreshOverview hides the programme when the API gate closes',
    build: () {
      when(() => service.getSummary()).thenAnswer(
        (_) async => const ReferralSummaryDto(
          eligible: false,
          termsAccepted: true,
          openCount: 0,
          creditedCount: 0,
          realuSum: 0,
          chfSum: 0,
        ),
      );
      return ReferralCubit(service);
    },
    seed: () => const ReferralOverviewLoaded(summary: _eligible, invites: []),
    act: (cubit) => cubit.refreshOverview(),
    expect: () => const [ReferralNotEligible()],
  );

  blocTest<ReferralCubit, ReferralState>(
    'createInvite truncates a guest name to the field cap',
    build: () {
      when(
        () => service.createInvite(
          guestName: 'A' * maxReferralGuestNameLength,
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => ReferralCreatedInviteDto(
          code: 'AB12',
          url: 'https://realunit.app/invite/AB12',
          guestName: 'A' * maxReferralGuestNameLength,
        ),
      );
      return ReferralCubit(service);
    },
    seed: () => const ReferralCreateReady(summary: _eligible),
    act: (cubit) => cubit.createInvite(guestName: 'A' * 120),
    expect: () => [
      ReferralCreating(
        summary: _eligible,
        guestName: 'A' * maxReferralGuestNameLength,
      ),
      ReferralInviteCreated(
        summary: _eligible,
        invite: ReferralCreatedInviteDto(
          code: 'AB12',
          url: 'https://realunit.app/invite/AB12',
          guestName: 'A' * maxReferralGuestNameLength,
        ),
      ),
    ],
    verify: (_) {
      verify(
        () => service.createInvite(
          guestName: 'A' * maxReferralGuestNameLength,
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).called(1);
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'createInvite collapses newlines in the guest name to a single line',
    build: () {
      when(() => service.createInvite(guestName: 'Alice Bob', idempotencyKey: any(named: 'idempotencyKey'))).thenAnswer(
        (_) async => const ReferralCreatedInviteDto(
          code: 'AB12',
          url: 'https://realunit.app/invite/AB12',
          guestName: 'Alice Bob',
        ),
      );
      return ReferralCubit(service);
    },
    seed: () => const ReferralCreateReady(summary: _eligible),
    act: (cubit) => cubit.createInvite(guestName: ' Alice\nBob\t '),
    expect: () => [
      const ReferralCreating(summary: _eligible, guestName: 'Alice Bob'),
      const ReferralInviteCreated(
        summary: _eligible,
        invite: ReferralCreatedInviteDto(
          code: 'AB12',
          url: 'https://realunit.app/invite/AB12',
          guestName: 'Alice Bob',
        ),
      ),
    ],
    verify: (_) {
      verify(() => service.createInvite(guestName: 'Alice Bob', idempotencyKey: any(named: 'idempotencyKey'))).called(1);
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'createInvite ignores a blank guest name',
    build: () => ReferralCubit(service),
    seed: () => const ReferralCreateReady(summary: _eligible),
    act: (cubit) => cubit.createInvite(guestName: '   '),
    expect: () => <ReferralState>[],
    verify: (_) {
      verifyNever(() => service.createInvite(guestName: any(named: 'guestName')));
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'load ignores a second call while summary is in flight',
    build: () {
      loadRelease = Completer<ReferralSummaryDto>();
      when(() => service.getSummary()).thenAnswer((_) => loadRelease.future);
      when(() => service.getInvites()).thenAnswer((_) async => []);
      return ReferralCubit(service);
    },
    act: (cubit) async {
      final first = cubit.load();
      final second = cubit.load();
      loadRelease.complete(_eligible);
      await first;
      await second;
    },
    expect: () => [
      const ReferralLoading(),
      const ReferralOverviewLoaded(summary: _eligible, invites: []),
    ],
    verify: (_) {
      verify(() => service.getSummary()).called(1);
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'retrying a failed load keeps the error instead of a blank spinner',
    build: () {
      when(() => service.getSummary()).thenAnswer((_) async => _eligible);
      when(() => service.getInvites()).thenAnswer((_) async => []);
      return ReferralCubit(service);
    },
    seed: () => const ReferralFailure(message: 'boom'),
    act: (cubit) => cubit.load(),
    expect: () => [
      const ReferralFailure(message: 'boom', retrying: true),
      const ReferralOverviewLoaded(summary: _eligible, invites: []),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'a second load while failure retry is in flight is ignored',
    build: () {
      loadRelease = Completer<ReferralSummaryDto>();
      when(() => service.getSummary()).thenAnswer((_) => loadRelease.future);
      when(() => service.getInvites()).thenAnswer((_) async => []);
      return ReferralCubit(service);
    },
    seed: () => const ReferralFailure(message: 'boom'),
    act: (cubit) async {
      final first = cubit.load();
      final second = cubit.load();
      loadRelease.complete(_eligible);
      await first;
      await second;
    },
    expect: () => [
      const ReferralFailure(message: 'boom', retrying: true),
      const ReferralOverviewLoaded(summary: _eligible, invites: []),
    ],
    verify: (_) {
      verify(() => service.getSummary()).called(1);
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'retrying needs-terms keeps the copy instead of a blank spinner',
    build: () {
      when(() => service.getSummary()).thenAnswer((_) async => _eligible);
      when(() => service.getInvites()).thenAnswer((_) async => []);
      return ReferralCubit(service);
    },
    seed: () => const ReferralNeedsTerms(summary: _needsTerms),
    act: (cubit) => cubit.load(),
    expect: () => [
      const ReferralNeedsTerms(summary: _needsTerms, retrying: true),
      const ReferralOverviewLoaded(summary: _eligible, invites: []),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'a second load while needs-terms retry is in flight is ignored',
    build: () {
      loadRelease = Completer<ReferralSummaryDto>();
      when(() => service.getSummary()).thenAnswer((_) => loadRelease.future);
      when(() => service.getInvites()).thenAnswer((_) async => []);
      return ReferralCubit(service);
    },
    seed: () => const ReferralNeedsTerms(summary: _needsTerms),
    act: (cubit) async {
      final first = cubit.load();
      final second = cubit.load();
      loadRelease.complete(_eligible);
      await first;
      await second;
    },
    expect: () => [
      const ReferralNeedsTerms(summary: _needsTerms, retrying: true),
      const ReferralOverviewLoaded(summary: _eligible, invites: []),
    ],
    verify: (_) {
      verify(() => service.getSummary()).called(1);
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'load surfaces API errors',
    build: () {
      when(() => service.getSummary()).thenThrow(
        const ApiException(code: 'SERVER_ERROR', message: 'boom'),
      );
      return ReferralCubit(service);
    },
    act: (cubit) => cubit.load(),
    expect: () => const [
      ReferralLoading(),
      ReferralFailure(message: referralUnavailableMessage),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'load maps a timed-out summary to the unavailable token',
    build: () {
      when(() => service.getSummary()).thenThrow(
        TimeoutException('summary'),
      );
      return ReferralCubit(service);
    },
    act: (cubit) => cubit.load(),
    expect: () => const [
      ReferralLoading(),
      ReferralFailure(message: referralUnavailableMessage),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'load maps an unmounted NestJS summary to the unavailable token',
    build: () {
      when(() => service.getSummary()).thenThrow(
        const ApiException(
          statusCode: 404,
          code: 'NOT_FOUND',
          message: 'Cannot GET /v1/realunit/referral/summary',
        ),
      );
      return ReferralCubit(service);
    },
    act: (cubit) => cubit.load(),
    expect: () => const [
      ReferralLoading(),
      ReferralFailure(message: referralUnavailableMessage),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'load maps 503 persist failure to the unavailable token',
    build: () {
      when(() => service.getSummary()).thenThrow(
        const ApiException(
          statusCode: 503,
          code: 'UNAVAILABLE',
          message: 'persist failed',
        ),
      );
      return ReferralCubit(service);
    },
    act: (cubit) => cubit.load(),
    expect: () => const [
      ReferralLoading(),
      ReferralFailure(message: referralUnavailableMessage),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'load maps 503 holding lookup failed to the unavailable token',
    build: () {
      when(() => service.getSummary()).thenThrow(
        const ApiException(
          statusCode: 503,
          code: 'UNAVAILABLE',
          message: 'holding lookup failed',
        ),
      );
      return ReferralCubit(service);
    },
    act: (cubit) => cubit.load(),
    expect: () => const [
      ReferralLoading(),
      ReferralFailure(message: referralUnavailableMessage),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'acceptTerms maps a timed-out PUT back to the checkbox',
    build: () {
      when(
        () => service.acceptTerms(version: any(named: 'version')),
      ).thenThrow(TimeoutException('accept'));
      return ReferralCubit(service);
    },
    seed: () => const ReferralNeedsTerms(summary: _needsTerms),
    act: (cubit) => cubit.acceptTerms(),
    expect: () => [
      const ReferralTermsAccepting(summary: _needsTerms),
      const ReferralNeedsTerms(
        summary: _needsTerms,
        errorMessage: referralUnavailableMessage,
      ),
    ],
    verify: (_) {
      verify(
        () => service.acceptTerms(version: ReferralTermsDto.bundledVersion),
      ).called(1);
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'acceptTerms maps a failed summary refresh to the failure copy',
    build: () {
      when(() => service.acceptTerms(version: any(named: 'version'))).thenAnswer((_) async {});
      when(() => service.getSummary()).thenThrow(
        const ApiException(code: 'SERVER_ERROR', message: 'down'),
      );
      return ReferralCubit(service);
    },
    seed: () => const ReferralNeedsTerms(summary: _needsTerms),
    act: (cubit) => cubit.acceptTerms(),
    expect: () => [
      const ReferralTermsAccepting(summary: _needsTerms),
      const ReferralFailure(message: referralUnavailableMessage),
    ],
    verify: (_) {
      verify(
        () => service.acceptTerms(version: ReferralTermsDto.bundledVersion),
      ).called(1);
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'acceptTerms maps a timed-out summary refresh to the failure copy',
    build: () {
      when(() => service.acceptTerms(version: any(named: 'version'))).thenAnswer((_) async {});
      when(() => service.getSummary()).thenThrow(TimeoutException('summary'));
      return ReferralCubit(service);
    },
    seed: () => const ReferralNeedsTerms(summary: _needsTerms),
    act: (cubit) => cubit.acceptTerms(),
    expect: () => [
      const ReferralTermsAccepting(summary: _needsTerms),
      const ReferralFailure(message: referralUnavailableMessage),
    ],
    verify: (_) {
      verify(
        () => service.acceptTerms(version: ReferralTermsDto.bundledVersion),
      ).called(1);
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'createInvite maps a timed-out POST to the name-entry form',
    build: () {
      when(
        () => service.createInvite(guestName: 'Alice', idempotencyKey: any(named: 'idempotencyKey')),
      ).thenThrow(TimeoutException('create'));
      return ReferralCubit(service);
    },
    seed: () => const ReferralCreateReady(summary: _eligible),
    act: (cubit) => cubit.createInvite(guestName: 'Alice'),
    expect: () => [
      const ReferralCreating(summary: _eligible, guestName: 'Alice'),
      const ReferralCreateReady(
        summary: _eligible,
        errorMessage: referralUnavailableMessage,
      ),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'refreshOverview maps a failed summary to failure when tiles are not shown',
    build: () {
      when(() => service.getSummary()).thenThrow(
        const ApiException(code: 'SERVER_ERROR', message: 'down'),
      );
      return ReferralCubit(service);
    },
    seed: () => const ReferralInviteCreated(
      summary: _eligible,
      invite: ReferralCreatedInviteDto(
        code: 'AB12',
        url: 'https://realunit.app/invite/AB12',
        guestName: 'Alice',
      ),
    ),
    act: (cubit) => cubit.refreshOverview(),
    expect: () => const [
      ReferralFailure(message: referralUnavailableMessage),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'refreshOverview keeps overview tiles when summary times out',
    build: () {
      when(() => service.getSummary()).thenThrow(TimeoutException('summary'));
      return ReferralCubit(service);
    },
    seed: () => const ReferralOverviewLoaded(summary: _eligible, invites: []),
    act: (cubit) => cubit.refreshOverview(),
    expect: () => <ReferralState>[],
  );

  blocTest<ReferralCubit, ReferralState>(
    'refreshOverview maps a timed-out summary to failure when tiles are not shown',
    build: () {
      when(() => service.getSummary()).thenThrow(TimeoutException('summary'));
      return ReferralCubit(service);
    },
    seed: () => const ReferralInviteCreated(
      summary: _eligible,
      invite: ReferralCreatedInviteDto(
        code: 'AB12',
        url: 'https://realunit.app/invite/AB12',
        guestName: 'Alice',
      ),
    ),
    act: (cubit) => cubit.refreshOverview(),
    expect: () => const [
      ReferralFailure(message: referralUnavailableMessage),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'reloadInvites keeps the current overview when the list times out',
    build: () {
      when(() => service.getInvites()).thenThrow(TimeoutException('invites'));
      return ReferralCubit(service);
    },
    seed: () => const ReferralOverviewLoaded(summary: _eligible, invites: []),
    act: (cubit) => cubit.reloadInvites(),
    expect: () => [
      const ReferralOverviewLoaded(
        summary: _eligible,
        invites: [],
        invitesLoading: true,
      ),
      const ReferralOverviewLoaded(
        summary: _eligible,
        invites: [],
        invitesError: referralUnavailableMessage,
      ),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'load shows overview counts when the invite list times out',
    build: () {
      when(() => service.getSummary()).thenAnswer((_) async => _eligible);
      when(() => service.getInvites()).thenThrow(TimeoutException('invites'));
      return ReferralCubit(service);
    },
    act: (cubit) => cubit.load(),
    expect: () => [
      const ReferralLoading(),
      const ReferralOverviewLoaded(
        summary: _eligible,
        invites: [],
        invitesError: referralUnavailableMessage,
      ),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'createImpersonalInvite emits loading then ready from create-ready',
    build: () {
      when(() => service.createImpersonalInvite()).thenAnswer(
        (_) async => const ReferralCreatedInviteDto(
          code: 'IMP1',
          url: 'https://realunit.app/invite/IMP1',
          guestName: '',
          kind: 'Impersonal',
          copyText: 'Share IMP1: https://realunit.app/invite/IMP1',
        ),
      );
      return ReferralCubit(service);
    },
    seed: () => const ReferralCreateReady(summary: _eligible),
    act: (cubit) => cubit.createImpersonalInvite(),
    expect: () => [
      const ReferralImpersonalLoading(summary: _eligible),
      const ReferralImpersonalReady(
        summary: _eligible,
        invite: ReferralCreatedInviteDto(
          code: 'IMP1',
          url: 'https://realunit.app/invite/IMP1',
          guestName: '',
          kind: 'Impersonal',
          copyText: 'Share IMP1: https://realunit.app/invite/IMP1',
        ),
      ),
    ],
    verify: (_) {
      verify(() => service.createImpersonalInvite()).called(1);
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'createImpersonalInvite maps an API error to failure and showPersonalCreate '
    'returns to the personal form',
    build: () {
      when(() => service.createImpersonalInvite()).thenThrow(
        const ApiException(code: 'SERVER_ERROR', message: 'boom'),
      );
      return ReferralCubit(service);
    },
    seed: () => const ReferralCreateReady(summary: _eligible),
    act: (cubit) async {
      await cubit.createImpersonalInvite();
      cubit.showPersonalCreate();
    },
    expect: () => const [
      ReferralImpersonalLoading(summary: _eligible),
      ReferralImpersonalFailure(
        summary: _eligible,
        message: referralUnavailableMessage,
      ),
      ReferralCreateReady(summary: _eligible),
    ],
    verify: (_) {
      verify(() => service.createImpersonalInvite()).called(1);
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'createImpersonalInvite reuses the cached code after the overview reloads',
    build: () {
      when(() => service.createImpersonalInvite()).thenAnswer(
        (_) async => const ReferralCreatedInviteDto(
          code: 'IMP1',
          url: 'https://realunit.app/invite/IMP1',
          guestName: '',
          kind: 'Impersonal',
          copyText: 'Share IMP1: https://realunit.app/invite/IMP1',
        ),
      );
      when(() => service.getSummary()).thenAnswer((_) async => _eligible);
      when(() => service.getInvites()).thenAnswer((_) async => []);
      return ReferralCubit(service);
    },
    seed: () => const ReferralCreateReady(summary: _eligible),
    act: (cubit) async {
      await cubit.createImpersonalInvite();
      await cubit.refreshOverview();
      await cubit.createImpersonalInvite();
    },
    expect: () => const [
      ReferralImpersonalLoading(summary: _eligible),
      ReferralImpersonalReady(
        summary: _eligible,
        invite: ReferralCreatedInviteDto(
          code: 'IMP1',
          url: 'https://realunit.app/invite/IMP1',
          guestName: '',
          kind: 'Impersonal',
          copyText: 'Share IMP1: https://realunit.app/invite/IMP1',
        ),
      ),
      ReferralOverviewLoaded(summary: _eligible, invites: []),
      ReferralImpersonalReady(
        summary: _eligible,
        invite: ReferralCreatedInviteDto(
          code: 'IMP1',
          url: 'https://realunit.app/invite/IMP1',
          guestName: '',
          kind: 'Impersonal',
          copyText: 'Share IMP1: https://realunit.app/invite/IMP1',
        ),
      ),
    ],
    verify: (_) {
      verify(() => service.createImpersonalInvite()).called(1);
      verify(() => service.getSummary()).called(1);
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'createImpersonalInvite uses the open invite from load and does not post again',
    build: () {
      when(() => service.getSummary()).thenAnswer((_) async => _eligible);
      when(() => service.getInvites()).thenAnswer(
        (_) async => [
          ReferralInviteDto(
            id: 7,
            code: 'IMP1',
            url: 'https://realunit.app/invite/IMP1',
            guestName: '',
            status: 'Open',
            created: DateTime.utc(2026, 8, 1),
            copyText: 'Share IMP1: https://realunit.app/invite/IMP1',
            kind: 'Impersonal',
            prizeCount: 1,
          ),
        ],
      );
      return ReferralCubit(service);
    },
    act: (cubit) async {
      await cubit.load();
      cubit.openCreate();
      await cubit.createImpersonalInvite();
    },
    expect: () => [
      const ReferralLoading(),
      ReferralOverviewLoaded(
        summary: _eligible,
        invites: [
          ReferralInviteDto(
            id: 7,
            code: 'IMP1',
            url: 'https://realunit.app/invite/IMP1',
            guestName: '',
            status: 'Open',
            created: DateTime.utc(2026, 8, 1),
            copyText: 'Share IMP1: https://realunit.app/invite/IMP1',
            kind: 'Impersonal',
            prizeCount: 1,
          ),
        ],
      ),
      const ReferralCreateReady(summary: _eligible),
      const ReferralImpersonalReady(
        summary: _eligible,
        invite: ReferralCreatedInviteDto(
          code: 'IMP1',
          url: 'https://realunit.app/invite/IMP1',
          guestName: '',
          kind: 'Impersonal',
          copyText: 'Share IMP1: https://realunit.app/invite/IMP1',
          prizeCount: 1,
        ),
      ),
    ],
    verify: (cubit) {
      verifyNever(() => service.createImpersonalInvite());
      expect(cubit.state, isA<ReferralImpersonalReady>());
      final invite = (cubit.state as ReferralImpersonalReady).invite;
      expect(invite.code, 'IMP1');
      expect(invite.prizeCount, 1);
      expect(invite.kind, 'Impersonal');
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'createImpersonalInvite keeps the open impersonal invite with the smaller id',
    build: () {
      when(() => service.getSummary()).thenAnswer((_) async => _eligible);
      when(() => service.getInvites()).thenAnswer(
        (_) async => [
          ReferralInviteDto(
            id: 3,
            code: 'PER',
            url: 'https://realunit.app/invite/PER',
            guestName: '',
            status: 'Open',
            created: DateTime.utc(2026, 8, 1),
            copyText: 'Share PER: https://realunit.app/invite/PER',
            kind: 'Personal',
          ),
          ReferralInviteDto(
            id: 9,
            code: 'IMP9',
            url: 'https://realunit.app/invite/IMP9',
            guestName: '',
            status: 'Open',
            created: DateTime.utc(2026, 8, 1),
            copyText: 'Share IMP9: https://realunit.app/invite/IMP9',
            kind: 'Impersonal',
            prizeCount: 2,
          ),
          ReferralInviteDto(
            id: 4,
            code: 'IMP4',
            url: 'https://realunit.app/invite/IMP4',
            guestName: '',
            status: 'Open',
            created: DateTime.utc(2026, 8, 1),
            copyText: 'Share IMP4: https://realunit.app/invite/IMP4',
            kind: 'Impersonal',
            prizeCount: 1,
          ),
        ],
      );
      return ReferralCubit(service);
    },
    act: (cubit) async {
      await cubit.load();
      cubit.openCreate();
      await cubit.createImpersonalInvite();
    },
    expect: () => [
      const ReferralLoading(),
      ReferralOverviewLoaded(
        summary: _eligible,
        invites: [
          ReferralInviteDto(
            id: 3,
            code: 'PER',
            url: 'https://realunit.app/invite/PER',
            guestName: '',
            status: 'Open',
            created: DateTime.utc(2026, 8, 1),
            copyText: 'Share PER: https://realunit.app/invite/PER',
            kind: 'Personal',
          ),
          ReferralInviteDto(
            id: 9,
            code: 'IMP9',
            url: 'https://realunit.app/invite/IMP9',
            guestName: '',
            status: 'Open',
            created: DateTime.utc(2026, 8, 1),
            copyText: 'Share IMP9: https://realunit.app/invite/IMP9',
            kind: 'Impersonal',
            prizeCount: 2,
          ),
          ReferralInviteDto(
            id: 4,
            code: 'IMP4',
            url: 'https://realunit.app/invite/IMP4',
            guestName: '',
            status: 'Open',
            created: DateTime.utc(2026, 8, 1),
            copyText: 'Share IMP4: https://realunit.app/invite/IMP4',
            kind: 'Impersonal',
            prizeCount: 1,
          ),
        ],
      ),
      const ReferralCreateReady(summary: _eligible),
      const ReferralImpersonalReady(
        summary: _eligible,
        invite: ReferralCreatedInviteDto(
          code: 'IMP4',
          url: 'https://realunit.app/invite/IMP4',
          guestName: '',
          kind: 'Impersonal',
          copyText: 'Share IMP4: https://realunit.app/invite/IMP4',
          prizeCount: 1,
        ),
      ),
    ],
    verify: (cubit) {
      verifyNever(() => service.createImpersonalInvite());
      expect(cubit.state, isA<ReferralImpersonalReady>());
      final invite = (cubit.state as ReferralImpersonalReady).invite;
      expect(invite.code, 'IMP4');
      expect(invite.prizeCount, 1);
      expect(invite.kind, 'Impersonal');
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'createImpersonalInvite from ready does not hit the service again',
    build: () {
      when(() => service.createImpersonalInvite()).thenAnswer(
        (_) async => const ReferralCreatedInviteDto(
          code: 'IMP1',
          url: 'https://realunit.app/invite/IMP1',
          guestName: '',
          kind: 'Impersonal',
          copyText: 'Share IMP1: https://realunit.app/invite/IMP1',
        ),
      );
      return ReferralCubit(service);
    },
    seed: () => const ReferralImpersonalReady(
      summary: _eligible,
      invite: ReferralCreatedInviteDto(
        code: 'IMP1',
        url: 'https://realunit.app/invite/IMP1',
        guestName: '',
        kind: 'Impersonal',
        copyText: 'Share IMP1: https://realunit.app/invite/IMP1',
      ),
    ),
    act: (cubit) => cubit.createImpersonalInvite(),
    expect: () => <ReferralState>[],
    verify: (_) {
      verifyNever(() => service.createImpersonalInvite());
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'showPersonalCreate from ready then createImpersonalInvite reuses the cached code',
    build: () {
      when(() => service.createImpersonalInvite()).thenAnswer(
        (_) async => const ReferralCreatedInviteDto(
          code: 'IMP1',
          url: 'https://realunit.app/invite/IMP1',
          guestName: '',
          kind: 'Impersonal',
          copyText: 'Share IMP1: https://realunit.app/invite/IMP1',
        ),
      );
      return ReferralCubit(service);
    },
    seed: () => const ReferralCreateReady(summary: _eligible),
    act: (cubit) async {
      await cubit.createImpersonalInvite();
      cubit.showPersonalCreate();
      await cubit.createImpersonalInvite();
    },
    expect: () => [
      const ReferralImpersonalLoading(summary: _eligible),
      const ReferralImpersonalReady(
        summary: _eligible,
        invite: ReferralCreatedInviteDto(
          code: 'IMP1',
          url: 'https://realunit.app/invite/IMP1',
          guestName: '',
          kind: 'Impersonal',
          copyText: 'Share IMP1: https://realunit.app/invite/IMP1',
        ),
      ),
      const ReferralCreateReady(summary: _eligible),
      const ReferralImpersonalReady(
        summary: _eligible,
        invite: ReferralCreatedInviteDto(
          code: 'IMP1',
          url: 'https://realunit.app/invite/IMP1',
          guestName: '',
          kind: 'Impersonal',
          copyText: 'Share IMP1: https://realunit.app/invite/IMP1',
        ),
      ),
    ],
    verify: (_) {
      verify(() => service.createImpersonalInvite()).called(1);
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'createImpersonalInvite maps a timeout to failure and retries only with retry: true',
    build: () {
      when(
        () => service.createImpersonalInvite(),
      ).thenThrow(TimeoutException('create'));
      return ReferralCubit(service);
    },
    seed: () => const ReferralCreateReady(summary: _eligible),
    act: (cubit) async {
      await cubit.createImpersonalInvite();
      await cubit.createImpersonalInvite();
      await cubit.createImpersonalInvite(retry: true);
    },
    expect: () => [
      const ReferralImpersonalLoading(summary: _eligible),
      ReferralImpersonalFailure(
        summary: _eligible,
        message: referralErrorMessage(TimeoutException('create')),
      ),
      const ReferralImpersonalLoading(summary: _eligible),
      ReferralImpersonalFailure(
        summary: _eligible,
        message: referralErrorMessage(TimeoutException('create')),
      ),
    ],
    verify: (_) {
      verify(() => service.createImpersonalInvite()).called(2);
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'createImpersonalInvite from initial does not hit the service',
    build: () => ReferralCubit(service),
    act: (cubit) => cubit.createImpersonalInvite(),
    expect: () => <ReferralState>[],
    verify: (_) {
      verifyNever(() => service.createImpersonalInvite());
    },
  );

  blocTest<ReferralCubit, ReferralState>(
    'createImpersonalInvite maps NOT_ELIGIBLE to the gate screen',
    build: () {
      when(() => service.createImpersonalInvite()).thenThrow(
        const ApiException(
          statusCode: 403,
          code: 'NOT_ELIGIBLE',
          message: 'holding below min',
        ),
      );
      return ReferralCubit(service);
    },
    seed: () => const ReferralCreateReady(summary: _eligible),
    act: (cubit) => cubit.createImpersonalInvite(),
    expect: () => [
      const ReferralImpersonalLoading(summary: _eligible),
      const ReferralNotEligible(),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'createImpersonalInvite maps NEEDS_TERMS to the terms screen',
    build: () {
      when(() => service.createImpersonalInvite()).thenThrow(
        const ApiException(
          statusCode: 409,
          code: 'NEEDS_TERMS',
          message: 'terms not accepted',
        ),
      );
      return ReferralCubit(service);
    },
    seed: () => const ReferralCreateReady(summary: _eligible),
    act: (cubit) => cubit.createImpersonalInvite(),
    expect: () => [
      const ReferralImpersonalLoading(summary: _eligible),
      const ReferralNeedsTerms(summary: _eligible),
    ],
  );

  blocTest<ReferralCubit, ReferralState>(
    'impersonalInviteCreated stays true after showPersonalCreate',
    build: () {
      when(() => service.createImpersonalInvite()).thenAnswer(
        (_) async => const ReferralCreatedInviteDto(
          code: 'IMP1',
          url: 'https://realunit.app/invite/IMP1',
          guestName: '',
          kind: 'Impersonal',
          copyText: 'Share IMP1: https://realunit.app/invite/IMP1',
        ),
      );
      return ReferralCubit(service);
    },
    seed: () => const ReferralCreateReady(summary: _eligible),
    act: (cubit) async {
      await cubit.createImpersonalInvite();
      cubit.showPersonalCreate();
      expect(await cubit.impersonalInviteCreated(), isTrue);
      expect(cubit.state, const ReferralCreateReady(summary: _eligible));
    },
    expect: () => [
      const ReferralImpersonalLoading(summary: _eligible),
      const ReferralImpersonalReady(
        summary: _eligible,
        invite: ReferralCreatedInviteDto(
          code: 'IMP1',
          url: 'https://realunit.app/invite/IMP1',
          guestName: '',
          kind: 'Impersonal',
          copyText: 'Share IMP1: https://realunit.app/invite/IMP1',
        ),
      ),
      const ReferralCreateReady(summary: _eligible),
    ],
    verify: (_) {
      verify(() => service.createImpersonalInvite()).called(1);
    },
  );

  test('impersonalInviteCreated waits for an in-flight POST', () async {
    final release = Completer<ReferralCreatedInviteDto>();
    when(() => service.createImpersonalInvite()).thenAnswer((_) => release.future);
    final cubit = ReferralCubit(service);
    cubit.emit(const ReferralCreateReady(summary: _eligible));

    final created = cubit.createImpersonalInvite();
    final pending = cubit.impersonalInviteCreated();
    var settled = false;
    unawaited(pending.then((_) => settled = true));
    await Future<void>.delayed(Duration.zero);
    expect(settled, isFalse);

    release.complete(
      const ReferralCreatedInviteDto(
        code: 'IMP1',
        url: 'https://realunit.app/invite/IMP1',
        guestName: '',
        kind: 'Impersonal',
        copyText: 'Share IMP1: https://realunit.app/invite/IMP1',
      ),
    );
    expect(await pending, isTrue);
    await created;
    verify(() => service.createImpersonalInvite()).called(1);
    await cubit.close();
  });

  test('impersonalInviteCreated is false after a failed POST and does not hang', () async {
    when(
      () => service.createImpersonalInvite(),
    ).thenThrow(TimeoutException('create'));
    final cubit = ReferralCubit(service);
    cubit.emit(const ReferralCreateReady(summary: _eligible));

    await cubit.createImpersonalInvite();
    expect(await cubit.impersonalInviteCreated(), isFalse);
    expect(await cubit.impersonalInviteCreated(), isFalse);
    verify(() => service.createImpersonalInvite()).called(1);
    await cubit.close();
  });
}
