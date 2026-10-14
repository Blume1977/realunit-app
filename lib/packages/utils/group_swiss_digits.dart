/// Groups a machine number the Swiss way: `332323.12` becomes `332'323.12`.
///
/// Thousands mark is the ASCII apostrophe. The decimal mark stays `.`.
/// [formatFixed] stays ungrouped because chart math parses it back.
/// Anything that is not an optional minus, digits, and an optional
/// fractional part is returned unchanged (`--.--`, `***.**`).
String groupSwissDigits(String value) {
  if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(value)) return value;

  final negative = value.startsWith('-');
  final body = negative ? value.substring(1) : value;
  final dot = body.indexOf('.');
  final whole = dot < 0 ? body : body.substring(0, dot);
  final fraction = dot < 0 ? null : body.substring(dot + 1);
  final grouped = _groupThousands(whole);
  final sign = negative ? '-' : '';
  if (fraction == null) return '$sign$grouped';
  return '$sign$grouped.$fraction';
}

String _groupThousands(String digits) {
  if (digits.length <= 3) return digits;
  final lead = digits.length % 3;
  final buffer = StringBuffer();
  var index = 0;
  if (lead != 0) {
    buffer.write(digits.substring(0, lead));
    index = lead;
  }
  while (index < digits.length) {
    if (buffer.isNotEmpty) buffer.write("'");
    buffer.write(digits.substring(index, index + 3));
    index += 3;
  }
  return buffer.toString();
}
