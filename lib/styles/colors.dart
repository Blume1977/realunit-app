import 'dart:ui';

class RealUnitColors {
  static final basic = _Basic();
  static final status = _Status();

  static const realUnitBlue = Color.fromARGB(255, 25, 136, 198);
  static const realUnitBlack = Color.fromARGB(255, 52, 50, 51);
  static const brand200 = Color(0xFFD1E6F5);
  static const brand700 = Color.fromARGB(255, 236, 243, 249);
  static const darkBlue = Color.fromARGB(255, 3, 76, 129);
  static const green = Color.fromARGB(255, 76, 172, 54);
  static const okker = Color(0xFFE9AD3F);

  static const neutral900 = Color.fromARGB(255, 15, 23, 42);
  static const neutral600 = Color(0xFF475569);
  static const neutral500 = Color.fromARGB(255, 100, 116, 139);
  static const neutral400 = Color.fromARGB(255, 148, 163, 184);
  static const neutral300 = Color(0xFFCED5DE);
  static const neutral200 = Color.fromARGB(255, 226, 232, 240);
  static const neutral100 = Color.fromARGB(255, 242, 245, 248);
  static const neutral50 = Color(0xFFF8FAFC);

  static const payActivityDaily = Color(0xFFFF4D00);
  static const payActivityWeekly = Color(0xFFFF7A29);
  static const payActivityMonthly = Color(0xFFFFA05C);
  static const payActivityIdle = Color(0xFFFFC48F);
  static const payActivityNone = Color(0xFFFFE3CC);
}

class _Basic {
  final white = const Color(0xFFFFFFFF);
  final black = const Color(0xFF000000);
}

class _Status {
  final red600 = const Color(0xFFE02523);
  final red100 = const Color(0xFFFCE8E8);
}
