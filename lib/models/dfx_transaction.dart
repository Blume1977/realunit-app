import 'package:realunit_wallet/models/transaction.dart';

/// Transaction with additional off-chain metadata
class DfxTransaction extends Transaction {
  final int dfxId;
  final double? rate;
  final String? inputTxId;
  final String? outputTxId;
  final double? inputAmount;
  final String? inputAsset;
  final double? outputAmount;
  final String? outputAsset;

  const DfxTransaction({
    required this.dfxId,
    this.rate,
    this.inputTxId,
    this.outputTxId,
    this.inputAmount,
    this.inputAsset,
    this.outputAmount,
    this.outputAsset,
    required super.height,
    required super.txId,
    required super.chainId,
    required super.senderAddress,
    required super.receiverAddress,
    required super.amount,
    required super.asset,
    required super.type,
    super.category,
    required super.note,
    required super.data,
    required super.timestamp,
  });
}
