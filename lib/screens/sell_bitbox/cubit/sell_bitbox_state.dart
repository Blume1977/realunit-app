part of 'sell_bitbox_cubit.dart';

sealed class SellBitboxState extends Equatable {
  @override
  List<Object?> get props => [];
}

sealed class SellBitboxEthState extends SellBitboxState {}

sealed class SellBitboxSwapState extends SellBitboxState {}

sealed class SellBitboxDepositState extends SellBitboxState {}

class SellBitboxBitboxRequired extends SellBitboxEthState {}

class SellBitboxCheckingEth extends SellBitboxEthState {}

class SellBitboxRequestingFaucet extends SellBitboxEthState {}

class SellBitboxWaitingForEth extends SellBitboxEthState {}

class SellBitboxEthReady extends SellBitboxEthState {}

class SellBitboxPreparingSwap extends SellBitboxSwapState {}

class SellBitboxAwaitingSwapConfirm extends SellBitboxSwapState {
  final String rawSwapTransaction;
  final String rawDepositTransaction;

  SellBitboxAwaitingSwapConfirm(this.rawSwapTransaction, this.rawDepositTransaction);

  @override
  List<Object?> get props => [rawSwapTransaction, rawDepositTransaction];
}

class SellBitboxSwapping extends SellBitboxSwapState {}

class SellBitboxAwaitingDepositConfirm extends SellBitboxDepositState {
  final BroadcastTransactionRequestDto signedSwapTransaction;
  final String rawDepositTransaction;

  SellBitboxAwaitingDepositConfirm(this.signedSwapTransaction, this.rawDepositTransaction);

  @override
  List<Object?> get props => [signedSwapTransaction, rawDepositTransaction];
}

class SellBitboxDepositing extends SellBitboxDepositState {}

// Retry in flight: HTTP-only work on stored signed bytes — no BitBox prompt.
class SellBitboxRetryingDeposit extends SellBitboxDepositState {}

// The swap was broadcast; the deposit step then failed. A null `broadcastTxHash`
// means the deposit broadcast got no usable response (retry re-sends the same
// signed bytes); non-null means it is on-chain and retry resumes at the confirm.
class SellBitboxDepositRetry extends SellBitboxDepositState {
  final BroadcastTransactionRequestDto signedSwapTransaction;
  final BroadcastTransactionRequestDto signedDepositTransaction;
  final String? broadcastTxHash;
  final String errorMessage;

  SellBitboxDepositRetry(
    this.signedSwapTransaction,
    this.signedDepositTransaction,
    this.errorMessage, {
    this.broadcastTxHash,
  });

  @override
  List<Object?> get props => [
    signedSwapTransaction,
    signedDepositTransaction,
    broadcastTxHash,
    errorMessage,
  ];
}

class SellBitboxSuccess extends SellBitboxDepositState {}

class SellBitboxError extends SellBitboxState {
  final String message;

  SellBitboxError(this.message);

  @override
  List<Object?> get props => [message];
}

/// The unsigned transactions do not match the confirmed quote. Nothing was
/// signed. [message] keeps the reason for diagnostics.
class SellBitboxTransactionMismatch extends SellBitboxError {
  SellBitboxTransactionMismatch(super.message);
}
