import 'package:flutter/material.dart';
import 'dart:math';

class WaveformWidget extends StatelessWidget {
  final List<double> waveform;
  const WaveformWidget({super.key, required this.waveform});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF060F06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1A3A1A)),
      ),
      child: CustomPaint(
        painter: _WaveformPainter(waveform),
        size: const Size(double.infinity, 110),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> waveform;
  _WaveformPainter(this.waveform);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1A3A1A)
      ..strokeWidth = 0.5;

    // Grid lines
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), gridPaint..strokeWidth = 1);
    canvas.drawLine(Offset(0, size.height / 4), Offset(size.width, size.height / 4), gridPaint..strokeWidth = 0.5);
    canvas.drawLine(Offset(0, size.height * 3 / 4), Offset(size.width, size.height * 3 / 4), gridPaint..strokeWidth = 0.5);

    if (waveform.isEmpty) return;

    final wavePaint = Paint()
      ..color = const Color(0xFF00FF88)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < waveform.length; i++) {
      final x = (i / (waveform.length - 1)) * size.width;
      final y = size.height / 2 - waveform[i] * (size.height / 2 - 4);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, wavePaint);

    // Labels
    final textStyle = const TextStyle(color: Color(0xFF3A7A3A), fontSize: 9, fontFamily: 'monospace');
    for (final label in ['+1.0', '0', '-1.0']) {
      final y = label == '+1.0' ? 8.0 : label == '0' ? size.height / 2 + 4 : size.height - 4;
      TextPainter(text: TextSpan(text: label, style: textStyle), textDirection: TextDirection.ltr)
        ..layout()
        ..paint(canvas, Offset(4, y));
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.waveform != waveform;
}
