import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:realunit_wallet/generated/i18n.dart';
import 'package:realunit_wallet/models/portfolio_value_point.dart';
import 'package:realunit_wallet/packages/utils/format_fixed.dart';
import 'package:realunit_wallet/packages/utils/group_swiss_digits.dart';
import 'package:realunit_wallet/screens/dashboard/bloc/portfolio_chart/portfolio_chart_cubit.dart';
import 'package:realunit_wallet/screens/dashboard/models/time_period.dart';
import 'package:realunit_wallet/screens/dashboard/widgets/portfolio_chart.dart';
import 'package:realunit_wallet/screens/dashboard/widgets/time_period_selection_button.dart';
import 'package:realunit_wallet/screens/settings/bloc/settings_bloc.dart';

class DashboardPortfolioChartWidget extends StatelessWidget {
  final BigInt currentValue;
  final List<PortfolioValuePoint> portfolioHistory;

  const DashboardPortfolioChartWidget({
    super.key,
    required this.currentValue,
    required this.portfolioHistory,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      key: ValueKey(portfolioHistory.hashCode),
      create: (context) => PortfolioChartCubit(portfolioHistory),
      child: DashboardPortfolioChartView(
        currentValue: currentValue,
        portfolioHistory: portfolioHistory,
      ),
    );
  }
}

class DashboardPortfolioChartView extends StatelessWidget {
  final BigInt currentValue;
  final List<PortfolioValuePoint> portfolioHistory;

  const DashboardPortfolioChartView({
    super.key,
    required this.currentValue,
    required this.portfolioHistory,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const .only(top: 8),
    child: SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const .symmetric(vertical: 12, horizontal: 20),
            child: BlocBuilder<SettingsBloc, SettingsState>(
              builder: (context, settingsState) {
                return Row(
                  spacing: 12.0,
                  children: [
                    Column(
                      crossAxisAlignment: .start,
                      children: [
                        Text(
                          S.of(context).portfolioDevelopment,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: .w600),
                        ),
                        Row(
                          spacing: 12.0,
                          crossAxisAlignment: .center,
                          children: [
                            Row(
                              crossAxisAlignment: .start,
                              children: [
                                Text(
                                  settingsState.currency.code.toUpperCase(),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.copyWith(fontWeight: .w600),
                                ),
                                Text(
                                  currentValue == BigInt.zero
                                      ? '--.--'
                                      : groupSwissDigits(
                                          formatFixed(currentValue, 2, trimZeros: false),
                                        ),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.copyWith(fontWeight: .w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    Flexible(
                      child: BlocBuilder<PortfolioChartCubit, PortfolioChartState>(
                        builder: (context, state) {
                          if (state.visibleSpots.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final firstValue = state.visibleSpots.first.y;
                          final lastValue = state.visibleSpots.last.y;
                          final difference = lastValue - firstValue;
                          final percentChange = firstValue != 0
                              ? (difference / firstValue) * 100
                              : 0.0;
                          final sign = difference >= 0 ? '+' : '';
                          final money = groupSwissDigits(difference.toStringAsFixed(2));
                          final percent = percentChange.toStringAsFixed(2);

                          return Column(
                            crossAxisAlignment: .start,
                            children: [
                              Text(
                                state.selectedPeriod.name(context),
                                style:
                                    Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                      height: 16 / 10,
                                    ),
                              ),
                              Text(
                                '$sign$money ${settingsState.currency.code.toUpperCase()} | '
                                '$sign$percent%',
                                style:
                                    Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                      height: 16 / 10,
                                      fontWeight: .w600,
                                    ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const PortfolioChart(),
          BlocBuilder<PortfolioChartCubit, PortfolioChartState>(
            builder: (context, state) {
              return Padding(
                padding: const .symmetric(horizontal: 20.0),
                child: Row(
                  children: TimePeriod.values.map((period) {
                    return Expanded(
                      child: TimePeriodSelectionButton(
                        period.name(context).toUpperCase(),
                        isSelected: state.selectedPeriod == period,
                        onTap: () => context.read<PortfolioChartCubit>().selectPeriod(period),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}
