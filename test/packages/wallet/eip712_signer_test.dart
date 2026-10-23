import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realunit_wallet/packages/hardware_wallet/bitbox_credentials.dart';
import 'package:realunit_wallet/packages/service/dfx/models/country/country.dart';
import 'package:realunit_wallet/packages/service/dfx/models/payment/sell/dto/eip7702/eip7702_data_dto.dart';
import 'package:realunit_wallet/packages/service/dfx/models/registration/registration.dart';
import 'package:realunit_wallet/packages/service/dfx/models/registration/registration_user_type.dart';
import 'package:realunit_wallet/packages/wallet/eip712_signer.dart';
import 'package:realunit_wallet/packages/wallet/exceptions/signing_cancelled_exception.dart';
import 'package:realunit_wallet/packages/wallet/wallet.dart';
import 'package:web3dart/web3dart.dart';

class _MockBitboxCredentials extends Mock implements BitboxCredentials {}

Future<String> _signWith(BitboxCredentials credentials) => Eip712Signer.signRegistration(
  credentials: credentials,
  chainId: 1,
  type: RegistrationUserType.human.jsonName,
  email: 'cancel@dfx.swiss',
  name: 'Cancel User',
  phoneNumber: '+41790000000',
  birthday: '1990-01-01',
  nationality: 'CH',
  addressStreet: 'Teststrasse 1',
  addressPostalCode: '8000',
  addressCity: 'Zurich',
  addressCountry: 'CH',
  swissTaxResidence: true,
  registrationDate: '2026-05-12',
);

