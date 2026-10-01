import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class _CustomIcon extends StatelessWidget {
  final String iconPath;
  final double? size;
  final Color? color;

  const _CustomIcon({required this.iconPath, this.size, this.color});

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        iconPath,
        width: size,
        height: size,
        colorFilter:
            color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
      );
}

class LanguagesIcon extends _CustomIcon {
  const LanguagesIcon({super.size, super.color})
      : super(iconPath: 'assets/images/icons/globe-alt.svg');
}

class CurrencyIcon extends _CustomIcon {
  const CurrencyIcon({super.size, super.color})
      : super(iconPath: 'assets/images/icons/currency-euro.svg');
}

class DocumentReportIcon extends _CustomIcon {
  const DocumentReportIcon({super.size, super.color})
      : super(iconPath: 'assets/images/icons/document-report.svg');
}

class DocumentTextIcon extends _CustomIcon {
  const DocumentTextIcon({super.size, super.color})
      : super(iconPath: 'assets/images/icons/document-text.svg');
}

class IdentificationIcon extends _CustomIcon {
  const IdentificationIcon({super.size, super.color})
      : super(iconPath: 'assets/images/icons/identification.svg');
}

class UserCircleIcon extends _CustomIcon {
  const UserCircleIcon({super.size, super.color})
      : super(iconPath: 'assets/images/icons/user-circle.svg');
}

class KeySolidIcon extends _CustomIcon {
  const KeySolidIcon({super.size, super.color})
      : super(iconPath: 'assets/images/icons/key-solid.svg');
}

class XCircleIcon extends _CustomIcon {
  const XCircleIcon({super.size, super.color})
      : super(iconPath: 'assets/images/icons/x-circle.svg');
}

class NodesIcon extends _CustomIcon {
  const NodesIcon({super.size, super.color})
      : super(iconPath: 'assets/images/icons/setting_nodes.svg');
}

class RecoveryKeyIcon extends _CustomIcon {
  const RecoveryKeyIcon({super.size, super.color})
      : super(iconPath: 'assets/images/icons/recovery_key.svg');
}

class GrowthIcon extends _CustomIcon {
  const GrowthIcon({super.size, super.color})
      : super(iconPath: 'assets/images/icons/growth.svg');
}

class RealUnitIcon extends _CustomIcon {
  const RealUnitIcon({super.size, super.color})
      : super(iconPath: 'assets/images/icons/realunit_icon.svg');
}

class RealUnitTokenIcon extends _CustomIcon {
  const RealUnitTokenIcon({super.size, super.color})
      : super(iconPath: 'assets/images/icons/realunit_token.svg');
}

