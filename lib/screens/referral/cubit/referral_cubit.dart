import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:realunit_wallet/packages/service/dfx/exceptions/api_exception.dart';
import 'package:realunit_wallet/packages/service/dfx/models/referral/dto/referral_created_invite_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/referral/dto/referral_invite_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/referral/dto/referral_summary_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/referral/dto/referral_terms_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/real_unit_referral_service.dart';
import 'package:realunit_wallet/screens/referral/referral_error_message.dart';
import 'package:realunit_wallet/screens/referral/referral_limits.dart';

part 'referral_state.dart';

class ReferralCubit extends Cubit<ReferralState> {
  final RealUnitReferralService _service;
  bool _refreshing = false;
  int _invitesGeneration = 0;
  int _summaryGeneration = 0;
  String? _createIdempotencyKey;
  /// The guest name [_createIdempotencyKey] was minted for. A retry after a
  /// failure may carry a different name, and reusing the key would let a
  /// conforming server answer with the previous name's invite.
  String? _createIdempotencyName;

  ReferralCubit(this._service) : super(const ReferralInitial());

  void _emitIfOpen(ReferralState next) {
    if (isClosed) return;
    emit(next);
  }

  Future<void> load() async {
    final current = state;
    if (current is ReferralLoading) return;
    if (current is ReferralFailure && current.retrying) return;
    if (current is ReferralNeedsTerms && current.retrying) return;
    if (current is ReferralFailure) {
      _emitIfOpen(ReferralFailure(message: current.message, retrying: true));
    } else if (current is ReferralNeedsTerms) {
      _emitIfOpen(
        ReferralNeedsTerms(
          summary: current.summary,
          errorMessage: current.errorMessage,
          retrying: true,
        ),
      );
    } else {
      _emitIfOpen(const ReferralLoading());
    }
    final generation = ++_summaryGeneration;
    try {
      final summary = await _service.getSummary();
      if (generation != _summaryGeneration) return;
      await _emitFromSummary(summary);
    } on ApiException catch (e) {
      _emitIfOpen(ReferralFailure(message: referralErrorMessage(e)));
    } catch (e) {
      _emitIfOpen(ReferralFailure(message: referralErrorMessage(e)));
    }
  }

  Future<void> acceptTerms({
    String version = ReferralTermsDto.bundledVersion,
  }) async {
    final current = state;
    if (current is! ReferralNeedsTerms) return;
    final summary = current.summary;

    _emitIfOpen(
      ReferralTermsAccepting(
        summary: summary,
        errorMessage: current.errorMessage,
      ),
    );
    try {
      await _service.acceptTerms(version: version);
    } on ApiException catch (e) {
      _emitIfOpen(
        ReferralNeedsTerms(
          summary: summary,
          errorMessage: referralErrorMessage(e),
        ),
      );
      return;
    } catch (e) {
      _emitIfOpen(
        ReferralNeedsTerms(
          summary: summary,
          errorMessage: referralErrorMessage(e),
        ),
      );
      return;
    }
    // Accept already posted. A later summary/invite-list failure must not
    // send the user back to the checkbox as if they still need to accept.
    try {
      await _emitFromSummary(await _service.getSummary());
    } on ApiException catch (e) {
      _emitIfOpen(ReferralFailure(message: referralErrorMessage(e)));
    } catch (e) {
      _emitIfOpen(ReferralFailure(message: referralErrorMessage(e)));
    }
  }

