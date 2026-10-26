import 'package:eip7702/eip7702.dart' as eip7702;
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/eip7702/eip7702_data_dto.dart';
import 'package:realunit_wallet/packages/wallet/eip712_signer.dart';
import 'package:realunit_wallet/packages/wallet/eip7702_signer.dart';
import 'package:web3dart/web3dart.dart';

/// Signs the EIP-712 delegation and the EIP-7702 authorization of a gasless
/// confirm.
class DelegationSigner {
  const DelegationSigner();

  Future<String> signDelegation({
    required CredentialsWithKnownAddress credentials,
    required Eip7702Data eip7702Data,
  }) => Eip712Signer.signDelegation(credentials: credentials, eip7702Data: eip7702Data);

  eip7702.EIP7702MsgSignature signAuthorization({
    required CredentialsWithKnownAddress credentials,
    required Eip7702Data eip7702Data,
  }) => Eip7702Signer.signAuthorization(credentials: credentials, eip7702Data: eip7702Data);
}
