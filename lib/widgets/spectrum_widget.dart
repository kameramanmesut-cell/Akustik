import 'package:flutter/material.dart';

class SpectrumWidget extends StatelessWidget {
  final List<double> spectrum;
  final double lowFreq;
  final double highFreq;

  const SpectrumWidget({
    super.key,
    required this.spectrum,
    required this.lowFreq,
    required this.highFreq,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF060F06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1A3A1A)),
      ),
      child: CustomPaint(
        painter: _SpectrumPainter(spectrum, lowFreq, highFreq),
        size: const Size(double.infinity, 130),
      ),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  final List<double> spectrum;
  final double lowFreq, highFreq;
  static const sampleRate = 44100.0;

  _SpectrumPainter(this.spectrum, this.lowFreq, this.highFreq);

  @override
  void paint(Canvas canvas, Size size) {
    if (spectrum.isEmpty) return;

    final chartH = size.height - 18;
    final numBins = spectrum.length;

    // Bandpass highlight
    final lowBin  = (lowFreq  / (sampleRate / 2) * numBins).toInt();
    final highBin = (highFreq / (sampleRate / 2) * numBins).toInt();
    final hx = (lowBin  / numBins) * size.width;
    final hw = ((highBin - lowBin) / numBins) * size.width;
    canvas.drawRect(
      Rect.fromLTWH(hx, 0, hw, chartH),
      Paint()..color = const Color(0xFF00FF88).withOpacity(0.06),
    );

    // Bars
    final barW = size.width / numBins;
    for (int i = 0; i < numBins; i++) {
      final barH = (spectrum[i].clamp(0.0, 1.0) * chartH);
      final inRange = i >= lowBin && i <= highBin;
      canvas.drawRect(
        Rect.fromLTWH(
          i * barW, chartH - barH,
          (barW - 0.5).clamp(1, barW), barH,
        ),
        Paint()
          ..color = inRange
              ? const Color(0xFF00FF88).withOpacity(0.85)
              : const Color(0xFF1A4A2A).withOpacity(0.5),
      );
    }

    // Axis
    canvas.drawLine(
      Offset(0, chartH), Offset(size.width, chartH),
      Paint()..color = const Color(0xFF1A3A1A)..strokeWidth = 1,
    );

    // Freq labels
    final labels = [50, 100, 200, 500, 1000, 5000, 10000];
    final ts = const TextStyle(color: Color(0xFF3A7A3A), fontSize: 8, fontFamily: 'monospace');
    for (final f in labels) {
      final x = (f / (sampleRate / 2)) * size.width;
      if (x > size.width - 10) continue;
      final label = f >= 1000 ? '${f ~/ 1000}k' : '$f';
      final tp = TextPainter(text: TextSpan(text: label, style: ts), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, chartH + 3));
    }
  }

  @override
  bool shouldRepaint(_SpectrumPainter old) =>
      old.spectrum != spectrum || old.lowFreq != lowFreq || old.highFreq != highFreq;
}
