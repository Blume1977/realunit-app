import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/packages/service/dfx/models/support/support_issue.dart';
import 'package:realunit_wallet/packages/service/dfx/models/support/support_issue_reason.dart';
import 'package:realunit_wallet/packages/service/dfx/models/support/support_issue_state.dart';
import 'package:realunit_wallet/packages/service/dfx/models/support/support_issue_type.dart';
import 'package:realunit_wallet/screens/debug_auth/cubit/debug_auth_cubit.dart';
import 'package:realunit_wallet/screens/support/cubits/support_chat/support_chat_state.dart';
import 'package:realunit_wallet/screens/support/cubits/support_create_ticket/support_create_ticket_state.dart';
import 'package:realunit_wallet/screens/support/cubits/support_tickets/support_tickets_state.dart';

void main() {
  group('$DebugAuthState defaults + copyWith', () {
    test('defaults: empty address, idle, not authenticated', () {
      const state = DebugAuthState();
      expect(state.address, '');
      expect(state.signMessage, isNull);
      expect(state.isLoading, isFalse);
      expect(state.isAuthenticated, isFalse);
      expect(state.missingSignMessage, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('copyWith preserves untouched fields', () {
      const base = DebugAuthState(address: '0xabc');
      final next = base.copyWith(isLoading: true);
      expect(next.address, '0xabc');
      expect(next.isLoading, isTrue);
      expect(next.isAuthenticated, isFalse);
    });

    test('Equatable props pin all seven fields', () {
      const a = DebugAuthState(address: '0xabc');
      const b = DebugAuthState(address: '0xabc');
      const c = DebugAuthState(address: '0xdef');
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('$SupportCreateTicketState defaults + copyWith', () {
    test('defaults: nothing selected, empty message, idle', () {
      const state = SupportCreateTicketState();
      expect(state.selectedType, isNull);
      expect(state.selectedReason, isNull);
      expect(state.message, '');
      expect(state.isSubmitting, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.error, isNull);
    });

    test('copyWith preserves untouched fields', () {
      const base = SupportCreateTicketState(message: 'hello');
      final next = base.copyWith(isSubmitting: true);
      expect(next.message, 'hello');
      expect(next.isSubmitting, isTrue);
      expect(next.isSuccess, isFalse);
    });

    test('Equatable props pin everything', () {
      const a = SupportCreateTicketState(message: 'a');
      const b = SupportCreateTicketState(message: 'a');
      const c = SupportCreateTicketState(message: 'b');
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('$SupportChatState equality', () {
    test('Initial vs Loading distinct', () {
      expect(const SupportChatInitial(), const SupportChatInitial());
      expect(const SupportChatLoading(), const SupportChatLoading());
      expect(const SupportChatInitial(), isNot(const SupportChatLoading()));
    });

    test('SupportChatLoaded.copyWith preserves untouched fields', () {
      final ticket = SupportIssue(
        uid: 'u',
        state: SupportIssueState.created,
        type: SupportIssueType.genericIssue,
        reason: SupportIssueReason.other,
        name: 'n',
        created: DateTime.utc(2026, 5, 15),
        messages: const [],
      );
      final base = SupportChatLoaded(ticket: ticket);
      final next = base.copyWith(isSending: true);
      expect(next.ticket, ticket);
      expect(next.isSending, isTrue);
    });

    test('SupportChatLoaded.props pin (ticket, isSending)', () {
      final ticket = SupportIssue(
        uid: 'u',
        state: SupportIssueState.created,
        type: SupportIssueType.genericIssue,
        reason: SupportIssueReason.other,
        name: 'n',
        created: DateTime.utc(2026, 5, 15),
        messages: const [],
      );
      expect(
        SupportChatLoaded(ticket: ticket),
        SupportChatLoaded(ticket: ticket),
      );
      expect(
        SupportChatLoaded(ticket: ticket),
        isNot(SupportChatLoaded(ticket: ticket, isSending: true)),
      );
    });
  });

  group('$SupportTicketsState equality', () {
    test('Loaded props pin the tickets list', () {
      final t = SupportIssue(
        uid: 'u',
        state: SupportIssueState.created,
        type: SupportIssueType.genericIssue,
        reason: SupportIssueReason.other,
        name: 'n',
        created: DateTime.utc(2026, 5, 15),
        messages: const [],
      );
      expect(SupportTicketsLoaded([t]), SupportTicketsLoaded([t]));
      expect(SupportTicketsLoaded([t]), isNot(const SupportTicketsLoaded([])));
    });

    test('Error props pin the message', () {
      expect(
        const SupportTicketsError('boom'),
        const SupportTicketsError('boom'),
      );
      expect(
        const SupportTicketsError('boom'),
        isNot(const SupportTicketsError('other')),
      );
    });
  });
}
