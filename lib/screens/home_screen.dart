import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../utils/audio_service.dart';
import '../widgets/waveform_widget.dart';
import '../widgets/spectrum_widget.dart';
import '../widgets/analog_gauge.dart';
import 'dart:math';

const kFreqPresets = [
  {'label': 'Su Kaçağı',       'low': 20.0,  'high': 300.0},
  {'label': 'Boru Titreşim',   'low': 50.0,  'high': 500.0},
  {'label': 'Genel',           'low': 20.0,  'high': 2000.0},
  {'label': 'Tüm Aralık',      'low': 20.0,  'high': 8000.0},
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _audio = AudioService();

  bool   _isRunning  = false;
  bool   _loopback   = true;
  double _gain       = 5.0;
  double _lowFreq    = 20.0;
  double _highFreq   = 300.0;

  // Mikrofon bilgisi
  bool   _hasExternal = false;
  String _micName     = 'Dahili Mikrofon';
  String _micType     = 'Dahili';

  List<double> _waveform = List.filled(256, 0.0);
  List<double> _spectrum = List.filled(128, 0.0);
  double _level = 0.0;

  final _gainOptions = [1.0, 3.0, 5.0, 8.0, 12.0, 16.0, 20.0];
  final _lowOptions  = [20.0, 50.0, 80.0, 100.0, 200.0];
  final _highOptions = [100.0, 300.0, 500.0, 1000.0, 2000.0];

  double get _dbValue {
    if (_level <= 0) return double.negativeInfinity;
    return 20 * log(_level) / ln10;
  }

  @override
  void initState() {
    super.initState();
    // Ses verisi stream
    _audio.stream.listen((data) {
      if (!mounted) return;
      setState(() {
        _waveform = data.waveform;
        _spectrum = data.spectrum;
        _level    = data.level;
      });
    });
    // Mikrofon cihaz olayları
    _audio.micStream.listen((event) {
      if (!mounted) return;
      setState(() {
        _hasExternal = event.isExternal;
        _micName     = event.deviceName;
        _micType     = event.deviceType;
      });
    });
    // İlk açılışta bağlı mikrofonu kontrol et
    _checkMic();
  }

  Future<void> _checkMic() async {
    try {
      final info = await _audio.getMicInfo();
      if (!mounted) return;
      setState(() {
        _hasExternal = info['hasExternal'] as bool? ?? false;
        _micName     = info['deviceName'] as String? ?? 'Dahili Mikrofon';
        _micType     = info['deviceType'] as String? ?? 'Dahili';
      });
    } catch (_) {}
  }

  Future<void> _toggleAudio() async {
    if (_isRunning) {
      await _audio.stop();
      WakelockPlus.disable();
      setState(() { _isRunning = false; _level = 0; });
    } else {
      await _audio.setGain(_gain);
      await _audio.setLowFreq(_lowFreq);
      await _audio.setHighFreq(_highFreq);
      await _audio.setLoopback(_loopback);
      await _audio.start();
      WakelockPlus.enable();
      setState(() => _isRunning = true);
    }
  }

  @override
  void dispose() {
    _audio.stop();
    _audio.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020802),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildMicInfoCard(),
              const SizedBox(height: 12),
              _buildGaugeCard(),
              const SizedBox(height: 12),
              _buildWaveformCard(),
              const SizedBox(height: 12),
              _buildSpectrumCard(),
              const SizedBox(height: 12),
              _buildPresetsCard(),
              const SizedBox(height: 12),
              _buildGainCard(),
              const SizedBox(height: 12),
              _buildFreqCard(),
              const SizedBox(height: 12),
              _buildLoopbackCard(),
              const SizedBox(height: 16),
              _buildRecordButton(),
              const SizedBox(height: 12),
              _buildTip(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('🎙 AKUSTİK DİNLEYİCİ',
          style: TextStyle(color: Color(0xFF00FF88), fontSize: 15,
            fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 2)),
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isRunning ? const Color(0xFF00FF88) : const Color(0xFF333333),
          ),
        ),
      ],
    );
  }

  Widget _buildMicInfoCard() {
    final color  = _hasExternal ? const Color(0xFF00FF88) : const Color(0xFFFFAA00);
    final icon   = _hasExternal ? '🎙' : '📵';
    final status = _hasExternal ? 'HARİCİ MİKROFON ALGILANDI' : 'DAHİLİ MİKROFON';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _hasExternal ? const Color(0xFF002A10) : const Color(0xFF1A1000),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _hasExternal ? const Color(0xFF00AA44) : const Color(0xFF664400)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status,
                  style: TextStyle(color: color, fontSize: 10,
                    fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 2),
                Text(_micType,
                  style: const TextStyle(color: Color(0xFF3A7A3A), fontSize: 10, fontFamily: 'monospace')),
              ],
            ),
          ),
          GestureDetector(
            onTap: _checkMic,
            child: const Text('↻', style: TextStyle(color: Color(0xFF3A7A3A), fontSize: 18)),
          ),
        ],
      ),
    );
  }

  Widget _buildGaugeCard() {
    return _card(
      title: 'SEVİYE GÖSTERGESI',
      child: AnalogGauge(level: _level, dbValue: _dbValue),
    );
  }

  Widget _buildWaveformCard() {
    return _card(
      title: 'DALGA FORMU',
      child: WaveformWidget(waveform: _waveform),
    );
  }

  Widget _buildSpectrumCard() {
    return _card(
      title: 'FREKANS SPEKTRUMU',
      child: Column(
        children: [
          SpectrumWidget(spectrum: _spectrum, lowFreq: _lowFreq, highFreq: _highFreq),
          const SizedBox(height: 6),
          Text(
            'Filtre: ${_lowFreq.toInt()} Hz – ${_highFreq >= 1000 ? "${(_highFreq / 1000).toStringAsFixed(1)}k" : _highFreq.toInt()} Hz  (yeşil alan)',
            style: const TextStyle(color: Color(0xFF2A5A2A), fontSize: 10, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsCard() {
    return _card(
      title: 'HIZLI PRESET',
      child: Wrap(
        spacing: 8, runSpacing: 8,
        children: kFreqPresets.map((p) {
          final active = _lowFreq == p['low'] && _highFreq == p['high'];
          return _chip(
            label: p['label'] as String,
            active: active,
            onTap: () async {
              setState(() { _lowFreq = p['low'] as double; _highFreq = p['high'] as double; });
              if (_isRunning) {
                await _audio.setLowFreq(_lowFreq);
                await _audio.setHighFreq(_highFreq);
              }
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGainCard() {
    return _card(
      title: 'AMPLİFİKASYON (KAZANÇ)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _gainOptions.map((g) {
              return _chip(
                label: '${g.toInt()}x',
                active: _gain == g,
                onTap: () async {
                  setState(() => _gain = g);
                  if (_isRunning) await _audio.setGain(g);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Text(
            _gain <= 3 ? 'Düşük – yakın sesler' :
            _gain <= 8 ? 'Orta – duvar içi sesler' :
            'Yüksek – çok zayıf sesler',
            style: const TextStyle(color: Color(0xFF2A5A2A), fontSize: 10, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildFreqCard() {
    return _card(
      title: 'FREKANS SINIRI (HASSAS)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ALT SINIR', style: TextStyle(color: Color(0xFF2A5A2A), fontSize: 10, fontFamily: 'monospace', letterSpacing: 1)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _lowOptions.map((f) => _chip(
              label: '${f.toInt()}',
              active: _lowFreq == f,
              onTap: () async {
                setState(() => _lowFreq = f);
                if (_isRunning) await _audio.setLowFreq(f);
              },
            )).toList(),
          ),
          const SizedBox(height: 12),
          const Text('ÜST SINIR', style: TextStyle(color: Color(0xFF2A5A2A), fontSize: 10, fontFamily: 'monospace', letterSpacing: 1)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _highOptions.map((f) => _chip(
              label: f >= 1000 ? '${(f / 1000).toStringAsFixed(0)}k' : '${f.toInt()}',
              active: _highFreq == f,
              onTap: () async {
                setState(() => _highFreq = f);
                if (_isRunning) await _audio.setHighFreq(f);
              },
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoopbackCard() {
    return _card(
      title: 'KULAKLИК LOOPBACK',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Mikrofonu kulaklığa ilet',
            style: TextStyle(color: Color(0xFF3A7A3A), fontSize: 13, fontFamily: 'monospace')),
          Switch(
            value: _loopback,
            onChanged: (v) async {
              setState(() => _loopback = v);
              if (_isRunning) await _audio.setLoopback(v);
            },
            activeColor: const Color(0xFF00FF88),
            inactiveThumbColor: const Color(0xFF333333),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: _toggleAudio,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: _isRunning ? const Color(0xFF1A0A0A) : const Color(0xFF0A1F0A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isRunning ? const Color(0xFFFF4444) : const Color(0xFF00AA55),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_isRunning ? '⏹' : '⏺', style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Text(
              _isRunning ? 'DURDUR' : 'DİNLEMEYE BAŞLA',
              style: const TextStyle(color: Color(0xFF00FF88), fontSize: 16,
                fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTip() {
    return Text(
      '💡 Harici mikrofonu takın, ardından dinleme başlatın.\nBoru/su kaçağı için "Su Kaçağı" presetini kullanın.',
      textAlign: TextAlign.center,
      style: const TextStyle(color: Color(0xFF2A4A2A), fontSize: 11, fontFamily: 'monospace', height: 1.6),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF080F08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1A2A1A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF3A7A3A), fontSize: 10,
            fontFamily: 'monospace', letterSpacing: 2)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _chip({required String label, required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF003A10) : const Color(0xFF0A150A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? const Color(0xFF00FF88) : const Color(0xFF1A3A1A)),
        ),
        child: Text(label,
          style: TextStyle(
            color: active ? const Color(0xFF00FF88) : const Color(0xFF3A7A3A),
            fontSize: 12, fontFamily: 'monospace',
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
