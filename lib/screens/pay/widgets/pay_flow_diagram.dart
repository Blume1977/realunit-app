import 'package:flutter/material.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/styles/colors.dart';

/// The payment flow in one picture, as RealUnit asked for on 06.10.2026: the
/// shareholder sells REALU for ZCHF (1), the merchant receives the countervalue
/// for the goods (2). Three stations with one word under each icon, and the
/// two numbered steps explained below. Above the default text size the
/// stations stand one below the other so that word is not squeezed. The arrows
/// are decorative for screen readers; the legend carries the numbered steps.
class PayFlowDiagram extends StatelessWidget {
  const PayFlowDiagram({super.key});

  static const horizontalKey = Key('pay-flow-diagram-horizontal');
  static const verticalKey = Key('pay-flow-diagram-vertical');

  static const _maxHorizontalTextScale = 1.0;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final horizontal = MediaQuery.textScalerOf(context).scale(1) <= _maxHorizontalTextScale;
    final shareholder = _Station(icon: Icons.person_outline, label: s.payFlowShareholder);
    final zchf = _Station(icon: Icons.swap_horiz, label: s.payFlowZchf);
    final merchant = _Station(icon: Icons.storefront_outlined, label: s.payFlowMerchant);
    return Column(
      spacing: 16,
      crossAxisAlignment: .stretch,
      children: [
        if (horizontal)
          Row(
            key: horizontalKey,
            crossAxisAlignment: .start,
            children: [
              Expanded(child: shareholder),
              const _ArrowRight(step: 1),
              Expanded(child: zchf),
              const _ArrowRight(step: 2),
              Expanded(child: merchant),
            ],
          )
        else
          Column(
            key: verticalKey,
            spacing: 8,
            children: [
              shareholder,
              const _ArrowDown(step: 1),
              zchf,
              const _ArrowDown(step: 2),
              merchant,
            ],
          ),
        _Legend(step: 1, text: s.payFlowStep1),
        _Legend(step: 2, text: s.payFlowStep2),
      ],
    );
  }
}

class _Station extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Station({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 8,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: RealUnitColors.brand700,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 28, color: RealUnitColors.realUnitBlue),
        ),
        Text(
          label,
          textAlign: .center,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: RealUnitColors.neutral900,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StepBadge extends StatelessWidget {
  final int step;

  const _StepBadge({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: .center,
      decoration: const BoxDecoration(
        color: RealUnitColors.realUnitBlue,
        shape: BoxShape.circle,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$step',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: RealUnitColors.basic.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ArrowRight extends StatelessWidget {
  final int step;

  const _ArrowRight({required this.step});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 48,
        height: 56,
        child: Stack(
          alignment: .center,
          children: [
            Row(
              children: [
                Expanded(child: Container(height: 2, color: RealUnitColors.realUnitBlue)),
                const Icon(Icons.arrow_forward_ios, size: 10, color: RealUnitColors.realUnitBlue),
              ],
            ),
            _StepBadge(step: step),
          ],
        ),
      ),
    );
  }
}

class _ArrowDown extends StatelessWidget {
  final int step;

  const _ArrowDown({required this.step});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: 56,
        child: Stack(
          alignment: .center,
          children: [
            Column(
              children: [
                Expanded(child: Container(width: 2, color: RealUnitColors.realUnitBlue)),
                const Icon(Icons.keyboard_arrow_down, size: 16, color: RealUnitColors.realUnitBlue),
              ],
            ),
            _StepBadge(step: step),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final int step;
  final String text;

  const _Legend({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 8,
      crossAxisAlignment: .start,
      children: [
        _StepBadge(step: step),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: RealUnitColors.neutral600,
            ),
          ),
        ),
      ],
    );
  }
}
