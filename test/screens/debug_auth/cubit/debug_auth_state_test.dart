// We deliberately use non-const constructors throughout this file so the
// generative constructor lines get counted as executed in the coverage
// report. Const-only construction is a compile-time optimisation and is
// not visible to the line-coverage instrumentation.
// ignore_for_file: prefer_const_constructors
import 'package:flutter_test/flutter_test.dart';
import 'package:realunit_wallet/screens/debug_auth/cubit/debug_auth_cubit.dart';

/// Equatable-`props` surface tests for `DebugAuthState`.
void main() {
  group('DebugAuthState defaults + ctor', () {
    test('defaults are: empty address, null signature/error, all flags false', () {
      final state = DebugAuthState();
      expect(state.address, '');
      expect(state.signMessage, isNull);
      expect(state.savedSignature, isNull);
      expect(state.isLoading, isFalse);
      expect(state.isAuthenticated, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.missingSignMessage, isFalse);
      expect(state.props, ['', null, null, false, false, false, null]);
    });
  });

  group('DebugAuthState equality', () {
    test('same payload is equal and props match', () {
      final a = DebugAuthState(
        address: '0xabc',
        signMessage: 'msg',
        savedSignature: 'sig',
        isLoading: true,
        isAuthenticated: true,
        errorMessage: 'err',
      );
      final b = DebugAuthState(
        address: '0xabc',
        signMessage: 'msg',
        savedSignature: 'sig',
        isLoading: true,
        isAuthenticated: true,
        errorMessage: 'err',
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a.props, ['0xabc', 'msg', 'sig', true, true, false, 'err']);
    });

    test('different address is unequal', () {
      final a = DebugAuthState(address: '0xabc');
      final b = DebugAuthState(address: '0xdef');
      expect(a, isNot(equals(b)));
    });
  });

  group('DebugAuthState.copyWith', () {
    test('copyWith with new field changes only that field', () {
      final base = DebugAuthState(address: '0xabc');
      final next = base.copyWith(isLoading: true);
      expect(next.address, '0xabc');
      expect(next.isLoading, isTrue);
      expect(next.isAuthenticated, isFalse);
    });

    test('copyWith always rewrites errorMessage from the argument', () {
      // The ctor positional argument for errorMessage is passed through
      // unconditionally — copyWith does NOT apply the `?? this.errorMessage`
      // fallback for it. Pin that behaviour so a future refactor that
      // accidentally adds the fallback gets flagged.
      final base = DebugAuthState(errorMessage: 'old');
      final cleared = base.copyWith();
      expect(cleared.errorMessage, isNull);
      final reset = base.copyWith(errorMessage: 'new');
      expect(reset.errorMessage, 'new');
    });
  });
}
