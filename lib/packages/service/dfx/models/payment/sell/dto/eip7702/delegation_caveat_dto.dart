/// One signed caveat. The wire object has two strings, `enforcer` and `terms`.
class DelegationCaveatDto {
  final String enforcer;
  final String terms;

  const DelegationCaveatDto({required this.enforcer, required this.terms});

  factory DelegationCaveatDto.fromJson(Map<String, dynamic> json) {
    return DelegationCaveatDto(
      enforcer: json['enforcer'] as String,
      terms: json['terms'] as String,
    );
  }

  /// A non-object, or a field that is not a string, is the caveat rejection.
  /// Callers keep that exception instead of a cast error.
  static List<DelegationCaveatDto> listFrom(List<dynamic> raw) {
    final parsed = <DelegationCaveatDto>[];
    for (final element in raw) {
      if (element is! Map) {
        throw Exception('EIP-7702 caveats: a caveat is not an object');
      }
      try {
        parsed.add(DelegationCaveatDto.fromJson(Map<String, dynamic>.from(element)));
      } on TypeError {
        throw Exception('EIP-7702 caveats: a caveat is missing string enforcer or terms');
      }
    }
    return parsed;
  }
}
