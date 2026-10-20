import 'package:flutter/material.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/styles/colors.dart';

/// The payment flow in one picture, as RealUnit sent it on 06.10.2026 and
/// corrected it on 19.10.2026: the shareholder sells REALU for ZCHF (1), the
/// merchant is paid with the ZCHF (2). Three stations with one word under each
/// icon, and the two numbered steps explained below. The middle station is the
/// coin from RealUnit's picture: a ring with its exchange glyph inside. Above
/// the default text size the stations stand one below the other so that word
/// is not squeezed. The arrows are decorative for screen readers; the legend
/// carries the numbered steps.
///
/// [compact] is the small picture on the scanner: the three stations in one
/// row with plain arrows, no step numbers and no legend. The host makes it a
/// button that opens the full picture again.
class PayFlowDiagram extends StatelessWidget {
  final bool compact;

  const PayFlowDiagram({super.key, this.compact = false});

  static const horizontalKey = Key('pay-flow-diagram-horizontal');
  static const verticalKey = Key('pay-flow-diagram-vertical');
  static const compactKey = Key('pay-flow-diagram-compact');

  static const _maxHorizontalTextScale = 1.0;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (compact) {
      return Row(
        key: compactKey,
        crossAxisAlignment: .start,
        children: [
          Expanded(
            child: _Station(
              glyph: const Icon(Icons.person_outline, size: 18, color: RealUnitColors.realUnitBlue),
              label: s.payFlowShareholder,
              compact: true,
            ),
          ),
          const _ArrowRight(compact: true),
          Expanded(
            child: _Station(
              glyph: const _ZchfCoin(compact: true),
              label: s.payFlowZchf,
              compact: true,
            ),
          ),
          const _ArrowRight(compact: true),
          Expanded(
            child: _Station(
              glyph: const Icon(
                Icons.storefront_outlined,
                size: 18,
                color: RealUnitColors.realUnitBlue,
              ),
              label: s.payFlowMerchant,
              compact: true,
            ),
          ),
        ],
      );
    }
    final horizontal = MediaQuery.textScalerOf(context).scale(1) <= _maxHorizontalTextScale;
    final shareholder = _Station(
      glyph: const Icon(Icons.person_outline, size: 28, color: RealUnitColors.realUnitBlue),
      label: s.payFlowShareholder,
    );
    final zchf = _Station(glyph: const _ZchfCoin(), label: s.payFlowZchf);
    final merchant = _Station(
      glyph: const Icon(Icons.storefront_outlined, size: 28, color: RealUnitColors.realUnitBlue),
      label: s.payFlowMerchant,
    );
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

/// The ZCHF coin as RealUnit drew it: a ring, and inside it two bars with a
/// half head each, the upper one to the right, the lower one to the left.
/// Not two arrows, so it is painted by hand instead of using an arrow icon.
class _ZchfCoin extends StatelessWidget {
  final bool compact;

  const _ZchfCoin({this.compact = false});

  static const coinKey = Key('pay-flow-zchf-coin');

  @override
  Widget build(BuildContext context) {
    final size = compact ? 18.0 : 28.0;
    return CustomPaint(
      key: coinKey,
      size: Size.square(size),
      painter: const _ZchfCoinPainter(RealUnitColors.realUnitBlue),
    );
  }
}

class _ZchfCoinPainter extends CustomPainter {
  final Color color;

  const _ZchfCoinPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final stroke = w / 11;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(Offset(w / 2, w / 2), (w - stroke) / 2, paint);

    // The bars inside are thinner than the ring.
    final glyph = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final left = w * 0.3;
    final right = w * 0.7;
    final head = w * 0.13;
    final upper = w * 0.43;
    final lower = w * 0.57;
    // Upper bar to the right, half head above the tip.
    canvas.drawPath(
      Path()
        ..moveTo(left, upper)
        ..lineTo(right, upper)
        ..lineTo(right - head, upper - head),
      glyph,
    );
    // Lower bar to the left, half head below the tip.
    canvas.drawPath(
      Path()
        ..moveTo(right, lower)
        ..lineTo(left, lower)
        ..lineTo(left + head, lower + head),
      glyph,
    );
  }

  @override
  bool shouldRepaint(_ZchfCoinPainter oldDelegate) => oldDelegate.color != color;
}

class _Station extends StatelessWidget {
  final Widget glyph;
  final String label;
  final bool compact;

  const _Station({required this.glyph, required this.label, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 36.0 : 56.0;
    return Column(
      spacing: compact ? 4 : 8,
      children: [
        Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: RealUnitColors.brand700,
            shape: BoxShape.circle,
          ),
          child: Center(child: glyph),
        ),
        Text(
          label,
          textAlign: .center,
          // The small picture has narrow columns: a long name may take a
          // second line there before it is cut.
          maxLines: compact ? 2 : 1,
          softWrap: compact,
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
  /// Null on the compact picture, which carries no legend to number.
  final int? step;
  final bool compact;

  const _ArrowRight({this.step, this.compact = false}) : assert(compact == (step == null));

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: compact ? 24 : 48,
        height: compact ? 36 : 56,
        child: Stack(
          alignment: .center,
          children: [
            Row(
              children: [
                Expanded(child: Container(height: 2, color: RealUnitColors.realUnitBlue)),
                const Icon(Icons.arrow_forward_ios, size: 10, color: RealUnitColors.realUnitBlue),
              ],
            ),
            if (step case final step?) _StepBadge(step: step),
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
