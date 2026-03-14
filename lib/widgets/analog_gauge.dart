import 'package:flutter/material.dart';
import 'dart:math';

class AnalogGauge extends StatefulWidget {
  final double level; // 0.0 - 1.0
  final double dbValue;

  const AnalogGauge({super.key, required this.level, required this.dbValue});

  @override
  State<AnalogGauge> createState() => _AnalogGaugeState();
}

class _AnalogGaugeState extends State<AnalogGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _needle;
  double _prevLevel = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _needle = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(AnalogGauge old) {
    super.didUpdateWidget(old);
    if (old.level != widget.level) {
      _needle = Tween<double>(begin: _prevLevel, end: widget.level).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
      );
      _prevLevel = widget.level;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _needle,
      builder: (_, __) {
        final db = widget.dbValue;
        final peak = db.isInfinite ? '-∞' : db.toStringAsFixed(1);

        return Column(
          children: [
            SizedBox(
              height: 180,
              child: CustomPaint(
                painter: _GaugePainter(_needle.value),
                size: const Size(double.infinity, 180),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statBox('PEAK', '$peak dB'),
                _statBox('SEVİYE', '${(_needle.value * 100).toInt()}%'),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _statBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F0A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1A3A1A)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF3A7A3A), fontSize: 10, fontFamily: 'monospace', letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Color(0xFF00FF88), fontSize: 18, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double level; // 0.0 - 1.0

  _GaugePainter(this.level);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.88;
    final r  = size.height * 0.82;

    const startAngle = pi;       // 180°
    const sweepAngle = pi;       // 180° sweep

    // Colored arc segments
    final segments = [
      (0.00, 0.20, const Color(0xFF1A6AFF)), // 0–20 dB quiet (blue)
      (0.20, 0.50, const Color(0xFF00CC44)), // 20–50 dB speech (green)
      (0.50, 0.70, const Color(0xFFFFDD00)), // 50–70 dB normal (yellow)
      (0.70, 0.85, const Color(0xFFFF8800)), // 70–85 dB loud (orange)
      (0.85, 1.00, const Color(0xFFFF2222)), // 85–120 dB danger (red)
    ];

    for (final seg in segments) {
      final sAngle = startAngle + sweepAngle * seg.$1;
      final eAngle = sweepAngle * (seg.$2 - seg.$1);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        sAngle, eAngle, false,
        Paint()
          ..color = seg.$3
          ..strokeWidth = 14
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt,
      );
    }

    // Tick marks
    for (int i = 0; i <= 20; i++) {
      final t = i / 20.0;
      final angle = startAngle + sweepAngle * t;
      final isMajor = i % 4 == 0;
      final inner = r - (isMajor ? 20 : 12);
      final outer = r + 2;
      canvas.drawLine(
        Offset(cx + cos(angle) * inner, cy + sin(angle) * inner),
        Offset(cx + cos(angle) * outer, cy + sin(angle) * outer),
        Paint()
          ..color = Colors.white.withOpacity(isMajor ? 0.6 : 0.25)
          ..strokeWidth = isMajor ? 1.5 : 0.8,
      );

      // dB labels on major ticks
      if (isMajor) {
        final db = (t * 120).toInt();
        final lx = cx + cos(angle) * (r - 30);
        final ly = cy + sin(angle) * (r - 30);
        final tp = TextPainter(
          text: TextSpan(text: '$db', style: const TextStyle(color: Colors.white54, fontSize: 9, fontFamily: 'monospace')),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
      }
    }

    // Zone labels
    _drawLabel(canvas, cx, cy, r, 0.10, 'Sessiz');
    _drawLabel(canvas, cx, cy, r, 0.35, 'Konuşma');
    _drawLabel(canvas, cx, cy, r, 0.60, 'Gürültü');
    _drawLabel(canvas, cx, cy, r, 0.92, 'Tehlike');

    // Needle
    final needleAngle = startAngle + sweepAngle * level.clamp(0.0, 1.0);
    final nx = cx + cos(needleAngle) * (r - 18);
    final ny = cy + sin(needleAngle) * (r - 18);

    // Needle shadow
    canvas.drawLine(
      Offset(cx, cy), Offset(nx, ny),
      Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    // Needle body
    canvas.drawLine(
      Offset(cx, cy), Offset(nx, ny),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Center pivot
    canvas.drawCircle(
      Offset(cx, cy), 8,
      Paint()..color = const Color(0xFF333333),
    );
    canvas.drawCircle(
      Offset(cx, cy), 5,
      Paint()..color = const Color(0xFF00FF88),
    );
  }

  void _drawLabel(Canvas canvas, double cx, double cy, double r, double t, String text) {
    final angle = pi + pi * t;
    final lx = cx + cos(angle) * (r - 48);
    final ly = cy + sin(angle) * (r - 48);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white30, fontSize: 8, fontFamily: 'monospace'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(lx, ly);
    canvas.rotate(angle - pi / 2);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.level != level;
}
