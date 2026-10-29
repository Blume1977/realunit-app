class Eip7702Domain {
  final String name;
  final String version;
  final int chainId;
  final String verifyingContract;

  const Eip7702Domain({
    required this.name,
    required this.version,
    required this.chainId,
    required this.verifyingContract,
  });

  factory Eip7702Domain.fromJson(Map<String, dynamic> json) {
    return Eip7702Domain(
      name: json['name'] as String,
      version: json['version'] as String,
      chainId: json['chainId'] as int,
      verifyingContract: json['verifyingContract'] as String,
    );
  }
}

class Eip7702TypeField {
  final String name;
  final String type;

  const Eip7702TypeField({
    required this.name,
    required this.type,
  });

  factory Eip7702TypeField.fromJson(Map<String, dynamic> json) {
    return Eip7702TypeField(
      name: json['name'] as String,
      type: json['type'] as String,
    );
  }
}

class Eip7702Types {
  final List<Eip7702TypeField> delegation;
  final List<Eip7702TypeField> caveat;

  const Eip7702Types({
    required this.delegation,
    required this.caveat,
  });

  factory Eip7702Types.fromJson(Map<String, dynamic> json) {
    return Eip7702Types(
      delegation: (json['Delegation'] as List<dynamic>)
          .map((e) => Eip7702TypeField.fromJson(e as Map<String, dynamic>))
          .toList(),
      caveat: (json['Caveat'] as List<dynamic>)
          .map((e) => Eip7702TypeField.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Eip7702Message {
  final String delegate;
  final String delegator;
  final String authority;
  final List<dynamic> caveats;
  final int salt;

  const Eip7702Message({
    required this.delegate,
    required this.delegator,
    required this.authority,
    required this.caveats,
    required this.salt,
  });

  factory Eip7702Message.fromJson(Map<String, dynamic> json) {
    return Eip7702Message(
      delegate: json['delegate'] as String,
      delegator: json['delegator'] as String,
      authority: json['authority'] as String,
      caveats: json['caveats'] as List<dynamic>,
      salt: json['salt'] as int,
    );
  }
}

class Eip7702Data {
  final String relayerAddress;
  final String delegationManagerAddress;
  final String delegatorAddress;
  final int userNonce;
  final Eip7702Domain domain;
  final Eip7702Types types;
  final Eip7702Message message;
  final String tokenAddress;
  final String amountWei;

  /// Absent on a sell quote the API marks invalid. The signers never read it.
  final String? depositAddress;

  const Eip7702Data({
    required this.relayerAddress,
    required this.delegationManagerAddress,
    required this.delegatorAddress,
    required this.userNonce,
    required this.domain,
    required this.types,
    required this.message,
    required this.tokenAddress,
    required this.amountWei,
    this.depositAddress,
  });

  factory Eip7702Data.fromJson(Map<String, dynamic> json) {
    return Eip7702Data(
      relayerAddress: json['relayerAddress'] as String,
      delegationManagerAddress: json['delegationManagerAddress'] as String,
      delegatorAddress: json['delegatorAddress'] as String,
      userNonce: json['userNonce'] as int,
      domain: Eip7702Domain.fromJson(json['domain'] as Map<String, dynamic>),
      types: Eip7702Types.fromJson(json['types'] as Map<String, dynamic>),
      message: Eip7702Message.fromJson(json['message'] as Map<String, dynamic>),
      tokenAddress: json['tokenAddress'] as String,
      amountWei: json['amountWei'] as String,
      depositAddress: json['depositAddress'] as String?,
    );
  }
}