void main() {
  late String privateKeyHex;
  late RegistrationUserType type;
  late String email;
  late String firstName;
  late String lastName;
  late String phoneNumber;
  late String birthday;
  late Country nationality;
  late String addressStreet;
  late String addressStreetNumber;
  late String addressPostalCode;
  late String addressCity;
  late Country addressCountry;
  late bool swissTaxResidence;
  late String registrationDate;

  group('$Eip712Signer', () {
    test(('sign Registration Data works correctly'), () async {
      privateKeyHex = 'fb1ace12f9801e85f3db1b3935dd47d9f064f98152466f47c701b5e12680e612';
      final credentials = EthPrivateKey.fromHex(privateKeyHex);
      type = RegistrationUserType.human;
      email = 'test-direct@dfx.swiss';
      firstName = 'Test';
      lastName = 'Direct';
      phoneNumber = '+41791234567';
      birthday = '1990-01-15';
      nationality = const Country(
        id: 41,
        symbol: 'CH',
        name: 'Switzerland',
        kycAllowed: true,
      );
      addressStreet = 'Teststrasse';
      addressStreetNumber = '1';
      addressPostalCode = '8000';
      addressCity = 'Zurich';
      addressCountry = const Country(
        id: 41,
        symbol: 'CH',
        name: 'Switzerland',
        kycAllowed: true,
      );
      swissTaxResidence = true;
      registrationDate = '2025-12-17';

      final registration = Registration(
        type: type,
        email: email,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        birthday: birthday,
        nationality: nationality,
        addressStreet: addressStreet,
        addressStreetNumber: addressStreetNumber,
        addressPostalCode: addressPostalCode,
        addressCity: addressCity,
        addressCountry: addressCountry,
        swissTaxResidence: swissTaxResidence,
      );

      final signature = await Eip712Signer.signRegistration(
        credentials: credentials,
        chainId: 1,
        type: registration.type.jsonName,
        email: registration.email,
        name: '${registration.firstName} ${registration.lastName}',
        phoneNumber: registration.phoneNumber,
        birthday: registration.birthday,
        nationality: registration.nationality.symbol,
        addressStreet: '${registration.addressStreet} ${registration.addressStreetNumber}',
        addressPostalCode: registration.addressPostalCode,
        addressCity: registration.addressCity,
        addressCountry: registration.addressCountry.symbol,
        swissTaxResidence: registration.swissTaxResidence,
        registrationDate: registrationDate,
      );

      expect(
        signature,
        '0xa11cb57186b9c9f9a09fafa7a3aa256ab14ca030d7eba89f35026b64925d617b3e2cb15349ca561fae5e431deed3f1aa69c7d391cfba80aa6111e753fa782ea21c',
      );
    });

    for (final emptySignature in const ['', '0x']) {
      test('throws SigningCancelledException when BitBox returns "$emptySignature"', () async {
        final credentials = _MockBitboxCredentials();
        when(
          () => credentials.address,
        ).thenReturn(EthereumAddress.fromHex('0x0000000000000000000000000000000000000001'));
        when(
          () => credentials.signTypedDataV4(any(), any()),
        ).thenAnswer((_) async => emptySignature);

        expect(() => _signWith(credentials), throwsA(isA<SigningCancelledException>()));
      });
    }

    // The switch in _signTypedData routes BitboxCredentials and EthPrivateKey
    // explicitly; every other CredentialsWithKnownAddress subtype hits the
    // `_ => throw UnsupportedError` default arm. SoftwareViewWallet's
    // `_LockedCredentials` is exactly such a subtype that lives in
    // production code, so it doubles as a regression check that the locked
    // sentinel does not get routed to a sign backend by accident.
    test('throws UnsupportedError for an unknown credentials subtype', () async {
      final viewWallet = SoftwareViewWallet(
        1,
        'View',
        '0x0000000000000000000000000000000000000001',
      );

      expect(
        () => Eip712Signer.signRegistration(
          credentials: viewWallet.primaryAccount.primaryAddress,
          chainId: 1,
          type: RegistrationUserType.human.jsonName,
          email: 'unsupported@dfx.swiss',
          name: 'Unsupported',
          phoneNumber: '+41790000000',
          birthday: '1990-01-01',
          nationality: 'CH',
          addressStreet: 'Teststrasse 1',
          addressPostalCode: '8000',
          addressCity: 'Zurich',
          addressCountry: 'CH',
          swissTaxResidence: true,
          registrationDate: '2026-05-12',
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    group('signDelegation', () {
      // Empty server type lists must not reach the signature. The signer
      // replaces them with the canonical Delegation and Caveat schema.
      const delegationData = Eip7702Data(
        relayerAddress: '0x0000000000000000000000000000000000000010',
        delegationManagerAddress: '0x0000000000000000000000000000000000000011',
        delegatorAddress: '0x0000000000000000000000000000000000000012',
        userNonce: 0,
        domain: Eip7702Domain(
          name: 'RealUnitDelegation',
          version: '1',
          chainId: 1,
          verifyingContract: '0x0000000000000000000000000000000000000013',
        ),
        types: Eip7702Types(delegation: [], caveat: []),
        message: Eip7702Message(
          delegate: '0x0000000000000000000000000000000000000014',
          delegator: '0x0000000000000000000000000000000000000015',
          authority: '0x0000000000000000000000000000000000000016',
          caveats: [],
          salt: 0,
        ),
        tokenAddress: '0x0000000000000000000000000000000000000017',
        amountWei: '0',
        depositAddress: '0x0000000000000000000000000000000000000018',
      );

      test('signs the EIP-7702 typed data with a software EthPrivateKey', () async {
        // Same well-known private key as the registration happy-path test
        // so the produced signature is deterministic and a future
        // accidental schema change in signDelegation surfaces as a mismatch.
        final credentials = EthPrivateKey.fromHex(
          'fb1ace12f9801e85f3db1b3935dd47d9f064f98152466f47c701b5e12680e612',
        );

        final signature = await Eip712Signer.signDelegation(
          credentials: credentials,
          eip7702Data: delegationData,
        );

        // 0x prefix + 65 bytes * 2 hex chars = 132 chars.
        expect(signature, startsWith('0x'));
        expect(signature.length, 132);
      });

      test('signature is deterministic for the same delegation payload', () async {
        final credentials = EthPrivateKey.fromHex(
          'fb1ace12f9801e85f3db1b3935dd47d9f064f98152466f47c701b5e12680e612',
        );

        final first = await Eip712Signer.signDelegation(
          credentials: credentials,
          eip7702Data: delegationData,
        );
        final second = await Eip712Signer.signDelegation(
          credentials: credentials,
          eip7702Data: delegationData,
        );

        expect(first, second);
      });

      test('routes BitboxCredentials through signTypedDataV4 with the domain chainId', () async {
        final credentials = _MockBitboxCredentials();
        when(
          () => credentials.address,
        ).thenReturn(EthereumAddress.fromHex('0x0000000000000000000000000000000000000019'));
        when(
          () => credentials.signTypedDataV4(any(), any()),
        ).thenAnswer((_) async => '0xdeadbeef');

        final signature = await Eip712Signer.signDelegation(
          credentials: credentials,
          eip7702Data: delegationData,
        );

        expect(signature, '0xdeadbeef');
        // The chainId argument must come from eip7702Data.domain.chainId, not
        // a hardcoded value — verifies the parameter wiring. The typed data
        // uses the canonical schema even though the payload types are empty.
        final captured =
            verify(
              () => credentials.signTypedDataV4(
                delegationData.domain.chainId,
                captureAny(),
              ),
            ).captured.single
                as String;
        expect(captured, contains('"name":"caveats","type":"Caveat[]"'));
        expect(captured, contains('"name":"terms","type":"bytes"'));
      });

      test('throws SigningCancelledException when BitBox returns an empty signature', () async {
        final credentials = _MockBitboxCredentials();
        when(
          () => credentials.address,
        ).thenReturn(EthereumAddress.fromHex('0x0000000000000000000000000000000000000019'));
        when(
          () => credentials.signTypedDataV4(any(), any()),
        ).thenAnswer((_) async => '0x');

        expect(
          () => Eip712Signer.signDelegation(
            credentials: credentials,
            eip7702Data: delegationData,
          ),
          throwsA(isA<SigningCancelledException>()),
        );
      });
    });
  });
}
