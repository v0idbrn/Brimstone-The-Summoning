package com.brimstone.brimstone_summoning

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayDeque
import java.util.concurrent.ConcurrentHashMap
import kotlin.concurrent.thread

/**
 * Native PCM sink for Brimstone: The Summoning.
 *
 * The Dart side synthesizes 16-bit PCM WAV buffers and ships them over
 * `com.brimstone.summoning/audio`. This activity decodes the RIFF header once,
 * then feeds `android.media.AudioTrack`:
 *
 *  - one-shots (`play`)  -> a pool of six MODE_STREAM voices, each with its own
 *    writer thread, so overlapping impacts never allocate a new track per shot;
 *  - ambience (`loop`)   -> MODE_STATIC tracks with `setLoopPoints(-1)` for the
 *    seam-free dark choir and the ritual drums.
 *
 * No third-party audio plugin is involved.
 */
class MainActivity : FlutterActivity() {
    private var audioEngine: BrimstoneAudioEngine? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val engine = BrimstoneAudioEngine()
        audioEngine = engine
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "unlock" -> {
                        engine.unlock()
                        result.success(true)
                    }
                    "play" -> {
                        val key = call.argument<String>("key") ?: ""
                        val bytes = call.argument<ByteArray>("bytes")
                        val volume = call.argument<Double>("volume") ?: 1.0
                        if (bytes == null || bytes.isEmpty()) {
                            result.success(false)
                        } else {
                            result.success(engine.playSfx(key, bytes, volume.toFloat()))
                        }
                    }
                    "loop" -> {
                        val key = call.argument<String>("key") ?: ""
                        val bytes = call.argument<ByteArray>("bytes")
                        val volume = call.argument<Double>("volume") ?: 1.0
                        if (bytes == null || bytes.isEmpty()) {
                            result.success(false)
                        } else {
                            result.success(engine.startLoop(key, bytes, volume.toFloat()))
                        }
                    }
                    "stopLoop" -> {
                        engine.stopLoop(call.argument<String>("key") ?: "")
                        result.success(true)
                    }
                    "stopAll" -> {
                        engine.stopAll()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        audioEngine?.release()
        audioEngine = null
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "com.brimstone.summoning/audio"
    }
}

/** Decoded mono/stereo 16-bit PCM payload from a RIFF/WAVE buffer. */
private class WavPcm(
    val sampleRate: Int,
    val channels: Int,
    val pcm: ByteArray,
) {
    val frameCount: Int
        get() = if (channels <= 0) 0 else pcm.size / (2 * channels)
}

private object WavDecoder {
    fun decode(bytes: ByteArray): WavPcm? {
        if (bytes.size < 44) return null
        if (!tag(bytes, 0, "RIFF") || !tag(bytes, 8, "WAVE")) return null

        var sampleRate = 44100
        var channels = 1
        var bitsPerSample = 16
        var dataOffset = -1
        var dataLength = 0

        var cursor = 12
        while (cursor + 8 <= bytes.size) {
            val id = String(bytes, cursor, 4, Charsets.US_ASCII)
            val size = readInt(bytes, cursor + 4)
            val body = cursor + 8
            if (size < 0 || body + size > bytes.size) {
                // Some encoders pad the last chunk; trust the declared size for
                // "data" and stop otherwise.
                if (id == "data") {
                    dataOffset = body
                    dataLength = bytes.size - body
                }
                break
            }
            when (id) {
                "fmt " -> {
                    channels = readShort(bytes, body + 2)
                    sampleRate = readInt(bytes, body + 4)
                    bitsPerSample = readShort(bytes, body + 14)
                }
                "data" -> {
                    dataOffset = body
                    dataLength = size
                }
            }
            if (id == "data") break
            cursor = body + size + (size and 1)
        }

        if (dataOffset < 0 || dataLength <= 0) {
            // Fallback: engine output is always canonical 44-byte RIFF mono 44.1k.
            if (bytes.size <= 44) return null
            dataOffset = 44
            dataLength = bytes.size - 44
        }
        if (bitsPerSample != 16 || channels <= 0 || sampleRate <= 0) return null

        val pcm = ByteArray(dataLength)
        System.arraycopy(bytes, dataOffset, pcm, 0, dataLength)
        return WavPcm(sampleRate, channels, pcm)
    }

