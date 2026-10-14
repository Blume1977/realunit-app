import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:realunit_wallet/packages/utils/format_fixed.dart';
import 'package:realunit_wallet/packages/utils/group_swiss_digits.dart';
import 'package:realunit_wallet/screens/dashboard/bloc/price_chart/price_chart_cubit.dart';
import 'package:realunit_wallet/screens/dashboard/bloc/price_chart/price_chart_state.dart';
import 'package:realunit_wallet/styles/colors.dart';

class PriceChart extends StatelessWidget {
  const PriceChart({super.key});

  static const int _horizontalDivisions = 5;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PriceChartCubit, PriceChartState>(
      builder: (context, state) {
        return SizedBox(
          height: 126,
          child: LineChart(
            _buildChartData(state),
            duration: Duration.zero,
          ),
        );
      },
    );
  }

  LineChartData _buildChartData(PriceChartState state) {
    return LineChartData(
      minX: state.minX,
      maxX: state.maxX,
      minY: state.minY,
      maxY: state.maxY,
      clipData: const FlClipData.none(),
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      extraLinesData: ExtraLinesData(
        horizontalLines: _buildHorizontalLines(state.minY, state.maxY),
      ),
      lineBarsData: [_buildLineBar(state.visibleSpots)],
      lineTouchData: _buildTouchData(),
    );
  }

  List<HorizontalLine> _buildHorizontalLines(double minY, double maxY) {
    return List.generate(_horizontalDivisions + 1, (index) {
      final ratio = index / _horizontalDivisions;
      final y = maxY - ((maxY - minY) * ratio);
      final showLabel = index == 0 || index == _horizontalDivisions;

      return HorizontalLine(
        y: y,
        color: RealUnitColors.neutral400,
        dashArray: const [1, 3],
        strokeWidth: 1,
        label: showLabel
            ? HorizontalLineLabel(
                show: true,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20.0, top: -16.0),
                style: const TextStyle(
                  color: RealUnitColors.neutral400,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
                labelResolver: (line) => groupSwissDigits(
                  formatFixed(
                    BigInt.from((line.y * 100).round()),
                    2,
                  ),
                ),
              )
            : null,
      );
    });
  }

  LineChartBarData _buildLineBar(List<FlSpot> visibleSpots) {
    return LineChartBarData(
      spots: visibleSpots,
      isCurved: true,
      color: RealUnitColors.darkBlue,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromRGBO(185, 221, 241, 0.6),
            Color.fromRGBO(185, 221, 241, 0.2),
            Color.fromRGBO(185, 221, 241, 0.0),
          ],
          stops: [0.0, 0.3638, 1.0],
        ),
      ),
    );
  }

  LineTouchData _buildTouchData() {
    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        fitInsideHorizontally: true,
        tooltipMargin: 0,
        getTooltipItems: (touchedSpots) => touchedSpots.map((touchedSpot) {
          final date = DateTime.fromMillisecondsSinceEpoch(touchedSpot.x.toInt());
          final price = touchedSpot.y;
          return LineTooltipItem(
            '${date.day}.${date.month}.${date.year}\n'
            '${groupSwissDigits(formatFixed(BigInt.from((price * 100).round()), 2))}',
            const TextStyle(
              color: RealUnitColors.neutral500,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          );
        }).toList(),
        getTooltipColor: (_) => Colors.transparent,
      ),
      getTouchLineStart: (barData, spotIndex) => -double.infinity,
      getTouchLineEnd: (barData, spotIndex) => double.infinity,
      getTouchedSpotIndicator: (barData, spotIndexes) => spotIndexes.map((index) {
        return const TouchedSpotIndicatorData(
          FlLine(color: RealUnitColors.neutral200, dashArray: [4, 4]),
          FlDotData(show: true),
        );
      }).toList(),
    );
  }
}
