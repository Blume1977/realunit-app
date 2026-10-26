import 'unsigned_eip1559_tx.dart';

/// Mainnet BitBox sell quote values and the unsigned swap and deposit that
/// match them.
const sellQuoteRealuAddress = '0x553c7f9c780316fc1d34b8e14ac2465ab22a090b';
const sellQuoteDepositAddress = '0x222222222222222222222222222222222222bc02';
const sellQuoteShares = 100;
const sellQuoteZchfAmount = 250.5;

const _brokerbot = '0xcff32c60b87296b8c0c12980de685bed6cb9dd6d';
const _zchf = '0xb58e61c3098d85632df34eecfb899a1ed80921cb';
final _gasPrice = BigInt.from(2000000000); // 2 gwei, 0.0009 ETH for both

/// REALU `transferAndCall(brokerbot, sellQuoteShares, "")`.
final String matchingSellSwapHex = UnsignedEip1559Tx(
  chainId: 1,
  nonce: 7,
  maxPriorityFeePerGas: _gasPrice,
  maxFeePerGas: _gasPrice,
  gasLimit: 350000,
  to: sellQuoteRealuAddress,
  value: BigInt.zero,
  data: transferAndCallCalldata(_brokerbot, BigInt.from(sellQuoteShares)),
).toHex();

/// ZCHF `transfer(sellQuoteDepositAddress, sellQuoteZchfAmount)`.
final String matchingSellDepositHex = UnsignedEip1559Tx(
  chainId: 1,
  nonce: 8,
  maxPriorityFeePerGas: _gasPrice,
  maxFeePerGas: _gasPrice,
  gasLimit: 100000,
  to: _zchf,
  value: BigInt.zero,
  data: addressAmountCalldata(
    erc20TransferSelector,
    sellQuoteDepositAddress,
    BigInt.parse('250500000000000000000'),
  ),
).toHex();
