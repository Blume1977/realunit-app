/// Response of `PUT /v1/realunit/pay/submit` — the blockchain transaction id of
/// the submitted ZCHF payment.
class RealUnitOcpPayResultDto {
  final String txId;

  const RealUnitOcpPayResultDto({required this.txId});

  factory RealUnitOcpPayResultDto.fromJson(Map<String, dynamic> json) {
    return RealUnitOcpPayResultDto(txId: json['txId'] as String);
  }
}

/// Response of the relayed pay confirm. A missing hash means the confirm
/// never left the device and must not be treated as sent.
class RealUnitPayConfirmResultDto {
  final String? txHash;

  const RealUnitPayConfirmResultDto({required this.txHash});

  factory RealUnitPayConfirmResultDto.fromJson(Map<String, dynamic> json) {
    final raw = json['txHash'] as String?;
    if (raw == null || raw.trim().isEmpty) {
      return const RealUnitPayConfirmResultDto(txHash: null);
    }
    return RealUnitPayConfirmResultDto(txHash: raw);
  }
}