    private fun tag(bytes: ByteArray, offset: Int, expected: String): Boolean {
        if (offset + 4 > bytes.size) return false
        for (i in 0 until 4) {
            if (bytes[offset + i].toInt() and 0xFF != expected[i].code) return false
        }
        return true
    }

    private fun readInt(bytes: ByteArray, offset: Int): Int =
        (bytes[offset].toInt() and 0xFF) or
            ((bytes[offset + 1].toInt() and 0xFF) shl 8) or
            ((bytes[offset + 2].toInt() and 0xFF) shl 16) or
            ((bytes[offset + 3].toInt() and 0xFF) shl 24)

    private fun readShort(bytes: ByteArray, offset: Int): Int =
        (bytes[offset].toInt() and 0xFF) or ((bytes[offset + 1].toInt() and 0xFF) shl 8)
}

/** Owns every `AudioTrack` the game is currently sounding. */
private class BrimstoneAudioEngine {
    private val handler = Handler(Looper.getMainLooper())
    private val voices = List(VOICE_COUNT) { Voice() }
    private var nextVoice = 0
    private val loops = ConcurrentHashMap<String, LoopHandle>()
    private val decoded = ConcurrentHashMap<String, WavPcm>()
    private var released = false

    fun unlock() {
        // A muted zero-length track warms the audio HAL so the first impact is
        // not late (Android otherwise initialises the mixer on first play()).
        if (released) return
        runCatching {
            val silence = AudioTrack(
                AudioManager.STREAM_MUSIC,
                22050,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                2048,
                AudioTrack.MODE_STREAM,
            )
            silence.release()
        }
    }

    fun playSfx(key: String, bytes: ByteArray, volume: Float): Boolean {
        if (released) return false
        val wav = decodedFor(key, bytes) ?: return false
        val voice = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.size
        voice.play(wav, volume)
        return true
    }

    fun startLoop(key: String, bytes: ByteArray, volume: Float): Boolean {
        if (released) return false
        val wav = decodedFor(key, bytes) ?: return false
        stopLoop(key)
        val handle = LoopHandle.create(wav, volume) ?: return false
        loops[key] = handle
        return true
    }

    fun stopLoop(key: String) {
        loops.remove(key)?.release()
    }

    fun stopAll() {
        for (voice in voices) voice.stop()
        val keys = loops.keys.toList()
        for (key in keys) stopLoop(key)
        decoded.clear()
    }

    fun release() {
        if (released) return
        released = true
        stopAll()
        handler.removeCallbacksAndMessages(null)
    }

    private fun decodedFor(key: String, bytes: ByteArray): WavPcm? {
        decoded[key]?.let { return it }
        val wav = WavDecoder.decode(bytes) ?: return null
        if (decoded.size > MAX_CACHED_SOUNDS) decoded.clear()
        decoded[key] = wav
        return wav
    }

    companion object {
        private const val VOICE_COUNT = 6
        private const val MAX_CACHED_SOUNDS = 32
    }
}

/** One reusable streaming voice; its writer thread is parked on an ArrayDeque. */
private class Voice {
    private val queue = ArrayDeque<Job>()
    private val lock = Object()
    private var track: AudioTrack? = null
    private var sampleRate = -1
    private var channelCount = -1
    private var stopped = false

    private class Job(val wav: WavPcm, val volume: Float)

    init {
        thread(isDaemon = true, name = "brimstone-sfx-voice") {
            while (true) {
                val job: Job
                synchronized(lock) {
                    while (true) {
                        if (queue.isNotEmpty()) break
                        if (stopped) return@thread
                        lock.wait()
                    }
                    job = queue.removeFirst()
                }
                runCatching { render(job) }
            }
        }
    }