  Future<void> createInvite({required String guestName}) async {
    final name = sanitizeReferralGuestName(guestName);
    if (name.isEmpty) return;
    final current = state;
    if (current is! ReferralOverviewLoaded && current is! ReferralCreateReady) {
      return;
    }
    final summary = switch (current) {
      ReferralOverviewLoaded(:final summary) => summary,
      ReferralCreateReady(:final summary) => summary,
      _ => null,
    };
    if (summary == null) return;

    _emitIfOpen(
      ReferralCreating(
        summary: summary,
        guestName: name,
        errorMessage: current is ReferralCreateReady ? current.errorMessage : null,
      ),
    );
    if (_createIdempotencyKey == null || _createIdempotencyName != name) {
      _createIdempotencyKey =
          'invite-${name.hashCode}-${DateTime.now().microsecondsSinceEpoch}';
      _createIdempotencyName = name;
    }
    try {
      final created = await _service.createInvite(
        guestName: name,
        idempotencyKey: _createIdempotencyKey,
      );
      _createIdempotencyKey = null;
      _createIdempotencyName = null;
      _emitIfOpen(ReferralInviteCreated(summary: summary, invite: created));
    } on ApiException catch (e) {
      if (e.code == 'NOT_ELIGIBLE') {
        _emitIfOpen(const ReferralNotEligible());
        return;
      }
      if (e.code == 'NEEDS_TERMS') {
        _emitIfOpen(ReferralNeedsTerms(summary: summary));
        return;
      }
      _emitIfOpen(
        ReferralCreateReady(
          summary: summary,
          errorMessage: referralErrorMessage(e),
        ),
      );
    } catch (e) {
      _emitIfOpen(
        ReferralCreateReady(
          summary: summary,
          errorMessage: referralErrorMessage(e),
        ),
      );
    }
  }

  void openCreate() {
    final current = state;
    if (current is ReferralOverviewLoaded) {
      _emitIfOpen(ReferralCreateReady(summary: current.summary));
    } else if (current is ReferralInviteCreated) {
      _emitIfOpen(ReferralCreateReady(summary: current.summary));
    }
  }

  Future<void> refreshOverview() async {
    if (state is ReferralLoading || _refreshing) return;
    _refreshing = true;
    final previous = state;
    final generation = ++_summaryGeneration;
    try {
      final summary = await _service.getSummary();
      if (generation != _summaryGeneration) return;
      await _emitFromSummary(summary);
    } on ApiException catch (e) {
      if (previous is ReferralOverviewLoaded) return;
      _emitIfOpen(ReferralFailure(message: referralErrorMessage(e)));
    } catch (e) {
      if (previous is ReferralOverviewLoaded) return;
      _emitIfOpen(ReferralFailure(message: referralErrorMessage(e)));
    } finally {
      _refreshing = false;
    }
  }

  /// Refetches open-invite rows without dropping the summary tiles.
  Future<void> reloadInvites() async {
    final current = state;
    if (current is! ReferralOverviewLoaded) return;
    if (current.invitesLoading) return;
    if (_refreshing) return;
    final generation = ++_invitesGeneration;
    _emitIfOpen(
      ReferralOverviewLoaded(
        summary: current.summary,
        invites: current.invites,
        invitesError: current.invitesError,
        invitesLoading: true,
      ),
    );
    try {
      final invites = await _service.getInvites();
      if (generation != _invitesGeneration) return;
      final latest = state;
      if (latest is! ReferralOverviewLoaded) return;
      _emitIfOpen(ReferralOverviewLoaded(summary: latest.summary, invites: invites));
    } on ApiException catch (e) {
      if (generation != _invitesGeneration) return;
      final latest = state;
      if (latest is! ReferralOverviewLoaded) return;
      _emitIfOpen(
        ReferralOverviewLoaded(
          summary: latest.summary,
          invites: latest.invites,
          invitesError: referralErrorMessage(e),
        ),
      );
    } catch (e) {
      if (generation != _invitesGeneration) return;
      final latest = state;
      if (latest is! ReferralOverviewLoaded) return;
      _emitIfOpen(
        ReferralOverviewLoaded(
          summary: latest.summary,
          invites: latest.invites,
          invitesError: referralErrorMessage(e),
        ),
      );
    }
  }

  Future<void> _emitFromSummary(ReferralSummaryDto summary) async {
    _invitesGeneration++;
    if (!summary.eligible) {
      _emitIfOpen(const ReferralNotEligible());
      return;
    }
    if (!summary.termsAccepted) {
      _emitIfOpen(ReferralNeedsTerms(summary: summary));
      return;
    }
    // Counts come from summary. Open-invite copy/share is best-effort so a
    // list outage cannot hide the programme after terms are accepted.
    var invites = const <ReferralInviteDto>[];
    String? invitesError;
    try {
      invites = await _service.getInvites();
    } on ApiException catch (e) {
      invitesError = referralErrorMessage(e);
    } catch (e) {
      invitesError = referralErrorMessage(e);
    }
    _emitIfOpen(
      ReferralOverviewLoaded(
        summary: summary,
        invites: invites,
        invitesError: invitesError,
      ),
    );
  }
}
