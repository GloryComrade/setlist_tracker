import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../logic/show_math.dart';
import '../../logic/tour_stats.dart';
import '../../theme/app_theme.dart';

/// Chart marks use the bright twin of each venue light (DESIGN.md: bright
/// shades are for marks on the dark stage): cool cyan for Studio Sessions,
/// warm magenta for Live Shows.
const studioMark = StageColors.cyan;
const liveMark = StageColors.magenta;
const headlinerMark = StageColors.amber;
const ghostMark = StageColors.textMuted;

final _weekFmt = DateFormat('MMM d');
final _dayFmt = DateFormat('EEE, MMM d');

const _axisStyle = TextStyle(
  color: StageColors.textMuted,
  fontSize: 11,
  fontWeight: FontWeight.w600,
  fontFeatures: StageFonts.tabular,
);

const _tooltipTitle = TextStyle(
  color: StageColors.text,
  fontSize: 11,
  fontWeight: FontWeight.w800,
  letterSpacing: 1.0,
  height: 1.5,
);

const _tooltipBody = TextStyle(
  color: StageColors.textMuted,
  fontSize: 12,
  fontWeight: FontWeight.w600,
  height: 1.5,
);

/// "12.4" without the unit, for tight spots.
String _mi(double miles) => formatMiles(miles, withUnit: false);

/// A round step for axis lines: about four lines across [top].
double _niceStep(double top) {
  for (final s in const [2.0, 5.0, 10.0, 20.0, 25.0, 50.0]) {
    if (top / s <= 4) return s;
  }
  return 100;
}

// ---------------------------------------------------------------------------
// Weekly miles
// ---------------------------------------------------------------------------

/// Stacked bars, Studio under Live, one per week. A week with Tour miles
/// still to run shows a dashed outline up to the plan; a week that beat the
/// plan shows a white tick where the plan was.
class WeeklyMilesChart extends StatelessWidget {
  const WeeklyMilesChart({super.key, required this.weeks});
  final List<WeekMiles> weeks;

  bool get hasPlan => weeks.any((w) => (w.plannedMiles ?? 0) > 0);

