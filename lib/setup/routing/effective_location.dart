import 'package:go_router/go_router.dart';

/// `RouteMatchList.uri` only reflects declarative (`go`) matches — after a
/// `push` (how the KYC flow is entered from Buy/Sell) it still reports the
/// base route underneath. Everything that judges or captures "where the user
/// is" must read this helper instead, or a pushed flow is invisible to it.
String effectiveLocation(RouteMatchList configuration) {
  final matches = configuration.matches;
  final last = matches.isEmpty ? null : matches.last;
  if (last is ImperativeRouteMatch) return last.matches.uri.toString();
  return configuration.uri.toString();
}
