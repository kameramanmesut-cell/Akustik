# 🎙 Akustik Dinleyici — Flutter

Harici mikrofon ile duvar/boru içindeki düşük frekanslı sesleri (su kaçağı, patlak boru) dinlemek için Android uygulaması.

## Özellikler

- 🔊 Gerçek zamanlı amplifikasyon (1x–20x) — Kotlin native AudioRecord
- 🎛 Butterworth bandpass filtre (seçilebilir frekans aralığı)
- 📈 Canlı dalga formu (gerçek PCM verisi)
- 📊 FFT frekans spektrumu (2048 nokta)
- 🎯 Analog kadran seviye göstergesi
- 🎧 Kulaklık loopback (mikrofon → kulaklık)
- 💡 Hızlı presetler: Su Kaçağı, Boru Titreşim, Genel

## Teknik Mimari

```
Flutter UI (Dart)
    ↕ MethodChannel + EventChannel
Kotlin Native (MainActivity.kt)
    ├── AudioRecord (44100Hz, 16-bit PCM)
    ├── AGC/NoiseSuppressor devre dışı
    ├── Butterworth IIR bandpass
    ├── Gain + soft clipping (tanh)
    ├── FFT (2048 nokta, Hanning window)
    └── AudioTrack (loopback)
```

## GitHub Actions ile APK Build

Her `git push`ta otomatik APK oluşturulur.

### Kurulum

1. Bu repoyu GitHub'a yükle
2. Actions sekmesini aç → build başlar
3. Build bitti → **Artifacts** bölümünden APK indir

### Manuel build

```bash
flutter pub get
flutter build apk --release
```

APK: `build/app/outputs/flutter-apk/app-release.apk`

## Dosya Yapısı

```
lib/
├── main.dart
├── screens/
│   └── home_screen.dart          # Ana ekran + tüm kontroller
├── widgets/
│   ├── analog_gauge.dart         # Analog kadran (animasyonlu ibre)
│   ├── waveform_widget.dart      # Dalga formu (CustomPainter)
│   └── spectrum_widget.dart      # FFT spektrum (CustomPainter)
└── utils/
    └── audio_service.dart        # MethodChannel/EventChannel köprüsü

android/app/src/main/kotlin/com/akustik/dinleyici/
└── MainActivity.kt               # AudioRecord + FFT + bandpass
```

## Kullanım

1. Harici mikrofonu tak (3.5mm veya USB-C adaptör)
2. **Su Kaçağı** presetini seç (20–300 Hz)
3. Kazancı ayarla (duvar sesi için 8x–16x)
4. **DİNLEMEYE BAŞLA** → mikrofonu yüzeye değdir
5. Spektrumda yeşil alanda aktivite gözlemle