  String semanticsLabel() {
    final logged = weeks.where((w) => w.totalMiles > 0).toList();
    final b = StringBuffer('Weekly miles, last ${weeks.length} weeks. ');
    if (logged.isEmpty) {
      b.write('No miles logged yet. ');
    } else {
      final best = logged.reduce((a, c) => c.totalMiles > a.totalMiles ? c : a);
      final avg = weeks.fold(0.0, (s, w) => s + w.totalMiles) / weeks.length;
      b.write(
        'Biggest week ${formatMiles(best.totalMiles)}, week of '
        '${_weekFmt.format(best.weekStart)}. '
        'Average ${formatMiles(double.parse(avg.toStringAsFixed(1)))} a week. ',
      );
    }
    for (final w in weeks) {
      b.write('Week of ${_weekFmt.format(w.weekStart)}: ');
      b.write(formatMiles(w.totalMiles));
      if (w.totalMiles > 0) {
        b.write(' (${_mi(w.studioMiles)} Studio, ${_mi(w.liveMiles)} Live)');
      }
      final p = w.plannedMiles;
      if (p != null && p > 0) b.write(', ${formatMiles(p)} planned');
      b.write('. ');
    }
    return b.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final top = weeks.fold(
      0.0,
      (m, w) => math.max(m, math.max(w.totalMiles, w.plannedMiles ?? 0)),
    );
    final step = _niceStep(top == 0 ? 8 : top);
    final maxY = math.max(step, ((top * 1.08) / step).ceil() * step);
    final tick = maxY * 0.012;
    final last = weeks.length - 1;

    return Semantics(
      container: true,
      label: semanticsLabel(),
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, box) {
            final slot = (box.maxWidth - 30) / weeks.length;
            final barWidth = (slot * 0.58).clamp(8.0, 30.0);
            return SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  minY: 0,
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: [
                    for (var i = 0; i < weeks.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [_rod(weeks[i], barWidth, tick)],
                      ),
                  ],
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: step,
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: StageColors.outline,
                      strokeWidth: 1,
                      dashArray: [2, 4],
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: const Border(
                      bottom: BorderSide(color: StageColors.outline),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: step,
                        getTitlesWidget: (v, meta) => SideTitleWidget(
                          meta: meta,
                          space: 6,
                          child: Text(_mi(v), style: _axisStyle),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if ((last - i) % 3 != 0) {
                            return const SizedBox.shrink();
                          }
                          final isNow = i == last;
                          return SideTitleWidget(
                            meta: meta,
                            space: 8,
                            fitInside: SideTitleFitInsideData.fromTitleMeta(
                              meta,
                            ),
                            child: Text(
                              isNow
                                  ? 'This wk'
                                  : _weekFmt.format(weeks[i].weekStart),
                              style: isNow
                                  ? _axisStyle.copyWith(
                                      color: StageColors.text,
                                      fontWeight: FontWeight.w800,
                                    )
                                  : _axisStyle,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => StageColors.surfaceHigh,
                      tooltipBorder: const BorderSide(
                        color: StageColors.outline,
                      ),
                      tooltipBorderRadius: BorderRadius.circular(12),
                      tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      maxContentWidth: 170,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItem: (group, _, _, _) =>
                          _tooltip(weeks[group.x]),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  BarChartRodData _rod(WeekMiles w, double width, double tick) {
    final s = w.studioMiles;
    final a = w.totalMiles;
    final p = w.plannedMiles ?? 0;
    final ghost = p > a;
    return BarChartRodData(
      toY: math.max(a, p),
      width: width,
      color: Colors.transparent,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      borderSide: ghost
          ? const BorderSide(color: ghostMark, width: 1.2)
          : BorderSide.none,
      borderDashArray: ghost ? const [3, 3] : null,
      rodStackItems: [
        if (s > 0) BarChartRodStackItem(0, s, studioMark),
        if (a > s) BarChartRodStackItem(s, a, liveMark),
        if (p > 0 && !ghost)
          BarChartRodStackItem(math.max(0, p - tick), p, StageColors.text),
      ],
    );
  }

  BarTooltipItem _tooltip(WeekMiles w) {
    final p = w.plannedMiles;
    return BarTooltipItem(
      'WEEK OF ${_weekFmt.format(w.weekStart).toUpperCase()}\n',
      _tooltipTitle,
      textAlign: TextAlign.left,
      children: [
        TextSpan(
          text: formatMiles(w.totalMiles),
          style: _tooltipTitle.copyWith(fontSize: 13),
        ),
        if (w.totalMiles > 0)
          TextSpan(
            text: '\nStudio ${_mi(w.studioMiles)} · Live ${_mi(w.liveMiles)}',
            style: _tooltipBody,
          ),
        if (p != null && p > 0)
          TextSpan(text: '\nPlanned ${formatMiles(p)}', style: _tooltipBody),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Headliner progression
// ---------------------------------------------------------------------------

/// Headliners on a time axis: logged ones solid amber, upcoming Tour ones
/// as a dashed ghost, and the 18–20 mi peak band most plans build toward.
class HeadlinerChart extends StatelessWidget {
  HeadlinerChart({
    super.key,
    required List<HeadlinerPoint> points,
    required this.now,
  }) : logged = [
         for (final p in points)
           if (!p.planned) p,
       ],
       planned = _upcoming(points);

  final List<HeadlinerPoint> logged;
  final List<HeadlinerPoint> planned;
  final DateTime now;

  static const peakLow = 18.0;
  static const peakHigh = 20.0;

  /// Planned Headliners, minus any already run on that day.
  static List<HeadlinerPoint> _upcoming(List<HeadlinerPoint> points) {
    final ran = {
      for (final p in points)
        if (!p.planned) p.date,
    };
    return [
      for (final p in points)
        if (p.planned && !ran.contains(p.date)) p,
    ];
  }

  bool get isEmpty => logged.isEmpty && planned.isEmpty;

  HeadlinerPoint? get longest => logged.isEmpty
      ? null
      : logged.reduce((a, b) => b.miles >= a.miles ? b : a);

  HeadlinerPoint? get next => planned.isEmpty ? null : planned.first;

  String semanticsLabel() {
    final b = StringBuffer('Headliner progression. ');
    final l = longest;
    if (l == null) {
      b.write('No Headliners logged yet. ');
    } else {
      b.write(
        '${logged.length} logged, longest ${formatMiles(l.miles)} on '
        '${_dayFmt.format(l.date)}. ',
      );
      b.write(
        'Logged: ${logged.map((p) => '${_weekFmt.format(p.date)} ${formatMiles(p.miles)}').join(', ')}. ',
      );
    }
    final n = next;
    if (n != null) {
      final peak = planned.fold(0.0, (m, p) => math.max(m, p.miles));
      b.write(
        '${planned.length} planned, next ${formatMiles(n.miles)} on '
        '${_dayFmt.format(n.date)}, peaking at ${formatMiles(peak)}. ',
      );
    }
    b.write('Peak band ${_mi(peakLow)} to ${formatMiles(peakHigh)}.');
    return b.toString();
  }

  static int _days(DateTime a, DateTime b) => DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  @override
  Widget build(BuildContext context) {
    final all = [...logged, ...planned];
    final origin = all.first.date;
    double x(DateTime d) => _days(origin, d).toDouble();

    final span = math.max(6, x(all.last.date).toInt());
    final step = (span / 3).ceil().toDouble();
    final minX = all.length == 1 ? -step : 0.0;
    final maxX = all.length == 1 ? step : step * 3;
    final top = all.fold(0.0, (m, p) => math.max(m, p.miles));
    final maxY = math.max(22.0, (top / 5).ceil() * 5 + 2.0);
    final todayX = x(now);

    final loggedSpots = [for (final p in logged) FlSpot(x(p.date), p.miles)];
    final plannedSpots = [
      if (loggedSpots.isNotEmpty) loggedSpots.last,
      for (final p in planned) FlSpot(x(p.date), p.miles),
    ];
    final bridge = loggedSpots.isNotEmpty;

    return Semantics(
      container: true,
      label: semanticsLabel(),
      child: ExcludeSemantics(
        child: SizedBox(
          height: 210,
          child: LineChart(
            LineChartData(
              minX: minX,
              maxX: maxX,
              minY: 0,
              maxY: maxY,
              clipData: const FlClipData.none(),
              rangeAnnotations: RangeAnnotations(
                horizontalRangeAnnotations: [
                  HorizontalRangeAnnotation(
                    y1: peakLow,
                    y2: peakHigh,
                    color: liveMark.withValues(alpha: 0.14),
                  ),
                ],
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: peakHigh,
                    color: liveMark.withValues(alpha: 0.45),
                    strokeWidth: 1,
                    dashArray: const [2, 3],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topLeft,
                      padding: const EdgeInsets.only(left: 4, bottom: 3),
                      style: const TextStyle(
                        color: liveMark,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                      labelResolver: (_) => 'PEAK 18–20 MI',
                    ),
                  ),
                ],
                verticalLines: [
                  if (planned.isNotEmpty && todayX >= minX && todayX <= maxX)
                    VerticalLine(
                      x: todayX,
                      color: StageColors.textMuted.withValues(alpha: 0.6),
                      strokeWidth: 1,
                      dashArray: const [2, 3],
                      label: VerticalLineLabel(
                        show: true,
                        // Bottom of the line, clear of the peak band label
                        // at the top.
                        alignment: Alignment.bottomRight,
                        padding: const EdgeInsets.only(left: 4, bottom: 2),
                        style: const TextStyle(
                          color: StageColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                        labelResolver: (_) => 'TODAY',
                      ),
                    ),
                ],
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: 5,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: StageColors.outline,
                  strokeWidth: 1,
                  dashArray: [2, 4],
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: const Border(
                  bottom: BorderSide(color: StageColors.outline),
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 5,
                    // Only the round lines; skip fl_chart's extra top label.
                    getTitlesWidget: (v, meta) => v % 5 != 0
                        ? const SizedBox.shrink()
                        : SideTitleWidget(
                            meta: meta,
                            space: 6,
                            child: Text(_mi(v), style: _axisStyle),
                          ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: step,
                    getTitlesWidget: (v, meta) => SideTitleWidget(
                      meta: meta,
                      space: 8,
                      fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                      child: Text(
                        _weekFmt.format(
                          DateTime(
                            origin.year,
                            origin.month,
                            origin.day + v.round(),
                          ),
                        ),
                        style: _axisStyle,
                      ),
                    ),
                  ),
                ),
              ),
              lineBarsData: [
                if (plannedSpots.length > (bridge ? 1 : 0))
                  LineChartBarData(
                    spots: plannedSpots,
                    color: ghostMark,
                    barWidth: 2,
                    dashArray: const [4, 4],
                    dotData: FlDotData(
                      checkToShowDot: (spot, _) =>
                          !(bridge && spot == loggedSpots.last),
                      getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                        radius: 3.5,
                        color: StageColors.surface,
                        strokeWidth: 2,
                        strokeColor: ghostMark,
                      ),
                    ),
                  ),
                if (loggedSpots.isNotEmpty)
                  LineChartBarData(
                    spots: loggedSpots,
                    color: headlinerMark,
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          headlinerMark.withValues(alpha: 0.22),
                          headlinerMark.withValues(alpha: 0),
                        ],
                      ),
                    ),
                    dotData: FlDotData(
                      getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                        radius: 4.5,
                        color: headlinerMark,
                        strokeWidth: 2,
                        strokeColor: StageColors.surface,
                      ),
                    ),
                  ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => StageColors.surfaceHigh,
                  tooltipBorder: const BorderSide(color: StageColors.outline),
                  tooltipBorderRadius: BorderRadius.circular(12),
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  maxContentWidth: 170,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (spots) => [
                    for (final s in spots)
                      // The ghost line starts on the last logged dot; let the
                      // logged line speak for that one.
                      if (s.bar.color == ghostMark &&
                          bridge &&
                          s.spotIndex == 0)
                        null
                      else
                        LineTooltipItem(
                          '${_dayFmt.format(DateTime(origin.year, origin.month, origin.day + s.x.round())).toUpperCase()}\n',
                          _tooltipTitle,
                          textAlign: TextAlign.left,
                          children: [
                            TextSpan(
                              text: formatMiles(s.y),
                              style: _tooltipTitle.copyWith(fontSize: 13),
                            ),
                            TextSpan(
                              text: s.bar.color == ghostMark
                                  ? '  Planned'
                                  : '  Headliner',
                              style: _tooltipBody,
                            ),
                          ],
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Studio vs Live
// ---------------------------------------------------------------------------

/// One split bar: Studio share on the left in cyan, Live on the right in
/// magenta, with the numbers underneath.
class VenueSplitBar extends StatelessWidget {
  const VenueSplitBar({
    super.key,
    required this.label,
    required this.studio,
    required this.live,
    required this.format,
  });

  final String label;
  final double studio;
  final double live;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final total = studio + live;
    final share = total == 0 ? 0.0 : studio / total;
    final studioPct = (share * 100).round();
    final livePct = total == 0 ? 0 : 100 - studioPct;
    final studioFlex = (share * 1000).round();
    final liveFlex = 1000 - studioFlex;
    final numbers = Theme.of(context).textTheme.titleLarge
        ?.copyWith(fontFeatures: StageFonts.tabular);

    return Semantics(
      container: true,
      label:
          '$label: Studio Sessions ${format(studio)}, $studioPct percent. '
          'Live Shows ${format(live)}, $livePct percent.',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: StageColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                width: double.infinity,
                child: total == 0
                    ? const ColoredBox(color: StageColors.surfaceHigh)
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (studioFlex > 0)
                            Expanded(
                              flex: studioFlex,
                              child: const ColoredBox(color: studioMark),
                            ),
                          if (studioFlex > 0 && liveFlex > 0)
                            const SizedBox(width: 2),
                          if (liveFlex > 0)
                            Expanded(
                              flex: liveFlex,
                              child: const ColoredBox(color: liveMark),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _SplitSide(
                    icon: Icons.graphic_eq,
                    color: studioMark,
                    value: format(studio),
                    pct: '$studioPct%',
                    style: numbers,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SplitSide(
                    icon: Icons.landscape,
                    color: liveMark,
                    value: format(live),
                    pct: '$livePct%',
                    style: numbers,
                    end: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SplitSide extends StatelessWidget {
  const _SplitSide({
    required this.icon,
    required this.color,
    required this.value,
    required this.pct,
    required this.style,
    this.end = false,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String pct;
  final TextStyle? style;
  final bool end;

  @override
  Widget build(BuildContext context) {
    final children = [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: end ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(value, style: style, maxLines: 1),
        ),
      ),
      const SizedBox(width: 6),
      Text(pct, style: _axisStyle.copyWith(fontSize: 12, color: color)),
    ];
    return Row(
      mainAxisAlignment: end ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: end ? children.reversed.toList() : children,
    );
  }
}

// ---------------------------------------------------------------------------
// Legend
// ---------------------------------------------------------------------------

enum SwatchKind { block, dashed, dot, ring, band }

class LegendItem extends StatelessWidget {
  const LegendItem({
    super.key,
    required this.label,
    required this.color,
    this.kind = SwatchKind.block,
  });

  final String label;
  final Color color;
  final SwatchKind kind;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(14, 12),
          painter: _SwatchPainter(color, kind),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: StageColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SwatchPainter extends CustomPainter {
  _SwatchPainter(this.color, this.kind);
  final Color color;
  final SwatchKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final c = rect.center;
    switch (kind) {
      case SwatchKind.block:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(3)),
          fill,
        );
      case SwatchKind.band:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(3)),
          Paint()..color = color.withValues(alpha: 0.3),
        );
      case SwatchKind.dot:
        canvas.drawCircle(c, 4.5, fill);
      case SwatchKind.ring:
        canvas.drawCircle(c, 3.8, stroke);
      case SwatchKind.dashed:
        final r = rect.deflate(1.5);
        final path = Path()..addRect(r);
        for (final m in path.computeMetrics()) {
          for (var d = 0.0; d < m.length; d += 5) {
            canvas.drawPath(m.extractPath(d, d + 2.5), stroke);
          }
        }
    }
  }

  @override
  bool shouldRepaint(_SwatchPainter old) =>
      old.color != color || old.kind != kind;
}