    fun play(wav: WavPcm, volume: Float) {
        synchronized(lock) {
            // A voice keeps at most one pending shot: bursts stay bounded.
            queue.clear()
            queue.addLast(Job(wav, volume))
            lock.notifyAll()
        }
    }

    fun stop() {
        synchronized(lock) {
            queue.clear()
            lock.notifyAll()
        }
        runCatching {
            track?.pause()
            track?.flush()
        }
    }

    private fun render(job: Job) {
        val current = ensureTrack(job.wav.sampleRate, job.wav.channels) ?: return
        current.setVolume(job.volume.coerceIn(0f, 1f))
        current.pause()
        current.flush()
        current.play()
        var offset = 0
        while (offset < job.wav.pcm.size) {
            val written = current.write(job.wav.pcm, offset, job.wav.pcm.size - offset)
            if (written <= 0) break
            offset += written
        }
    }

    private fun ensureTrack(rate: Int, channels: Int): AudioTrack? {
        if (track != null && rate == sampleRate && channels == channelCount) return track
        runCatching { track?.release() }
        track = null
        val channelMask =
            if (channels >= 2) AudioFormat.CHANNEL_OUT_STEREO else AudioFormat.CHANNEL_OUT_MONO
        val minBuffer = AudioTrack.getMinBufferSize(
            rate,
            channelMask,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minBuffer <= 0) return null
        val bufferSize = maxOf(minBuffer, if (channels >= 2) rate * 4 else rate * 2)
        val created =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                AudioTrack.Builder()
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_GAME)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build(),
                    )
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(rate)
                            .setChannelMask(channelMask)
                            .build(),
                    )
                    .setBufferSizeInBytes(bufferSize)
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .build()
            } else {
                @Suppress("DEPRECATION")
                AudioTrack(
                    AudioManager.STREAM_MUSIC,
                    rate,
                    channelMask,
                    AudioFormat.ENCODING_PCM_16BIT,
                    bufferSize,
                    AudioTrack.MODE_STREAM,
                )
            }
        track = created
        sampleRate = rate
        channelCount = channels
        return created
    }
}

/** A looping ambient bed backed by a fully loaded MODE_STATIC track. */
private class LoopHandle private constructor(private val track: AudioTrack) {
    fun release() {
        runCatching {
            track.stop()
            track.release()
        }
    }

    companion object {
        fun create(wav: WavPcm, volume: Float): LoopHandle? {
            if (wav.frameCount <= 0) return null
            val channelMask =
                if (wav.channels >= 2) AudioFormat.CHANNEL_OUT_STEREO else AudioFormat.CHANNEL_OUT_MONO
            val created = runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    AudioTrack.Builder()
                        .setAudioAttributes(
                            AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_GAME)
                                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                                .build(),
                        )
                        .setAudioFormat(
                            AudioFormat.Builder()
                                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                                .setSampleRate(wav.sampleRate)
                                .setChannelMask(channelMask)
                                .build(),
                        )
                        .setBufferSizeInBytes(wav.pcm.size)
                        .setTransferMode(AudioTrack.MODE_STATIC)
                        .build()
                } else {
                    @Suppress("DEPRECATION")
                    AudioTrack(
                        AudioManager.STREAM_MUSIC,
                        wav.sampleRate,
                        channelMask,
                        AudioFormat.ENCODING_PCM_16BIT,
                        wav.pcm.size,
                        AudioTrack.MODE_STATIC,
                    )
                }
            }.getOrNull() ?: return null

            val written = created.write(wav.pcm, 0, wav.pcm.size)
            if (written <= 0) {
                runCatching { created.release() }
                return null
            }
            created.setVolume(volume.coerceIn(0f, 1f))
            // Seam-free: frame-accurate loop over the whole buffer.
            created.setLoopPoints(0, wav.frameCount, -1)
            created.play()
            return LoopHandle(created)
        }
    }
}
