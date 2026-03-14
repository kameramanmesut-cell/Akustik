import 'dart:async';
import 'package:flutter/services.dart';

class AudioService {
  static const _method = MethodChannel('com.akustik.dinleyici/audio');
  static const _event  = EventChannel('com.akustik.dinleyici/audioStream');

  StreamSubscription? _sub;
  final _dataController = StreamController<AudioData>.broadcast();
  final _micController  = StreamController<MicEvent>.broadcast();

  Stream<AudioData> get stream    => _dataController.stream;
  Stream<MicEvent>  get micStream => _micController.stream;

  Future<void> start() async {
    await _method.invokeMethod('start');
    _sub = _event.receiveBroadcastStream().listen((data) {
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        // Mikrofon cihaz olayı — ses verisi değil
        if (m.containsKey('micEvent')) {
          _micController.add(MicEvent(
            isExternal: m['micEvent'] == 'external',
            deviceName: m['deviceName'] ?? '',
            deviceType: m['deviceType'] ?? '',
          ));
          return;
        }
        _dataController.add(AudioData.fromMap(m));
      }
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    await _method.invokeMethod('stop');
  }

  Future<void> setGain(double gain) =>
      _method.invokeMethod('setGain', {'gain': gain});

  Future<void> setLowFreq(double hz) =>
      _method.invokeMethod('setLowFreq', {'low': hz});

  Future<void> setHighFreq(double hz) =>
      _method.invokeMethod('setHighFreq', {'high': hz});

  Future<void> setLoopback(bool enabled) =>
      _method.invokeMethod('setLoopback', {'enabled': enabled});

  Future<Map<String, dynamic>> getMicInfo() async {
    final result = await _method.invokeMethod('getMicInfo');
    return Map<String, dynamic>.from(result);
  }

  void dispose() {
    _sub?.cancel();
    _dataController.close();
    _micController.close();
  }
}

class MicEvent {
  final bool isExternal;
  final String deviceName;
  final String deviceType;
  MicEvent({required this.isExternal, required this.deviceName, required this.deviceType});
}

class AudioData {
  final List<double> waveform;
  final List<double> spectrum;
  final double level;

  AudioData({
    required this.waveform,
    required this.spectrum,
    required this.level,
  });

  factory AudioData.fromMap(Map<String, dynamic> m) {
    return AudioData(
      waveform: List<double>.from(m['waveform'] ?? []),
      spectrum: List<double>.from(m['spectrum'] ?? []),
      level:    (m['level'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
