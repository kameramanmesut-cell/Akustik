package com.akustik.dinleyici

import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.*
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {

    companion object {
        const val METHOD_CHANNEL = "com.akustik.dinleyici/audio"
        const val EVENT_CHANNEL  = "com.akustik.dinleyici/audioStream"
        const val SAMPLE_RATE    = 44100
        const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        const val AUDIO_FORMAT   = AudioFormat.ENCODING_PCM_16BIT
        const val FFT_SIZE       = 2048
        const val WAVEFORM_SIZE  = 256
    }

    private var audioRecord: AudioRecord? = null
    private var audioTrack: AudioTrack?   = null
    private var isRunning = false
    private var gainFactor   = 5.0f
    private var lowFreqHz    = 20.0f
    private var highFreqHz   = 500.0f
    private var loopbackOn   = true

    private var eventSink: EventChannel.EventSink? = null

    // IIR bandpass state
    private var bpX1 = 0f; private var bpX2 = 0f
    private var bpY1 = 0f; private var bpY2 = 0f

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Method Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start"       -> { startAudio(); result.success(null) }
                    "stop"        -> { stopAudio();  result.success(null) }
                    "setGain"     -> { gainFactor = (call.argument<Double>("gain") ?: 5.0).toFloat(); result.success(null) }
                    "setLowFreq"  -> { lowFreqHz  = (call.argument<Double>("low")  ?: 20.0).toFloat(); resetFilter(); result.success(null) }
                    "setHighFreq" -> { highFreqHz = (call.argument<Double>("high") ?: 500.0).toFloat(); resetFilter(); result.success(null) }
                    "setLoopback" -> { loopbackOn = call.argument<Boolean>("enabled") ?: true; result.success(null) }
                    "getMicInfo"  -> { result.success(getMicInfo()) }
                    else          -> result.notImplemented()
                }
            }

        // Event Channel — streams audio data to Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) { eventSink = sink }
                override fun onCancel(args: Any?) { eventSink = null }
            })
    }

    // ── Bağlı mikrofon cihazlarını listele ──────────────────────
    private fun getMicInfo(): Map<String, Any> {
        val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)

        val external = devices.firstOrNull { dev ->
            dev.type == AudioDeviceInfo.TYPE_WIRED_HEADSET   ||
            dev.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES ||
            dev.type == AudioDeviceInfo.TYPE_USB_DEVICE       ||
            dev.type == AudioDeviceInfo.TYPE_USB_HEADSET
        }

        return mapOf(
            "hasExternal"  to (external != null),
            "deviceName"   to (external?.productName?.toString() ?: "Dahili Mikrofon"),
            "deviceType"   to when (external?.type) {
                AudioDeviceInfo.TYPE_WIRED_HEADSET    -> "3.5mm Kulaklık/Mikrofon"
                AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "3.5mm Kulaklık"
                AudioDeviceInfo.TYPE_USB_DEVICE       -> "USB Mikrofon"
                AudioDeviceInfo.TYPE_USB_HEADSET      -> "USB Kulaklık/Mikrofon"
                else                                  -> "Dahili Mikrofon"
            }
        )
    }

    // ── Harici mikrofonu AudioRecord'a bağla ────────────────────
    private fun attachExternalMic(rec: AudioRecord) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)

        val externalMic = devices.firstOrNull { dev ->
            dev.type == AudioDeviceInfo.TYPE_WIRED_HEADSET   ||
            dev.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES ||
            dev.type == AudioDeviceInfo.TYPE_USB_DEVICE       ||
            dev.type == AudioDeviceInfo.TYPE_USB_HEADSET
        }

        if (externalMic != null) {
            rec.preferredDevice = externalMic
            // UI'ya bildir
            runOnUiThread {
                eventSink?.success(mapOf(
                    "micEvent" to "external",
                    "deviceName" to (externalMic.productName?.toString() ?: "Harici Mikrofon"),
                    "deviceType" to when (externalMic.type) {
                        AudioDeviceInfo.TYPE_WIRED_HEADSET    -> "3.5mm Kulaklık/Mikrofon"
                        AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "3.5mm Kulaklık"
                        AudioDeviceInfo.TYPE_USB_DEVICE       -> "USB Mikrofon"
                        AudioDeviceInfo.TYPE_USB_HEADSET      -> "USB Kulaklık/Mikrofon"
                        else                                  -> "Harici"
                    }
                ))
            }
        } else {
            // Harici yok — dahili ile devam et, UI'yı bildir
            runOnUiThread {
                eventSink?.success(mapOf(
                    "micEvent"   to "internal",
                    "deviceName" to "Dahili Mikrofon",
                    "deviceType" to "Dahili"
                ))
            }
        }
    }

    private fun startAudio() {
        if (isRunning) return
        val bufSize = maxOf(
            AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT) * 2,
            FFT_SIZE * 2
        )

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.UNPROCESSED.let {
                // UNPROCESSED = ham sinyal, AGC/EQ yok — harici mikrofon için ideal
                // API 24+ gerekli, yoksa MIC fallback
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) it
                else MediaRecorder.AudioSource.MIC
            },
            SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT, bufSize
        ).also { rec ->
            // AGC ve Noise Suppressor'ı kapat
            if (AutomaticGainControl.isAvailable()) {
                AutomaticGainControl.create(rec.audioSessionId)?.enabled = false
            }
            if (NoiseSuppressor.isAvailable()) {
                NoiseSuppressor.create(rec.audioSessionId)?.enabled = false
            }
            // Harici mikrofonu bağla
            attachExternalMic(rec)
        }

        // AudioTrack for loopback
        val outBufSize = AudioTrack.getMinBufferSize(SAMPLE_RATE,
            AudioFormat.CHANNEL_OUT_MONO, AUDIO_FORMAT)
        audioTrack = AudioTrack(
            AudioManager.STREAM_MUSIC, SAMPLE_RATE,
            AudioFormat.CHANNEL_OUT_MONO, AUDIO_FORMAT,
            outBufSize, AudioTrack.MODE_STREAM
        )

        resetFilter()
        isRunning = true
        audioRecord?.startRecording()
        audioTrack?.play()

        thread(isDaemon = true, name = "AudioProcessThread") {
            val buf = ShortArray(FFT_SIZE)
            while (isRunning) {
                val read = audioRecord?.read(buf, 0, FFT_SIZE) ?: break
                if (read <= 0) continue

                // 1. Convert to float [-1, 1]
                val float = FloatArray(read) { buf[it] / 32768f }

                // 2. Bandpass filter
                val filtered = applyBandpass(float)

                // 3. Gain + soft clip
                val gained = FloatArray(read) { tanh(filtered[it] * gainFactor) }

                // 4. Loopback to speaker
                if (loopbackOn) {
                    val outBuf = ShortArray(read) { (gained[it] * 32767f).toInt().toShort() }
                    audioTrack?.write(outBuf, 0, read)
                }

                // 5. Waveform (downsample to WAVEFORM_SIZE)
                val waveform = DoubleArray(WAVEFORM_SIZE) { i ->
                    val idx = (i.toFloat() / WAVEFORM_SIZE * read).toInt()
                    gained[idx.coerceIn(0, read - 1)].toDouble()
                }

                // 6. FFT spectrum (128 bins)
                val spectrum = computeFFT(gained)

                // 7. RMS level
                val rms = sqrt(gained.map { it * it }.average())

                // 8. Send to Flutter on main thread
                runOnUiThread {
                    eventSink?.success(mapOf(
                        "waveform"  to waveform.toList(),
                        "spectrum"  to spectrum.toList(),
                        "level"     to rms
                    ))
                }
            }
        }
    }

    private fun stopAudio() {
        isRunning = false
        try { audioRecord?.stop(); audioRecord?.release() } catch (_: Exception) {}
        try { audioTrack?.stop();  audioTrack?.release()  } catch (_: Exception) {}
        audioRecord = null
        audioTrack  = null
        resetFilter()
    }

    private fun resetFilter() { bpX1=0f; bpX2=0f; bpY1=0f; bpY2=0f }

    // Butterworth bandpass IIR
    private fun applyBandpass(input: FloatArray): FloatArray {
        val sr = SAMPLE_RATE.toFloat()
        val low  = (lowFreqHz  / (sr / 2f)).coerceIn(0.001f, 0.999f)
        val high = (highFreqHz / (sr / 2f)).coerceIn(0.001f, 0.999f)
        val f1 = tan(PI.toFloat() * low)
        val f2 = tan(PI.toFloat() * high)
        val bw = f2 - f1
        val q  = sqrt(f1 * f2) / bw
        val norm = 1f / (1f + q + f1 * f2)
        val b0 =  bw * norm
        val b2 = -bw * norm
        val a1 = 2f * (f1 * f2 - 1f) * norm
        val a2 = (1f - q + f1 * f2) * norm

        val out = FloatArray(input.size)
        for (i in input.indices) {
            val x0 = input[i]
            val y0 = b0 * x0 + b2 * bpX2 - a1 * bpY1 - a2 * bpY2
            bpX2 = bpX1; bpX1 = x0
            bpY2 = bpY1; bpY1 = y0
            out[i] = y0
        }
        return out
    }

    // Real FFT → 128 magnitude bins
    private fun computeFFT(signal: FloatArray): DoubleArray {
        val n = FFT_SIZE
        val real = DoubleArray(n) { if (it < signal.size) signal[it].toDouble() else 0.0 }
        val imag = DoubleArray(n)

        // Hanning window
        for (i in 0 until n) real[i] *= 0.5 * (1 - cos(2 * PI * i / (n - 1)))

        fftInPlace(real, imag, n)

        val half = n / 2
        val mag  = DoubleArray(half) { sqrt(real[it].pow(2) + imag[it].pow(2)) / n }

        // Downsample to 128 bins
        val bins = 128
        val ratio = half.toDouble() / bins
        return DoubleArray(bins) { i ->
            val start = (i * ratio).toInt()
            val end   = ((i + 1) * ratio).toInt().coerceAtMost(half)
            if (end <= start) mag[start] * 6
            else mag.slice(start until end).average() * 6
        }
    }

    private fun fftInPlace(re: DoubleArray, im: DoubleArray, n: Int) {
        var j = 0
        for (i in 1 until n) {
            var bit = n shr 1
            while (j and bit != 0) { j = j xor bit; bit = bit shr 1 }
            j = j xor bit
            if (i < j) { re[i] = re[j].also { re[j] = re[i] }; im[i] = im[j].also { im[j] = im[i] } }
        }
        var len = 2
        while (len <= n) {
            val ang = -2 * PI / len
            val wRe = cos(ang); val wIm = sin(ang)
            var i = 0
            while (i < n) {
                var cRe = 1.0; var cIm = 0.0
                for (k in 0 until len / 2) {
                    val uRe = re[i+k]; val uIm = im[i+k]
                    val vRe = re[i+k+len/2]*cRe - im[i+k+len/2]*cIm
                    val vIm = re[i+k+len/2]*cIm + im[i+k+len/2]*cRe
                    re[i+k] = uRe+vRe; im[i+k] = uIm+vIm
                    re[i+k+len/2] = uRe-vRe; im[i+k+len/2] = uIm-vIm
                    val nr = cRe*wRe - cIm*wIm; cIm = cRe*wIm + cIm*wRe; cRe = nr
                }
                i += len
            }
            len = len shl 1
        }
    }

    override fun onDestroy() { stopAudio(); super.onDestroy() }
}
