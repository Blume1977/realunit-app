part of 'debug_auth_cubit.dart';

class DebugAuthState extends Equatable {
  final String address;
  final String? signMessage;
  final String? savedSignature;
  final bool isLoading;
  final bool isAuthenticated;
  final bool missingSignMessage;
  final String? errorMessage;

  const DebugAuthState({
    this.address = '',
    this.signMessage,
    this.savedSignature,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.missingSignMessage = false,
    this.errorMessage,
  });

  DebugAuthState copyWith({
    String? address,
    String? signMessage,
    String? savedSignature,
    bool? isLoading,
    bool? isAuthenticated,
    bool missingSignMessage = false,
    String? errorMessage,
  }) {
    return DebugAuthState(
      address: address ?? this.address,
      signMessage: signMessage ?? this.signMessage,
      savedSignature: savedSignature ?? this.savedSignature,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      missingSignMessage: missingSignMessage,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        address,
        signMessage,
        savedSignature,
        isLoading,
        isAuthenticated,
        missingSignMessage,
        errorMessage,
      ];
}
