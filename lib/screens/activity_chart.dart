import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// The Daily / Weekly / Monthly area chart from the web dashboard.
///
/// Hand-painted rather than pulling in a charting package: it is one line plus
/// a gradient fill, and this keeps the app's dependency list short.
class ActivityChart extends StatefulWidget {
  final String title;
  final ChartSeries series;

  const ActivityChart({super.key, required this.title, required this.series});

  @override
  State<ActivityChart> createState() => _ActivityChartState();
}

class _ActivityChartState extends State<ActivityChart> {
  String _range = 'daily';

  List<LabelCount> get _points => widget.series.of(_range);

  @override
  Widget build(BuildContext context) {
    final points = _points;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.ink700,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              _RangeToggle(
                value: _range,
                onChanged: (r) => setState(() => _range = r),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (points.every((p) => p.count == 0))
            const SizedBox(
              height: 140,
              child: Center(
                child: Text('No activity yet.', style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else ...[
            SizedBox(
              height: 140,
              width: double.infinity,
              child: CustomPaint(painter: _AreaPainter(points)),
            ),
            const SizedBox(height: 8),
            // Only the ends are labelled; a full axis is unreadable at this width.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(points.first.label,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                Text(points.last.label,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RangeToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _RangeToggle({required this.value, required this.onChanged});

  static const _ranges = {'daily': 'D', 'weekly': 'W', 'monthly': 'M'};

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.ink600,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _ranges.entries.map((e) {
          final selected = e.key == value;
          return GestureDetector(
            onTap: () => onChanged(e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: selected ? AppColors.gold : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(e.value,
                  style: TextStyle(
                    color: selected ? AppColors.ink : Colors.white70,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  )),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AreaPainter extends CustomPainter {
  final List<LabelCount> points;
  _AreaPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final maxValue = points.map((p) => p.count).reduce((a, b) => a > b ? a : b);
    final top = maxValue == 0 ? 1.0 : maxValue.toDouble();
    final dx = size.width / (points.length - 1);

    Offset at(int i) => Offset(
          i * dx,
          size.height - (points[i].count / top) * (size.height - 8) - 4,
        );

    // Horizontal guides behind the line.
    final guide = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guide);
    }

    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x66F9B233), Color(0x00F9B233)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.gold
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    // Dot on the most recent point.
    final last = at(points.length - 1);
    canvas.drawCircle(last, 4, Paint()..color = AppColors.gold);
    canvas.drawCircle(last, 7, Paint()..color = AppColors.gold.withValues(alpha: 0.25));
  }

  @override
  bool shouldRepaint(_AreaPainter old) => old.points != points;
}
